#!/bin/bash
# 00-zfs.sh — Install ZFS tools, import existing pool, create datasets
set -euo pipefail

POOL="nas"

echo "=== Installing ZFS kernel modules and tools ==="
apt-get update -qq
apt-get install -y -qq zfsutils-linux

echo "=== Loading ZFS kernel module ==="
modprobe zfs || true

echo "=== Scanning for importable pools ==="
zpool import

echo ""
echo "=== Importing pool '${POOL}' ==="
if zpool list -H -o name 2>/dev/null | grep -q "^${POOL}$"; then
    echo "Pool '${POOL}' already imported."
else
    zpool import -d /dev/disk/by-id -d /dev "${POOL}"
fi

echo "=== Pool status ==="
zpool status "${POOL}" | head -20
zpool list "${POOL}"

echo "=== Upgrading pool features ==="
zpool upgrade "${POOL}" || true

echo "=== Ensuring datasets exist ==="
for ds in media backups shared; do
    if zfs list -H -o name "${POOL}/${ds}" &>/dev/null; then
        echo "  Dataset ${POOL}/${ds} already exists."
    else
        echo "  Creating ${POOL}/${ds}..."
        zfs create -o mountpoint=/mnt/nas/${ds} "${POOL}/${ds}"
    fi
done

if ! zfs list -H -o name "${POOL}/backups/rack-server" &>/dev/null; then
    echo "  Creating ${POOL}/backups/rack-server..."
    zfs create -o mountpoint=/mnt/nas/backups/rack-server "${POOL}/backups/rack-server"
fi

echo "=== Datasets ==="
zfs list -r "${POOL}" -o name,mountpoint,used,avail
echo "Done."
