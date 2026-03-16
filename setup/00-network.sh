#!/bin/bash
set -e

# Interactive: armbian-config

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

armbian-config network static set \
    --interface "${STATIC_INTERFACE}" \
    --ip "${STATIC_IP}" \
    --prefix "${STATIC_PREFIX}" \
    --gateway "${STATIC_GATEWAY}" \
    --dns1 "${STATIC_DNS1}" \
    --dns2 "${STATIC_DNS2}"