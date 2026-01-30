#!/usr/bin/env zsh
# 01-xcode-cli.sh — Install Xcode Command Line Tools (non-interactive)

step "Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
  if is_force_install; then
    log "Force mode: reinstalling Xcode CLI Tools"
  else
    skip "Xcode CLI Tools already installed at $(xcode-select -p)"
    return 0
  fi
fi

log "Installing Xcode Command Line Tools..."

# Trigger the install via softwareupdate (non-interactive).
# First, create the placeholder that tells softwareupdate to list CLI tools.
touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

PROD=$(softwareupdate -l 2>&1 | grep -B 1 -E 'Command Line Tools' | \
       grep -E '^\s+\*' | head -1 | sed 's/^[ *]*//' | sed 's/^ Label: //')

if [[ -n "$PROD" ]]; then
  log "Found update: $PROD"
  spin "Installing $PROD..." sudo softwareupdate -i "$PROD" --verbose
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
else
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  warn "softwareupdate couldn't find CLI Tools, falling back to xcode-select --install"
  xcode-select --install
  log "Waiting for Xcode CLI Tools installation to complete..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
fi

if xcode-select -p &>/dev/null; then
  ok "Xcode CLI Tools installed"
else
  fail "Xcode CLI Tools installation may have failed"
  return 1
fi
