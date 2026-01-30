#!/usr/bin/env zsh
# 02-homebrew.sh — Install Homebrew and ensure PATH is set

step "Homebrew"

if command -v brew &>/dev/null && ! is_force_install; then
  skip "Homebrew already installed"
else
  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    2>&1 | tee -a "$DOTFILES_LOG"

  if [[ $? -ne 0 ]]; then
    fail "Homebrew installation failed"
    return 1
  fi

  # Ensure brew is on PATH for the rest of this session
  eval "$(/opt/homebrew/bin/brew shellenv)"
  ok "Homebrew installed"
fi

# Ensure .zprofile has the shellenv line (idempotent)
ensure_line "$HOME/.zprofile" 'eval "$(/opt/homebrew/bin/brew shellenv)"'

spin "Updating Homebrew..." brew update --verbose
ok "Homebrew up to date"
