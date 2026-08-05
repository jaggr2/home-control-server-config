#!/bin/bash
# 05-vm-create.sh — Create KVM VMs for UniFi OS and Home Assistant OS
# Uses cloud-init definitions from vm-definitions/
set -euo pipefail

VM_DIR="/var/lib/libvirt/images"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEF_DIR="${SCRIPT_DIR}/../vm-definitions"
USERNAME="${SUDO_USER:-$USER}"
SSH_PUBKEY="${SSH_PUBLIC_KEY:-}"

echo "=== Creating VM storage directories ==="
mkdir -p "${VM_DIR}/unifi-os" "${VM_DIR}/ha-os"

if [ -z "$SSH_PUBKEY" ]; then
    if [ -f "/home/${USERNAME}/.ssh/id_ed25519.pub" ]; then
        SSH_PUBKEY=$(cat "/home/${USERNAME}/.ssh/id_ed25519.pub")
    elif [ -f "/home/${USERNAME}/.ssh/id_rsa.pub" ]; then
        SSH_PUBKEY=$(cat "/home/${USERNAME}/.ssh/id_rsa.pub")
    else
        echo "WARNING: No SSH public key found. Cloud-init will use password auth."
    fi
fi

# ============================================================
# VM 1: UniFi OS Server (Ubuntu 24.04 + UniFi OS Server installer)
# ============================================================
echo ""
echo "=== [1/2] UniFi OS Server VM ==="

UNIFI_NAME="unifi-os"
UNIFI_VM_DIR="${VM_DIR}/${UNIFI_NAME}"
CLOUD_INIT="${DEF_DIR}/unifi-os/cloud-init.yaml"

if [ ! -f "$CLOUD_INIT" ]; then
    echo "ERROR: Cloud-init file not found: ${CLOUD_INIT}"
    exit 1
fi

# Check if VM already exists
if virsh dominfo "${UNIFI_NAME}" &>/dev/null; then
    echo "VM ${UNIFI_NAME} already exists. Skipping."
else
    echo "Creating cloud-init seed image..."

    # Prepare a temporary cloud-init config with the SSH key injected
    CLOUD_TMP="/tmp/unifi-cloud-init.yaml"
    cp "$CLOUD_INIT" "$CLOUD_TMP"

    if [ -n "$SSH_PUBKEY" ]; then
        sed -i "s|# ssh_authorized_keys:|ssh_authorized_keys:\n      - ${SSH_PUBKEY}|" "$CLOUD_TMP"
    fi

    # Generate password hash for the homelab user
    echo "Enter password for homelab user (will be hashed):"
    read -rs HOMELAB_PASS
    HASHED_PASS=$(mkpasswd --method=SHA-512 "$HOMELAB_PASS" 2>/dev/null || \
        python3 -c "import crypt; print(crypt.crypt('$HOMELAB_PASS', crypt.mksalt(crypt.METHOD_SHA512)))")
    sed -i "s|\$6\$changeme|${HASHED_PASS}|" "$CLOUD_TMP"

    echo ""
    echo "Creating VM..."
    virt-install \
        --name "${UNIFI_NAME}" \
        --memory 2048 \
        --vcpus 2 \
        --disk "path=${UNIFI_VM_DIR}/os.qcow2,size=32,format=qcow2,bus=virtio" \
        --network bridge:br0.1,model=virtio \
        --graphics none \
        --console pty,target_type=serial \
        --os-variant ubuntu24.04 \
        --location "https://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-live-server-amd64.iso" \
        --cloud-init user-data="$CLOUD_TMP" \
        --noautoconsole

    rm -f "$CLOUD_TMP"
fi

