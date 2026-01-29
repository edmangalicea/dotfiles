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

step() {
  if [[ -n "${MODULE_CURRENT:-}" ]] && [[ -n "${MODULE_TOTAL:-}" ]]; then
    printf '\n\033[1;36m── [%s/%s] %s ──\033[0m\n' "$MODULE_CURRENT" "$MODULE_TOTAL" "$*" | tee -a "$DOTFILES_LOG"
  else
    printf '\n\033[1;36m── %s ──\033[0m\n' "$*" | tee -a "$DOTFILES_LOG"
  fi
}

# ── Verbose runner ──────────────────────────────────────────────────────────

# Run a command with full output visible to the user.
# Usage: spin "description" command [args...]
# Returns the command's exit code.
spin() {
  local desc="$1"; shift
  log "$desc"
  "$@" 2>&1 | tee -a "$DOTFILES_LOG"
  return ${pipestatus[1]}
}

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
# Set DOTFILES_SUDO_CACHED=1 in a parent process to skip the interactive prompt.
sudo_keepalive() {
  # If a parent (e.g. install.sh) already cached sudo, skip the prompt.
  if [[ "${DOTFILES_SUDO_CACHED:-0}" != "1" ]]; then
    if ! sudo -n true 2>/dev/null; then
      log "Requesting sudo credentials..."
      sudo -v || die "sudo authentication failed"
    fi
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
