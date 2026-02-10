#!/usr/bin/env zsh
# utils.sh — Shared utilities for dotfiles modules
# Sourced by fresh.sh and individual modules

# ── Logging ──────────────────────────────────────────────────────────────────

DOTFILES_LOG="${DOTFILES_LOG:-$HOME/.dotfiles-install.log}"

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
  # If the install created a NOPASSWD sudoers entry, skip keepalive
  if [[ "${DOTFILES_SUDOERS_INSTALLED:-0}" == "1" ]]; then
    log "NOPASSWD sudoers active — skipping keepalive"
    return 0
  fi

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

# ── Install Mode Resolution ─────────────────────────────────────────────

_resolve_install_mode() {
  local mode_file="$HOME/.dotfiles/.force-install"
  if [[ -n "${DOTFILES_FORCE_INSTALL+x}" ]]; then
    return 0
  fi
  if [[ -f "$mode_file" ]]; then
    DOTFILES_FORCE_INSTALL="$(< "$mode_file")"
    export DOTFILES_FORCE_INSTALL
    return 0
  fi
  export DOTFILES_FORCE_INSTALL=0
}
_resolve_install_mode

is_force_install() {
  [[ "${DOTFILES_FORCE_INSTALL:-0}" == "1" ]]
}

# ── Machine Type Mode ──────────────────────────────────────────────────

# Returns the machine type: personal, host, or guest
# Checks env var first, then file, defaults to personal
get_install_mode() {
  if [[ -n "${DOTFILES_INSTALL_MODE:-}" ]]; then
    echo "$DOTFILES_INSTALL_MODE"
    return 0
  fi
  local mode_file="$HOME/.dotfiles/.install-mode"
  if [[ -f "$mode_file" ]]; then
    cat "$mode_file"
    return 0
  fi
  echo "personal"
}

# Check if a module should run for the given machine type
# Usage: should_run_module "01-xcode-cli" [mode]
# Host mode runs: 01, 02, 03, 05, 07 only
# Personal and guest run all modules
should_run_module() {
  local module_name="$1"
  local mode="${2:-$(get_install_mode)}"

  case "$mode" in
    host)
      case "$module_name" in
        01-xcode-cli|02-homebrew|03-omz|05-brewfile|07-directories)
          return 0 ;;
        *)
          return 1 ;;
      esac
      ;;
    personal|guest|*)
      return 0 ;;
  esac
}

# ── Dry-Run Mode ───────────────────────────────────────────────────────────

is_dry_run() {
  [[ "${DOTFILES_DRY_RUN:-0}" == "1" ]]
}

if is_dry_run; then
  DOTFILES_LOG="/dev/null"

  spin() {
    local desc="$1"; shift
    log "$desc"
    log "[DRY RUN] Would execute: $*"
    return 0
  }

  sudo_keepalive() { log "[DRY RUN] Would start sudo keepalive"; return 0; }

  ensure_line() { log "[DRY RUN] Would ensure line in $1: $2"; return 0; }

  config() { log "[DRY RUN] Would run: git (bare repo) $*"; return 0; }

  sudo()    { log "[DRY RUN] Would run: sudo $*"; return 0; }
  rm()      { log "[DRY RUN] Would run: rm $*"; return 0; }
  touch()   { log "[DRY RUN] Would run: touch $*"; return 0; }
  mkdir()   { log "[DRY RUN] Would run: mkdir $*"; return 0; }
  chmod()   { log "[DRY RUN] Would run: chmod $*"; return 0; }
  defaults(){ log "[DRY RUN] Would run: defaults $*"; return 0; }
  killall() { log "[DRY RUN] Would run: killall $*"; return 0; }
  dockutil(){ log "[DRY RUN] Would run: dockutil $*"; return 0; }

  softwareupdate() {
    case "$1" in
      -l|--list) command softwareupdate "$@" ;;
      *)         log "[DRY RUN] Would run: softwareupdate $*"; return 0 ;;
    esac
  }

  xcode-select() {
    case "$1" in
      -p|--print-path) command xcode-select "$@" ;;
      *)               log "[DRY RUN] Would run: xcode-select $*"; return 0 ;;
    esac
  }

  curl() {
    log "[DRY RUN] Would fetch: curl $*"
    return 0
  }
fi
