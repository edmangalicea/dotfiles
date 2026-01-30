# ── Powerlevel10k Instant Prompt ──────────────────────────────────────────────
# Must stay at the top. Console input (password prompts, confirmations, etc.)
# must go above this block; everything else goes below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── Tmux Auto-Launch for SSH Sessions ────────────────────────────────────────
# Works with all SSH clients including mobile apps (Termius, Termix, etc.)
if [[ -n "$SSH_CONNECTION" ]] && \
   [[ -z "$TMUX" ]] && \
   [[ $- == *i* ]] && \
   command -v tmux &>/dev/null; then
  exec tmux new-session -A -s main
fi

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
export ZSH_DISABLE_COMPFIX=true
ZSH_THEME="powerlevel10k/powerlevel10k"
zstyle ':omz:update' mode auto

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source "$ZSH/oh-my-zsh.sh"

# ── Powerlevel10k Config ─────────────────────────────────────────────────────
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ── PATH ─────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── Java ─────────────────────────────────────────────────────────────────────
export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home

# ── Bun ──────────────────────────────────────────────────────────────────────
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── Editors ──────────────────────────────────────────────────────────────────
export REACT_EDITOR=cursor

# ── 1Password ────────────────────────────────────────────────────────────────
export OP_PLUGIN_ALIASES_SOURCED=1
alias cdk="op plugin run -- cdk"

# ── Android SDK ──────────────────────────────────────────────────────────────
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/platform-tools"

# ── 1Password SSH Agent ──────────────────────────────────────────────────────
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

# ── fnm (Fast Node Manager) ─────────────────────────────────────────────────
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# ── Dotfiles Bare Repo ───────────────────────────────────────────────────────
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# ── Environment ──────────────────────────────────────────────────────────────
if [ -f "$HOME/.env" ]; then
  set -a
  . "$HOME/.env"
  set +a
fi

# ── Aliases ──────────────────────────────────────────────────────────────────
alias t='tmux new -As main'

# bun completions
[ -s "/Users/base-mac-os/.bun/_bun" ] && source "/Users/base-mac-os/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
