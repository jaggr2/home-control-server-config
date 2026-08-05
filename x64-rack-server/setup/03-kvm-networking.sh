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

# ============================================================
# Create VLAN subinterfaces for libvirt VMs
# ============================================================
echo "=== Creating VLAN subinterfaces for libvirt ==="
cat >> "/etc/network/interfaces.d/br0" << 'VLANEOF'

# VLAN subinterfaces for libvirt VMs (no IP on these)
auto br0.1
iface br0.1 inet manual

auto br0.11
iface br0.11 inet manual

auto br0.20
iface br0.20 inet manual

auto br0.30
iface br0.30 inet manual
VLANEOF

echo "=== Configuring libvirt networks ==="
systemctl enable --now libvirtd

cat > /etc/libvirt/qemu/networks/trusted.xml << 'EOF'
<network>
  <name>trusted</name>
  <forward mode="bridge"/>
  <bridge name="br0.1"/>
</network>
EOF

cat > /etc/libvirt/qemu/networks/mgmt.xml << 'EOF'
<network>
  <name>mgmt</name>
  <forward mode="bridge"/>
  <bridge name="br0.11"/>
</network>
EOF

cat > /etc/libvirt/qemu/networks/iot.xml << 'EOF'
<network>
  <name>iot</name>
  <forward mode="bridge"/>
  <bridge name="br0.20"/>
</network>
EOF

cat > /etc/libvirt/qemu/networks/ai.xml << 'EOF'
<network>
  <name>ai</name>
  <forward mode="bridge"/>
  <bridge name="br0.30"/>
</network>
EOF

for net in trusted mgmt iot ai; do
    virsh net-define "/etc/libvirt/qemu/networks/${net}.xml" 2>/dev/null || true
    virsh net-autostart "${net}" 2>/dev/null || true
    virsh net-start "${net}" 2>/dev/null || true
done

echo ""
echo "=== KVM networking configured ==="
echo "Bridge: br0 (VLAN-aware, host IP on br0)"
echo "Physical NIC: ${PHYSICAL_IFACE} enslaved to br0"
echo "VLAN sub-interfaces: br0.1 (vlan 1), br0.11 (vlan 11), br0.20 (vlan 20), br0.30 (vlan 30)"
echo ""
echo "To apply: reboot, or:"
echo "  sudo ifdown ${PHYSICAL_IFACE}; sudo ifup br0"
echo "  (This will disconnect you — reconnect to ${CURRENT_IP})"
