#!/bin/bash
set -e
hostnamectl set-hostname derog-hc

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

# Interactive: armbian-config
armbian-config network static set \
    --interface "${INTERFACE}" \
    --ip "${IP_ADDRESS}" \
    --prefix "${PREFIX}" \
    --gateway "${GATEWAY}" \
    --dns1 "${DNS1}" \
    --dns2 "${DNS2}"

reboot now