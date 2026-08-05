#!/bin/bash
# 01-kvm-networking.sh — Configure VLAN-aware bridge for KVM VMs
set -euo pipefail

PHYSICAL_IFACE="${1:-}"
if [ -z "$PHYSICAL_IFACE" ]; then
    PHYSICAL_IFACE=$(ip -o link show | grep -v "lo\|br\|docker\|podman\|veth" | awk -F': ' '{print $2}' | head -1)
    echo "Auto-detected physical interface: ${PHYSICAL_IFACE}"
fi

echo ""
echo "=== Installing KVM + networking packages ==="
apt-get update -qq
apt-get install -y -qq qemu-kvm libvirt-daemon-system virtinst bridge-utils cloud-image-utils

echo "=== Creating VLAN-aware bridge br0 ==="

cat > /etc/network/interfaces.d/br0 << EOF
# VLAN-aware bridge for KVM VMs
auto br0
iface br0 inet manual
    bridge_ports ${PHYSICAL_IFACE}
    bridge_stp off
    bridge_fd 0
    bridge_vlan_aware yes
EOF

echo "=== Moving physical interface IP to bridge ==="
CURRENT_IP=$(ip -4 addr show "${PHYSICAL_IFACE}" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1 || echo "")
CURRENT_GW=$(ip route | grep default | awk '{print $3}' || echo "")

if [ -n "$CURRENT_IP" ]; then
    cat >> /etc/network/interfaces.d/br0 << EOF

# Host access via VLAN 1 (Trusted / LAN)
auto br0.1
iface br0.1 inet static
    address ${CURRENT_IP}
    gateway ${CURRENT_GW}
    dns-nameservers 1.1.1.1 8.8.8.8
EOF
fi

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
echo "Bridge: br0 (VLAN-aware trunk on ${PHYSICAL_IFACE})"
echo "VLAN sub-interfaces: br0.1 (trusted), br0.11 (mgmt), br0.20 (iot), br0.30 (ai)"
echo "IMPORTANT: Run 'systemctl restart networking' to apply bridge config."
