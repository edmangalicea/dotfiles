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

  # 3b. Log local-only files not in backup repo
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

  # 3c. Daemon collision noted (used in Phase 5)
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
  # 6a. Check claude CLI exists
  if command -v claude &>/dev/null; then
    ok "claude CLI found"
  else
    warn "claude CLI not found in PATH"
  fi

  # 6b. Check PAT placeholder
  if [[ -f "$SETTINGS_FILE" ]]; then
    if grep -q '<YOUR_GITHUB_PAT_HERE>' "$SETTINGS_FILE" 2>/dev/null; then
      warn "GitHub PAT is still a placeholder in $SETTINGS_FILE — update it with a real token"
    fi
  fi

  # 6c. Check macos-trash
  if ! command -v macos-trash &>/dev/null; then
    warn "macos-trash not installed (recommended) — run: brew install macos-trash"
  fi

  # 6d. Log backup location
  if [[ -n "$_backup_dir" && -d "$_backup_dir" ]]; then
    log "Rollback backup available at: $_backup_dir"
  fi
fi
