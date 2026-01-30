#!/usr/bin/env zsh
# install.sh — Dotfiles bootstrap script
# Usage: zsh -c "$(curl -fsSL https://raw.githubusercontent.com/edmangalicea/dotfiles/main/install.sh)"
#
# This script:
#   1. Checks prerequisites (network, macOS version)
#   2. Caches sudo credentials
#   3. Clones the bare dotfiles repo to ~/.cfg
#   4. Backs up any conflicting files
#   5. Checks out dotfiles into $HOME
#   6. Hands off to fresh.sh for tool installation

set -o pipefail

DOTFILES_LOG="$HOME/.dotfiles-install.log"
REPO_URL="https://github.com/edmangalicea/dotfiles.git"

# ── Logging ──────────────────────────────────────────────────────────────────

_ts() { date '+%Y-%m-%d %H:%M:%S'; }
log()  { printf '[%s]  INFO  %s\n' "$(_ts)" "$*" | tee -a "$DOTFILES_LOG"; }
fail() { printf '[%s]  \033[1;31mFAIL\033[0m  %s\n' "$(_ts)" "$*" | tee -a "$DOTFILES_LOG"; }
warn() { printf '[%s]  \033[1;33mWARN\033[0m  %s\n' "$(_ts)" "$*" | tee -a "$DOTFILES_LOG"; }
die()  { fail "$*"; exit 1; }

# ── Config alias (bare repo git wrapper) ─────────────────────────────────────

config() {
  /usr/bin/git --git-dir="$HOME/.cfg/" --work-tree="$HOME" "$@"
}

# ── Auth window cleanup helper ───────────────────────────────────────────────
_close_auth_window() {
  if [[ -f "$BOOTSTRAP_DIR/auth-script.pid" ]]; then
    local auth_pid
    auth_pid=$(cat "$BOOTSTRAP_DIR/auth-script.pid")

    kill -INT -- -"$auth_pid" 2>/dev/null        # graceful Ctrl+C

    # Poll for actual process death (up to 10s)
    local waited=0
    while (( waited < 10 )); do
      kill -0 "$auth_pid" 2>/dev/null || break
      sleep 1
      waited=$((waited + 1))
    done

    # Force-kill if still alive
    if kill -0 "$auth_pid" 2>/dev/null; then
      warn "Auth process did not exit gracefully — forcing termination"
      kill -9 -- -"$auth_pid" 2>/dev/null
      sleep 1
    fi
  fi

  if [[ -f "$BOOTSTRAP_DIR/auth-window-id" ]]; then
    local win_id
    win_id=$(cat "$BOOTSTRAP_DIR/auth-window-id")
    osascript -e "tell application \"Terminal\" to close window id $win_id" 2>/dev/null || true
  fi

  rm -f "$BOOTSTRAP_DIR/auth-script.pid" "$BOOTSTRAP_DIR/auth-window-id" 2>/dev/null
}

# ── Pre-flight checks ───────────────────────────────────────────────────────

log "Dotfiles install started"
log "macOS version: $(sw_vers -productVersion) ($(uname -m))"

log "Checking network connectivity..."
if ! curl -sfI https://github.com --max-time 10 &>/dev/null; then
  die "Cannot reach github.com — check your internet connection"
fi
log "Network OK"

# ── Previous-run detection ───────────────────────────────────────────────
INSTALL_MODE_FILE="$HOME/.dotfiles/.install-mode"
FRESH_DONE_MARKER="$HOME/.dotfiles/.fresh-install-done"

if [[ -f "$FRESH_DONE_MARKER" ]]; then
  log "Previous installation detected"
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  A previous dotfiles installation was detected.            ║"
  echo "║                                                            ║"
  echo "║  Choose an install mode:                                   ║"
  echo "║                                                            ║"
  echo "║    [F] Force       — Reinstall everything, even software   ║"
  echo "║                      that is already installed             ║"
  echo "║                                                            ║"
  echo "║    [I] Incremental — Only install what's missing           ║"
  echo "║                      (skip already-installed items)        ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  printf "Enter choice [F/I]: "
  read -r install_choice
  case "$install_choice" in
    [Ff]*)
      export DOTFILES_FORCE_INSTALL=1
      log "Install mode: FORCE (reinstall everything)"
      ;;
    *)
      export DOTFILES_FORCE_INSTALL=0
      log "Install mode: INCREMENTAL (skip already-installed)"
      ;;
  esac
  mkdir -p "$(dirname "$INSTALL_MODE_FILE")"
  echo "$DOTFILES_FORCE_INSTALL" > "$INSTALL_MODE_FILE"
