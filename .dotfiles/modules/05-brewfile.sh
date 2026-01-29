#!/usr/bin/env zsh
# 05-brewfile.sh — Install packages from ~/Brewfile

step "Brewfile Packages"

if [[ ! -f "$HOME/Brewfile" ]]; then
  fail "~/Brewfile not found"
  return 1
fi

log "Running brew bundle..."
brew bundle --file="$HOME/Brewfile" 2>&1 | tee -a "$DOTFILES_LOG" || {
  warn "brew bundle had partial failures (some casks may require manual install)"
}

log "Cleaning up..."
brew cleanup 2>&1 | tee -a "$DOTFILES_LOG"

ok "Brewfile packages installed"
