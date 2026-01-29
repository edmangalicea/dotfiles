#!/usr/bin/env zsh
# 08-macos-defaults.sh — macOS Finder, keyboard, and UI preferences

step "macOS Defaults"

log "Setting macOS preferences..."

# ── Finder ───────────────────────────────────────────────────────────────────
log "Finder: Show all file extensions"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

log "Finder: Show hidden files"
defaults write com.apple.finder AppleShowAllFiles -bool true

log "Finder: Show path bar"
defaults write com.apple.finder ShowPathbar -bool true

log "Finder: Show status bar"
defaults write com.apple.finder ShowStatusBar -bool true

log "Finder: Default to list view"
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# ── Keyboard ─────────────────────────────────────────────────────────────────
log "Keyboard: Disable press-and-hold (enable key repeat)"
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

log "Keyboard: Set fast key repeat rate (KeyRepeat=2)"
defaults write NSGlobalDomain KeyRepeat -int 2

log "Keyboard: Set short initial key repeat delay (InitialKeyRepeat=15)"
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# ── Dock ─────────────────────────────────────────────────────────────────────
log "Dock: Set minimize effect to scale"
defaults write com.apple.dock mineffect -string "scale"

# ── Restart affected services ────────────────────────────────────────────────
log "Restarting Finder and Dock to apply changes..."
for app in Finder Dock; do
  killall "$app" 2>/dev/null || true
done

ok "macOS defaults applied (Finder and Dock restarted)"
