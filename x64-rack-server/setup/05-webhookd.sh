#!/bin/bash
# 05-webhookd.sh — Install webhookd for GitHub Actions CI/CD trigger
# Sets up auth (random password), correct script path, and systemd override.
set -euo pipefail

USERNAME="${SUDO_USER:-$USER}"
REPO_DIR="/opt/homelab"
SCRIPTS_DIR="${REPO_DIR}/x64-rack-server/scripts"

echo "=== Installing webhookd ==="
if ! command -v webhookd &>/dev/null; then
    wget -O /usr/share/keyrings/azlux-archive-keyring.gpg https://azlux.fr/repo.gpg

    cat << 'EOF' | sudo tee /etc/apt/sources.list.d/azlux.sources
Types: deb
URIs: http://packages.azlux.fr/debian/
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/azlux-archive-keyring.gpg
EOF

    sudo apt-get update -qq
    sudo apt-get install -y -qq webhookd apache2-utils
fi

echo "=== Configuring webhookd ==="
sudo bash -c "cat > /etc/webhookd.env << 'ENVEOF'
WHD_HOOK_SCRIPTS=\"${SCRIPTS_DIR}\"
WHD_LISTEN_ADDR=:8080
WHD_PASSWD_FILE=\"/etc/webhookd.htpasswd\"
WHD_HOOK_TIMEOUT=180
ENVEOF"

echo "=== Setting up htpasswd ==="
if [ ! -s /etc/webhookd.htpasswd ]; then
    WEBHOOK_PASS=$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-24)
    echo "  Generated webhook password: ${WEBHOOK_PASS}"
    echo "  Store this in GitHub secrets: WEBHOOK_USER=github-deploy, WEBHOOK_PASSWORD=${WEBHOOK_PASS}"
    echo "${WEBHOOK_PASS}" | sudo htpasswd -ciB /etc/webhookd.htpasswd github-deploy
else
    echo "  htpasswd file already exists, keeping existing credentials."
fi

echo "=== Making scripts executable ==="
chmod +x "${SCRIPTS_DIR}"/*.sh 2>/dev/null || true
chmod 755 "${SCRIPTS_DIR}"

echo "=== Creating webhookd service override ==="
sudo mkdir -p /etc/systemd/system/webhookd.service.d
sudo bash -c "cat > /etc/systemd/system/webhookd.service.d/override.conf << 'OVERRIDE'
[Service]
User=${USERNAME}
Group=${USERNAME}
OVERRIDE"

sudo systemctl daemon-reload
sudo systemctl enable --now webhookd
sleep 2

echo "=== Verifying ==="
if sudo ss -tlnp 2>/dev/null | grep -q :8080; then
    echo "  webhookd listening on :8080"
else
    echo "  WARNING: webhookd not listening. Check: sudo journalctl -u webhookd"
fi

echo ""
echo "=== webhookd setup complete ==="
echo "Test locally:"
echo "  curl -u github-deploy:<password> http://localhost:8080/health.sh"
echo ""
echo "For GitHub Actions, the following secrets are needed:"
echo "  WEBHOOK_USER=github-deploy"
echo "  WEBHOOK_PASSWORD=<generated or existing>"
echo "  CF_ACCESS_CLIENT_ID / CF_ACCESS_CLIENT_SECRET (if behind Cloudflare Access)"
