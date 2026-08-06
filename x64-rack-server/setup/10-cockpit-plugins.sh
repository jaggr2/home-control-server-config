#!/bin/bash
# 10-cockpit-plugins.sh — Third-party Cockpit plugins
# Run after 09-cockpit.sh. Installs (no build step, pure frontend):
#   explorer — file manager (Tools → Explorer)
#   ctop     — btop-style system monitor (Tools → Cockpit Top)
#
# Tried and REMOVED (incompatible with this host):
#   cockpit-cloudflared — needs a locally managed tunnel (cert.pem); this host
#       uses a token-based (remotely managed) tunnel → can't list, hangs.
#   cockpit-zfs (45Drives) — needs python3-libzfs which won't build on Debian
#       trixie (Cython/Python 3.13 incompatibility); CLI-fallback is limited.
#   cockpit-file-sharing (45Drives) — Samba tab manages a NATIVE host samba
#       registry, but samba runs in a container (dperson/samba quadlet).
set -euo pipefail

WORKDIR="/tmp/cockpit-plugins"
mkdir -p "$WORKDIR"

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
cockpit-bridge --packages 2>/dev/null | grep -iE 'ctop|explorer' || true

echo ""
echo "=== Cleanup ==="
rm -rf "$WORKDIR"

echo "Done."
