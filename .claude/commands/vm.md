---
name: vm
description: Manage the Lume macOS VM — create, start with shared drive, stop, or check status
allowed-tools: Bash, Read, AskUserQuestion, mcp__lume__lume_list_vms, mcp__lume__lume_get_vm, mcp__lume__lume_run_vm, mcp__lume__lume_stop_vm, mcp__lume__lume_exec, mcp__lume__lume_create_vm, mcp__lume__lume_delete_vm
---

# Lume VM Management

You are managing a macOS virtual machine using **Lume** (Apple Virtualization framework). If the user doesn't specify anything else `base-macos-setup` is the base configuration:

## VM Details

- **Name:** `base-macos-setup`
- **OS:** macOS
- **CPU:** 4 cores
- **Memory:** 8 GB
- **Disk:** 50 GB
- **Shared directory (host):** `~/shared`
- **Shared directory (guest):** Auto-mounted via VirtioFS at `/Volumes/My Shared Files`

## Prerequisites

Before any VM operation, verify `lume` is installed (`which lume`). If not found, install via the **official installer only** (do NOT use `brew install lume` — the Homebrew formula omits the resource bundle, causing `--unattended` presets to silently fail):

```bash
# Remove Homebrew version first if present
brew uninstall lume 2>/dev/null || true
# Install official lume with resource bundle
curl -fsSL https://raw.githubusercontent.com/trycua/cua/main/libs/lume/scripts/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"
```

Verify the resource bundle is intact:
```bash
ls ~/.local/bin/lume_lume.bundle/unattended-presets/
# Should list tahoe.yml and other presets
```

## Step 1: Ask the user what they want to do

Present options using paginated AskUserQuestion calls (max 4 options per call).

**Page 1** — call AskUserQuestion with these 4 options:
1. **Start** — Start the VM with the shared drive mounted
2. **Stop** — Stop the VM
3. **Status** — Check if the VM is running and show details
4. **More options...** — Show additional VM actions

If the user picks "More options..." on Page 1, show **Page 2**:
1. **Restart** — Stop and restart the VM with the shared drive
2. **Rebuild** — Delete and recreate VM by cloning from base-macos-setup
3. **Delete** — Delete the VM
4. **More options...** — Show additional VM actions

If the user picks "More options..." on Page 2, show **Page 3**:
1. **Create** — Create a clone of an existing VM with a shared drive
2. **Create from IPSW** — Create from scratch using macOS IPSW restore image and a shared drive
3. **Create Unattended** — Create a VM with the tahoe preset (SSH-ready, user `lume`/`lume`, no manual Setup Assistant)

## Step 2A: Create

1. Ask the user for a name for the VM (default: `base-macos-setup`).

2. Ask the user for the disk size (default: 50GB).

3. Ensure `~/shared` exists:

```bash
mkdir -p ~/shared
```

4. Ask the user for the IPSW path or use `--ipsw latest` (default). If the user has a local IPSW, use `--ipsw <PATH>`. Otherwise:

```bash
lume create --disk-size <SIZE>GB --ipsw latest <NAME>
```

This command takes a long time (downloads macOS IPSW + installs). Run it with a 10-minute timeout.

5. Once created, immediately start it with the shared drive:

```bash
lume run <NAME> --shared-dir ~/shared:rw --no-display
```

Run in background, wait ~15 seconds, then verify with `lume ls`.

6. Open the VNC window so the user can complete macOS setup:

```bash
open "<VNC_URL from lume ls>"
```

7. Remind the user that the shared drive will be available in the guest at `/Volumes/My Shared Files` once macOS setup is complete.

## Step 2B: Start

1. List all VMs and ask the user which one to start (if not already specified):

```bash
lume ls
```

If the selected VM shows `running`, tell the user it's already running and show the VNC URL. Ask if they want to restart it instead.

2. Ensure `~/shared` exists:

```bash
mkdir -p ~/shared
```

3. Start the VM with the shared directory (use the selected `<NAME>`):

```bash
lume run <NAME> --shared-dir ~/shared:rw --no-display
```

