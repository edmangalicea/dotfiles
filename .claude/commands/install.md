---
name: install
description: Run the dotfiles setup — install all dependencies and configure the system
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# Dotfiles Install Command

You are orchestrating a macOS dotfiles setup. The modules live in `~/.dotfiles/modules/` and are numbered 01-10. Each module is a zsh script sourced with shared utilities from `~/.dotfiles/lib/utils.sh`.

## Step 1: Ask the user which install mode they want

Use AskUserQuestion to present two options:

- **Agentic Install** — You run each module interactively, check output, ask about preferences (Rosetta, Brewfile contents, macOS defaults, Node version), and handle errors as they come up.
- **Deterministic Install** — You run `~/fresh.sh` directly with no questions asked. Fast and non-interactive.

## Step 2A: Agentic Install

If the user chose **Agentic**, run modules one at a time. For each module, execute:

```bash
zsh -c 'source ~/.dotfiles/lib/utils.sh && source ~/.dotfiles/modules/NN-name.sh'
```

Before modules that need sudo (01, 04, 08), refresh credentials:

```bash
sudo -v
```

Track results for each module: **succeeded**, **skipped** (already done), **failed**, or **declined** (user chose not to run it).

### Module-specific behavior

1. **01-xcode-cli** — Run without asking. Required for everything else. If it fails, ask retry/skip/abort.

2. **02-homebrew** — Run without asking. Required for subsequent modules. If it fails, ask retry/skip/abort.

3. **03-omz** — Run without asking. Installs Oh My Zsh, Powerlevel10k, and plugins.

4. **04-rosetta** — Ask the user: "Install Rosetta 2 for x86_64 app compatibility?" If they decline, mark as **declined** and continue.

5. **05-brewfile** — Before running, read `~/Brewfile` and show a summary of what will be installed (formulae, casks, Mac App Store apps). Ask "Proceed with installing these packages?" If they decline, mark as **declined**.

6. **06-runtime** — Run without asking. After it completes, ask: "Which Node.js version would you like to install via fnm? (e.g., 22, 20, or skip)" If the user provides a version, run `fnm install <version> && fnm default <version>`. If they say skip, move on.

7. **07-directories** — Run without asking. Creates ~/Development and sets permissions.

8. **08-macos-defaults** — Before running, describe the changes it will make:
   - Finder: show extensions, path bar, status bar, ~/Library
   - Keyboard: fast key repeat, short delay
   - Dock: auto-hide, small icons
   Ask "Apply these macOS defaults?" If they decline, mark as **declined**.

9. **09-dock** — Ask the user: "Configure the Dock layout? (sets specific apps, clears defaults)" Requires `dockutil` (installed by Brewfile). If they decline, mark as **declined**.

10. **10-claude-config** — This module restores Claude Code configuration from the backup repo. It requires `gh auth status` to succeed. Before running this module, perform the **gh auth gate** procedure below. If auth succeeds, run the module. If auth fails, times out, or the user declines, mark as **skipped**.

#### gh auth gate (before module 10)

Before module 10, check `gh auth status`. If already authenticated, proceed directly to module 10. If not authenticated and `gh` is installed, auto-open a Terminal window for `gh auth login`:

1. Set `BOOTSTRAP_DIR="$HOME/.dotfiles/.bootstrap"` and clean stale markers:
   ```bash
   rm -f "$HOME/.dotfiles/.bootstrap/gh-auth-done" "$HOME/.dotfiles/.bootstrap/gh-auth-failed" "$HOME/.dotfiles/.bootstrap/gh-auth-script.pid" "$HOME/.dotfiles/.bootstrap/gh-auth-window-id"
   ```

2. Open the auth window via osascript (run as a single Bash command):
   ```bash
   osascript -e 'tell application "Terminal"' -e 'activate' -e "do script \"exec zsh '$HOME/.dotfiles/lib/gh-auth-window.sh' '$HOME/.dotfiles/.bootstrap'\"" -e 'return id of front window' -e 'end tell'
   ```
   Save the returned window ID to `$HOME/.dotfiles/.bootstrap/gh-auth-window-id`.

3. Tell the user: "A Terminal window has opened for GitHub CLI authentication. Complete the login there — the install will continue automatically once you're done."

4. Poll for marker files with a 5-minute timeout, checking every 2 seconds:
   ```bash
   elapsed=0; while [ $elapsed -lt 300 ]; do [ -f "$HOME/.dotfiles/.bootstrap/gh-auth-done" ] && echo "AUTH_DONE" && break; [ -f "$HOME/.dotfiles/.bootstrap/gh-auth-failed" ] && echo "AUTH_FAILED" && break; sleep 2; elapsed=$((elapsed + 2)); done; [ $elapsed -ge 300 ] && echo "TIMEOUT"
   ```

5. Close the Terminal window via osascript using the saved window ID:
   ```bash
   wid=$(cat "$HOME/.dotfiles/.bootstrap/gh-auth-window-id" 2>/dev/null); [ -n "$wid" ] && osascript -e 'tell application "Terminal"' -e "repeat with w in windows" -e "if id of w is $wid then" -e "close w" -e "exit repeat" -e "end if" -e "end repeat" -e 'end tell' 2>/dev/null || true
   ```

6. Clean up markers:
   ```bash
   rm -f "$HOME/.dotfiles/.bootstrap/gh-auth-done" "$HOME/.dotfiles/.bootstrap/gh-auth-failed" "$HOME/.dotfiles/.bootstrap/gh-auth-script.pid" "$HOME/.dotfiles/.bootstrap/gh-auth-window-id"
   ```

7. Verify with `gh auth status`. If it succeeds, run module 10. If it fails, tell the user module 10 is being skipped and they can run `gh auth login` manually later.

If `gh` is not installed, skip the gate and module 10 entirely. If osascript fails (headless/SSH), fall back to telling the user to run `gh auth login` in another terminal manually, then poll for `gh auth status` success.

### Error handling

If any module fails (non-zero exit code), show the error output and ask the user:
- **Retry** — run the module again
- **Skip** — mark as failed and continue to the next module
- **Abort** — stop the entire install and show the summary so far

## Step 2B: Deterministic Install

If the user chose **Deterministic**, run:

```bash
chmod +x ~/fresh.sh && ~/fresh.sh
```

Capture and display the output. The script prints its own summary table at the end.

## Step 3: Summary

After either path completes, print a summary table:

```
============================================
  Dotfiles Setup Summary
============================================
Succeeded:  01-xcode-cli, 02-homebrew, ...
Skipped:    (already done modules)
Failed:     (any failures)
Declined:   (user chose not to run)
============================================
```

## Step 4: Post-install steps

Present the post-install steps:

1. **Generate SSH key**: `ssh-keygen -t ed25519 -C "edmangalicea@gmail.com"`
2. **Add key to GitHub**: `cat ~/.ssh/id_ed25519.pub | pbcopy` then paste at github.com/settings/keys
3. **Switch dotfiles remote to SSH**: `config remote set-url origin git@github.com:edmangalicea/dotfiles.git`
4. **Authenticate GitHub CLI**: If `gh auth status` already succeeds (authentication was completed during module 10's gh auth gate), tell the user it's already done and skip. Otherwise, use the same **gh auth gate** auto-open procedure from module 10 to open a Terminal window for `gh auth login`.

Ask the user: "Would you like help with any of these post-install steps?" If yes, walk them through the ones they choose.

## Step 5: Final reminder

Remind the user: "Restart your terminal to load the new shell configuration."
