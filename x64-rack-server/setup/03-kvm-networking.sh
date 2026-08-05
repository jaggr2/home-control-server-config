#!/bin/bash
# 03-kvm-networking.sh — Configure VLAN-aware bridge for KVM VMs
# Host IP goes on br0 (untagged). VMs get tagged VLANs via libvirt.
set -euo pipefail

PHYSICAL_IFACE="${1:-}"
if [ -z "$PHYSICAL_IFACE" ]; then
    PHYSICAL_IFACE=$(ip -o link show | grep -v "lo\|br\|docker\|podman\|veth\|vnet\|virbr" | awk -F': ' '{print $2}' | head -1)
    echo "Auto-detected physical interface: ${PHYSICAL_IFACE}"
fi

echo ""
echo "=== Installing KVM + networking packages ==="
apt-get update -qq
apt-get install -y -qq qemu-kvm libvirt-daemon-system virtinst bridge-utils cloud-image-utils

echo "=== Detecting current IP config ==="
CURRENT_IP=$(ip -4 addr show "${PHYSICAL_IFACE}" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1 || echo "")
CURRENT_GW=$(ip route | grep default | awk '{print $3}' || echo "")

if [ -z "$CURRENT_IP" ]; then
    echo "WARNING: Could not detect current IP on ${PHYSICAL_IFACE}."
    echo "  Please set a static IP in /etc/network/interfaces.d/br0 manually."
    CURRENT_IP="192.168.1.10/24"
    CURRENT_GW="192.168.1.1"
fi

echo "  Current IP: ${CURRENT_IP}, Gateway: ${CURRENT_GW}"

# ============================================================
# Remove any existing physical interface config to avoid IP conflicts
# ============================================================
echo "=== Removing old ${PHYSICAL_IFACE} config ==="
rm -f "/etc/network/interfaces.d/${PHYSICAL_IFACE}"
sed -i "/^allow-hotplug ${PHYSICAL_IFACE}$/d; /^iface ${PHYSICAL_IFACE} inet/d" /etc/network/interfaces 2>/dev/null || true

# Kill any running DHCP client on the physical interface
pkill -f "dhclient.*${PHYSICAL_IFACE}" 2>/dev/null || true

# ============================================================
# Create bridge config — host IP on br0 (untagged)
# ============================================================
echo "=== Creating VLAN-aware bridge br0 ==="
cat > "/etc/network/interfaces.d/br0" << EOF
# VLAN-aware bridge for KVM VMs
# Host IP is on br0 (untagged). VMs get tagged VLANs via libvirt.
auto br0
iface br0 inet static
    address ${CURRENT_IP}
    gateway ${CURRENT_GW}
    dns-nameservers 1.1.1.1 8.8.8.8
    bridge_ports ${PHYSICAL_IFACE}
    bridge_stp off
    bridge_fd 0
    bridge_vlan_aware yes
EOF

echo "  Bridge config written to /etc/network/interfaces.d/br0"

echo "=== Configuring libvirt networks ==="
systemctl enable --now libvirtd

# libvirt bridges each VM to br0 (VLAN-aware) with a native <vlan> tag.
# This is the supported way — VMs connect to br0 and libvirt tags their
# vnet ports with the correct VLAN. (VLAN subinterfaces like br0.1 cannot
# accept bridge ports, so they are NOT used.)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBVIRT_DIR="${SCRIPT_DIR}/libvirt"

for net in trusted mgmt iot ai; do
    if [ -f "${LIBVIRT_DIR}/${net}.xml" ]; then
        cp "${LIBVIRT_DIR}/${net}.xml" "/etc/libvirt/qemu/networks/${net}.xml"
    else
        echo "  WARNING: ${LIBVIRT_DIR}/${net}.xml not found, skipping."
        continue
    fi
    virsh net-define "/etc/libvirt/qemu/networks/${net}.xml" 2>/dev/null || true
    virsh net-autostart "${net}" 2>/dev/null || true
    virsh net-start "${net}" 2>/dev/null || true
done

echo ""
echo "=== KVM networking configured ==="
echo "Bridge: br0 (VLAN-aware, host IP on br0)"
echo "Physical NIC: ${PHYSICAL_IFACE} enslaved to br0"
echo "libvirt networks (VMs attach to br0, tagged): trusted(vlan1), mgmt(vlan11), iot(vlan20), ai(vlan30)"
echo ""
echo "To apply: reboot, or:"
echo "  sudo ifdown ${PHYSICAL_IFACE}; sudo ifup br0"
echo "  (This will disconnect you — reconnect to ${CURRENT_IP})"