Run this in the background. Wait ~15 seconds, then verify it started:

```bash
lume ls
```

4. If the VM fails with "Failed to lock auxiliary storage", a stale process is holding file locks. Fix it:

```bash
lsof ~/.lume/<NAME>/nvram.bin
```

Kill the stale PID shown, wait 2 seconds, then retry the `lume run` command.

5. Once running, verify the shared directory is in the session config:

```bash
cat ~/.lume/<NAME>/sessions.json
```

Confirm `sharedDirectories` contains the `~/shared` entry with `com.apple.virtio-fs.automount` tag.

6. Show the user the VNC URL from `lume ls` output so they can connect.

## Step 2C: Stop

```bash
lume stop <NAME>
```

> **Note:** `lume stop` normally returns exit code 130 (SIGINT). This is expected — the VM stops successfully despite the non-zero exit code. Do not treat this as an error.

If the stop hangs or fails, find and kill the process:

```bash
lsof ~/.lume/<NAME>/nvram.bin
```

Kill the PID shown, then confirm the VM is stopped with `lume ls`.

## Step 2D: Status

Run:

```bash
lume ls
```

Show the user:
- Whether the VM is running or stopped
- IP address (if running)
- VNC URL (if running)
- Whether shared directories are configured (check `sessions.json`)

## Step 2E: Restart

Run Stop (Step 2C), then Start (Step 2B).

## Step 2F: Delete

1. Stop the VM first if it's running (Step 2C).

2. Delete the VM:

```bash
echo "y" | lume delete <NAME>
```

3. Verify with `lume ls`.

## Step 2G: Rebuild

Rebuild destroys an existing VM and recreates it by cloning from `base-macos-setup`. Do NOT ask for confirmation — proceed directly.

1. Ask the user which VM to rebuild. Default: `base-macos-setup`. Show the list from `lume ls` so they can pick.

2. Ask the user for the desired disk size (default: 50GB). If the user already specified a size in their request, use that value without asking.

3. Stop the target VM if it is running (Step 2C).

4. Delete the target VM:

```bash
echo "y" | lume delete <NAME>
```

5. Verify deletion with `lume ls`.

6. Stop `base-macos-setup` if it is running (`lume clone` requires the source VM to be stopped for a consistent disk state):

```bash
lume stop base-macos-setup
```

7. Clone `base-macos-setup` to the new VM:

```bash
lume clone base-macos-setup <NAME>
```

8. If the requested disk size differs from the base image default, resize the cloned VM's disk (VM must be stopped, which it is right after cloning):

```bash
lume set <NAME> --disk-size <SIZE>GB
```

9. Start the new clone with the shared directory:

```bash
lume run <NAME> --shared-dir ~/shared:rw --no-display
```

Run in background, wait ~15 seconds, then verify with `lume ls`.

10. Get the full VNC URL from the session config (since `lume ls` may truncate it):

```bash
cat ~/.lume/<NAME>/sessions.json
```

11. Open the VNC window:

```bash
open "<VNC_URL from sessions.json>"
```

12. Show the user the VM details (name, IP, VNC URL, shared directory paths) and let them know the VM is ready to use — macOS is already set up from the base image. The shared drive will be available at `/Volumes/My Shared Files`.

## Step 2H: Create from IPSW

Creates a brand-new VM from scratch using the local macOS IPSW restore image. This is slower than cloning from a base image but produces a clean install.

1. Ask the user for a name for the VM (default: `base-macos-setup`).

2. Ask the user for the disk size (minimum 30GB, default: 50GB). If the user provides a value below 50GB, warn them

3. Ensure `~/shared` exists:

```bash
mkdir -p ~/shared
```

4. Ask the user for the IPSW path or use `--ipsw latest` (default). If the user has a local IPSW file, use `--ipsw <PATH>`. Otherwise:

```bash
lume create --disk-size <SIZE>GB --ipsw latest <NAME>
```

This command takes a long time (downloads macOS IPSW + installs). Run it with a 10-minute timeout.

5. Once created, immediately start it with the shared drive:

