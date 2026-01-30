#!/usr/bin/env bash
# setup-hook.sh — Claude Code Setup hook for dotfiles
# Triggered by `claude --init` via .claude/settings.json
#
# Responsibilities:
#   1. Check network connectivity
#   2. Cache sudo credentials
#   3. Export env vars via CLAUDE_ENV_FILE
#   4. Log macOS version
#   5. Return JSON with additionalContext

set -euo pipefail

# ── Network check ────────────────────────────────────────────────────────────

if ! curl -sfI https://github.com --max-time 10 &>/dev/null; then
  echo '{"error": "No network connectivity — cannot reach github.com"}' >&2
  exit 2
fi

# ── Sudo caching ────────────────────────────────────────────────────────────

if sudo -n true 2>/dev/null; then
  echo "Sudo access confirmed (NOPASSWD active)"
else
  echo "Caching sudo credentials for dotfiles setup..."
  sudo -v || {
    echo '{"error": "sudo authentication failed"}' >&2
    exit 1
  }
  (while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done) &
fi

# ── Environment variables via CLAUDE_ENV_FILE ────────────────────────────────

if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  {
    echo "DOTFILES_DIR=$HOME/.dotfiles"
    echo "MODULES_DIR=$HOME/.dotfiles/modules"
    echo "DOTFILES_LOG=$HOME/.dotfiles-install.log"
  } >> "$CLAUDE_ENV_FILE"
fi

# ── Log system info ─────────────────────────────────────────────────────────

MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
ARCH="$(uname -m 2>/dev/null || echo 'unknown')"

echo "[$(date '+%Y-%m-%d %H:%M:%S')]  INFO  Setup hook: macOS $MACOS_VERSION ($ARCH)" \
  >> "$HOME/.dotfiles-install.log"

# ── Return context to Claude ────────────────────────────────────────────────

MARKER="$HOME/.dotfiles/.fresh-install-done"

if [[ -f "$MARKER" ]]; then
  # Fresh install just completed — guide post-install steps
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "Setup",
    "additionalContext": "Fresh dotfiles install completed. macOS $MACOS_VERSION ($ARCH). All modules ran via fresh.sh.\n\nRun the /install command now — it will detect modules are already installed (they are idempotent) and guide the user through the remaining post-install steps:\n1. Generate SSH key (ed25519)\n2. Add public key to GitHub\n3. Switch dotfiles remote to SSH\n4. Authenticate GitHub CLI (gh auth login)\n\nThis is a dotfiles bare git repo (~/.cfg) managing dotfiles in \$HOME."
  }
}
EOF
else
  # No marker — fresh install hasn't run yet
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "Setup",
    "additionalContext": "Setup hook completed. macOS $MACOS_VERSION ($ARCH). Sudo cached. Environment ready.\n\nThis is a dotfiles bare git repo (~/.cfg) managing dotfiles in \$HOME. Run the /install command now to set up the machine."
  }
}
EOF
fi
