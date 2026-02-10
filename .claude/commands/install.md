---
name: install
description: Run the dotfiles setup — install all dependencies and configure the system
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# Dotfiles Install Command

You are orchestrating a macOS dotfiles setup. The modules live in `~/.dotfiles/modules/` and are numbered 01-10. Each module is a zsh script sourced with shared utilities from `~/.dotfiles/lib/utils.sh`.

## Step 1: Machine type selection

Check if `~/.dotfiles/.install-mode` already exists. If it does, read it and confirm with the user: "Detected machine type: **{mode}**. Continue with this?" If the user wants to change it, or if the file doesn't exist, use AskUserQuestion to present three options:

- **Personal** — Full install on a personal machine
- **VM Host** — Minimal install on a machine that runs Lume macOS VMs
- **VM Guest** — Full install inside a virtual machine

Write the choice (`personal`, `host`, or `guest`) to `~/.dotfiles/.install-mode` and export `DOTFILES_INSTALL_MODE` for child processes:

```bash
mkdir -p ~/.dotfiles && echo "personal" > ~/.dotfiles/.install-mode
```

### Mode module matrix

The machine type determines which modules run:

| Module | Personal | Host | Guest |
|--------|----------|------|-------|
| 01-xcode-cli | ✓ | ✓ | ✓ |
| 02-homebrew | ✓ | ✓ | ✓ |
| 03-omz | ✓ | ✓ | ✓ |
| 04-rosetta | ✓ | ✗ | ✓ |
| 05-brewfile | ✓ | ✓ | ✓ |
| 06-runtime | ✓ | ✗ | ✓ |
| 07-directories | ✓ | ✓ | ✓ |
| 08-macos-defaults | ✓ | ✗ | ✓ |
| 09-dock | ✓ | ✗ | ✓ |
| 10-claude-config | ✓ | ✗ | ✓ |

**Host mode runs only:** 01, 02, 03, 05, 07

## Step 2: Ask the user which install mode they want

Use AskUserQuestion to present two options:

- **Agentic Install** — You run each module interactively, check output, ask about preferences (Rosetta, Brewfile contents, macOS defaults, Node version), and handle errors as they come up.
- **Deterministic Install** — You run `~/fresh.sh` directly with no questions asked. Fast and non-interactive.

## Step 3A: Agentic Install

If the user chose **Agentic**, run modules one at a time **according to the mode matrix**. Skip modules that don't apply to the current machine type. For each applicable module, execute:

```bash
zsh -c 'source ~/.dotfiles/lib/utils.sh && source ~/.dotfiles/modules/NN-name.sh'
```

Before modules that need sudo (01, 04, 08), refresh credentials:

```bash
sudo -v
```

Track results for each module: **succeeded**, **skipped** (already done or not applicable for mode), **failed**, or **declined** (user chose not to run it).

### Module-specific behavior

1. **01-xcode-cli** — Run without asking. Required for everything else. If it fails, ask retry/skip/abort.

2. **02-homebrew** — Run without asking. Required for subsequent modules. If it fails, ask retry/skip/abort.

3. **03-omz** — Run without asking. Installs Oh My Zsh, Powerlevel10k, and plugins.

4. **04-rosetta** *(Personal, Guest only)* — Ask the user: "Install Rosetta 2 for x86_64 app compatibility?" If they decline, mark as **declined** and continue.

5. **05-brewfile** — The `~/Brewfile` uses inline `@mode` tags to filter packages per machine type. Before running, filter the Brewfile and show a summary:
   - Run `zsh ~/.dotfiles/lib/brewfile-filter.sh <mode> ~/Brewfile` to get the mode-filtered list (where `<mode>` is the value from `~/.dotfiles/.install-mode`)
   - Show a summary of what will be installed from the filtered output (formulae, casks, Mac App Store apps)
   - Ask "Proceed with installing these packages?"
   - If they approve, write the filtered output to `~/.dotfiles/.brewfile-filtered` and then run the module (which will pick up the pre-filtered file)
   - If they decline, mark as **declined**

6. **06-runtime** *(Personal, Guest only)* — Run without asking. After it completes, ask: "Which Node.js version would you like to install via fnm? (e.g., 22, 20, or skip)" If the user provides a version, run `fnm install <version> && fnm default <version>`. If they say skip, move on.

7. **07-directories** — Run without asking. Creates ~/Development and sets permissions.

8. **08-macos-defaults** *(Personal, Guest only)* — Before running, describe the changes it will make:
   - Finder: show extensions, path bar, status bar, ~/Library
   - Keyboard: fast key repeat, short delay
   - Dock: auto-hide, small icons
   Ask "Apply these macOS defaults?" If they decline, mark as **declined**.

9. **09-dock** *(Personal, Guest only)* — Ask the user: "Configure the Dock layout? (sets specific apps, clears defaults)" Requires `dockutil` (installed by Brewfile). If they decline, mark as **declined**.

10. **10-claude-config** *(Personal, Guest only)* — This module restores Claude Code configuration from the backup repo. It requires `gh auth status` to succeed. Before running this module, perform the **gh auth gate** procedure below. If auth succeeds, run the module. If auth fails, times out, or the user declines, mark as **skipped**.

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

