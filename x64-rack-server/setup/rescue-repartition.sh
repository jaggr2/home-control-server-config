#!/bin/bash
# rescue-repartition.sh — Run from Debian installer Rescue Mode shell
#
# Context: root LV absorbed the entire VG (0 free). This script:
#   - shrinks root ext4 to 100G (offline — must run with /target unmounted)
#   - creates `containers` LV (200G) for /var/lib/containers
#   - creates `libvirt` LV (rest, ~1.47T) for /var/lib/libvirt
#   - resizes swap_1 to 32G
#   - moves existing /var/lib/containers + /var/lib/libvirt data onto new LVs
#   - updates /etc/fstab
#
# How to run:
#   1. Boot Debian installer ISO/USB → Advanced options → Rescue mode
#   2. Language/keyboard → configure network (or skip) → Detect devices
#   3. It will find the LUKS volume → unlock with disk passphrase
#   4. Root is mounted at /target → choose "Execute a shell in the installer environment"
#   5. bash /target/opt/homelab/x64-rack-server/setup/rescue-repartition.sh
#
# NOTE: /tmp stays as tmpfs (RAM). No /tmp LV created.
set -euo pipefail

VG="derog-server-vg"
ROOT_LV="/dev/mapper/derog--server--vg-root"
SWAP_LV="/dev/mapper/derog--server--vg-swap_1"
CONTAINERS_LV="/dev/mapper/derog--server--vg-containers"
LIBVIRT_LV="/dev/mapper/derog--server--vg-libvirt"

ROOT_SIZE_G=100
CONTAINERS_SIZE_G=200
SWAP_SIZE_G=32

echo "=============================================="
echo " Rescue Repartition Script"
echo " VG:  ${VG}"
echo "=============================================="

# ============================================================
# 0. Pre-checks
# ============================================================
if ! command -v lvs &>/dev/null || ! command -v resize2fs &>/dev/null; then
    echo "ERROR: LVM tools or resize2fs not available."
    echo "  In rescue mode, tools are usually in /sbin. Ensure you chose"
    echo "  'Execute a shell in the installer environment' (full env)."
    exit 1
fi

echo "=== Current LVs ==="
lvs "${VG}"

# ============================================================
# 1. Unmount /target (root fs) so it can be shrunk offline
# ============================================================
echo ""
echo "=== Unmounting /target ==="
umount /target 2>/dev/null || echo "  /target already unmounted"

# ============================================================
# 2. Shrink root to 100G
# ============================================================
echo ""
echo "=== Checking + shrinking root to ${ROOT_SIZE_G}G ==="
e2fsck -f -y "${ROOT_LV}"
resize2fs "${ROOT_LV}" "${ROOT_SIZE_G}G"
lvreduce -y -L "${ROOT_SIZE_G}G" "${ROOT_LV}"
echo "  Root shrunk to ${ROOT_SIZE_G}G"

# ============================================================
# 3. Create containers + libvirt LVs
# ============================================================
echo ""
echo "=== Creating containers LV (${CONTAINERS_SIZE_G}G) ==="
if lvs "${VG}/containers" &>/dev/null; then
    echo "  containers LV already exists, skipping."
else
    lvcreate -y -L "${CONTAINERS_SIZE_G}G" -n containers "${VG}"
fi

echo "=== Creating libvirt LV (rest of VG) ==="
if lvs "${VG}/libvirt" &>/dev/null; then
    echo "  libvirt LV already exists, skipping."
else
    lvcreate -y -l 100%FREE -n libvirt "${VG}"
fi

# ============================================================
# 4. Resize swap to 32G
# ============================================================
echo ""
echo "=== Resizing swap to ${SWAP_SIZE_G}G ==="
swapoff "${SWAP_LV}" 2>/dev/null || true
lvresize -y -L "${SWAP_SIZE_G}G" "${SWAP_LV}"
mkswap "${SWAP_LV}"
echo "  Swap resized + reformatted to ${SWAP_SIZE_G}G"

# ============================================================
# 5. Format new LVs
# ============================================================
echo ""
echo "=== Formatting new LVs ==="
mkfs.ext4 -F "${CONTAINERS_LV}"
mkfs.ext4 -F "${LIBVIRT_LV}"

# ============================================================
# 6. Remount root, move existing data onto new LVs
# ============================================================
echo ""
echo "=== Remounting root at /target ==="
mount "${ROOT_LV}" /target

echo "=== Moving existing container/libvirt data onto new LVs ==="
mkdir -p /mnt/containers /mnt/libvirt
mount "${CONTAINERS_LV}" /mnt/containers
mount "${LIBVIRT_LV}" /mnt/libvirt

if [ -d /target/var/lib/containers ] && [ "$(ls -A /target/var/lib/containers 2>/dev/null)" ]; then
    echo "  Copying /var/lib/containers data..."
    cp -a /target/var/lib/containers/. /mnt/containers/
fi

if [ -d /target/var/lib/libvirt ] && [ "$(ls -A /target/var/lib/libvirt 2>/dev/null)" ]; then
    echo "  Copying /var/lib/libvirt data..."
    cp -a /target/var/lib/libvirt/. /mnt/libvirt/
fi

umount /mnt/containers
umount /mnt/libvirt

# ============================================================
# 7. Update fstab
# ============================================================
echo ""
echo "=== Updating /etc/fstab ==="

add_fstab() {
    local spec="$1" mp="$2" type="$3"
    if grep -Fq "${spec}" /target/etc/fstab; then
        echo "  ${spec} already in fstab."
    else
        echo "${spec} ${mp} ${type} defaults 0 2" >> /target/etc/fstab
        echo "  Added: ${spec} ${mp} ${type} defaults 0 2"
    fi
}

add_fstab "${CONTAINERS_LV}" /var/lib/containers ext4
add_fstab "${LIBVIRT_LV}"    /var/lib/libvirt   ext4

# Ensure swap line points to the LV (it does via /dev/mapper path)
grep -q "${SWAP_LV}" /target/etc/fstab || \
    echo "${SWAP_LV} none swap sw 0 0" >> /target/etc/fstab

echo ""
echo "=== Final fstab ==="
cat /target/etc/fstab

echo ""
echo "=== Final LVs ==="
lvs "${VG}"

echo ""
echo "=============================================="
echo " Repartition complete."
echo " Reboot now: exit → Continue → (reboot)"
echo " On boot, TPM2 will auto-unlock; /var/lib/containers"
echo " and /var/lib/libvirt will be on their own LVs."
echo "=============================================="
