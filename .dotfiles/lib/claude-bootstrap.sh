#!/usr/bin/env zsh
# claude-bootstrap.sh — Hands control to Claude Code for module installation
# Called via `exec` from install.sh after prerequisites and auth are done.

# ── PATH setup (Homebrew/Claude may not be in default PATH yet) ──────────────
export PATH="$HOME/.claude/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# ── Propagate install mode ─────────────────────────────────────────────
if [[ -f "$HOME/.dotfiles/.install-mode" ]]; then
  export DOTFILES_FORCE_INSTALL="$(< "$HOME/.dotfiles/.install-mode")"
fi

# ── Logging ──────────────────────────────────────────────────────────────────
_ts() { date '+%Y-%m-%d %H:%M:%S'; }
log()  { printf '[%s]  INFO  %s\n' "$(_ts)" "$*"; }
warn() { printf '[%s]  \033[1;33mWARN\033[0m  %s\n' "$(_ts)" "$*"; }

# ── Verify non-interactive sudo access ───────────────────────────────────────

SUDO_OK=0

if sudo -n true 2>/dev/null; then
  SUDO_OK=1
  log "NOPASSWD sudo verified"
else
  warn "sudo -n true failed — attempting to create NOPASSWD entry"

  # We still have an interactive terminal here, so we can prompt for password
  SUDO_USER=$(whoami)
  SUDOERS_FILE="/etc/sudoers.d/dotfiles-install"
  SUDOERS_LINE="$SUDO_USER ALL=(ALL) NOPASSWD: ALL"
  CLEANUP_MARKER="$HOME/.dotfiles/.bootstrap/install-cleanup"

  mkdir -p "$HOME/.dotfiles/.bootstrap"
  rm -f "$CLEANUP_MARKER"

  echo "sudo password required to create temporary NOPASSWD entry for Claude Code:"
  if sudo -v; then
    SUDOERS_TMP=$(mktemp)
    echo "$SUDOERS_LINE" > "$SUDOERS_TMP"
    if sudo visudo -c -f "$SUDOERS_TMP" &>/dev/null; then
      sudo cp "$SUDOERS_TMP" "$SUDOERS_FILE"
      sudo chown root:wheel "$SUDOERS_FILE"
      sudo chmod 0440 "$SUDOERS_FILE"
      log "Temporary NOPASSWD sudoers entry created"

      if sudo -n true 2>/dev/null; then
        SUDO_OK=1
        log "NOPASSWD sudo verified after repair"

        # Start cleanup daemon: removes entry on completion or after 2 hours
        (
          max_wait=7200; elapsed=0
          while (( elapsed < max_wait )); do
            [[ -f "$CLEANUP_MARKER" ]] && break
            sleep 10; elapsed=$((elapsed + 10))
          done
          sudo rm -f "$SUDOERS_FILE" 2>/dev/null
          rm -f "$CLEANUP_MARKER" 2>/dev/null
        ) &>/dev/null &
        disown
      else
        warn "NOPASSWD entry created but verification still fails"
      fi
    else
      warn "visudo validation failed — cannot create sudoers entry"
    fi
    rm -f "$SUDOERS_TMP"
  else
    warn "sudo authentication failed"
  fi
fi

if (( ! SUDO_OK )); then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  WARNING: Non-interactive sudo is NOT available.           ║"
  echo "║  Claude Code cannot prompt for passwords, so modules       ║"
  echo "║  that need sudo (01, 04) will fail.                       ║"
  echo "║                                                            ║"
  echo "║  To fix, open another terminal and run:                    ║"
  echo "║    echo \"$(whoami) ALL=(ALL) NOPASSWD: ALL\" |             ║"
  echo "║      sudo tee /etc/sudoers.d/dotfiles-install              ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  printf "Continue anyway? [y/N] "
  read -r reply
  if [[ ! "$reply" =~ ^[Yy] ]]; then
    echo "Aborted. Fix sudo access and re-run:"
    echo "  exec zsh ~/.dotfiles/lib/claude-bootstrap.sh"
    exit 1
  fi
fi

# ── TTY guard — prevent hang in headless/SSH contexts ───────────────────────
if [[ ! -t 0 || ! -t 1 ]]; then
  warn "No TTY detected (SSH/headless context) — cannot hand off to Claude Code"
  warn "Run fresh.sh directly instead: ~/fresh.sh"
  exit 1
fi

# ── Hand off to Claude Code ─────────────────────────────────────────────────
exec claude --dangerously-skip-permissions \
  "Run the /install command to set up this machine. All prerequisites are done (Xcode CLT, bare repo cloned, dotfiles checked out, Claude authenticated). The modules in ~/.dotfiles/modules/ need to be installed now."
