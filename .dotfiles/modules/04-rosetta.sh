#!/usr/bin/env zsh
# 04-rosetta.sh — Install Rosetta 2 for x86_64 compatibility

step "Rosetta 2"

# Only needed on Apple Silicon
if [[ "$(uname -m)" != "arm64" ]]; then
  skip "Not Apple Silicon — Rosetta 2 not needed"
  return 0
fi

# Check if Rosetta is already running
if pgrep -q oahd; then
  skip "Rosetta 2 already installed and running"
  return 0
fi

log "Installing Rosetta 2..."
sudo softwareupdate --install-rosetta --agree-to-license 2>&1 | tee -a "$DOTFILES_LOG" || {
  warn "Rosetta 2 installation returned non-zero exit code (may already be installed)"
}

ok "Rosetta 2 setup complete"
