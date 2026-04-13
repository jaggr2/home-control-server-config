#!/bin/bash
set -e

REPO_DIR="/home/homecontrol/home-control-server-config"
cd "$REPO_DIR"

echo "=== Apply Configuration ==="
echo "Working directory: $(pwd)"
echo "Date: $(date)"
echo ""

# Git-Status prüfen
if [ -n "$(git status --porcelain)" ]; then
    echo "WARNUNG: Uncommitted changes!"
    git status --short
    exit 1
fi

# fetch new changes and check if local is behind remote
git fetch origin main
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    echo "New changes found, pulling..."
    git pull origin main
fi

# apply configuration
echo "Updating containers..."
docker compose pull
docker compose up -d --remove-orphans

# cleanup old images
docker image prune -f

echo ""
echo "=== Apply Configuration completed ==="
echo "docker compose ps:"
docker compose ps
