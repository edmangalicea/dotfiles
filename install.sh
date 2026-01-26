#!/bin/zsh

# Exit on error
set -e

echo "🚀 Starting dotfiles installation..."

echo "🔐 Please enter your sudo password (will be cached for script duration):"
sudo -v

# Keep sudo alive in the background and export the timestamp
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
export SUDO_ASKPASS="/usr/bin/true"  # Prevent GUI password prompts

# Create initial config files
echo "📝 Creating configuration files..."
touch ~/.zshrc ~/.gitignore
echo "alias config='/usr/bin/git --git-dir=\$HOME/.cfg/ --work-tree=\$HOME'" >> ~/.zshrc
echo ".cfg" >> ~/.gitignore

# Define config function since sourcing might not work in script
function config() {
    /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@
}

# Clone and setup dotfiles
echo "📦 Cloning dotfiles repository..."
if [[ ! -d "$HOME/.cfg" ]]; then
    git clone --bare https://github.com/edmangalicea/dotfiles.git $HOME/.cfg
else
    echo "⚠️  .cfg directory already exists, skipping clone"
fi

echo "🔄 Checking out dotfiles..."
#config checkout 2>&1 | grep -E "\s+\." | awk {'print $1'} | xargs -I{} dirname {} | xargs -I{} mkdir -p {}

# Ensure directories exist before checkout
mkdir -p ~/.ssh && chmod 700 ~/.ssh
mkdir -p ~/.config/gh && chmod 700 ~/.config/gh

# Remove install.sh and .zshrc so that config checkout doesn't fail
rm install.sh .zshrc
config checkout

# Run fresh.sh if it exists
if [[ -f "./fresh.sh" ]]; then
    echo "🛠️  Running fresh.sh..."
    chmod +x ./fresh.sh
    ./fresh.sh
fi

echo "✅ Installation complete!"
echo "🔄 Please restart your terminal or run 'source ~/.zshrc' to use the 'config' command"

echo ""
echo "Post-installation steps:"
echo "   1. Generate SSH key: ssh-keygen -t ed25519 -C \"your@email.com\""
echo "   2. Add to GitHub: cat ~/.ssh/id_ed25519.pub | pbcopy → github.com/settings/keys"
echo "   3. Switch remote to SSH: config remote set-url origin git@github.com:edmangalicea/dotfiles.git"
echo "   4. Authenticate GitHub CLI: gh auth login"