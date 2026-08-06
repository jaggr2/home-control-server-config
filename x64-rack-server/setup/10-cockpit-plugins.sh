#!/bin/bash
# 10-cockpit-plugins.sh — Third-party Cockpit plugins
# Run after 09-cockpit.sh. Installs:
#   cockpit-file-sharing (45Drives) — Samba/NFS/iSCSI/S3 mgmt (trixie .deb)
#   cockpit-zfs (45Drives)         — ZFS pool/dataset/snapshot mgmt (build)
#   explorer                       — file manager (no build)
#   ctop                           — btop-style system monitor (no build)
#
# Note: cockpit-cloudflared was tried but removed — it requires a locally
# managed tunnel (cert.pem); this host uses a token-based (remotely managed)
# tunnel, so the plugin can't list tunnels and hangs on loading.
set -euo pipefail

USERNAME="${SUDO_USER:-$USER}"
WORKDIR="/tmp/cockpit-plugins"
mkdir -p "$WORKDIR"

echo "=== Build prerequisites ==="
sudo apt-get install -y -qq nodejs npm moreutils gettext

if ! command -v yarn >/dev/null 2>&1; then
    sudo npm install -g yarn
fi

echo ""
echo "=== cockpit-file-sharing (45Drives trixie .deb) ==="
if [ ! -d /usr/share/cockpit/file-sharing ]; then
    curl -sLo "${WORKDIR}/cockpit-file-sharing.deb" \
        https://github.com/45Drives/cockpit-file-sharing/releases/download/v4.6.1-2/cockpit-file-sharing_4.6.1-2trixie_all.deb
    sudo apt-get install -y -qq "${WORKDIR}/cockpit-file-sharing.deb"
else
    echo "  already installed"
fi

echo ""
echo "=== cockpit-zfs (45Drives, build from source) ==="
# No prebuilt packages; python3-libzfs is optional (CLI fallback used).
if [ ! -d /usr/share/cockpit/zfs ]; then
    git clone -q --recurse-submodules https://github.com/45Drives/cockpit-zfs.git "${WORKDIR}/cockpit-zfs"
    (cd "${WORKDIR}/cockpit-zfs" && make && sudo make install)
else
    echo "  already installed"
fi

echo ""
echo "=== explorer (file manager, no build) ==="
if [ ! -d /usr/share/cockpit/explorer ]; then
    git clone -q --depth 1 https://github.com/ismetozalp/explorer.git "${WORKDIR}/explorer"
    (cd "${WORKDIR}/explorer" && sudo make install)
else
    echo "  already installed"
fi

echo ""
echo "=== ctop (btop-style monitor, no build) ==="
if [ ! -d /usr/share/cockpit/ctop ]; then
    git clone -q --depth 1 https://github.com/ismetozalp/ctop.git "${WORKDIR}/ctop"
    (cd "${WORKDIR}/ctop" && sudo make install)
else
    echo "  already installed"
fi

echo ""
echo "=== Restarting cockpit ==="
sudo systemctl try-restart cockpit.socket

echo ""
echo "=== Installed plugins ==="
cockpit-bridge --packages 2>/dev/null | grep -iE 'ctop|explorer|file-sharing|zfs' || true

echo ""
echo "=== Cleanup ==="
rm -rf "$WORKDIR"

echo "Done."
