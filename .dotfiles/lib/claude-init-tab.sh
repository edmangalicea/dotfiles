#!/usr/bin/env zsh
# claude-init-tab.sh — Runs in a new Terminal tab during install.sh bootstrap
# Handles interactive Claude Code authentication while fresh.sh runs in parallel.

BOOTSTRAP_DIR="$HOME/.dotfiles/.bootstrap"
MARKER_SUCCESS="$BOOTSTRAP_DIR/claude-init-done"
MARKER_FAILURE="$BOOTSTRAP_DIR/claude-init-failed"

# ── PATH setup (Homebrew/Claude may not be in default PATH yet) ──────────────
export PATH="$HOME/.claude/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# ── Ensure bootstrap directory exists ────────────────────────────────────────
mkdir -p "$BOOTSTRAP_DIR"

# ── Banner ───────────────────────────────────────────────────────────────────
printf '\n\033[1;36m'
printf '╔══════════════════════════════════════════════════════════════╗\n'
printf '║              Claude Code Interactive Setup                  ║\n'
printf '╠══════════════════════════════════════════════════════════════╣\n'
printf '║  The main tab is waiting for you to finish auth here.      ║\n'
printf '║  Complete the Claude auth steps below, then this tab       ║\n'
printf '║  will close automatically.                                 ║\n'
printf '╚══════════════════════════════════════════════════════════════╝\n'
printf '\033[0m\n'

# ── Run claude --init ────────────────────────────────────────────────────────
if claude --init; then
  touch "$MARKER_SUCCESS"
  printf '\n\033[1;32m✓ Claude Code setup complete!\033[0m\n'
  printf 'This tab will close in 10 seconds...\n'
else
  touch "$MARKER_FAILURE"
  printf '\n\033[1;31m✗ Claude Code setup failed.\033[0m\n'
  printf 'You can re-run "claude --init" manually later.\n'
  printf 'This tab will close in 10 seconds...\n'
fi

sleep 10
exit 0
