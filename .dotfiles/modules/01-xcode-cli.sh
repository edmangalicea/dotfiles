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

if [[ -z "$PROD" ]]; then
  # Retry softwareupdate discovery — fresh VMs need up to 5 min for the catalog to populate
  local max_retries=20
  local retry_delay=15
  local retries=0
  while [[ -z "$PROD" ]] && (( retries < max_retries )); do
    log "softwareupdate didn't find CLI Tools yet — retrying in ${retry_delay}s (attempt $((retries + 1))/${max_retries})..."
    sleep "$retry_delay"
    PROD=$(softwareupdate -l 2>&1 | grep -B 1 -E 'Command Line Tools' | \
           grep -E '^\s+\*' | head -1 | sed 's/^[ *]*//' | sed 's/^ Label: //')
    retries=$((retries + 1))
  done
fi

if [[ -n "$PROD" ]]; then
  log "Found update: $PROD"
  spin "Installing $PROD..." sudo softwareupdate -i "$PROD" --verbose
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
else
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  if is_dry_run; then
    log "[DRY RUN] Would fall back to xcode-select --install"
  elif [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
    fail "softwareupdate couldn't find CLI Tools and xcode-select --install requires GUI interaction"
    fail "Run manually: sudo softwareupdate -i 'Command Line Tools for Xcode ...' --agree-to-license"
    return 1
  else
    warn "softwareupdate couldn't find CLI Tools, falling back to xcode-select --install"
    xcode-select --install
    log "Waiting for Xcode CLI Tools installation to complete..."
    local xclt_elapsed=0
    until xcode-select -p &>/dev/null; do
      sleep 5
      xclt_elapsed=$((xclt_elapsed + 5))
      if (( xclt_elapsed > 600 )); then
        fail "Xcode CLI Tools installation timed out after 10 minutes"
        return 1
      fi
    done
  fi
fi

if is_dry_run; then
  ok "Xcode CLI Tools would be installed"
elif xcode-select -p &>/dev/null; then
  ok "Xcode CLI Tools installed"
else
  fail "Xcode CLI Tools installation may have failed"
  return 1
fi
