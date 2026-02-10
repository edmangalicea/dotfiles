#!/usr/bin/env zsh
# gh-auth-window.sh — Runs in a new Terminal window during agentic install
# Handles interactive GitHub CLI authentication while the main process waits.
#
# Usage: zsh gh-auth-window.sh <bootstrap-dir>

set -euo pipefail

BOOTSTRAP_DIR="${1:?Usage: $0 <bootstrap-dir>}"

MARKER_DONE="$BOOTSTRAP_DIR/gh-auth-done"
MARKER_FAILED="$BOOTSTRAP_DIR/gh-auth-failed"

mkdir -p "$BOOTSTRAP_DIR"

# Write our PID so the caller can signal us
echo $$ > "$BOOTSTRAP_DIR/gh-auth-script.pid"

# ── Already authenticated? ────────────────────────────────────────────────
if gh auth status &>/dev/null 2>&1; then
  printf '\n\033[1;32m✓ GitHub CLI is already authenticated!\033[0m\n'
  touch "$MARKER_DONE"
  exit 0
fi

# ── Banner ────────────────────────────────────────────────────────────────
printf '\n\033[1;36m'
printf '╔══════════════════════════════════════════════════════════════╗\n'
printf '║              GitHub CLI Authentication                      ║\n'
printf '╠══════════════════════════════════════════════════════════════╣\n'
printf '║  Complete the GitHub auth steps below.                      ║\n'
printf '║  This window will close automatically when done.            ║\n'
printf '║  The main install will continue after you authenticate.     ║\n'
printf '╚══════════════════════════════════════════════════════════════╝\n'
printf '\033[0m\n'

sleep 1

# ── Run gh auth login ─────────────────────────────────────────────────────
if gh auth login --git-protocol https --web; then
  touch "$MARKER_DONE"
  printf '\n\033[1;32m✓ GitHub CLI authentication complete! This window will close.\033[0m\n'
else
  touch "$MARKER_FAILED"
  printf '\n\033[1;31m✗ GitHub CLI authentication cancelled or failed.\033[0m\n'
fi

sleep 1
exit 0
