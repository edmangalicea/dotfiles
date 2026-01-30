#!/usr/bin/env zsh
# 03-omz.sh — Oh My Zsh + Powerlevel10k + plugins

step "Oh My Zsh & Plugins"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  if is_force_install; then
    log "Force mode: removing existing Oh My Zsh"
    rm -rf "$HOME/.oh-my-zsh"
  else
    skip "Oh My Zsh already installed"
  fi
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
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

# ── Powerlevel10k ────────────────────────────────────────────────────────────
P10K_DIR="${ZSH_CUSTOM}/themes/powerlevel10k"
if [[ -d "$P10K_DIR" ]]; then
  if is_force_install; then
    log "Force mode: removing existing Powerlevel10k"
    rm -rf "$P10K_DIR"
  else
    skip "Powerlevel10k already installed"
  fi
fi

if [[ ! -d "$P10K_DIR" ]]; then
  spin "Cloning Powerlevel10k..." git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  ok "Powerlevel10k installed"
fi

# ── zsh-autosuggestions ──────────────────────────────────────────────────────
AS_DIR="${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
if [[ -d "$AS_DIR" ]]; then
  if is_force_install; then
    log "Force mode: removing existing zsh-autosuggestions"
    rm -rf "$AS_DIR"
  else
    skip "zsh-autosuggestions already installed"
  fi
fi

if [[ ! -d "$AS_DIR" ]]; then
  spin "Cloning zsh-autosuggestions..." git clone https://github.com/zsh-users/zsh-autosuggestions.git "$AS_DIR"
  ok "zsh-autosuggestions installed"
fi

# ── zsh-syntax-highlighting ─────────────────────────────────────────────────
SH_DIR="${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
if [[ -d "$SH_DIR" ]]; then
  if is_force_install; then
    log "Force mode: removing existing zsh-syntax-highlighting"
    rm -rf "$SH_DIR"
  else
    skip "zsh-syntax-highlighting already installed"
  fi
fi

if [[ ! -d "$SH_DIR" ]]; then
  spin "Cloning zsh-syntax-highlighting..." git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$SH_DIR"
  ok "zsh-syntax-highlighting installed"
fi
