# Edman's Dotfiles

Automated Mac setup using a [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles).

## One-Line Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/edmangalicea/dotfiles/main/install.sh)"
```

> You'll be prompted for your sudo password. Installation runs unattended after that.

## Project Structure

```
~/
├── .config/
│   └── gh/config.yml      # GitHub CLI config
├── .ssh/config            # SSH configuration
├── .gitconfig             # Git configuration
├── .p10k.zsh              # Powerlevel10k theme
├── .zprofile              # Zsh profile (Homebrew path)
├── .zshrc                 # Zsh configuration
├── Brewfile               # Homebrew packages & apps
├── fresh.sh               # Post-clone setup script
├── install.sh             # Main installation script
└── README.md              # This file
```

## What Gets Installed

### CLI Tools
cocoapods, fnm, gh, git-lfs, jq, mas, mpv, openssl, pandoc, stunnel, tldr, uv, watchman

### Applications

| Category | Apps |
|----------|------|
| Development | Android Studio, Cursor, Windsurf |
| AI Tools | Claude Code, ClaudeBar, Codex |
| Browsers | Chrome, Zen |
| Productivity | Cold Turkey, f.lux, LibreOffice, Obsidian, Raycast, Rectangle, Superwhisper |
| Communication | Discord, Slack, Telegram, Zoom |
| Media | Calibre, OBS, Spotify, VLC |
| Utilities | KeyCastr, UTM, Warp |
| Mac App Store | Jomo |

### Also Installs
- Oh My Zsh
- Homebrew
- Bun
- Rosetta 2

## Post-Install

Use `config` instead of `git` to manage dotfiles:

```bash
config status
config add .zshrc
config commit -m "Update zshrc"
config push
```

## Post-Install Setup

1. Generate SSH key: `ssh-keygen -t ed25519 -C "your@email.com"`
2. Add to GitHub: `cat ~/.ssh/id_ed25519.pub | pbcopy` → [github.com/settings/keys](https://github.com/settings/keys)
3. Switch remote to SSH: `config remote set-url origin git@github.com:edmangalicea/dotfiles.git`
4. Authenticate GitHub CLI: `gh auth login`
