#!/usr/bin/env zsh
# utils.sh — Shared utilities for dotfiles modules
# Sourced by fresh.sh and individual modules

# ── Logging ──────────────────────────────────────────────────────────────────

DOTFILES_LOG="${HOME}/.dotfiles-install.log"

_ts() { date '+%Y-%m-%d %H:%M:%S'; }

log()  { printf '[%s]  INFO  %s\n' "$(_ts)" "$*" | tee -a "$DOTFILES_LOG"; }
ok()   { printf '[%s]  \033[1;32m OK \033[0m  %s\n' "$(_ts)" "$*" | tee -a "$DOTFILES_LOG"; }
warn() { printf '[%s]  \033[1;33mWARN\033[0m  %s\n' "$(_ts)" "$*" | tee -a "$DOTFILES_LOG"; }
fail() { printf '[%s]  \033[1;31mFAIL\033[0m  %s\n' "$(_ts)" "$*" | tee -a "$DOTFILES_LOG"; }
skip() { printf '[%s]  \033[1;36mSKIP\033[0m  %s\n' "$(_ts)" "$*" | tee -a "$DOTFILES_LOG"; }
die()  { fail "$*"; exit 1; }

step() { printf '\n\033[1;36m── %s ──\033[0m\n' "$*" | tee -a "$DOTFILES_LOG"; }

# ── Idempotent Helpers ───────────────────────────────────────────────────────

# ensure_line FILE LINE — append LINE to FILE only if not already present
ensure_line() {
  local file="$1" line="$2"
  if [[ ! -f "$file" ]]; then
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$line" > "$file"
    return 0
  fi
  grep -qxF "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >> "$file"
}

# ── Bare Repo Wrapper ───────────────────────────────────────────────────────

config() {
  /usr/bin/git --git-dir="$HOME/.cfg/" --work-tree="$HOME" "$@"
}

# ── Sudo Keep-Alive ─────────────────────────────────────────────────────────

# Start a background loop that refreshes sudo credentials every 50 seconds.
# Safe to call multiple times — only spawns one loop.
sudo_keepalive() {
  # If sudo is already cached, just refresh; otherwise prompt once.
  if ! sudo -n true 2>/dev/null; then
    log "Requesting sudo credentials..."
    sudo -v || die "sudo authentication failed"
  fi

  # Only start the keep-alive loop if one isn't already running.
  if [[ -z "${_SUDO_KEEPALIVE_PID:-}" ]]; then
    (while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done) &
    _SUDO_KEEPALIVE_PID=$!
    trap '_sudo_cleanup' EXIT
  fi
}

_sudo_cleanup() {
  if [[ -n "${_SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null
    unset _SUDO_KEEPALIVE_PID
  fi
}
