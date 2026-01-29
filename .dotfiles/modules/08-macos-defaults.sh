#!/usr/bin/env zsh
# 08-macos-defaults.sh — macOS Finder, keyboard, and UI preferences

step "macOS Defaults"

log "Setting macOS preferences..."

# ── Finder ───────────────────────────────────────────────────────────────────
# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show path bar at the bottom of Finder windows
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar in Finder
defaults write com.apple.finder ShowStatusBar -bool true

# Use list view as default in all Finder windows
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# ── Keyboard ─────────────────────────────────────────────────────────────────
# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Fast key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2

# Short delay until key repeat
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# ── Dock ─────────────────────────────────────────────────────────────────────
# Minimize windows using scale effect
defaults write com.apple.dock mineffect -string "scale"

# ── Restart affected services ────────────────────────────────────────────────
for app in Finder Dock; do
  killall "$app" 2>/dev/null || true
done

ok "macOS defaults applied (Finder and Dock restarted)"
