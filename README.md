# Edman's Dotfiles

Automated macOS setup using a [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles). Fully idempotent — safe to run multiple times.

## Prerequisites

- macOS 26.x Tahoe on Apple Silicon (M-series)
- Admin account with sudo access
- Internet connection

## One-Line Install

```bash
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/edmangalicea/dotfiles/main/install.sh)"
```

You'll be prompted for your sudo password once. After cloning, the installer prompts for machine type (Personal / VM Host / VM Guest) to tailor the setup to your environment.

## Installation Modes

The installer supports three machine types, selected during install:

| Mode | Description | Modules Run | Brewfile |
|------|-------------|-------------|----------|
| **Personal** | Full install on a personal machine | All 10 modules | Full (untagged + `@personal` lines) |
| **VM Host** | Minimal install to run Lume macOS VMs | 01, 02, 03, 05, 07 | Host-only (untagged + `@host` lines) |
| **VM Guest** | Full install inside a virtual machine | All 10 modules | Guest-only (untagged + `@guest` lines) |

### Module execution matrix

| Module | Personal | Host | Guest |
|--------|:--------:|:----:|:-----:|
| `01-xcode-cli` | yes | yes | yes |
| `02-homebrew` | yes | yes | yes |
| `03-omz` | yes | yes | yes |
| `04-rosetta` | yes | — | yes |
| `05-brewfile` | yes | yes | yes |
| `06-runtime` | yes | — | yes |
| `07-directories` | yes | yes | yes |
| `08-macos-defaults` | yes | — | yes |
| `09-dock` | yes | — | yes |
| `10-claude-config` | yes | — | yes |

### Overriding the mode

Set the `DOTFILES_INSTALL_MODE` environment variable to skip the interactive prompt:

```bash
DOTFILES_INSTALL_MODE=guest ~/fresh.sh
```

The selected mode is persisted to `~/.dotfiles/.install-mode` and used by subsequent runs of `fresh.sh`.

### Non-interactive mode

Set `DOTFILES_NONINTERACTIVE=1` for fully headless execution (e.g., inside a VM provisioned via MCP/SSH):

```bash
DOTFILES_INSTALL_MODE=guest DOTFILES_NONINTERACTIVE=1 zsh -c "$(curl -fsSL https://raw.githubusercontent.com/edmangalicea/dotfiles/main/install.sh)"
```

This skips all interactive prompts, auto-selects force install, requires passwordless sudo, skips the Claude auth window, and sets `DOTFILES_SKIP_CLAUDE_LAUNCH=1` to prevent fresh.sh from hanging at `exec claude`.

## Agentic Setup (via Claude Code)

