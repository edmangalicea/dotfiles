#!/bin/zsh

# Exit on error
set -e

echo "🚀 Starting dotfiles installation..."

# Create initial config files
echo "📝 Creating configuration files..."
touch ~/.zshrc ~/.gitignore
echo "alias config='/usr/bin/git --git-dir=\$HOME/.cfg/ --work-tree=\$HOME'" >> ~/.zshrc
echo ".cfg" >> ~/.gitignore

# Define config function since sourcing might not work in script
function config() {
    /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@
}

# Generate SSH key
echo "🔑 Generating SSH key..."
ssh-keygen -t ed25519 -C "edmangalicea@gmail.com" -f ~/.ssh/id_ed25519 -N ""
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
echo "SSH key has been copied to clipboard"
echo "⚠️  Please add the SSH key to your GitHub account at: https://github.com/settings/keys"
echo "Press Enter when you've added the key to continue..."
read -r REPLY

# Test SSH connection
printf "🔄 Testing SSH connection to GitHub..."
while ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; do
    echo "❌ SSH connection failed. Please make sure you've added the key to GitHub"
    echo "Press Enter to try again..."
    read -r REPLY
done
printf "✅ SSH connection successful!\n"

# Clone and setup dotfiles
echo "📦 Cloning dotfiles repository..."
if [[ ! -d "$HOME/.cfg" ]]; then
    git clone --bare git@github.com:edmangalicea/dotfiles.git $HOME/.cfg
else
    echo "⚠️  .cfg directory already exists, skipping clone"
fi

echo "🔄 Checking out dotfiles..."
config checkout 2>&1 | grep -E "\s+\." | awk {'print $1'} | xargs -I{} dirname {} | xargs -I{} mkdir -p {}
config checkout

# Run fresh.sh if it exists
if [[ -f "./fresh.sh" ]]; then
    echo "🛠️  Running fresh.sh..."
    chmod +x ./fresh.sh
    ./fresh.sh
fi

echo "✅ Installation complete!"
echo "🔄 Please restart your terminal or run 'source ~/.zshrc' to use the 'config' command"