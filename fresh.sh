#!/usr/bin/env zsh
# fresh.sh — Modular dotfiles orchestrator
# Runs numbered modules from ~/.dotfiles/modules/ in order.
# Each module is sourced (not executed) so it shares utils and state.

DOTFILES_DIR="$HOME/.dotfiles"
MODULES_DIR="$DOTFILES_DIR/modules"

# ── Source shared utilities ──────────────────────────────────────────────────
if [[ ! -f "$DOTFILES_DIR/lib/utils.sh" ]]; then
  printf '\033[1;31mFATAL:\033[0m %s not found\n' "$DOTFILES_DIR/lib/utils.sh"
  exit 1
fi
source "$DOTFILES_DIR/lib/utils.sh"

if is_dry_run; then
  log "============================================"
  log "  DRY RUN MODE — No changes will be made"
  log "============================================"
fi

if is_force_install; then
  log "Install mode: FORCE (reinstall everything)"
else
  log "Install mode: INCREMENTAL (skip already-installed)"
fi

log "Machine type: $(get_install_mode)"

# ── Result tracking ─────────────────────────────────────────────────────────
typeset -a SUCCEEDED FAILED SKIPPED
SUCCEEDED=()
FAILED=()
SKIPPED=()

# ── Summary on exit ─────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo "============================================"
  if is_dry_run; then
    echo "  Dotfiles Setup Summary  [DRY RUN]"
  else
    echo "  Dotfiles Setup Summary"
  fi
  echo "============================================"

  if (( ${#SUCCEEDED[@]} > 0 )); then
    printf '\033[1;32mSucceeded:\033[0m\n'
    for m in "${SUCCEEDED[@]}"; do printf '  + %s\n' "$m"; done
  fi

  if (( ${#SKIPPED[@]} > 0 )); then
    printf '\033[1;36mSkipped (already done):\033[0m\n'
    for m in "${SKIPPED[@]}"; do printf '  ~ %s\n' "$m"; done
  fi

  if (( ${#FAILED[@]} > 0 )); then
    printf '\033[1;31mFailed:\033[0m\n'
    for m in "${FAILED[@]}"; do printf '  ! %s\n' "$m"; done
  fi

  echo "============================================"
  echo "Log: $DOTFILES_LOG"
  echo "============================================"
}
trap print_summary EXIT

# ── Sudo keep-alive ──────────────────────────────────────────────────────────
sudo_keepalive

# ── Run modules ──────────────────────────────────────────────────────────────

# Count modules for progress display
typeset -a _all_modules
_all_modules=("$MODULES_DIR"/[0-9][0-9]-*.sh(N))
export MODULE_TOTAL=${#_all_modules[@]}
export MODULE_CURRENT=0

log "Starting dotfiles setup... ($MODULE_TOTAL modules)"

for module in "${_all_modules[@]}"; do
  module_name="${module:t:r}"   # e.g. "01-xcode-cli"
  (( MODULE_CURRENT++ ))
  export MODULE_CURRENT

  # Skip modules not applicable for the current machine type
  if ! should_run_module "$module_name"; then
    log "[$MODULE_CURRENT/$MODULE_TOTAL] Skipping $module_name (not applicable for $(get_install_mode) mode)"
    SKIPPED+=("$module_name")
    continue
  fi

  log "[$MODULE_CURRENT/$MODULE_TOTAL] Running module: $module_name"

  # Track skip messages to detect "already done" modules.
  # We capture the return code and check for skip/fail.
  _skip_count_before=${#SKIPPED[@]}

  # Source the module. If it calls `return`, we catch the code here.
  local rc=0
  source "$module" || rc=$?

  if (( rc != 0 )); then
    FAILED+=("$module_name")
    fail "Module $module_name failed (exit code $rc)"
  else
    # If SKIPPED grew during this module, the module was already done.
    # But we still consider it a success overall.
    SUCCEEDED+=("$module_name")
  fi
done

# ── Post-setup ───────────────────────────────────────────────────────────────
# Ensure the bare repo hides untracked files
if [[ -d "$HOME/.cfg" ]]; then
  config config status.showUntrackedFiles no
fi

# Signal sudoers cleanup daemon
touch "$HOME/.dotfiles/.bootstrap/install-cleanup"

log "Dotfiles setup complete."

# ── Hand off to Claude Code ──────────────────────────────────────────────────
# Create marker so the setup hook knows fresh.sh completed
rm -f "$HOME/.dotfiles/.force-install"
touch "$HOME/.dotfiles/.fresh-install-done"

# When called from install.sh, skip the Claude launch (install.sh handles it)
if [[ "${DOTFILES_SKIP_CLAUDE_LAUNCH:-0}" == "1" ]]; then
  log "fresh.sh modules complete (Claude launch deferred to install.sh)"
  exit 0
fi

if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
  log "Non-interactive mode — skipping Claude Code launch"
  exit 0
fi

if [[ ! -t 0 || ! -t 1 ]]; then
  log "No TTY detected (SSH/headless context) — skipping Claude Code launch"
  exit 0
fi

if command -v claude &>/dev/null; then
  log "Launching Claude Code to continue setup..."
  exec claude --dangerously-skip-permissions
fi

# Fallback: if claude is not installed, print manual post-install steps
echo ""
echo "Post-install manual steps:"
echo "  1. GitHub CLI auth:   gh auth login"
echo ""
echo "Restart your terminal to load the new shell configuration."
