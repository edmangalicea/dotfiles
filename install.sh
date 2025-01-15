#!/bin/bash

echo "🚀 Starting dotfiles installation..."

# Create initial config files
echo "📝 Creating configuration files..."
touch ~/.zshrc ~/.gitignore
echo "alias config='/usr/bin/git --git-dir=\$HOME/.cfg/ --work-tree=\$HOME'" >> ~/.zshrc
echo ".cfg" >> ~/.gitignore
source ~/.zshrc
echo "Finished creating configuration files. Press Enter to continue..."
read

# Generate SSH key
echo "🔑 Generating SSH key..."
ssh-keygen -t ed25519 -C "edmangalicea@gmail.com" -f ~/.ssh/id_ed25519 -N ""
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
echo "SSH key has been copied to clipboard"
echo "⚠️  Please add the SSH key to your GitHub account at: https://github.com/settings/keys"
echo "Press Enter when you've added the key to continue..."
read

# Clone and setup dotfiles
echo "📦 Cloning dotfiles repository..."
git clone --bare git@github.com:edmangalicea/dotfiles.git $HOME/.cfg

echo "🔄 Checking out dotfiles..."
config checkout
echo "Press Enter to continue..."
read

# Run fresh.sh if it exists
if [ -f "./fresh.sh" ]; then
    echo "🛠️  Running fresh.sh..."
    ./fresh.sh
fi

echo "✅ Installation complete! You can now use the 'config' command to manage your dotfiles."