## Step 3B: Deterministic Install

If the user chose **Deterministic**, run:

```bash
chmod +x ~/fresh.sh && ~/fresh.sh
```

The script is mode-aware — it reads `~/.dotfiles/.install-mode` and automatically skips modules not applicable to the current machine type. Capture and display the output. The script prints its own summary table at the end.

## Step 4: Host Post-Install — VM Creation and Guest Bootstrap

**This step only runs when the machine type is `host`.** After host modules complete (01, 02, 03, 05, 07), continue with VM creation and guest bootstrapping.

### Phase 1: VM Creation

1. Ask the user for VM configuration:
   - VM name (default: `dev-vm`)
   - Disk size (default: `80` GB)

2. Create the macOS VM via Lume (installed by the host Brewfile):
   ```bash
   lume create <VM_NAME> --os macos --ipsw latest --disk-size <SIZE> --unattended tahoe
   ```
   `--unattended tahoe` creates user `lume`/`lume` with SSH enabled. This may take a while (macOS IPSW download + install).

3. Start the VM with a shared directory:
   ```bash
   lume run <VM_NAME> --shared-dir ~/shared:rw --no-display
   ```

4. Wait for the VM to be SSH-ready:
   ```bash
   # Poll lume ls for VM IP
   lume ls
   # Once IP is available, test SSH
   ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no lume@<VM_IP> echo ready
   ```
   Poll every 10 seconds with a 5-minute timeout. If it fails, ask the user: retry/skip/abort.

### Phase 2: Configure Lume MCP Server on Host

1. Install the CUA MCP server:
   ```bash
   uv pip install cua-mcp-server
   ```
   (Use `uv` if available, otherwise `pip install cua-mcp-server`)

2. Add to Claude Code as an MCP server:
   ```bash
   claude mcp add --transport stdio --scope user lume -- cua-mcp-server
   ```

3. Verify the MCP server is available. If it fails, warn the user and provide fallback SSH instructions.

### Phase 3: Guest Bootstrap via SSH

Using SSH (or the Lume MCP server if available), bootstrap the VM:

```bash
VM_IP=$(lume ls | grep <VM_NAME> | awk '{print $NF}')

# 1. Install Xcode CLI tools
ssh lume@$VM_IP 'xcode-select --install 2>/dev/null; until xcode-select -p &>/dev/null; do sleep 5; done'

# 2. Install Homebrew
ssh lume@$VM_IP '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# 3. Clone dotfiles bare repo
ssh lume@$VM_IP 'git clone --bare https://github.com/edmangalicea/dotfiles.git ~/.cfg && /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME checkout && /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME config status.showUntrackedFiles no'

# 4. Set install mode to guest
ssh lume@$VM_IP 'mkdir -p ~/.dotfiles && echo guest > ~/.dotfiles/.install-mode'
```

Each step should be run individually with error checking. If any step fails, ask the user: retry/skip/abort.

### Phase 4: Guest Agentic Install

Tell the user: "The VM is bootstrapped. To complete the guest install, you have two options:"

1. **MCP-orchestrated** (if MCP server was configured): Use the Lume MCP server to continue running the guest install from this host Claude session. Execute commands inside the VM via MCP, running the guest-mode modules (all 10 modules with guest Brewfile).

2. **Manual SSH** (fallback): SSH into the VM and run the install there:
   ```bash
   ssh lume@<VM_IP>
   # Inside the VM:
   DOTFILES_INSTALL_MODE=guest fresh.sh
   # Or for agentic: run `claude` and use /install
   ```

Ask the user which approach they prefer.

## Step 5: Summary

After either install path completes, print a summary table:

```
============================================
  Dotfiles Setup Summary  (mode: personal)
============================================
Succeeded:  01-xcode-cli, 02-homebrew, ...
Skipped:    04-rosetta (not applicable), ...
Failed:     (any failures)
Declined:   (user chose not to run)
============================================
```

For **host** mode, also include VM status:
```
VM Status:  dev-vm created and running (IP: x.x.x.x)
Guest:      Bootstrap complete / pending manual install
```

## Step 6: Post-install steps

Present the post-install steps:

1. **Generate SSH key**: `ssh-keygen -t ed25519 -C "edmangalicea@gmail.com"`
2. **Add key to GitHub**: `cat ~/.ssh/id_ed25519.pub | pbcopy` then paste at github.com/settings/keys
3. **Switch dotfiles remote to SSH**: `config remote set-url origin git@github.com:edmangalicea/dotfiles.git`
4. **Authenticate GitHub CLI**: If `gh auth status` already succeeds (authentication was completed during module 10's gh auth gate), tell the user it's already done and skip. Otherwise, use the same **gh auth gate** auto-open procedure from module 10 to open a Terminal window for `gh auth login`.

Ask the user: "Would you like help with any of these post-install steps?" If yes, walk them through the ones they choose.

## Step 7: Final reminder

Remind the user: "Restart your terminal to load the new shell configuration."
