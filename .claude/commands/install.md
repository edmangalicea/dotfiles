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

10. **10-claude-config** *(Personal, Guest only)* — This module restores Claude Code configuration from the backup repo. It requires `gh auth status` to succeed. Before running this module, perform the **gh auth gate** procedure below. If auth succeeds, continue to the **branch selection** step before running the module. If auth fails, times out, or the user declines, mark as **skipped**.

#### Branch selection (before running module 10)

After gh auth succeeds, clone the repo first (Phase 1 only) so remote branches are available, then let the user pick which branch to restore config from:

1. **Run Phase 1 (clone only)** — Execute the module with `CLAUDE_BACKUP_BRANCH=__skip__` to trigger only the clone, then abort before Phase 2. In practice, just clone directly:
   ```bash
   if [[ ! -d "$HOME/claude-code-backup/.git" ]]; then
     gh repo clone edmangalicea/claude-code-backup "$HOME/claude-code-backup"
   fi
   ```

2. **Fetch all remote branches and list them**:
   ```bash
   git -C ~/claude-code-backup fetch --all 2>/dev/null
   git -C ~/claude-code-backup branch -r --format='%(refname:short)' | sed 's|origin/||' | grep -v HEAD
   ```

3. **Determine the recommended default** — Compute the hostname-derived branch:
   ```bash
   _hostname_branch="$(hostname -s | tr '[:upper:]' '[:lower:]')"
   ```
   If `$_hostname_branch` exists in the remote branch list, mark it as `(Recommended)`. Otherwise, mark `main` as `(Recommended)`.

4. **Present branches to the user** via `AskUserQuestion`. List the available remote branches as options (up to 4, with the recommended one first). Include the hostname-derived branch name even if it doesn't exist remotely (it will be created as a new branch). Example:

   - **mybranch (Recommended)** — "Matches this machine's hostname"
   - **main** — "Default branch"
   - **other-machine** — "Config from other-machine"

5. **Run module 10 with the selected branch**:
   ```bash
   zsh -c 'source ~/.dotfiles/lib/utils.sh && CLAUDE_BACKUP_BRANCH=<selected> source ~/.dotfiles/modules/10-claude-config.sh'
   ```
   The module's Phase 2 will use `CLAUDE_BACKUP_BRANCH` instead of deriving the branch from hostname.

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
6. **`lume create --unattended` must not be interrupted** — The tahoe preset uses VNC automation to complete macOS Setup Assistant. If the VM is stopped mid-creation (~15-30 min), the automation cannot resume and SSH will never become available. Fix: delete the VM and recreate from scratch.
7. **Xcode CLT `softwareupdate` needs up to 5 min on fresh VMs** — The software update catalog takes time to populate after first boot. The install.sh retry logic (20x15s = 5 min) handles this, but if you are running install.sh from the remote repo (not yet pushed), the old retry window may be insufficient. **Workaround:** Pre-install Xcode CLT in the guest before running install.sh (see Phase 2, step 1b).
8. **`lume stop` returns exit code 130** — This is normal (SIGINT). The VM stops successfully despite the non-zero exit code. Do not treat this as an error.
9. **Guest install.sh uses the remote (GitHub) version** — Changes to install.sh/modules are only picked up by the guest if they have been committed and pushed to the remote repo. Local uncommitted changes on the host have no effect on the guest bootstrap.

### Phase 1: VM Creation (MCP preferred, CLI fallback)

1. Ask the user for VM configuration:
   - VM name (default: `dev-vm`)
   - Disk size (default: `50` GB)

2. Ensure `~/shared` exists:
   ```bash
   mkdir -p ~/shared
   ```

3. Check if a VM with the same name already exists via `lume_list_vms` (or `lume ls`). If it does, ask the user whether to delete and recreate it or use a different name. To delete: `lume_delete_vm(name=<NAME>)` or `echo "y" | lume delete <NAME>`.

