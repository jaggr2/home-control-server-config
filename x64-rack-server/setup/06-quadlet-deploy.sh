#!/bin/bash
# 06-quadlet-deploy.sh — Symlink quadlets + deploy all containers
set -euo pipefail

REPO_DIR="/opt/homelab"
QUADLET_DIR="${REPO_DIR}/x64-rack-server/quadlets"
USERNAME="${SUDO_USER:-$USER}"
SYSTEMD_DIR="/home/${USERNAME}/.config/containers/systemd"
CONFIG_DIR="/home/${USERNAME}/config"

echo "=== Creating config directories ==="
for svc in sabnzbd sonarr radarr prowlarr plex; do
    mkdir -p "${CONFIG_DIR}/${svc}"
    chown -R "${USERNAME}:${USERNAME}" "${CONFIG_DIR}/${svc}"
done

echo "=== Creating quadlets.env ==="
if [ ! -f "${CONFIG_DIR}/quadlets.env" ]; then
    cp "${REPO_DIR}/x64-rack-server/.env.example" "${CONFIG_DIR}/quadlets.env"
    chown "${USERNAME}:${USERNAME}" "${CONFIG_DIR}/quadlets.env"
    chmod 600 "${CONFIG_DIR}/quadlets.env"
    echo "  Created ${CONFIG_DIR}/quadlets.env from example."
    echo "  >>> EDIT THIS FILE with real values before starting containers!"
    echo "  >>> nano ${CONFIG_DIR}/quadlets.env"
fi

echo "=== Provisioning Samba POSIX identity ==="
# Rootless podman userns: container uid 100 (smbuser) -> host 100099, gid 101 (smb) -> host 100100.
# dperson/samba force-users smbuser for all SMB writes, so the shares must be
# writable by that mapped host identity (homelab user/group).
if ! getent group homelab >/dev/null; then
    groupadd -g 100100 homelab
    echo "  group homelab (100100) created"
fi
if ! getent passwd homelab >/dev/null; then
    useradd -u 100099 -g 100100 -s /usr/sbin/nologin -M homelab
    echo "  user homelab (100099) created"
fi
usermod -aG 100100 "${USERNAME}"
chown -R 100099:100100 /mnt/nas/shared
chmod -R 2775 /mnt/nas/shared
echo "  /mnt/nas/shared -> homelab:homelab (2775, setgid)"

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

SERVICES=(sabnzbd sonarr radarr prowlarr plex samba)
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
