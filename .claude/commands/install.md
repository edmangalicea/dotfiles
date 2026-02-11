---
name: install
description: Run the dotfiles setup — install all dependencies and configure the system
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, mcp__lume__lume_list_vms, mcp__lume__lume_get_vm, mcp__lume__lume_run_vm, mcp__lume__lume_stop_vm, mcp__lume__lume_exec, mcp__lume__lume_create_vm, mcp__lume__lume_delete_vm
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

### Prerequisites: Install Lume via official installer

Lume must NOT be installed via Homebrew (the brew formula omits the resource bundle, causing crashes). Install via the official script:

```bash
if ! command -v lume &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/trycua/cua/main/libs/lume/scripts/install.sh)"
  export PATH="$HOME/.local/bin:$PATH"
fi
```

This installs to `~/.local/bin/lume` with the resource bundle intact.

### Configure Lume MCP Server

Set up the MCP server **before** VM creation so MCP tools are available:

```bash
claude mcp add --transport stdio --scope user lume -- lume serve --mcp
```

Verify the MCP server is available by calling `lume_list_vms`. If it fails, warn the user and fall back to CLI commands.

### Known Issues & Workarounds

1. **`lume_exec` may timeout on long commands** — For anything that takes more than a few minutes (install.sh, fresh.sh), use `nohup` + log polling pattern.
2. **install.sh hangs at `exec claude` in headless SSH** — Set `DOTFILES_NONINTERACTIVE=1` to skip all interactive prompts and the Claude handoff. (fresh.sh also guards against this when `DOTFILES_NONINTERACTIVE=1`.)
3. **fresh.sh hangs at `exec claude --dangerously-skip-permissions`** — Set `DOTFILES_SKIP_CLAUDE_LAUNCH=1` to exit before the exec. (Also guarded by `DOTFILES_NONINTERACTIVE=1`.)
4. **Lume REST API (`lume serve` on port 7777) does NOT support `unattended` on create** — Always use MCP `lume_create_vm` or CLI `lume create` for VM creation with unattended setup.
5. **Cursor cask may fail with xattr permission error** — This is a known Homebrew/macOS SIP issue. If it fails, suggest: `brew install --cask cursor --no-quarantine`.

### Phase 1: VM Creation (MCP preferred, CLI fallback)

1. Ask the user for VM configuration:
   - VM name (default: `dev-vm`)
   - Disk size (default: `50` GB)

2. Ensure `~/shared` exists:
   ```bash
   mkdir -p ~/shared
   ```

3. Check if a VM with the same name already exists via `lume_list_vms` (or `lume ls`). If it does, ask the user whether to delete and recreate it or use a different name. To delete: `lume_delete_vm(name=<NAME>)` or `echo "y" | lume delete <NAME>`.

4. **Check for cached IPSW** (avoids re-downloading 17 GB):
   ```bash
   IPSW_CACHE="/Users/Shared/ipsw"
   IPSW_FILE="$IPSW_CACHE/latest.ipsw"
   mkdir -p "$IPSW_CACHE"
   if [[ -f "$IPSW_FILE" ]]; then
     echo "Using cached IPSW: $IPSW_FILE ($(du -h "$IPSW_FILE" | cut -f1))"
     IPSW_ARG="$IPSW_FILE"
   else
     echo "No cached IPSW — will download (~17 GB, ~15 min)"
     IPSW_ARG="latest"
   fi
   ```

5. **Create the VM via MCP** (preferred):
   ```
   lume_create_vm(name=<NAME>, disk_size="<SIZE>GB", unattended="tahoe", ipsw="$IPSW_ARG")
   ```
   This is asynchronous — it returns immediately. The `unattended="tahoe"` preset creates a user `lume` with password `lume` and SSH enabled.

   **CLI fallback** — If MCP `lume_create_vm` is unavailable or fails:
   ```bash
   lume create --ipsw "$IPSW_ARG" --disk-size <SIZE>GB --unattended tahoe --no-display <NAME>
   ```
   Run with `timeout: 600000` and `run_in_background: true`.

6. **Poll creation progress** every 90 seconds using `lume_get_vm(name=<NAME>)` or `lume ls`. Look for the VM status to change from creating to stopped/ready. Creation typically takes 15-30 minutes.

