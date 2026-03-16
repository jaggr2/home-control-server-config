#!/bin/bash
set -e

# ============================================================
# 00-network.sh - Statische IP-Konfiguration
# Konfiguration via Umgebungsvariablen
# ============================================================
## Beispiel: Variablen setzen und ausführen
## export STATIC_IP="192.168.1.100"
## export STATIC_PREFIX="24"
## export STATIC_GATEWAY="192.168.1.1"
## export STATIC_DNS1="1.1.1.1"
## export STATIC_DNS2="8.8.8.8"
## export STATIC_INTERFACE="eth0"
## 
## sudo -E ./setup/00-network.sh

# Konfiguration (anpassen!)
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

# Connection-Name ermitteln
CON_NAME=$(nmcli -t -f NAME,DEVICE connection show | grep ":${INTERFACE}$" | cut -d: -f1 | head -1)

if [ -z "$CON_NAME" ]; then
    CON_NAME="static-$INTERFACE"
    nmcli connection add type ethernet con-name "$CON_NAME" ifname "$INTERFACE"
fi

# Statische IP konfigurieren
nmcli connection modify "$CON_NAME" \
    ipv4.method manual \
    ipv4.addresses "${IP_ADDRESS}/${PREFIX}" \
    ipv4.gateway "$GATEWAY" \
    ipv4.dns "$DNS1,$DNS2" \
    connection.autoconnect yes

# Connection aktivieren
nmcli connection up "$CON_NAME"

echo ""
echo "=== Konfiguration angewendet ==="
ip -4 addr show $INTERFACE | grep inet
