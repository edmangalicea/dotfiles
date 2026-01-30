#!/usr/bin/env zsh
# claude-bootstrap.sh — Hands control to Claude Code for module installation
# Called via `exec` from install.sh after prerequisites and auth are done.

# ── PATH setup (Homebrew/Claude may not be in default PATH yet) ──────────────
export PATH="$HOME/.claude/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# ── Refresh sudo and start keepalive ────────────────────────────────────────
if sudo -v 2>/dev/null; then
  (while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done) &
else
  echo "Warning: sudo not available — some modules may fail"
fi

# ── Hand off to Claude Code ─────────────────────────────────────────────────
exec claude --dangerously-skip-permissions \
  "Run the /install command to set up this machine. All prerequisites are done (Xcode CLT, bare repo cloned, dotfiles checked out, Claude authenticated). The modules in ~/.dotfiles/modules/ need to be installed now."
