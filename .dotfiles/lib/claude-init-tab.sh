#!/usr/bin/env zsh
# claude-init-tab.sh — Runs in a new Terminal tab during install.sh bootstrap
# Handles interactive Claude Code authentication while install.sh waits.

BOOTSTRAP_DIR="$HOME/.dotfiles/.bootstrap"
MARKER_SUCCESS="$BOOTSTRAP_DIR/claude-init-done"
MARKER_FAILURE="$BOOTSTRAP_DIR/claude-init-failed"

export PATH="$HOME/.claude/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

mkdir -p "$BOOTSTRAP_DIR"

# ── Already authenticated? ─────────────────────────────────────────────────
if [[ -f "$HOME/.claude.json" ]] && grep -q '"oauthAccount"' "$HOME/.claude.json" 2>/dev/null; then
  printf '\n\033[1;32m✓ Claude Code is already authenticated!\033[0m\n'
  touch "$MARKER_SUCCESS"
  printf 'This tab will close in 5 seconds...\n'
  sleep 5
  exit 0
fi

# ── Banner ─────────────────────────────────────────────────────────────────
printf '\n\033[1;36m'
printf '╔══════════════════════════════════════════════════════════════╗\n'
printf '║              Claude Code Interactive Setup                  ║\n'
printf '╠══════════════════════════════════════════════════════════════╣\n'
printf '║  1. Complete the Claude auth steps below.                  ║\n'
printf '║  2. After signing in, type /exit or press Ctrl+C.         ║\n'
printf '║  The main tab will continue automatically once you auth.   ║\n'
printf '╚══════════════════════════════════════════════════════════════╝\n'
printf '\033[0m\n'

# ── Background watcher: create marker as soon as auth is detected ──────────
(
  while true; do
    if [[ -f "$HOME/.claude.json" ]] && grep -q '"oauthAccount"' "$HOME/.claude.json" 2>/dev/null; then
      touch "$MARKER_SUCCESS"
      exit 0
    fi
    sleep 2
  done
) &
WATCHER_PID=$!

# ── Run Claude in foreground for interactive auth ──────────────────────────
claude
CLAUDE_EXIT=$?

# ── Cleanup ────────────────────────────────────────────────────────────────
kill "$WATCHER_PID" 2>/dev/null
wait "$WATCHER_PID" 2>/dev/null

# Final check — create marker if watcher didn't already
if [[ ! -f "$MARKER_SUCCESS" ]] && [[ ! -f "$MARKER_FAILURE" ]]; then
  if [[ -f "$HOME/.claude.json" ]] && grep -q '"oauthAccount"' "$HOME/.claude.json" 2>/dev/null; then
    touch "$MARKER_SUCCESS"
  elif (( CLAUDE_EXIT == 0 )); then
    touch "$MARKER_SUCCESS"
  else
    touch "$MARKER_FAILURE"
  fi
fi

if [[ -f "$MARKER_SUCCESS" ]]; then
  printf '\n\033[1;32m✓ Claude Code setup complete!\033[0m\n'
else
  printf '\n\033[1;31m✗ Claude Code setup failed.\033[0m\n'
  printf 'You can re-run "claude" manually later to authenticate.\n'
fi

printf 'This tab will close in 5 seconds...\n'
sleep 5
exit 0
