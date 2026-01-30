#!/usr/bin/env zsh
# 10-claude-config.sh — Clone claude-code-backup repo, restore config, optional auto-sync

step "Claude Code Config"

BACKUP_REPO="$HOME/claude-code-backup"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
PLIST_LABEL="com.user.claude-code-sync"
PLIST_FILE="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

# ── Guard: gh CLI ──────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  warn "gh CLI not found — skipping Claude config restore (install gh via Homebrew first)"
  return 0
fi

# ── Guard: gh authenticated ────────────────────────────────────────────────
if ! gh auth status &>/dev/null 2>&1; then
  warn "gh not authenticated — skipping Claude config restore (run 'gh auth login' first)"
  return 0
fi

# ── Phase 1: Clone repo ───────────────────────────────────────────────────
local _clone_needs_install=0
if [[ -d "$BACKUP_REPO/.git" ]]; then
  if is_force_install; then
    log "Force mode: pulling latest claude-code-backup"
    if is_dry_run; then
      log "[DRY RUN] Would git pull --ff-only in $BACKUP_REPO"
    else
      spin "Pulling claude-code-backup..." git -C "$BACKUP_REPO" pull --ff-only || {
        warn "git pull --ff-only failed (dirty tree?); continuing with existing state"
      }
    fi
  else
    skip "claude-code-backup already cloned"
  fi
else
  _clone_needs_install=1
fi

if (( _clone_needs_install )); then
  if is_dry_run; then
    log "[DRY RUN] Would clone edmangalicea/claude-code-backup to $BACKUP_REPO"
    ok "claude-code-backup would be cloned"
  else
    spin "Cloning claude-code-backup..." gh repo clone edmangalicea/claude-code-backup "$BACKUP_REPO"
    if [[ -d "$BACKUP_REPO/.git" ]]; then
      ok "claude-code-backup cloned"
    else
      fail "Failed to clone claude-code-backup"
      return 1
    fi
  fi
fi

# ── Phase 2: Switch to machine branch ─────────────────────────────────────
local _branch
_branch="$(hostname -s | tr '[:upper:]' '[:lower:]')"

if ! is_dry_run; then
  local _current_branch
  _current_branch="$(git -C "$BACKUP_REPO" branch --show-current 2>/dev/null)"

  if [[ "$_current_branch" == "$_branch" ]]; then
    skip "Already on branch $_branch"
  elif git -C "$BACKUP_REPO" show-ref --verify --quiet "refs/heads/$_branch" 2>/dev/null; then
    spin "Switching to local branch $_branch..." git -C "$BACKUP_REPO" checkout "$_branch"
    ok "Switched to branch $_branch"
  elif git -C "$BACKUP_REPO" show-ref --verify --quiet "refs/remotes/origin/$_branch" 2>/dev/null; then
    spin "Checking out remote branch $_branch..." git -C "$BACKUP_REPO" checkout -b "$_branch" "origin/$_branch"
    ok "Checked out branch $_branch from remote"
  else
    spin "Creating new branch $_branch..." git -C "$BACKUP_REPO" checkout -b "$_branch"
    ok "Created new branch $_branch"
  fi
else
  log "[DRY RUN] Would switch to machine branch: $_branch"
fi

# ── Phase 3: Existing installation guardrails ─────────────────────────────
local _backup_dir=""
local _preserved_pat=""
local _daemon_existed=0

if [[ -f "$PLIST_FILE" ]]; then
  _daemon_existed=1
fi

if [[ -f "$SETTINGS_FILE" ]]; then
  # 3a. Full directory backup
  _backup_dir="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"
  if is_dry_run; then
    log "[DRY RUN] Would back up $CLAUDE_DIR to $_backup_dir"
  else
    cp -R "$CLAUDE_DIR" "$_backup_dir"
    log "Backed up existing Claude config to $_backup_dir"
  fi

  # 3b. Detect existing GitHub PAT (not placeholder)
  if command -v python3 &>/dev/null; then
    _preserved_pat="$(python3 -c "
import json, sys
try:
    d = json.load(open('$SETTINGS_FILE'))
    pat = d.get('env', {}).get('GITHUB_PERSONAL_ACCESS_TOKEN', '')
    if pat and pat != '<YOUR_GITHUB_PAT_HERE>':
        print(pat)
except Exception:
    pass
