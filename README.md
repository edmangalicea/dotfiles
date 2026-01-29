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

You'll be prompted for your sudo password once. Everything else runs unattended.

## What Happens During Install

1. **Pre-flight** — verifies network connectivity, logs macOS version
2. **Sudo caching** — prompts once, then keeps credentials alive via background loop
3. **Bare repo clone** — clones `dotfiles.git` to `~/.cfg` (skips if already present)
4. **Backup** — any conflicting files are moved to `~/.dotfiles-backup/<timestamp>/` (not deleted)
5. **Checkout** — dotfiles are checked out into `$HOME`
6. **Modules** — `fresh.sh` runs each module in `~/.dotfiles/modules/` in order

## Modules

| Module | What It Does |
|--------|--------------|
| `01-xcode-cli` | Installs Xcode Command Line Tools via `softwareupdate` (non-interactive) |
| `02-homebrew` | Installs Homebrew, ensures `~/.zprofile` PATH line, runs `brew update` |
| `03-omz` | Installs Oh My Zsh (`--unattended --keep-zshrc`), Powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting |
| `04-rosetta` | Installs Rosetta 2 on Apple Silicon (skips on Intel or if already running) |
| `05-brewfile` | Runs `brew bundle` from `~/Brewfile`, then `brew cleanup` |
| `06-runtime` | Installs bun, initializes fnm |
| `07-directories` | Creates `~/Development`, sets `~/.ssh` and `~/.config/gh` permissions |
| `08-macos-defaults` | Configures Finder, keyboard repeat, Dock preferences |

Each module is independently re-runnable and idempotent. Guards check if work is already done and skip accordingly.

## Re-Running

### Full re-run

```bash
~/fresh.sh
```

Modules that detect their work is already done will skip. The summary at the end shows what succeeded, skipped, or failed.

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

## File Structure

```
~/
├── .dotfiles/
│   ├── lib/
│   │   └── utils.sh              # Shared: logging, idempotent helpers, config()
│   └── modules/
│       ├── 01-xcode-cli.sh       # Xcode CLI Tools
│       ├── 02-homebrew.sh        # Homebrew install + PATH
│       ├── 03-omz.sh             # Oh My Zsh + Powerlevel10k + plugins
│       ├── 04-rosetta.sh         # Rosetta 2
│       ├── 05-brewfile.sh        # brew bundle
│       ├── 06-runtime.sh         # bun, fnm
│       ├── 07-directories.sh     # ~/Development, .ssh perms
│       └── 08-macos-defaults.sh  # Finder, keyboard, Dock
├── .config/gh/config.yml          # GitHub CLI config
├── .ssh/config                    # SSH configuration (1Password agent)
├── .gitconfig                     # Git identity, aliases, LFS
├── .gitignore                     # Ignores .cfg bare repo directory
├── .p10k.zsh                      # Powerlevel10k prompt theme
├── .zprofile                      # Homebrew shellenv
├── .zshrc                         # Shell config (plugins, paths, aliases)
├── Brewfile                       # Homebrew packages, casks, MAS apps
├── fresh.sh                       # Modular setup orchestrator
├── install.sh                     # Bootstrap entry point
└── README.md                      # This file
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
| `config checkout` fails | Existing files conflict — check `~/.dotfiles-backup/` for your originals |
| Powerlevel10k garbled | Install a Nerd Font: `brew install --cask font-meslo-lg-nerd-font`, then set it in your terminal |
| Module failed | Re-run just that module: `source ~/.dotfiles/lib/utils.sh && source ~/.dotfiles/modules/NN-name.sh` |
