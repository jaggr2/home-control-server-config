#!/bin/bash
# 03-kvm-networking.sh — Configure per-VLAN bridges for KVM VMs + host mgmt
#
# Architecture:
#   enp3s0 (physical trunk, no IP)
#   ├── enp3s0.1   → br1    (VLAN 1  / trusted)   [VMs]
#   ├── enp3s0.11  → br11   (VLAN 11 / mgmt)      [host IP + VMs]
#   ├── enp3s0.20  → br20   (VLAN 20 / iot)       [VMs]
#   └── enp3s0.30  → br30   (VLAN 30 / ai)        [VMs]
#
# Each VLAN subinterface on the physical NIC gets its own plain bridge.
# The host management IP lives on br11. libvirt networks bridge to each brXX.
#
# NOTE: Do NOT use a single VLAN-aware bridge with bridge_vlan_aware yes for
# the host IP — VLAN subinterfaces on a VLAN-aware bridge cannot route the
# host IP (tested: host gets no gateway connectivity). Use per-VLAN bridges.
set -euo pipefail

PHYSICAL_IFACE="${1:-}"
if [ -z "$PHYSICAL_IFACE" ]; then
    PHYSICAL_IFACE=$(ip -o link show | grep -v "lo\|br\|docker\|podman\|veth\|vnet\|virbr\|\.1$" | awk -F': ' '{print $2}' | head -1)
    echo "Auto-detected physical interface: ${PHYSICAL_IFACE}"
fi

HOST_IP="${2:-192.168.11.11/24}"    # mgmt VLAN 11 IP
HOST_GW="${3:-192.168.11.1}"        # mgmt gateway (USG)
DNS1="${4:-1.1.1.1}"
DNS2="${5:-8.8.8.8}"

echo ""
echo "=== Installing KVM + networking packages ==="
apt-get update -qq
apt-get install -y -qq qemu-kvm libvirt-daemon-system virtinst bridge-utils cloud-image-utils vlan

echo "=== Loading 8021q module ==="
modprobe 8021q 2>/dev/null || true
grep -q "8021q" /etc/modules-load.d/modules.conf 2>/dev/null || echo "8021q" >> /etc/modules-load.d/modules.conf

# ============================================================
# Remove old config to avoid conflicts
# ============================================================
echo "=== Removing old ${PHYSICAL_IFACE} config ==="
rm -f "/etc/network/interfaces.d/${PHYSICAL_IFACE}"
sed -i "/^allow-hotplug ${PHYSICAL_IFACE}$/d; /^iface ${PHYSICAL_IFACE} inet/d" /etc/network/interfaces 2>/dev/null || true
pkill -f "dhclient.*${PHYSICAL_IFACE}" 2>/dev/null || true

# ============================================================
# Write per-VLAN bridge config
# ============================================================
echo "=== Writing per-VLAN bridge config ==="
cat > "/etc/network/interfaces.d/br0" << EOF
# Per-VLAN bridges for KVM VMs + host mgmt
# ${PHYSICAL_IFACE} is the physical trunk. Each VLAN gets a subinterface -> bridge.
# Host mgmt IP lives on br11 (VLAN 11 / mgmt).

# VLAN 1 (trusted)
auto ${PHYSICAL_IFACE}.1
iface ${PHYSICAL_IFACE}.1 inet manual

auto br1
iface br1 inet manual
    bridge_ports ${PHYSICAL_IFACE}.1
    bridge_stp off
    bridge_fd 0

# VLAN 11 (mgmt) - host mgmt IP
auto ${PHYSICAL_IFACE}.11
iface ${PHYSICAL_IFACE}.11 inet manual

auto br11
iface br11 inet static
    address ${HOST_IP}
    gateway ${HOST_GW}
    dns-nameservers ${DNS1} ${DNS2}
    bridge_ports ${PHYSICAL_IFACE}.11
    bridge_stp off
    bridge_fd 0

# VLAN 20 (iot)
auto ${PHYSICAL_IFACE}.20
iface ${PHYSICAL_IFACE}.20 inet manual

auto br20
iface br20 inet manual
    bridge_ports ${PHYSICAL_IFACE}.20
    bridge_stp off
    bridge_fd 0

# VLAN 30 (ai)
auto ${PHYSICAL_IFACE}.30
iface ${PHYSICAL_IFACE}.30 inet manual

auto br30
iface br30 inet manual
    bridge_ports ${PHYSICAL_IFACE}.30
    bridge_stp off
    bridge_fd 0
EOF

echo "  Bridge config written to /etc/network/interfaces.d/br0"
echo "  Host mgmt: ${HOST_IP} via ${HOST_GW} on br11"

# ============================================================
# Configure libvirt networks (bridge to per-VLAN bridges)
# ============================================================
echo "=== Configuring libvirt networks ==="
systemctl enable --now libvirtd

echo "=== Granting user libvirt group access (Cockpit VMs) ==="
# polkit 60-libvirt.rules allows any user in the 'libvirt' group to manage
# the system libvirtd without a password — required for cockpit-machines.
USERNAME="${SUDO_USER:-$USER}"
if ! id -nG "${USERNAME}" | tr ' ' '\n' | grep -qx libvirt; then
    usermod -aG libvirt "${USERNAME}"
    echo "  ${USERNAME} added to libvirt group (re-login required)"
else
    echo "  ${USERNAME} already in libvirt group"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBVIRT_DIR="${SCRIPT_DIR}/libvirt"

for net in trusted mgmt iot ai; do
    if [ -f "${LIBVIRT_DIR}/${net}.xml" ]; then
        cp "${LIBVIRT_DIR}/${net}.xml" "/etc/libvirt/qemu/networks/${net}.xml"
    else
        echo "  WARNING: ${LIBVIRT_DIR}/${net}.xml not found, skipping."
        continue
    fi
    virsh net-destroy "${net}" 2>/dev/null || true
    virsh net-undefine "${net}" 2>/dev/null || true
    virsh net-define "/etc/libvirt/qemu/networks/${net}.xml" 2>/dev/null || true
    virsh net-autostart "${net}" 2>/dev/null || true
    virsh net-start "${net}" 2>/dev/null || true
done

echo ""
echo "=== KVM networking configured ==="
echo "Physical NIC: ${PHYSICAL_IFACE} (trunk, no IP)"
echo "VLAN bridges: br1(vlan1), br11(vlan11/mgmt/host), br20(vlan20), br30(vlan30)"
echo "Host mgmt:    ${HOST_IP} via ${HOST_GW}"
echo ""
echo "To apply: reboot, or:"
echo "  sudo systemctl restart networking"
echo "  (This will disconnect you — reconnect to ${HOST_IP%/*})"
