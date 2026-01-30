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

# ── Pre-flight checks ───────────────────────────────────────────────────────

log "Dotfiles install started"
log "macOS version: $(sw_vers -productVersion) ($(uname -m))"

log "Checking network connectivity..."
if ! curl -sfI https://github.com --max-time 10 &>/dev/null; then
  die "Cannot reach github.com — check your internet connection"
fi
log "Network OK"

# ── Sudo keep-alive ─────────────────────────────────────────────────────────

echo "Enter your sudo password (it will be cached for the rest of the install):"
sudo -v || die "sudo authentication failed"

(while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done) &
SUDO_PID=$!
trap 'kill $SUDO_PID 2>/dev/null' EXIT

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

# ── Claude auth in a separate tab ─────────────────────────────────────────────

BOOTSTRAP_DIR="$HOME/.dotfiles/.bootstrap"
MARKER_SUCCESS="$BOOTSTRAP_DIR/claude-init-done"
MARKER_FAILURE="$BOOTSTRAP_DIR/claude-init-failed"
INIT_SCRIPT="$HOME/.dotfiles/lib/claude-init-tab.sh"

# Clean stale markers
mkdir -p "$BOOTSTRAP_DIR"
rm -f "$MARKER_SUCCESS" "$MARKER_FAILURE"

# ── Open Claude auth in a new Terminal tab ───────────────────────────────────

CLAUDE_TAB_OPENED=0

if command -v claude &>/dev/null && [[ -f "$INIT_SCRIPT" ]]; then
  chmod +x "$INIT_SCRIPT" 2>/dev/null
  log "Opening new Terminal tab for Claude Code setup..."

  # Try AppleScript to open a new tab in the current Terminal window
  if osascript <<APPLESCRIPT 2>/dev/null
tell application "Terminal"
  activate
  tell application "System Events"
    keystroke "t" using {command down}
  end tell
  delay 0.5
  do script "exec zsh '${INIT_SCRIPT}'" in front tab of front window
end tell
APPLESCRIPT
  then
    CLAUDE_TAB_OPENED=1
    log "Claude setup tab opened successfully"
  else
    # Fallback: open a new Terminal window instead
    warn "Could not open new tab (Accessibility permission may be needed)"
    log "Trying new Terminal window instead..."
    if open -a Terminal "$INIT_SCRIPT" 2>/dev/null; then
      CLAUDE_TAB_OPENED=1
      log "Claude setup window opened successfully"
    else
      warn "Could not open new Terminal window — skipping parallel Claude setup"
    fi
  fi
else
  if ! command -v claude &>/dev/null; then
    warn "Claude Code not available — skipping Claude setup tab"
  fi
fi

# ── Wait for Claude setup to complete (if tab was opened) ────────────────────

if (( CLAUDE_TAB_OPENED )); then
  TIMEOUT=600  # 10 minutes
  ELAPSED=0
  REMINDER_INTERVAL=30
  NEXT_REMINDER=$REMINDER_INTERVAL

  while (( ELAPSED < TIMEOUT )); do
    if [[ -f "$MARKER_SUCCESS" ]] || [[ -f "$MARKER_FAILURE" ]]; then
      break
    fi

    # Fallback: detect auth even if tab script failed to create marker
    if [[ -f "$HOME/.claude.json" ]] && grep -q '"oauthAccount"' "$HOME/.claude.json" 2>/dev/null; then
      touch "$MARKER_SUCCESS"
      log "Auth detected via credentials file (fallback)"
      break
    fi

    if (( ELAPSED >= NEXT_REMINDER )); then
      log "Still waiting for Claude Code setup in the other tab... (${ELAPSED}s elapsed)"
      NEXT_REMINDER=$((NEXT_REMINDER + REMINDER_INTERVAL))
    fi

    sleep 2
    ELAPSED=$((ELAPSED + 2))
  done

  if (( ELAPSED >= TIMEOUT )); then
    warn "Timed out waiting for Claude Code setup (${TIMEOUT}s)"
    warn "You can run 'claude --init' manually later"
  fi
fi

# ── Final handoff ────────────────────────────────────────────────────────────

CLAUDE_OK=0
if [[ -f "$MARKER_SUCCESS" ]]; then
  CLAUDE_OK=1
  log "Claude Code setup completed successfully"
elif [[ -f "$MARKER_FAILURE" ]]; then
  warn "Claude Code setup failed in the other tab"
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
