#!/usr/bin/env zsh

#Cache sudo credentials. So we don't have to enter it again.
export SUDO_ASKPASS="/usr/bin/true"
sudo -v

# Keep sudo credentials valid for 10 minutes
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &


# Print with colors and formatting
print_step() {
  echo "\n\033[1;36m$1...\033[0m"
}

set -e
trap 'echo "An error occurred. Exiting..."' ERR

print_step "Setting up your Mac..."

# Check for Command Line Tools first as they're needed for git and homebrew
if ! xcode-select -p &>/dev/null; then
    print_step "Installing Command Line Tools"
    xcode-select --install
    # Wait for installation to complete
    until xcode-select -p &>/dev/null; do
        sleep 5
    done
fi

# Check for Oh My Zsh and install if we don't have it
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_step "Installing Oh My Zsh"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)" "" --unattended
fi

# Install Homebrew with better error handling
if ! command -v brew &>/dev/null; then
    print_step "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

print_step "Updating Homebrew"
brew update

# Setup Rosetta 2 emulation 
print_step "Setting up Rosetta 2 emulation"
softwareupdate --install-rosetta --agree-to-license

# Install apps from Homebrew
print_step "Installing apps from Homebrew..."
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
brew install utm
brew install powerlevel10k
brew install watchman
brew install --cask zulu@17




# Install Mac App Store apps. Check if mas is installed. Install if not.
print_step "Installing Mac App Store apps"
if ! command -v mas &>/dev/null; then
    brew install mas
fi

# Install apps from Mac App Store
print_step "Installing apps from Mac App Store..."
mas install 497799835 # Xcode
mas install 585829637 # Todoist
mas install 1452453066  # Hidden Bar
mas install 1482575592 # Pipad
mas install 899247664 # TestFlight
mas install 937984704 # Amphetamine
mas install 409183694 # Keynote
mas install 409201541 # Pages

#install fnm
print_step "Installing fnm"
brew install fnm
eval "$(fnm env --use-on-cd --shell zsh)"

# Install bun
print_step "Installing bun"
curl -fsSL https://bun.sh/install | bash

# Accept Xcode license
print_step "Accepting Xcode license"
xcodebuild -license accept

print_step "Making Development directory"
mkdir -p ~/Development

# At the end of your script
print_step "Cleaning up..."
brew cleanup

print_step "Verifying installations..."
brew doctor

print_step "Finished setting up your Mac!"

# Source the zshrc file
source ~/.zshrc

# Don't show untracked files in git. So the entire home directory is not shown in git status.
config config status.showUntrackedFiles no
