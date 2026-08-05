#!/bin/bash
# 03-webhookd.sh — Install webhookd for GitHub Actions CI/CD trigger
set -euo pipefail

echo "=== Installing webhookd ==="
wget -O /usr/share/keyrings/azlux-archive-keyring.gpg https://azlux.fr/repo.gpg

cat << EOF | tee /etc/apt/sources.list.d/azlux.sources
Types: deb
URIs: http://packages.azlux.fr/debian/
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/azlux-archive-keyring.gpg
EOF

apt-get update -qq
apt-get install -y -qq webhookd apache2-utils

echo "=== Configuring webhookd ==="
REPO_DIR="/opt/homelab"
SCRIPTS_DIR="${REPO_DIR}/scripts"

tee /etc/webhookd.env << EOF
WHD_HOOK_SCRIPTS="${SCRIPTS_DIR}"
WHD_LISTEN_ADDR=:8080
WHD_PASSWD_FILE="/etc/webhookd.htpasswd"
WHD_HOOK_TIMEOUT=180
EOF

echo "=== Setting up htpasswd ==="
echo "Enter password for github-deploy user:"
htpasswd -cB /etc/webhookd.htpasswd github-deploy

echo "=== Creating webhookd service override ==="
USERNAME="${SUDO_USER:-$USER}"
mkdir -p /etc/systemd/system/webhookd.service.d
cat > /etc/systemd/system/webhookd.service.d/override.conf << EOF
[Service]
User=${USERNAME}
Group=${USERNAME}
EOF

systemctl daemon-reload
systemctl enable --now webhookd

echo "Done."
