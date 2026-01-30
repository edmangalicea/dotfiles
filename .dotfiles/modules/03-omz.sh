#!/usr/bin/env zsh
# 03-omz.sh — Oh My Zsh + Powerlevel10k + plugins

step "Oh My Zsh & Plugins"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
local _omz_needs_install=0
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  if is_force_install; then
    log "Force mode: removing existing Oh My Zsh"
    rm -rf "$HOME/.oh-my-zsh"
    _omz_needs_install=1
  else
    skip "Oh My Zsh already installed"
  fi
else
  _omz_needs_install=1
fi

if (( _omz_needs_install )); then
  if is_dry_run; then
    log "[DRY RUN] Would install Oh My Zsh"
    ok "Oh My Zsh would be installed"
  else
    log "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)" \
      "" --unattended --keep-zshrc 2>&1 | tee -a "$DOTFILES_LOG"

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
      ok "Oh My Zsh installed"
    else
      fail "Oh My Zsh installation failed"
      return 1
    fi
  fi
fi

# ── Powerlevel10k ────────────────────────────────────────────────────────────
P10K_DIR="${ZSH_CUSTOM}/themes/powerlevel10k"
local _p10k_needs_install=0
if [[ -d "$P10K_DIR" ]]; then
  if is_force_install; then
    log "Force mode: removing existing Powerlevel10k"
    rm -rf "$P10K_DIR"
    _p10k_needs_install=1
  else
    skip "Powerlevel10k already installed"
  fi
else
  _p10k_needs_install=1
fi

if (( _p10k_needs_install )); then
  spin "Cloning Powerlevel10k..." git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  ok "Powerlevel10k installed"
fi

# ── zsh-autosuggestions ──────────────────────────────────────────────────────
AS_DIR="${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
local _as_needs_install=0
if [[ -d "$AS_DIR" ]]; then
  if is_force_install; then
    log "Force mode: removing existing zsh-autosuggestions"
    rm -rf "$AS_DIR"
    _as_needs_install=1
  else
    skip "zsh-autosuggestions already installed"
  fi
else
  _as_needs_install=1
fi

if (( _as_needs_install )); then
  spin "Cloning zsh-autosuggestions..." git clone https://github.com/zsh-users/zsh-autosuggestions.git "$AS_DIR"
  ok "zsh-autosuggestions installed"
fi

# ── zsh-syntax-highlighting ─────────────────────────────────────────────────
SH_DIR="${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
local _sh_needs_install=0
if [[ -d "$SH_DIR" ]]; then
  if is_force_install; then
    log "Force mode: removing existing zsh-syntax-highlighting"
    rm -rf "$SH_DIR"
    _sh_needs_install=1
  else
    skip "zsh-syntax-highlighting already installed"
  fi
else
  _sh_needs_install=1
fi

if (( _sh_needs_install )); then
  spin "Cloning zsh-syntax-highlighting..." git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$SH_DIR"
  ok "zsh-syntax-highlighting installed"
fi
