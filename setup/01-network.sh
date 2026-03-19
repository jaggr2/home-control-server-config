#!/bin/bash
set -e

# ============================================================
# 00-network.sh - Statische IP-Konfiguration (Netplan)
# ============================================================

INTERFACE="${STATIC_INTERFACE:-eth0}"
IP_ADDRESS="${STATIC_IP:-192.168.1.11}"
PREFIX="${STATIC_PREFIX:-24}"
GATEWAY="${STATIC_GATEWAY:-192.168.1.1}"
DNS1="${STATIC_DNS1:-1.1.1.1}"
DNS2="${STATIC_DNS2:-8.8.8.8}"

echo "=== Statische IP-Konfiguration ==="
echo "Interface:  $INTERFACE"
echo "IP:         $IP_ADDRESS/$PREFIX"
echo "Gateway:    $GATEWAY"
echo "DNS:        $DNS1, $DNS2"
echo ""

# Backup
mkdir -p /etc/netplan/backup
cp /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null || true

# Neue Konfiguration
cat > /etc/netplan/10-static.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      addresses:
        - ${IP_ADDRESS}/${PREFIX}
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses:
          - $DNS1
          - $DNS2
EOF

chmod 600 /etc/netplan/10-static.yaml

# Alte DHCP-Konfig deaktivieren
for f in /etc/netplan/*.yaml; do
    if [ "$f" != "/etc/netplan/10-static.yaml" ]; then
        mv "$f" "${f}.disabled" 2>/dev/null || true
    fi
done

netplan apply

echo "=== Konfiguration angewendet ==="
sleep 2
ip -4 addr show $INTERFACE | grep inet
