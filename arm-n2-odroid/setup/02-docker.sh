#!/bin/bash
set -e

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# ============================================================
# 02-docker.sh - Docker Installation (Ubuntu)
# ============================================================

armbian-config --cmd CON001 # install docker
docker run hello-world

# armbian-config --cmd POR001 # install portainer and start it on boot
armbian-config --cmd CPT001 # install Cockpit OS and VM management tool

# ============================================
# DISABLE VM PLUGIN (cockpit-machines)
# ============================================
echo "[1/3] Disabling VM plugin (cockpit-machines)..."

# Create override file to hide the Virtual Machines menu item
cat > /etc/cockpit/machines.override.json << 'EOF'
{
  "menu": {
    "vms": null
  }
}
EOF

echo "Created /etc/cockpit/machines.override.json"

# ============================================
# Install additional plugins
# ============================================
echo "[2/3] Installing additional cockpit plugins..."
apt-get install cockpit-files cockpit-packagekit cockpit-networkmanager cockpit-sosreport -y

echo "deb [trusted=yes arch=all] https://chrisjbawden.github.io/cockpit-dockermanager stable main" \
  | tee /etc/apt/sources.list.d/cockpit-dockermanager.list

apt update
apt install dockermanager

# ============================================
# setup cloudflare app for cockpit
# ============================================
echo "[3/3] Setting up Cloudflare app for Cockpit..."

pip3 install PyJWT cryptography 2>/dev/null || apt install -y python3-jwt 2>/dev/null || echo "Warning: Could not install PyJWT"

cp cockpit-auth-cloudflare /usr/local/bin/cockpit-auth-cloudflare
chmod +x /usr/local/bin/cockpit-auth-cloudflare

mkdir -p /etc/cockpit

cat > /etc/cockpit/cockpit.conf << EOF
[WebService]
Origins = https://$COCKPIT_DOMAIN wss://$COCKPIT_DOMAIN
ProtocolHeader = X-Forwarded-Proto
AllowUnencrypted = true
LoginTitle = Cockpit (Cloudflare SSO)

[X-Cf-Access-Jwt-Assertion]
command = /usr/local/bin/cockpit-auth-cloudflare
timeout = 60
EOF


# echo "=== Docker Installation ==="

# # Alte Versionen entfernen
# for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
#     apt remove -y $pkg 2>/dev/null || true
# done

# # Docker Repository hinzufügen
# apt update
# apt install -y ca-certificates curl gnupg

# install -m 0755 -d /etc/apt/keyrings
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# chmod a+r /etc/apt/keyrings/docker.gpg

# echo \
#   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
#   $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
#   tee /etc/apt/sources.list.d/docker.list > /dev/null

# # Docker installieren
# apt update
# apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# # User zur Docker-Gruppe hinzufügen
# usermod -aG docker homelab

# # Docker beim Boot starten
# systemctl enable docker

# echo ""
# echo "=== Docker Installation abgeschlossen ==="
# docker --version
# docker compose version
# echo ""
# echo "Bitte neu einloggen oder 'newgrp docker' ausführen."