4. **Check for cached IPSW** — **NEVER pass `--ipsw latest` to `lume create`** (it downloads ~17 GB to a temp folder that is discarded after creation):
   ```bash
   IPSW_CACHE="/Users/Shared/ipsw"
   IPSW_FILE="$IPSW_CACHE/latest.ipsw"
   mkdir -p "$IPSW_CACHE"
   if [[ -f "$IPSW_FILE" ]]; then
     echo "Using cached IPSW: $IPSW_FILE ($(du -h "$IPSW_FILE" | cut -f1))"
     IPSW_ARG="$IPSW_FILE"
   fi
   ```

   If the cached IPSW is NOT found, ask the user: "Do you have a macOS IPSW file? Provide the path, or leave empty to download (~17 GB)."

   - If the user provides a path, copy it to the cache and use it:
     ```bash
     cp "<USER_PATH>" "$IPSW_FILE"
     IPSW_ARG="$IPSW_FILE"
     ```

   - If no local file exists anywhere, download to the cache FIRST, then use it:
     ```bash
     echo "No cached IPSW found. Downloading to $IPSW_FILE (~17 GB)..."
     lume pull ipsw latest --output "$IPSW_FILE"
     # Fallback if lume pull unavailable:
     # curl -fsSL -o "$IPSW_FILE" "$(lume ipsw-url latest)"
     IPSW_ARG="$IPSW_FILE"
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

7. **Start the VM** via CLI (**do not use MCP `lume_run_vm`** — `shared_dir` silently fails to mount):
   ```bash
   mkdir -p ~/shared
   lume run <NAME> --shared-dir $HOME/shared:rw --no-display
   ```
   Run in background. Wait 30 seconds, then verify with `lume_get_vm` or `lume ls`. Confirm shared directory is mounted by checking `sessions.json`.

8. Verify SSH connectivity via MCP:
   ```
   lume_exec(vm_name=<NAME>, command="whoami")
   ```
   Expected output: `lume`. If it fails, retry a few times with 15-second delays (VM may still be booting).

9. Verify shared directory is mounted:
    ```
    lume_exec(vm_name=<NAME>, command="ls /Volumes/")
    ```
    Expected: output includes `My Shared Files`.

### Phase 2: Guest Bootstrap via MCP

1. **Set up passwordless sudo** for the `lume` user (may already be configured by tahoe preset, but ensure it):
   ```
   lume_exec(vm_name=<NAME>, command="echo 'lume' | sudo -S sh -c 'echo \"lume ALL=(ALL) NOPASSWD:ALL\" > /etc/sudoers.d/lume && chmod 0440 /etc/sudoers.d/lume'")
   ```

1b. **Pre-install Xcode CLT** (workaround #7 — the software update catalog takes up to 5 min to populate on fresh VMs, and the remote install.sh may not have sufficient retry logic):
   ```
   lume_exec(vm_name=<NAME>, command="touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress && softwareupdate -l 2>&1 | grep 'Command Line Tools'")
   ```
   If the output is empty, retry via polling every 15 seconds for up to 5 minutes:
   ```bash
   for i in $(seq 1 20); do
     RESULT=$(sshpass -p lume ssh -o StrictHostKeyChecking=no lume@<IP> "softwareupdate -l 2>&1 | grep -B1 'Command Line Tools' | grep '^\s*\*' | head -1 | sed 's/^[ *]*//' | sed 's/^ Label: //'")
     [[ -n "$RESULT" ]] && break
     sleep 15
   done
   ```
   Once found, install it (this takes 1-2 min and will timeout via MCP — use nohup):
   ```
   lume_exec(vm_name=<NAME>, command="nohup sudo softwareupdate -i '<LABEL>' --verbose > /tmp/xcode-install.log 2>&1 &")
   ```
   Poll for completion by checking `xcode-select -p` every 15 seconds. Once it returns `/Library/Developer/CommandLineTools`, proceed.

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

3b. **Open a streaming terminal window** for real-time visibility into the guest install (the user sees nothing otherwise for 15+ min). Get the VM IP first, then open a Terminal window via osascript:
   ```bash
   VM_IP=$(lume ls 2>/dev/null | grep <NAME> | awk '{print $3}')
   STREAM_WINDOW_ID=$(osascript -e 'tell application "Terminal"' -e 'activate' -e "do script \"sshpass -p lume ssh -o StrictHostKeyChecking=no lume@${VM_IP} 'tail -f /tmp/fresh-install.log'\"" -e 'return id of front window' -e 'end tell' 2>/dev/null) || STREAM_WINDOW_ID=""
   ```
   If osascript fails (headless context), skip the streaming window — fall back to polling only. Save the window ID so it can be closed after fresh.sh completes.

   After step 4 confirms fresh.sh is DONE, close the streaming window:
   ```bash
   if [[ -n "$STREAM_WINDOW_ID" ]]; then
     osascript -e 'tell application "Terminal"' -e "repeat with w in windows" -e "if id of w is $STREAM_WINDOW_ID then" -e "close w" -e "exit repeat" -e "end if" -e "end repeat" -e 'end tell' 2>/dev/null || true
   fi
   ```

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
║    2. GitHub CLI:        gh auth login                       ║
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

1. **Authenticate GitHub CLI**: If `gh auth status` already succeeds (authentication was completed during module 10's gh auth gate), tell the user it's already done and skip. Otherwise, use the same **gh auth gate** auto-open procedure from module 10 to open a Terminal window for `gh auth login`.

Ask the user: "Would you like help with any of these post-install steps?" If yes, walk them through the ones they choose.

## Step 7: Final reminder

Remind the user: "Restart your terminal to load the new shell configuration."
