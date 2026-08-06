#!/bin/bash
# 09-cockpit.sh — Install Cockpit web console + addons, enable podman user socket
# Run after 04-podman-install.sh (needs rootless linger + user systemd).
set -euo pipefail

USERNAME="${SUDO_USER:-$USER}"

echo "=== Installing cockpit + addons ==="
sudo apt-get install -y -qq \
    cockpit \
    cockpit-podman \
    cockpit-machines \
    cockpit-storaged \
    cockpit-networkmanager \
    cockpit-sosreport \
    cockpit-packagekit

echo ""
echo "=== Enabling cockpit.socket (HTTPS :9090) ==="
sudo systemctl enable --now cockpit.socket
systemctl is-active cockpit.socket

echo ""
echo "=== Opening 9090 in UFW (if present) ==="
if command -v ufw &>/dev/null; then
    sudo ufw allow 9090/tcp
else
    echo "  ufw not installed — firewall handled elsewhere (USG)."
fi

echo ""
echo "=== Enabling podman user socket (for cockpit-podman) ==="
sudo loginctl enable-linger "$USERNAME"
systemctl --user enable --now podman.socket
systemctl --user is-active podman.socket

echo ""
echo "=== Verifying ==="
podman ps --format 'table {{.Names}}\t{{.Status}}'
curl -sI http://localhost:9090/ | head -1

echo ""
echo "=== Cockpit ready ==="
echo "  https://$(hostname -I | awk '{print $1}'):9090  (login as $USERNAME)"
echo "Done."
