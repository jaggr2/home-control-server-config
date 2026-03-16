#!/bin/bash
set -e

# ============================================================
# 02-docker.sh - Docker Installation via Armbian
# ============================================================

echo "=== Docker Installation via armbian-config ==="

# Docker + Docker Compose installieren (full featured)
armbian-config --CON02

# User zur Docker-Gruppe hinzufügen
usermod -aG docker homecontrol

# Docker beim Boot starten
systemctl enable docker

echo ""
echo "=== Docker Installation abgeschlossen ==="
echo "Bitte neu einloggen oder 'newgrp docker' ausführen."
docker --version
docker compose version