echo ""
echo "UniFi OS VM: ${UNIFI_NAME}"
echo "  Memory: 2 GB | vCPUs: 2 | Disk: 32 GB"
echo "  Network: br0.1 (VLAN 1 — Trusted)"
echo "  SSH:   ssh homelab@<vm-ip>"
echo ""
echo "  To install UniFi OS Server after VM boots:"
echo "    ssh homelab@<vm-ip> /usr/local/bin/install-unifi.sh <installer_url>"
echo "  Get the installer URL from: https://ui.com/download/software/unifi-os-server"
echo "    (Right-click Linux x64 → Copy link address)"
echo ""
echo "  To restore backup after UniFi OS is installed:"
echo "    1. Copy unifi_os_backup_*.unifi to VM: scp backup.unifi homelab@<vm-ip>:/tmp/"
echo "    2. Open https://<vm-ip>:11443"
echo "    3. Select 'Restore from backup' during wizard"
echo "  Backup file: unifi_os_backup_1785762027534_66c79ac6-86de-4445-a3ad-3dc5e09652d7.unifi"
echo ""

# ============================================================
# VM 2: Home Assistant OS
# ============================================================
echo "=== [2/2] Home Assistant OS VM ==="

HA_NAME="ha-os"
HA_VM_DIR="${VM_DIR}/${HA_NAME}"

if virsh dominfo "${HA_NAME}" &>/dev/null; then
    echo "VM ${HA_NAME} already exists. Skipping."
else
    echo "Downloading latest HA OS image..."
    # Get latest release info
    LATEST_URL=$(curl -s https://api.github.com/repos/home-assistant/operating-system/releases/latest | \
        jq -r '.assets[] | select(.name | test("haos_ova.*\\.qcow2\\.xz$")) | .browser_download_url' | head -1)
    SHA_URL="${LATEST_URL}.sha256"

    if [ -z "$LATEST_URL" ]; then
        echo "ERROR: Could not find latest HA OS download URL."
        exit 1
    fi

    FILE_NAME=$(basename "$LATEST_URL")
    echo "  Latest: ${FILE_NAME}"

    if [ ! -f "${HA_VM_DIR}/haos.qcow2" ]; then
        cd /tmp
        curl -fLO --progress-bar "${LATEST_URL}"
        curl -fLO "${SHA_URL}"
        sha256sum -c "${FILE_NAME}.sha256" || echo "WARNING: checksum failed, verify manually"
        xz -d "${FILE_NAME}"
        mv "${FILE_NAME%.xz}" "${HA_VM_DIR}/haos.qcow2"
        rm -f "${FILE_NAME}.sha256"
        echo "  Image saved to ${HA_VM_DIR}/haos.qcow2"
    else
        echo "  Image already exists."
    fi

    echo "Creating VM..."
    virt-install \
        --name "${HA_NAME}" \
        --memory 4096 \
        --vcpus 2 \
        --disk "path=${HA_VM_DIR}/haos.qcow2,format=qcow2,bus=virtio" \
        --network bridge:br0.1,model=virtio \
        --graphics none \
        --console pty,target_type=serial \
        --os-variant linux2022 \
        --import \
        --noautoconsole
fi

echo ""
echo "HA OS VM: ${HA_NAME}"
echo "  Memory: 4 GB | vCPUs: 2 | Disk: 32 GB"
echo "  Network: br0.1 (VLAN 1 — Trusted)"
echo "  Access: http://<vm-ip>:8123"
echo ""
echo "  After first boot, add IoT VLAN access:"
echo "    virsh attach-interface ha-os bridge br0.20 --model virtio --persistent"
echo "    virsh reboot ha-os"
echo "  Then configure static IP on 192.168.20.x subnet in HA UI"
echo ""
echo "  For detailed addon setup and maintenance:"
echo "    See: ${DEF_DIR}/ha-os/README.md"
echo ""

# ============================================================
# Summary
# ============================================================
echo "=== VM Summary ==="
virsh list --all | grep -E "${UNIFI_NAME}|${HA_NAME}" || true
echo ""
echo "=== Done ==="
echo "Both VMs created. Run 'virsh console <name>' to access serial console."
echo "See cloud-init definitions in: ${DEF_DIR}/"