The install script automatically installs [Claude Code](https://claude.ai) and launches an interactive agentic setup session:

```bash
# Automatic — install.sh installs Claude Code and runs:
claude --init
```

After machine type selection, Claude receives the `/install` instruction via the Setup hook and offers two modes:

- **Agentic** — Claude runs each module interactively, asks about preferences (Rosetta, Brewfile contents, macOS defaults, Node version), and handles errors as they come up
- **Deterministic** — Claude runs `~/fresh.sh` directly with no questions asked

You can also launch the agentic setup manually at any time:

```bash
claude --init    # from $HOME
```

For fully non-interactive / headless use, `~/fresh.sh` still works standalone:

```bash
~/fresh.sh
```

## Host → VM → Guest Bootstrap Flow

When installing in **VM Host** mode, the `/install` command orchestrates end-to-end VM creation and guest provisioning:

1. **Host setup** — Runs host modules (01, 02, 03, 05, 07) to install Lume, sshpass, and other host dependencies
2. **VM creation** — Downloads the tahoe unattended preset, creates a macOS VM via `lume create` CLI with SSH-ready user `lume`/`lume`
3. **VM start** — Starts the VM with a shared directory (`~/shared` ↔ `/Volumes/My Shared Files`)
4. **Guest bootstrap** — Runs `install.sh` inside the VM with `DOTFILES_NONINTERACTIVE=1` and `DOTFILES_INSTALL_MODE=guest` via Lume MCP exec, then polls `fresh.sh` progress via nohup + log tailing
5. **Verification** — Confirms Homebrew packages, dotfiles, and modules are installed in the guest

This flow incorporates battle-tested workarounds for Lume MCP limitations (creation timeouts, silent shared_dir failures, exec timeouts on long commands). See the `/install` command source for full details.

> **Warning:** `lume create --unattended tahoe` must run to completion without interruption (~15-30 min). The tahoe preset uses VNC automation to complete macOS Setup Assistant — if interrupted, the automation cannot resume and SSH will never become available. If this happens, delete the VM and recreate from scratch.

> **Note:** The `edmangalicea/vm-bootstrap` repo has been archived. Its VM creation and guest provisioning logic is now integrated here.

## What Happens During Install

1. **Pre-flight** — verifies network connectivity, logs macOS version
2. **Sudo caching** — prompts once, then keeps credentials alive via background loop
3. **Bare repo clone** — clones `dotfiles.git` to `~/.cfg` (skips if already present)
4. **Backup** — any conflicting files are moved to `~/.dotfiles-backup/<timestamp>/` (not deleted)
5. **Checkout** — dotfiles are checked out into `$HOME`
6. **Machine type selection** — prompts for Personal / VM Host / VM Guest (or reads `DOTFILES_INSTALL_MODE` env var), saves choice to `~/.dotfiles/.install-mode`
7. **Modules** — `fresh.sh` runs each module in `~/.dotfiles/modules/` in order (skipping modules not applicable for the selected mode)

## Modules

| Module | What It Does |
|--------|--------------|
| `01-xcode-cli` | Installs Xcode Command Line Tools via `softwareupdate` (non-interactive) |
| `02-homebrew` | Installs Homebrew, ensures `~/.zprofile` PATH line, runs `brew update` |
| `03-omz` | Installs Oh My Zsh (`--unattended --keep-zshrc`), Powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting |
| `04-rosetta` | Installs Rosetta 2 on Apple Silicon (skips on Intel or if already running) |
| `05-brewfile` | Filters `~/Brewfile` by machine mode (`@mode` tags), runs `brew bundle`, then `brew cleanup` |
| `06-runtime` | Installs bun, initializes fnm |
| `07-directories` | Creates `~/Development`, `~/shared` (host/guest), sets `~/.ssh` and `~/.config/gh` permissions |
| `08-macos-defaults` | Configures Finder, keyboard repeat, Dock preferences |
| `09-dock` | Configures Dock layout via `dockutil` (removes defaults, adds preferred apps in order) |
| `10-claude-config` | Clones `claude-code-backup` repo, restores Claude Code settings/hooks/commands, optional auto-sync daemon |

Each module is independently re-runnable and idempotent. Guards check if work is already done and skip accordingly.

## Re-Running

### Full re-run

```bash
~/fresh.sh
```

Modules that detect their work is already done will skip. `fresh.sh` is mode-aware — it reads `~/.dotfiles/.install-mode` (or `DOTFILES_INSTALL_MODE` env var) and skips modules not applicable for the current machine type. The summary at the end shows what succeeded, skipped, or failed.

### Individual module

```bash
source ~/.dotfiles/lib/utils.sh && source ~/.dotfiles/modules/05-brewfile.sh
```

## Managing Dotfiles

Use `config` instead of `git` to manage tracked files:

```bash
config status                       # see what's changed
config add .zshrc                   # stage a file
config commit -m "Update zshrc"     # commit
config push                         # push to remote
```

The `config` alias is defined in `~/.zshrc` and points at the bare repo in `~/.cfg`.

## Adding / Removing Apps

Edit `~/Brewfile`, then run:

```bash
brew bundle --file=~/Brewfile       # install new entries
brew bundle cleanup --file=~/Brewfile --force  # remove unlisted entries
```

### Brewfile Tag System

Lines in `~/Brewfile` can be tagged with `@personal`, `@host`, and/or `@guest` in a trailing comment to control which modes include them. Untagged lines are included in all modes.

```ruby
brew "git"                  # no tag → included in all modes
brew "sshpass"              # @host
cask "cursor"               # @personal @guest
cask "docker"               # @personal
```

The `brewfile-filter.sh` script strips lines that don't match the current mode before passing the Brewfile to `brew bundle`. A line matches if it has no `@mode` tags at all, or if at least one of its tags matches the active mode.

## File Structure

```
~/
├── .claude/
│   ├── commands/
│   │   ├── install.md             # /install command for agentic setup
│   │   └── vm.md                  # /vm command for Lume VM management
│   └── settings.json              # Setup hook + pre-approved permissions
├── .dotfiles/
│   ├── lib/
│   │   ├── brewfile-filter.sh     # Filters Brewfile by @mode tags (personal/host/guest)
│   │   ├── brewfile-selector.sh   # Interactive Brewfile package selector TUI
│   │   ├── claude-bootstrap.sh    # Claude Code bootstrap orchestrator
│   │   ├── claude-init-window.sh  # Interactive auth window for Claude setup
│   │   ├── setup-hook.sh          # Claude Code Setup hook (sudo, env, network)
│   │   └── utils.sh               # Shared: logging, idempotent helpers, config()
│   └── modules/
│       ├── 01-xcode-cli.sh        # Xcode CLI Tools
│       ├── 02-homebrew.sh         # Homebrew install + PATH
│       ├── 03-omz.sh              # Oh My Zsh + Powerlevel10k + plugins
│       ├── 04-rosetta.sh          # Rosetta 2
│       ├── 05-brewfile.sh         # brew bundle
│       ├── 06-runtime.sh          # bun, fnm
│       ├── 07-directories.sh      # ~/Development, .ssh perms
│       ├── 08-macos-defaults.sh   # Finder, keyboard, Dock
│       ├── 09-dock.sh             # Dock layout via dockutil
│       └── 10-claude-config.sh    # Claude Code config restore + sync
├── .config/gh/config.yml           # GitHub CLI config
├── .ssh/config                     # SSH configuration (1Password agent)
├── .gitconfig                      # Git identity, aliases, LFS
├── .gitignore                      # Ignores .cfg bare repo directory
├── .p10k.zsh                       # Powerlevel10k prompt theme
├── .zprofile                       # Homebrew shellenv
├── .zshrc                          # Shell config (plugins, paths, aliases)
├── Brewfile                        # Homebrew packages, casks, MAS apps
├── fresh.sh                        # Modular setup orchestrator
├── install.sh                      # Bootstrap entry point
├── README.md                       # This file
└── claude-code-backup/             # Claude config backup repo (cloned by module 10)
```

## Post-Install Manual Steps

1. **Generate SSH key**
   ```bash
   ssh-keygen -t ed25519 -C "edmangalicea@gmail.com"
   ```

2. **Add key to GitHub**
   ```bash
   cat ~/.ssh/id_ed25519.pub | pbcopy
   ```
   Then paste at [github.com/settings/keys](https://github.com/settings/keys).

3. **Switch dotfiles remote to SSH**
   ```bash
   config remote set-url origin git@github.com:edmangalicea/dotfiles.git
   ```

4. **Authenticate GitHub CLI**
   ```bash
   gh auth login
   ```

5. **Set up GitHub PAT for Claude Code**
   If module 10 warned about a placeholder, create a token at
   [github.com/settings/tokens](https://github.com/settings/tokens)
   and add it to `~/.claude/settings.json`.

## Troubleshooting

### Log file

All output is logged to `~/.dotfiles-install.log`. Check it for errors:

```bash
cat ~/.dotfiles-install.log
```

### Backups

If the install backed up conflicting files, they're in `~/.dotfiles-backup/<timestamp>/`. Restore anything you need from there.

### Common issues

| Problem | Fix |
|---------|-----|
| `brew` not found after install | Run `eval "$(/opt/homebrew/bin/brew shellenv)"` or restart your terminal |
| Xcode CLI Tools stuck | Delete `/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress` and retry |
| Xcode CLT "softwareupdate found nothing" in VM | Fresh VMs need up to 5 min for the catalog to populate. Wait and retry: `touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress && softwareupdate -l` |
| `config checkout` fails | Existing files conflict — check `~/.dotfiles-backup/` for your originals |
| Powerlevel10k garbled | Install a Nerd Font: `brew install --cask font-meslo-lg-nerd-font`, then set it in your terminal |
| Module failed | Re-run just that module: `source ~/.dotfiles/lib/utils.sh && source ~/.dotfiles/modules/NN-name.sh` |
| Claude config restore failed | Check `gh auth status`, ensure gh is authenticated. Re-run: `source ~/.dotfiles/lib/utils.sh && source ~/.dotfiles/modules/10-claude-config.sh` |
