#!/bin/bash
# 02-podman-install.sh — Install podman, enable rootless lingering
set -euo pipefail

echo "=== Installing podman ==="
if command -v podman &>/dev/null; then
    echo "Podman already installed: $(podman --version)"
else
    apt-get update -qq
    apt-get install -y -qq podman
fi

echo ""
echo "=== Enabling lingering for user ==="
USERNAME="${SUDO_USER:-$USER}"
if [ "$USERNAME" = "root" ]; then
    echo "Please run this as a non-root user with sudo."
    exit 1
fi

loginctl enable-linger "$USERNAME"
echo "Lingering enabled for user: ${USERNAME}"

echo ""
echo "=== Creating Quadlet directories ==="
mkdir -p "/home/${USERNAME}/.config/containers/systemd"
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config"

echo ""
echo "=== Verifying podman ==="
podman --version
podman info --format "{{.Host.RemoteSocket.Path}}"

echo "=== Enabling podman-auto-update.timer ==="
if id -u "$USERNAME" &>/dev/null; then
    su - "$USERNAME" -c "systemctl --user enable podman-auto-update.timer"
fi

echo ""
echo "=== Allowing rootless containers to bind low ports (Samba 139/445) ==="
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-unprivileged-ports.conf >/dev/null
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80 >/dev/null
echo "  net.ipv4.ip_unprivileged_port_start=80 applied (persists via /etc/sysctl.d/)"

echo "Done."
