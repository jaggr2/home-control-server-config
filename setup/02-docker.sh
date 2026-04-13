#!/bin/bash
set -e

# ============================================================
# 02-docker.sh - Docker Installation (Ubuntu)
# ============================================================

armbian-config --cmd CON001 # install docker
docker run hello-world

# armbian-config --cmd POR001 # install portainer and start it on boot
armbian-config --cmd CPT001 # install Cockpit OS and VM management tool
# echo "=== Docker Installation ==="

# # Alte Versionen entfernen
# for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
#     apt remove -y $pkg 2>/dev/null || true
# done

# # Docker Repository hinzufügen
# apt update
# apt install -y ca-certificates curl gnupg

# install -m 0755 -d /etc/apt/keyrings
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# chmod a+r /etc/apt/keyrings/docker.gpg

# echo \
#   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
#   $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
#   tee /etc/apt/sources.list.d/docker.list > /dev/null

# # Docker installieren
# apt update
# apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# # User zur Docker-Gruppe hinzufügen
# usermod -aG docker homelab

# # Docker beim Boot starten
# systemctl enable docker

# echo ""
# echo "=== Docker Installation abgeschlossen ==="
# docker --version
# docker compose version
# echo ""
# echo "Bitte neu einloggen oder 'newgrp docker' ausführen."
