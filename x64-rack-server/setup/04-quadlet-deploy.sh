#!/bin/bash
# 04-quadlet-deploy.sh — Symlink quadlets + deploy all containers
set -euo pipefail

REPO_DIR="/opt/homelab"
QUADLET_DIR="${REPO_DIR}/quadlets"
USERNAME="${SUDO_USER:-$USER}"
SYSTEMD_DIR="/home/${USERNAME}/.config/containers/systemd"

echo "=== Creating config directories ==="
for svc in sabnzbd sonarr radarr prowlarr plex cloudflared; do
    mkdir -p "/home/${USERNAME}/config/${svc}"
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/config/${svc}"
done

echo "=== Symlinking Quadlet files ==="
for file in "${QUADLET_DIR}"/*; do
    basename=$(basename "$file")
    if [ -L "${SYSTEMD_DIR}/${basename}" ]; then
        rm "${SYSTEMD_DIR}/${basename}"
    fi
    ln -sf "${QUADLET_DIR}/${basename}" "${SYSTEMD_DIR}/${basename}"
    echo "  ${basename} -> ${QUADLET_DIR}/${basename}"
done

echo "=== Reloading systemd ==="
su - "${USERNAME}" -c "systemctl --user daemon-reload"

echo "=== Starting all services ==="
su - "${USERNAME}" -c "systemctl --user start arr.network" || true

SERVICES=(sabnzbd sonarr radarr prowlarr plex cloudflared samba)
for svc in "${SERVICES[@]}"; do
    echo "Starting ${svc}..."
    su - "${USERNAME}" -c "systemctl --user start ${svc}.service" || echo "  Warning: ${svc} may need configuration"
done

echo ""
echo "=== Enabling persistent services ==="
for svc in "${SERVICES[@]}"; do
    su - "${USERNAME}" -c "systemctl --user enable ${svc}.service" 2>/dev/null || true
done

echo ""
echo "=== Service status ==="
su - "${USERNAME}" -c "podman ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

echo "Done."
