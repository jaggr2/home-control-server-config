#!/bin/bash
# 02-zfs.sh — Install ZFS tools, import existing pool, create datasets
# Handles: contrib/non-free repos, kernel headers, DKMS build, force import,
#          stuck resilver detection, dataset creation.
set -euo pipefail

POOL="nas"

# ============================================================
# 1. Ensure contrib/non-free repos (needed for zfsutils-linux)
# ============================================================
echo "=== Ensuring contrib/non-free apt sources ==="
if [ -f /etc/apt/sources.list ] && ! grep -q "non-free" /etc/apt/sources.list 2>/dev/null; then
    sudo sed -i 's/ main/ main contrib non-free non-free-firmware/g' /etc/apt/sources.list
fi
# deb822 format (.sources files)
for f in /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] || continue
    sudo sed -i 's/Components: main/Components: main contrib non-free non-free-firmware/g' "$f" || true
done

# ============================================================
# 2. Install ZFS (needs kernel headers for DKMS build)
# ============================================================
echo "=== Installing kernel headers ==="
sudo apt-get update -qq
sudo apt-get install -y -qq "linux-headers-$(uname -r)"

echo "=== Installing ZFS ==="
sudo apt-get install -y -qq zfsutils-linux

echo "=== Building ZFS kernel module (DKMS) ==="
sudo dkms autoinstall || sudo dkms install zfs/$(dpkg-query -W -f='${Version}' zfs-dkms | cut -d- -f1) -k "$(uname -r)" 2>/dev/null || true

echo "=== Loading ZFS module ==="
sudo modprobe zfs || true
sleep 2

# ============================================================
# 3. Import pool
# ============================================================
echo "=== Scanning for importable pools ==="
sudo zpool import 2>/dev/null || true

if zpool list -H -o name 2>/dev/null | grep -q "^${POOL}$"; then
    echo "Pool '${POOL}' already imported."
else
    echo "Importing pool '${POOL}'..."
    # -f needed if pool was last used on another host (old Proxmox)
    sudo zpool import -f -d /dev/disk/by-id "${POOL}" 2>/dev/null \
        || sudo zpool import -f "${POOL}"
fi

echo "=== Pool status ==="
zpool status "${POOL}" | head -20
zpool list "${POOL}"

# ============================================================
# 4. Handle stuck resilver (from unclean disconnect on old host)
# ============================================================
echo "=== Checking resilver state ==="
if zpool status "${POOL}" | grep -q "resilver in progress"; then
    echo "  NOTE: A resilver is in progress (likely from the previous host)."
    echo "  If '0B resilvered / 0% done' persists, the scan may be stuck."
    echo "  Options:"
    echo "    - Wait:   zpool status ${POOL}   (watch 'scan:' line)"
    echo "    - Restart: sudo zpool clear ${POOL}"
    echo "    - Offline/online the affected disk to retrigger:"
    echo "        sudo zpool offline ${POOL} <device>"
    echo "        sudo zpool online ${POOL} <device>"
    echo "  The pool stays usable (possibly degraded) while this runs."
fi

# ============================================================
# 5. Create datasets
# ============================================================
echo "=== Ensuring datasets exist ==="
for ds in media backups shared data; do
    if zfs list -H -o name "${POOL}/${ds}" &>/dev/null; then
        echo "  Dataset ${POOL}/${ds} already exists."
    else
        echo "  Creating ${POOL}/${ds}..."
        sudo zfs create -o mountpoint=/mnt/${POOL}/${ds} "${POOL}/${ds}" 2>/dev/null \
            || sudo zfs create -o mountpoint=/mnt/${ds} "${POOL}/${ds}"
    fi
done

if ! zfs list -H -o name "${POOL}/backups/rack-server" &>/dev/null; then
    echo "  Creating ${POOL}/backups/rack-server..."
    sudo zfs create -o mountpoint=/mnt/nas/backups/rack-server "${POOL}/backups/rack-server"
fi

echo ""
echo "=== Datasets ==="
zfs list -r "${POOL}" -o name,mountpoint,used,avail
echo "Done."