else
  log "First run detected — proceeding with full install"
  export DOTFILES_FORCE_INSTALL=1
  mkdir -p "$HOME/.dotfiles"
  echo "1" > "$HOME/.dotfiles/.install-mode"
fi

# ── Sudo keep-alive ─────────────────────────────────────────────────────────

echo "Enter your sudo password (it will be cached for the rest of the install):"
sudo -v || die "sudo authentication failed"

# ── Passwordless sudo for the install duration ────────────────────────────
SUDO_USER=$(whoami)
SUDOERS_FILE="/etc/sudoers.d/dotfiles-install"
SUDOERS_LINE="$SUDO_USER ALL=(ALL) NOPASSWD: ALL"
CLEANUP_MARKER="$HOME/.dotfiles/.bootstrap/install-cleanup"

mkdir -p "$HOME/.dotfiles/.bootstrap"
rm -f "$CLEANUP_MARKER"

SUDOERS_TMP=$(mktemp)
echo "$SUDOERS_LINE" > "$SUDOERS_TMP"
if sudo visudo -c -f "$SUDOERS_TMP" &>/dev/null; then
  sudo cp "$SUDOERS_TMP" "$SUDOERS_FILE"
  sudo chown root:wheel "$SUDOERS_FILE"
  sudo chmod 0440 "$SUDOERS_FILE"
  log "Temporary NOPASSWD sudoers entry created"

  # Verify the entry actually works
  if sudo -n true 2>/dev/null; then
    export DOTFILES_SUDOERS_INSTALLED=1
    log "NOPASSWD sudo verified — Claude Code will have sudo access"
  else
    warn "NOPASSWD entry created but sudo -n true still fails"
    # Diagnostics
    if ! grep -q '#includedir /etc/sudoers.d' /etc/sudoers 2>/dev/null && \
       ! grep -q '@includedir /etc/sudoers.d' /etc/sudoers 2>/dev/null; then
      warn "  /etc/sudoers does not include /etc/sudoers.d — entry will be ignored"
    fi
    if [[ ! -f "$SUDOERS_FILE" ]]; then
      warn "  $SUDOERS_FILE does not exist after copy"
    else
      perms=$(stat -f '%A' "$SUDOERS_FILE" 2>/dev/null)
      owner=$(stat -f '%Su:%Sg' "$SUDOERS_FILE" 2>/dev/null)
      [[ "$perms" != "440" ]] && warn "  Permissions are $perms (expected 440)"
      [[ "$owner" != "root:wheel" ]] && warn "  Ownership is $owner (expected root:wheel)"
      if ! sudo visudo -c -f "$SUDOERS_FILE" &>/dev/null; then
        warn "  visudo validation of installed file failed"
      fi
    fi
    warn "Claude Code may not be able to run sudo commands"
  fi
else
  warn "Failed to validate sudoers entry — falling back to keepalive only"
fi
rm -f "$SUDOERS_TMP"

# Self-cleaning daemon: removes sudoers entry on completion or after 2 hours
(
  max_wait=7200; elapsed=0
  while (( elapsed < max_wait )); do
    [[ -f "$CLEANUP_MARKER" ]] && break
    sleep 10; elapsed=$((elapsed + 10))
  done
  sudo rm -f "$SUDOERS_FILE" 2>/dev/null
  rm -f "$CLEANUP_MARKER" 2>/dev/null
) &>/dev/null &
disown

# Keepalive fallback (detached, self-terminates after 2 hours)
(
  end=$(($(date +%s) + 7200))
  while (( $(date +%s) < end )); do
    sudo -n true 2>/dev/null
    sleep 50
  done
) &>/dev/null &
disown

# ── Xcode Command Line Tools ────────────────────────────────────────────────

