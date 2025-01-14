# Edman's Dotfiles

This dotfile setup is used for new mac installations. After setup the .cfg directory will become a git bare repository. You will then be able to use the config alias instead of git to interact with dotfiles fromn anywhere on the system.

This is based on the [atlasian dotfiles setup](https://www.atlassian.com/git/tutorials/dotfiles).

Example commands:
```bash
config status
config add .zshrc
config commit -m "Added zshrc"
config push
```

# Install 

On a new mac, run the steps below to setup the dotfiles.


# Steps to take 


### 1 

Run the below command and copy the contents of #2 into the nano editor.

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

Run the following command. This will create the git.sh script and open it in nano.

```bash
touch git.sh && chmod +x git.sh && nano git.sh
```

###  5

Copy the below into git.sh. Generates ssh key and copies to clipboard

```bash
echo "Generating SSH key..."
ssh-keygen -t ed25519 -C "edmangalicea@gmail.com"
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
echo "SSH key generated and copied to clipboard. Please add it to your GitHub account."
```

### 6

Run the git.sh script

```bash
./git.sh
```

### 7

Add the ssh key to [github](https://github.com/settings/keys)



### 8 

Source zshrc and copy the repo to the home directory

```bash
source ~/.zshrc && git clone --bare git@github.com:edmangalicea/dotfiles.git $HOME/.cfg
```

### 9 

Run git checkout to move the files to the home directory

```bash
rm install.sh git.sh .zshrc && config checkout
```

### 10

Run the fresh.sh script

```bash
./fresh.sh
```

### 11 Congrats!

You have now setup the dotfiles. You can now use the config alias to interact with dotfiles fromn anywhere on the system.

```bash
config status
config add .zshrc
config commit -m "Added zshrc"
config push
```
