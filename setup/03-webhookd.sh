# Download the GPG key
wget -O /usr/share/keyrings/azlux-archive-keyring.gpg https://azlux.fr/repo.gpg

# Add the repository (adjust 'trixie' to your Debian/Armbian version)
cat << EOF | sudo tee /etc/apt/sources.list.d/azlux.sources
Types: deb
URIs: http://packages.azlux.fr/debian/
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/azlux-archive-keyring.gpg
EOF

# Update and install
apt update
apt install webhookd
