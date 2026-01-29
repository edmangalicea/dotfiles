#!/usr/bin/env zsh
# 05-brewfile.sh — Install packages from ~/Brewfile

step "Brewfile Packages"

if [[ ! -f "$HOME/Brewfile" ]]; then
  fail "~/Brewfile not found"
  return 1
fi

spin "Installing Brewfile packages..." brew bundle --verbose --file="$HOME/Brewfile" || {
  warn "brew bundle had partial failures (some casks may require manual install)"
}

spin "Cleaning up..." brew cleanup --verbose

ok "Brewfile packages installed"
