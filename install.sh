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

# ── Hand off to Claude Code or fresh.sh ──────────────────────────────────────

if command -v claude &>/dev/null; then
  log "Launching agentic setup via Claude Code..."
  log "(For non-interactive install, run: ~/fresh.sh)"
  exec claude --init
fi

# Fallback if Claude Code install failed
if [[ -f "$HOME/fresh.sh" ]]; then
  warn "Claude Code not available — using traditional setup..."
  chmod +x "$HOME/fresh.sh"
  "$HOME/fresh.sh"
else
  die "Neither Claude Code nor fresh.sh available"
fi