7. **Cache the IPSW** for future use (if not already cached):
   ```bash
   if [[ ! -f "$IPSW_FILE" ]]; then
     TEMP_IPSW=$(find /private/var/folders -maxdepth 4 -name "latest.ipsw" 2>/dev/null | head -1)
     if [[ -n "$TEMP_IPSW" ]]; then
       cp "$TEMP_IPSW" "$IPSW_FILE"
       echo "Cached IPSW to $IPSW_FILE for future use"
     fi
   fi
   ```

8. **Start the VM** via MCP or CLI:
   ```
   lume_run_vm(name=<NAME>, shared_dir="$HOME/shared", no_display=true)
   ```
   **CLI fallback:**
   ```bash
   lume run <NAME> --shared-dir $HOME/shared:rw --no-display
   ```
   Run in background. Wait 30 seconds, then verify with `lume_get_vm` or `lume ls`.

9. Verify SSH connectivity via MCP:
   ```
   lume_exec(vm_name=<NAME>, command="whoami")
   ```
   Expected output: `lume`. If it fails, retry a few times with 15-second delays (VM may still be booting).

10. Verify shared directory is mounted:
    ```
    lume_exec(vm_name=<NAME>, command="ls /Volumes/")
    ```
    Expected: output includes `My Shared Files`.

### Phase 2: Guest Bootstrap via MCP

1. **Set up passwordless sudo** for the `lume` user (may already be configured by tahoe preset, but ensure it):
   ```
   lume_exec(vm_name=<NAME>, command="echo 'lume' | sudo -S sh -c 'echo \"lume ALL=(ALL) NOPASSWD:ALL\" > /etc/sudoers.d/lume && chmod 0440 /etc/sudoers.d/lume'")
   ```

2. **Run install.sh** with non-interactive flags:
   ```
   lume_exec(vm_name=<NAME>, command="DOTFILES_INSTALL_MODE=guest DOTFILES_NONINTERACTIVE=1 zsh -c \"$(curl -fsSL https://raw.githubusercontent.com/edmangalicea/dotfiles/main/install.sh)\"")
   ```
   **Expected behavior**: This will likely timeout at the MCP level because install.sh takes a long time. That's OK — proceed to step 3.

3. **If timeout, verify dotfiles were cloned**, then run fresh.sh via nohup (workaround #5):
   ```
   lume_exec(vm_name=<NAME>, command="test -d ~/.cfg && echo CLONED || echo MISSING")
   ```
   If cloned, run fresh.sh in the background:
   ```
   lume_exec(vm_name=<NAME>, command="nohup zsh -c 'source $HOME/.dotfiles/lib/utils.sh && DOTFILES_INSTALL_MODE=guest DOTFILES_NONINTERACTIVE=1 DOTFILES_SKIP_CLAUDE_LAUNCH=1 $HOME/fresh.sh' > /tmp/fresh-install.log 2>&1 &")
   ```
   If not cloned, the install.sh may still be running. Wait and retry.

4. **Poll fresh.sh progress** every 60 seconds (workaround #5):
   ```
   lume_exec(vm_name=<NAME>, command="tail -20 /tmp/fresh-install.log")
   lume_exec(vm_name=<NAME>, command="pgrep -f fresh.sh && echo RUNNING || echo DONE")
   ```
   Look for "Dotfiles setup complete." or the summary table output. Keep polling until DONE.

5. **Verify the installation** succeeded:
   ```
   lume_exec(vm_name=<NAME>, command="brew list | head -20")
   lume_exec(vm_name=<NAME>, command="ls ~/.cfg && echo DOTFILES_OK")
   lume_exec(vm_name=<NAME>, command="ls ~/.dotfiles/modules/ | wc -l")
   ```

### Phase 3: Summary

Show a VM details box:
```
╔══════════════════════════════════════════════════════════════╗
║  VM Ready                                                    ║
║                                                              ║
║  Name:       <NAME>                                          ║
║  IP:         <IP from lume ls>                               ║
║  SSH:        sshpass -p lume ssh lume@<IP>                   ║
║  Shared dir: ~/shared (host) ↔ /Volumes/My Shared Files     ║
║                                                              ║
║  Manual steps remaining:                                     ║
║    1. Claude Code auth:  ssh in, run `claude --init`         ║
║    2. SSH key:           ssh-keygen -t ed25519               ║
║    3. GitHub CLI:        gh auth login                       ║
╚══════════════════════════════════════════════════════════════╝
```

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
