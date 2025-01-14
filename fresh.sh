# Change the shebang line at the top of the file
#!/usr/bin/env zsh

echo "Setting up your Mac..."


# Check for Oh My Zsh and install if we don't have it
if test ! $(which omz); then
  /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
fi




# Check for Homebrew and install if we don't have it
if test ! $(which brew); then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install Fnm (Fast node Manager)
curl -fsSL https://fnm.vercel.app/install | zsh

# Update Homebrew
brew update

echo "Installing apps from Homebrew..."

# Install apps from Homebrew
brew install discord
brew install 1password
brew install arc
brew install raycast
brew install obs
brew install slack
brew install spotify
brew install calibre
brew install vlc
brew install cursor
brew install rectangle
brew install figma
brew install android-studio
brew install cold-turkey-blocker
brew install warp
brew install uv
brew install telegram
brew install anki
brew install windsurf
brew install zoom
brew install git-lfs
brew install mas
brew install utm
brew install powerlevel10k

# Install apps from Mac App Store
echo "Installing apps from Mac App Store..."
mas install 497799835 # Xcode
mas install 585829637 # Todoist
mas install 1452453066  # Hidden Bar
mas install 1482575592 # Pipad
mas install 899247664 # TestFlight
mas install 937984704 # Amphetamine
mas install 409183694 # Keynote
mas install 409201541 # Pages

#install fnm
brew install fnm
eval "$(fnm env --use-on-cd --shell zsh)"



# Initialize git
git --version

# Install Command Line Tools
xcode-select --install

# Install bun
curl -fsSL https://bun.sh/install | bash

# Source the zshrc file
source ~/.zshrc

#Accept Xcode license
sudo xcodebuild -license accept

echo "Finished setting up your Mac!"