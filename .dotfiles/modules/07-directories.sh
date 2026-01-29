#!/usr/bin/env zsh
# 07-directories.sh — Create directories, set permissions

step "Directories & Permissions"

# ── Development directory ────────────────────────────────────────────────────
mkdir -p "$HOME/Development"
ok "~/Development exists"

# ── SSH directory ────────────────────────────────────────────────────────────
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
[[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
ok "~/.ssh permissions set (700)"

# ── GitHub CLI config ────────────────────────────────────────────────────────
mkdir -p "$HOME/.config/gh"
chmod 700 "$HOME/.config/gh"
ok "~/.config/gh permissions set (700)"
