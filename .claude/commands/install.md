---
name: install
description: Run the dotfiles setup — install all dependencies and configure the system
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# Dotfiles Install Command

## Step 0: Detect Install Mode

Read `~/.dotfiles/.install-mode`. If it contains `1`, the user chose **Force** mode. If `0` or absent, **Incremental** mode.

When running each module, prefix with the env var:

    DOTFILES_FORCE_INSTALL=$(cat ~/.dotfiles/.install-mode 2>/dev/null || echo 0) zsh -c 'source ~/.dotfiles/lib/utils.sh && source ~/.dotfiles/modules/NN-name.sh'

Mention the active mode in the summary.

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

Before modules that need sudo (01, 04), verify non-interactive access:

```bash
sudo -n true
```

If `sudo -n true` fails, do NOT attempt `sudo -v` (it requires an interactive terminal that Claude Code cannot provide). Instead, tell the user to run this command in their own terminal:

```
echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/dotfiles-install
```

Then retry `sudo -n true` to confirm it works before proceeding.

Track results for each module: **succeeded**, **skipped** (already done), **failed**, or **declined** (user chose not to run it).

### Module-specific behavior

1. **01-xcode-cli** — Run without asking. Required for everything else. If it fails, ask retry/skip/abort.

2. **02-homebrew** — Run without asking. Required for subsequent modules. If it fails, ask retry/skip/abort.

3. **03-omz** — Run without asking. Installs Oh My Zsh, Powerlevel10k, and plugins.

4. **04-rosetta** — Ask the user: "Install Rosetta 2 for x86_64 app compatibility?" If they decline, mark as **declined** and continue.

5. **05-brewfile** — Before running:
   a. Read `~/Brewfile` and show a categorized summary of what will
      be installed (taps, CLI tools, casks, fonts, VS Code extensions,
      Mac App Store apps) with counts per category.
   b. Ask the user (AskUserQuestion, 3 options):
      - "Install all packages" — proceed with the full Brewfile.
      - "Customize selection" — tell the user to run the interactive
        selector in their own terminal:
        `~/.dotfiles/lib/brewfile-selector.sh`
        Then ask them to confirm when done. The selector writes a
        filtered Brewfile to `~/.dotfiles/.brewfile-filtered`.
      - "Skip Brewfile entirely" — mark as **declined**.
   c. Run module 05. It will use the filtered file if present,
      otherwise the full ~/Brewfile.

6. **06-runtime** — Run without asking. After it completes, ask: "Which Node.js version would you like to install via fnm? (e.g., 22, 20, or skip)" If the user provides a version, run `fnm install <version> && fnm default <version>`. If they say skip, move on.

7. **07-directories** — Run without asking. Creates ~/Development and sets permissions.

8. **08-macos-defaults** — Before running, describe the changes it will make:
   - Finder: show extensions, path bar, status bar, ~/Library
   - Keyboard: fast key repeat, short delay
   - Dock: auto-hide, small icons
   Ask "Apply these macOS defaults?" If they decline, mark as **declined**.

9. **09-dock** — Before running, describe the Dock layout it will configure (list the apps from the script). Ask "Apply this Dock layout?" If they decline, mark as **declined**.

10. **10-claude-config** — Before running:
    a. Check `gh auth status`. If not authenticated, tell the user
       to run `gh auth login` in their terminal, then confirm when done.
    b. Check if `~/.claude/settings.json` already exists. If so, tell
       the user: "You have an existing Claude configuration. The module
       will back up your entire ~/.claude/ directory before restoring
       from the backup repo. Your GitHub PAT and any local-only files
       will be preserved."
    c. Ask the user (AskUserQuestion, 3 options):
       - "Set up config + auto-sync" — full setup (clone, restore, daemon).
       - "Restore config only" — clone + restore, skip daemon.
       - "Skip Claude config" — mark as **declined**.
    d. Run module 10. For "Restore config only", prepend
       `CLAUDE_SKIP_AUTOSYNC=1` to the execution command.
    e. After completion, check the output for:
       - Backup location — tell user where their backup is stored
       - GitHub PAT placeholder warning — remind user to edit settings.json
       - macos-trash warning — suggest `brew install macos-trash`

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
4. **Authenticate GitHub CLI**: `gh auth login`
5. **Set up GitHub PAT for Claude Code**: If restore warned about
   `<YOUR_GITHUB_PAT_HERE>`, create a token at github.com/settings/tokens
   and add it to `~/.claude/settings.json`.

Ask the user: "Would you like help with any of these post-install steps?" If yes, walk them through the ones they choose.

## Step 5: Final reminder

Remind the user: "Restart your terminal to load the new shell configuration."
