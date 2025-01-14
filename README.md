# Edman's Dotfiles

This dotfile setup is used for new mac installations.

# Install 

On a new mac, run the git.sh to setup ssh keys and then run the fresh.sh to install the necessary apps and configure the dotfiles.

```bash
./git.sh
./fresh.sh
```


# Steps to take 


### 1 

Create the below script and copy the contents of #2

```bash
touch install.sh && chmod +x install.sh && nano install.sh
```


### 2
Below creates zshrc
Then adds config alias
Then sources zshrc
Then runs config (to make sure it works)

```bash
touch ~/.zshrc
echo "alias config='/usr/bin/git --git-dir=\$HOME/.cfg/ --work-tree=\$HOME'" >> ~/.zshrc
touch ~/.gitignore
echo ".cfg" >> ~/.gitignore
source ~/.zshrc
config 
```

### 3 

Now run the install.sh script

```bash
./install.sh
```

### 4 

Create git.sh

```bash
touch git.sh && chmod +x git.sh && nano git.sh
```

###  5

Copy the below into git.sh Generates ssh key and copies to clipboard

```bash
echo "Generating SSH key..."
ssh-keygen -t ed25519 -C "edmangalicea@gmail.com"
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
echo "SSH key generated and copied to clipboard. Please add it to your GitHub account."
```

### 6 

Add the ssh key to [github](https://github.com/settings/keys)



### 7 

Copy the repo to the home directory

```bash
git clone --bare git@github.com:edmangalicea/dotfiles.git $HOME/.cfg
```