if ! xcode-select -p &>/dev/null; then
  log "Installing Xcode Command Line Tools..."
  xcode-select --install 2>/dev/null

  # Wait for the installation to complete
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  log "Xcode Command Line Tools installed"
else
  log "Xcode Command Line Tools already installed"
fi

# ── Idempotent .gitignore ───────────────────────────────────────────────────

touch "$HOME/.gitignore"
if ! grep -qxF '.cfg' "$HOME/.gitignore" 2>/dev/null; then
  printf '%s\n' '.cfg' >> "$HOME/.gitignore"
  log "Added .cfg to ~/.gitignore"
else
  log ".cfg already in ~/.gitignore"
fi

# ── Clone bare repo ─────────────────────────────────────────────────────────

if [[ -d "$HOME/.cfg" ]]; then
  log "~/.cfg already exists, skipping clone"
else
  log "Cloning dotfiles bare repo..."
  git clone --bare "$REPO_URL" "$HOME/.cfg" 2>&1 | tee -a "$DOTFILES_LOG"

  # Verify the clone
  if ! config rev-parse --git-dir &>/dev/null; then
    die "Bare repo clone failed — ~/.cfg is not a valid git directory"
  fi
  log "Bare repo cloned and verified"
fi

# ── Backup conflicting files ────────────────────────────────────────────────

log "Checking for conflicting files..."

BACKUP_DIR="$HOME/.dotfiles-backup/$(date '+%Y%m%d_%H%M%S')"

# Try a checkout — if it fails, back up the conflicting files.
if ! config checkout 2>/dev/null; then
  log "Conflicts detected — backing up to $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"

  # Parse the conflicting file paths from the checkout error
  config checkout 2>&1 | grep -E '^\t' | awk '{print $1}' | while read -r file; do
    if [[ -f "$HOME/$file" ]]; then
      mkdir -p "$BACKUP_DIR/$(dirname "$file")"
      mv "$HOME/$file" "$BACKUP_DIR/$file"
      log "Backed up: $file"
    fi
  done

  # Retry checkout after backing up
  config checkout 2>&1 | tee -a "$DOTFILES_LOG" || die "checkout failed even after backup"
  log "Checkout succeeded after backup"
else
  log "Checkout succeeded (no conflicts)"
fi

# ── Configure bare repo ─────────────────────────────────────────────────────

config config status.showUntrackedFiles no
log "Set status.showUntrackedFiles = no"

# ── Ensure required directories ──────────────────────────────────────────────

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
mkdir -p "$HOME/.config/gh" && chmod 700 "$HOME/.config/gh"

# ── Install Claude Code if needed ─────────────────────────────────────────────

if ! command -v claude &>/dev/null; then
  log "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash 2>&1 | tee -a "$DOTFILES_LOG"
  export PATH="$HOME/.claude/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
fi

# ── Claude auth in a separate window ─────────────────────────────────────────

BOOTSTRAP_DIR="$HOME/.dotfiles/.bootstrap"
MARKER_SUCCESS="$BOOTSTRAP_DIR/claude-init-done"
MARKER_FAILURE="$BOOTSTRAP_DIR/claude-init-failed"

# Clean stale markers
mkdir -p "$BOOTSTRAP_DIR"
rm -f "$MARKER_SUCCESS" "$MARKER_FAILURE"

# ── Open Claude auth in a new Terminal window ───────────────────────────────

CLAUDE_WINDOW_OPENED=0
INIT_SCRIPT="$HOME/.dotfiles/lib/claude-init-window.sh"

if command -v claude &>/dev/null && [[ -f "$INIT_SCRIPT" ]]; then
  chmod +x "$INIT_SCRIPT" 2>/dev/null
  log "Opening new Terminal window for Claude Code setup..."

  AUTH_WINDOW_ID=$(osascript <<APPLESCRIPT 2>/dev/null
tell application "Terminal"
  do script "exec zsh '${INIT_SCRIPT}'"
  return id of front window
end tell
APPLESCRIPT
  )

  if [[ -n "$AUTH_WINDOW_ID" ]]; then
    CLAUDE_WINDOW_OPENED=1
    echo "$AUTH_WINDOW_ID" > "$BOOTSTRAP_DIR/auth-window-id"
    log "Claude setup window opened (window ID: $AUTH_WINDOW_ID)"
  else
    warn "Could not open Terminal window — skipping parallel Claude setup"
  fi