" 2>/dev/null)"
  else
    # Fallback: grep for a token-like value
    if grep -q '"GITHUB_PERSONAL_ACCESS_TOKEN"' "$SETTINGS_FILE" 2>/dev/null; then
      if ! grep -q '<YOUR_GITHUB_PAT_HERE>' "$SETTINGS_FILE" 2>/dev/null; then
        _preserved_pat="__detected_but_no_python3__"
        warn "python3 not found; PAT detected but cannot extract it reliably"
      fi
    fi
  fi

  if [[ -n "$_preserved_pat" && "$_preserved_pat" != "__detected_but_no_python3__" ]]; then
    log "Existing GitHub PAT detected — will verify preservation after restore"
  fi

  # 3c. Log local-only files not in backup repo
  if [[ -d "$BACKUP_REPO/global" ]]; then
    for subdir in hooks commands agents; do
      local _local_dir="$CLAUDE_DIR/$subdir"
      local _repo_dir="$BACKUP_REPO/global/$subdir"
      if [[ -d "$_local_dir" ]]; then
        for f in "$_local_dir"/*(.N); do
          local _fname="${f:t}"
          if [[ ! -f "$_repo_dir/$_fname" ]]; then
            log "Local-only file preserved (not in backup repo): $subdir/$_fname"
          fi
        done
      fi
    done
  fi

  # 3d. Daemon collision noted (used in Phase 5)
  if (( _daemon_existed )); then
    log "Existing auto-sync daemon plist detected"
  fi
fi

# ── Phase 4: Run restore.sh ───────────────────────────────────────────────
if is_dry_run; then
  log "[DRY RUN] Would run: bash $BACKUP_REPO/restore.sh"
  ok "Claude config would be restored"
else
  if [[ -f "$BACKUP_REPO/restore.sh" ]]; then
    spin "Restoring Claude configuration..." bash "$BACKUP_REPO/restore.sh"
    ok "Claude configuration restored"
  else
    fail "restore.sh not found in $BACKUP_REPO"
    return 1
  fi
fi

# ── Phase 5: Auto-sync daemon ─────────────────────────────────────────────
if [[ "${CLAUDE_SKIP_AUTOSYNC:-0}" == "1" ]]; then
  skip "Auto-sync daemon skipped (CLAUDE_SKIP_AUTOSYNC=1)"
elif (( _daemon_existed )) && ! is_force_install; then
  skip "Auto-sync daemon already installed"
else
  if is_dry_run; then
    log "[DRY RUN] Would run: bash $BACKUP_REPO/sync.sh auto-sync install"
    ok "Auto-sync daemon would be installed"
  else
    if [[ -f "$BACKUP_REPO/sync.sh" ]]; then
      spin "Installing auto-sync daemon..." bash "$BACKUP_REPO/sync.sh" auto-sync install
      ok "Auto-sync daemon installed"
    else
      warn "sync.sh not found in $BACKUP_REPO — skipping auto-sync daemon"
    fi
  fi
fi

# ── Phase 6: Post-restore verification ────────────────────────────────────
if ! is_dry_run; then
  # 6a. PAT safety net
  if [[ -n "$_preserved_pat" && "$_preserved_pat" != "__detected_but_no_python3__" && -f "$SETTINGS_FILE" ]]; then
    local _current_pat=""
    if command -v python3 &>/dev/null; then
      _current_pat="$(python3 -c "
import json, sys
try:
    d = json.load(open('$SETTINGS_FILE'))
    pat = d.get('env', {}).get('GITHUB_PERSONAL_ACCESS_TOKEN', '')
    print(pat)
except Exception:
    pass
" 2>/dev/null)"
    fi

    if [[ "$_current_pat" == "<YOUR_GITHUB_PAT_HERE>" || -z "$_current_pat" ]]; then
      warn "PAT was lost during restore — restoring from backup"
      if command -v python3 &>/dev/null; then
        python3 -c "
import json
with open('$SETTINGS_FILE', 'r') as f:
    d = json.load(f)
d.setdefault('env', {})['GITHUB_PERSONAL_ACCESS_TOKEN'] = '''$_preserved_pat'''
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null && ok "PAT restored from backup" || fail "Failed to restore PAT automatically"
      else
        warn "python3 not available — manually restore PAT from backup: $_backup_dir"
      fi
    fi
  fi

  # 6b. Check claude CLI exists
  if command -v claude &>/dev/null; then
    ok "claude CLI found"
  else
    warn "claude CLI not found in PATH"
  fi

  # 6c. Check PAT placeholder
  if [[ -f "$SETTINGS_FILE" ]]; then
    if grep -q '<YOUR_GITHUB_PAT_HERE>' "$SETTINGS_FILE" 2>/dev/null; then
      warn "GitHub PAT is still a placeholder in $SETTINGS_FILE — update it with a real token"
    fi
  fi

  # 6d. Check macos-trash
  if ! command -v macos-trash &>/dev/null; then
    warn "macos-trash not installed (recommended) — run: brew install macos-trash"
  fi

  # 6e. Log backup location
  if [[ -n "$_backup_dir" && -d "$_backup_dir" ]]; then
    log "Rollback backup available at: $_backup_dir"
  fi
fi
