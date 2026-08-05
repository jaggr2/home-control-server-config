#!/bin/bash
# apply-config.sh — Git pull + systemd daemon-reload + restart changed services
set -e

REPO_DIR="/opt/homelab"
QUADLET_LINK="/home/homelab/.config/containers/systemd"

cd "$REPO_DIR"

echo "$(date): Checking for config updates..."

if [ -n "$(git status --porcelain)" ]; then
    echo "WARNING: Uncommitted changes — aborting."
    git status --short
    exit 1
fi

git fetch origin main
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "Already up-to-date."
    exit 0
fi

echo "New changes found, pulling..."
git pull origin main

echo "Reloading systemd..."
systemctl --user daemon-reload

echo "Restarting updated services..."
for file in "$REPO_DIR"/quadlets/*.container; do
    if [ ! -f "$file" ]; then
        continue
    fi
    name=$(basename "$file" .container)
    systemctl --user restart "${name}.service" 2>/dev/null || echo "  ${name}: not running, skipped"
done

echo ""
echo "=== Configuration applied ==="
podman ps --format "table {{.Names}}\t{{.Status}}"
