### Edman's Dotfiles

This dotfile setup is used for new mac installations.

# Install 

On a new mac, run the git.sh to setup ssh keys and then run the fresh.sh to install the necessary apps and configure the dotfiles.

```
./git.sh
./fresh.sh
```


### Steps to take 

# 1
Below creates zshrc
Then adds config alias
Then sources zshrc
Then runs config (to make sure it works)

```
touch ~/.zshrc
echo "alias config='/usr/bin/git --git-dir=\$HOME/.cfg/ --work-tree=\$HOME'" >> ~/.zshrc
touch ~/.gitignore
echo ".cfg" >> ~/.gitignore

source ~/.zshrc

config 

```

# 2

Generates ssh key and copies to clipboard
```
echo "Generating SSH key..."
ssh-keygen -t ed25519 -C "edmangalicea@gmail.com"
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
echo "SSH key generated and copied to clipboard. Please add it to your GitHub account."
```

