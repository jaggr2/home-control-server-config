#!/bin/bash
# cloudflared-setup.sh — Install Cloudflare Tunnel via apt (ONLY non-container service)
# Exception: cloudflared runs natively via systemd because its sd_notify
# behavior is incompatible with rootless podman quadlets (service dies immediately).
# Everything else on this host runs in containers.
set -euo pipefail

echo "=== Installing cloudflared via apt ==="
if ! command -v cloudflared &>/dev/null; then
    sudo mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

    # Cloudflare does not publish a trixie repo yet — use bookworm (stable-compatible)
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared bookworm main" \
        | sudo tee /etc/apt/sources.list.d/cloudflared.list

    sudo apt-get update -qq
    sudo apt-get install -y -qq cloudflared
fi
cloudflared --version

echo ""
echo "=== Installing cloudflared systemd service ==="
if [ ! -f /etc/cloudflared/token ]; then
    echo "Enter your Cloudflare Tunnel token (from Zero Trust → Networks → Tunnels):"
    read -r TUNNEL_TOKEN
    sudo cloudflared service install "${TUNNEL_TOKEN}"
else
    echo "  Token already present at /etc/cloudflared/token."
    sudo cloudflared service install "$(cat /etc/cloudflared/token)" 2>/dev/null || true
fi

sudo systemctl enable --now cloudflared
sleep 5

echo ""
echo "=== Verifying ==="
sudo systemctl is-active cloudflared
sudo systemctl status cloudflared --no-pager | head -8

echo ""
echo "=== cloudflared setup complete ==="
echo "Logs:  journalctl -u cloudflared -f"
echo "Troubleshoot: cloudflared tunnel info"
echo ""
echo "NOTE: This is intentionally the ONLY non-container service on this host."
