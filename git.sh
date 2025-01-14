
echo "Generating SSH key..."
ssh-keygen -t ed25519 -C "edmangalicea@gmail.com"
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
echo "SSH key generated and copied to clipboard. Please add it to your GitHub account."
