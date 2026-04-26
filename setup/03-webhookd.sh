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
apt install apache2-utils

tee /etc/webhookd.env << 'EOF'
WHD_HOOK_SCRIPTS="/home/homecontrol/home-control-server-config/scripts/"
WHD_LISTEN_ADDR=:8080
WHD_PASSWD_FILE="/etc/webhookd.htpasswd"
WHD_HOOK_TIMEOUT=180
EOF

# chmod -R +x /home/homecontrol/home-control-server-config/scripts

# add password to password manager
sudo htpasswd -cB /etc/webhookd.htpasswd github-deploy

sudo service webhookd restart

sudo systemctl edit webhookd
## Add the following content to override the service configuration
[Service]
User=homecontrol
Group=homecontrol


sudo systemctl daemon-reload
sudo systemctl restart webhookd