```bash
lume run <NAME> --shared-dir ~/shared:rw --no-display
```

Run in background, wait ~15 seconds, then verify with `lume ls`.

6. Get the full VNC URL from the session config (since `lume ls` may truncate it):

```bash
cat ~/.lume/<NAME>/sessions.json
```

7. Open the VNC window so the user can complete macOS setup:

```bash
open "<VNC_URL from sessions.json>"
```

8. Show the user the VM details (name, IP, VNC URL, shared directory paths) and remind them the shared drive will be available at `/Volumes/My Shared Files` once macOS setup is complete.

## Step 2I: Create Unattended

Creates a VM with the tahoe unattended preset — fully automated macOS setup with SSH-ready user `lume`/`lume`. No manual Setup Assistant needed.

1. Ask the user for a name for the VM (default: `dev-vm`).

2. Ask the user for the disk size (default: 50GB).

3. Ensure `~/shared` exists:

```bash
mkdir -p ~/shared
```

4. **Download tahoe preset** (the built-in preset name may fail to resolve):

```bash
curl -fsSL "https://raw.githubusercontent.com/trycua/cua/main/libs/lume/src/Resources/unattended-presets/tahoe.yml" -o /tmp/lume-unattended-tahoe.yml
```

Verify the download succeeded (non-empty file). If the first URL fails, try:

```bash
curl -fsSL "https://raw.githubusercontent.com/trycua/cua/main/libs/lume/resources/unattended-tahoe.yml" -o /tmp/lume-unattended-tahoe.yml
```

5. Check if a VM with the same name already exists via `lume ls`. If so, ask whether to delete and recreate it.

6. Create the VM via CLI (**do not use MCP** — `lume_create_vm` with `unattended` always times out):

```bash
lume create --ipsw latest --disk-size <SIZE>GB --unattended /tmp/lume-unattended-tahoe.yml --no-display <NAME>
```

Run with `timeout: 600000` and `run_in_background: true`. Poll progress via `lume ls` every 90 seconds. Creation takes 15-30 minutes.

7. Once created, start with shared directory (**do not use MCP `lume_run_vm`** — `shared_dir` silently fails):

```bash
lume run <NAME> --shared-dir $HOME/shared:rw --no-display
```

Run in background. Wait 30 seconds, then verify with `lume ls`.

8. Verify SSH connectivity:

```
lume_exec(vm_name=<NAME>, command="whoami")
```

Expected: `lume`. Retry with 15-second delays if the VM is still booting.

9. Show the user the VM details: name, IP, SSH credentials (`lume`/`lume`), shared directory paths.

## Troubleshooting

### "Failed to lock auxiliary storage"
A previous VM process didn't release its file locks. Find and kill the stale process:

```bash
lsof ~/.lume/<NAME>/nvram.bin
# Kill the PID from the output
kill <PID>
sleep 2
# Retry starting the VM
```

### Shared directory not visible in guest
- Ensure the VM was started with `--shared-dir ~/shared:rw`
- The `sessions.json` file should show the shared directory config
- In the guest macOS, check Finder sidebar under **Locations** or browse to `/Volumes/My Shared Files`
- The `lume ls` shared_dirs column may show `-` even when shared dirs are active — check `sessions.json` instead

### Unattended setup interrupted — SSH never becomes available

If `lume create --unattended tahoe` was interrupted (stopped, killed, or timed out before completion), the VNC automation that completes macOS Setup Assistant cannot resume. SSH will never become available.

**Fix:** Delete the VM and recreate from scratch. The creation process takes 15-30 minutes and must run to completion without interruption.

```bash
echo "y" | lume delete <NAME>
lume create --ipsw latest --disk-size <SIZE>GB --unattended tahoe --no-display <NAME>
# Wait 15-30 minutes for completion — do NOT interrupt
```

### VM won't start after unclean shutdown
Check for stale locks on both files:

```bash
lsof ~/.lume/<NAME>/nvram.bin
lsof ~/.lume/<NAME>/disk.img
```

Kill any processes shown, then retry.
