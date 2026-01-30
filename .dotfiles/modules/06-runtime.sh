#!/usr/bin/env zsh
# 06-runtime.sh — Install bun, init fnm

step "Runtime Tools"

# ── Bun ──────────────────────────────────────────────────────────────────────
if command -v bun &>/dev/null && ! is_force_install; then
  skip "bun already installed ($(bun --version))"
else
  spin "Installing bun..." bash -c 'curl -fsSL https://bun.sh/install | bash'

  if is_dry_run; then
    ok "bun would be installed"
  elif [[ -f "$HOME/.bun/bin/bun" ]]; then
    ok "bun installed"
  else
    fail "bun installation failed"
  fi
fi

# ── fnm ──────────────────────────────────────────────────────────────────────
if command -v fnm &>/dev/null; then
  log "Initializing fnm..."
  eval "$(fnm env --use-on-cd --shell zsh)" 2>&1 | tee -a "$DOTFILES_LOG"
  ok "fnm initialized"
else
  warn "fnm not found — install it via Brewfile first"
fi