else
  if ! command -v claude &>/dev/null; then
    warn "Claude Code not available — skipping Claude setup window"
  fi
fi

# ── Wait for Claude setup to complete (if window was opened) ─────────────────

if (( CLAUDE_WINDOW_OPENED )); then
  TIMEOUT=600  # 10 minutes
  ELAPSED=0
  REMINDER_INTERVAL=30
  NEXT_REMINDER=$REMINDER_INTERVAL

  while (( ELAPSED < TIMEOUT )); do
    if [[ -f "$MARKER_SUCCESS" ]] || [[ -f "$MARKER_FAILURE" ]]; then
      break
    fi

    # Fallback: detect auth even if window script failed to create marker
    if [[ -f "$HOME/.claude.json" ]] && grep -q '"oauthAccount"' "$HOME/.claude.json" 2>/dev/null; then
      touch "$MARKER_SUCCESS"
      log "Auth detected via credentials file (fallback)"
      break
    fi

    if (( ELAPSED >= NEXT_REMINDER )); then
      log "Still waiting for Claude Code setup in the other window... (${ELAPSED}s elapsed)"
      NEXT_REMINDER=$((NEXT_REMINDER + REMINDER_INTERVAL))
    fi

    sleep 2
    ELAPSED=$((ELAPSED + 2))
  done

  if [[ -f "$MARKER_SUCCESS" ]]; then
    log "Auth detected — closing auth window..."
    _close_auth_window

    # Verify credentials are fully persisted before proceeding
    local cred_ready=0 cred_wait=0
    while (( cred_wait < 5 )); do
      if [[ -f "$HOME/.claude.json" ]] && \
         grep -q '"oauthAccount"' "$HOME/.claude.json" 2>/dev/null && \
         grep -q '"hasCompletedOnboarding"' "$HOME/.claude.json" 2>/dev/null; then
        cred_ready=1
        break
      fi
      sleep 1
      cred_wait=$((cred_wait + 1))
    done

    if (( cred_ready )); then
      log "Credentials verified in ~/.claude.json"
    else
      warn "Credentials may be incomplete — Claude Code might require re-authentication"
    fi
  fi

  if (( ELAPSED >= TIMEOUT )); then
    warn "Timed out waiting for Claude Code setup (${TIMEOUT}s)"
    warn "You can run 'claude --init' manually later"
    _close_auth_window
  fi
fi

# ── Final handoff ────────────────────────────────────────────────────────────

CLAUDE_OK=0
if [[ -f "$MARKER_SUCCESS" ]]; then
  CLAUDE_OK=1
  log "Claude Code setup completed successfully"
elif [[ -f "$MARKER_FAILURE" ]]; then
  warn "Claude Code setup failed in the other window"
  warn "Run 'claude --init' manually to retry"
fi

if (( CLAUDE_OK )) && command -v claude &>/dev/null; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  Prerequisites complete. Claude Code will take over and     ║"
  echo "║  install your dotfiles modules via the /install command.    ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  printf "Press Enter to hand off to Claude Code..."
  read -r
  exec zsh "$HOME/.dotfiles/lib/claude-bootstrap.sh"
fi

# Fallback: Claude auth failed or unavailable — run fresh.sh directly
log "Running fresh.sh modules (fallback — no Claude orchestration)..."
if [[ -f "$HOME/fresh.sh" ]]; then
  chmod +x "$HOME/fresh.sh"
  DOTFILES_SKIP_CLAUDE_LAUNCH=1 DOTFILES_SUDO_CACHED=1 "$HOME/fresh.sh"
else
  die "fresh.sh not found"
fi

echo ""
echo "Post-install manual steps:"
echo "  1. Run 'claude --init' to set up Claude Code"
echo "  2. Generate SSH key:  ssh-keygen -t ed25519 -C \"edmangalicea@gmail.com\""
echo "  3. Add to GitHub:     cat ~/.ssh/id_ed25519.pub | pbcopy"
echo "  4. Switch to SSH:     config remote set-url origin git@github.com:edmangalicea/dotfiles.git"
echo "  5. GitHub CLI auth:   gh auth login"
echo ""
echo "Restart your terminal to load the new shell configuration."
