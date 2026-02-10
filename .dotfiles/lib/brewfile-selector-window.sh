#!/usr/bin/env zsh
# brewfile-selector-window.sh — Runs in a new Terminal window during agentic install
# Handles interactive Brewfile selection while the main process waits.
#
# Usage: zsh brewfile-selector-window.sh <brewfile> <output-file> <bootstrap-dir>

set -euo pipefail

BREWFILE="${1:?Usage: $0 <brewfile> <output-file> <bootstrap-dir>}"
OUTPUT_FILE="${2:?Usage: $0 <brewfile> <output-file> <bootstrap-dir>}"
BOOTSTRAP_DIR="${3:?Usage: $0 <brewfile> <output-file> <bootstrap-dir>}"

MARKER_DONE="$BOOTSTRAP_DIR/selector-done"
MARKER_FAILED="$BOOTSTRAP_DIR/selector-failed"
SELECTOR="$(dirname "$0")/brewfile-selector.sh"

mkdir -p "$BOOTSTRAP_DIR"

# Write our PID so the caller can signal us
echo $$ > "$BOOTSTRAP_DIR/selector-script.pid"

# ── Banner ─────────────────────────────────────────────────────────────────
printf '\n\033[1;36m'
printf '╔══════════════════════════════════════════════════════════════╗\n'
printf '║              Brewfile Package Selector                      ║\n'
printf '╠══════════════════════════════════════════════════════════════╣\n'
printf '║  Use ↑/↓ to navigate, Space to toggle, Enter to confirm.   ║\n'
printf '║  This window will close automatically when done.            ║\n'
printf '╚══════════════════════════════════════════════════════════════╝\n'
printf '\033[0m\n'

sleep 1

# ── Run selector ───────────────────────────────────────────────────────────
if zsh "$SELECTOR" "$BREWFILE" "$OUTPUT_FILE"; then
  touch "$MARKER_DONE"
  printf '\n\033[1;32m✓ Package selection complete! This window will close.\033[0m\n'
else
  touch "$MARKER_FAILED"
  printf '\n\033[1;31m✗ Package selection cancelled or failed.\033[0m\n'
fi

sleep 1
exit 0
