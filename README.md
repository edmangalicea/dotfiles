# Edman's Dotfiles

This dotfile setup is used for new mac installations. After setup the .cfg directory will become a git bare repository. You will then be able to use the config alias instead of git to interact with dotfiles from anywhere on the system.

This is based on the [atlasian dotfiles setup](https://www.atlassian.com/git/tutorials/dotfiles).

# Quick Install

1. Run this command to download and execute the installation script:
```bash
curl -O https://raw.githubusercontent.com/edmangalicea/dotfiles/main/install.sh && chmod +x install.sh && ./install.sh
```

2. When prompted, add the SSH key to your GitHub account at [github.com/settings/keys](https://github.com/settings/keys)

3. Press Enter in the terminal to continue the installation

4. When the installation is complete, restart your terminal or run `source ~/.zshrc` to use the `config` command

# What the installer does

1. Creates necessary configuration files (.zshrc, .gitignore)
2. Sets up the `config` alias for managing dotfiles
3. Generates SSH keys and copies to clipboard
4. Waits for you to add the SSH key to GitHub
5. Clones the dotfiles repository
6. Sets up your development environment using fresh.sh

# Post-installation usage

Use the `config` command to manage your dotfiles:
```bash
config status
config add .zshrc
config commit -m "Added zshrc"
config push
```
