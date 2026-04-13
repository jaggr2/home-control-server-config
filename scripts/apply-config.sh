#!/bin/bash
set -e

cd ~/homelab

echo "=== Konfiguration anwenden ==="
echo "Datum: $(date)"

# Git-Status prüfen
if [ -n "$(git status --porcelain)" ]; then
    echo "WARNUNG: Uncommitted changes vorhanden!"
    git status --short
    read -p "Fortfahren? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Neueste Änderungen holen
git fetch origin main
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    echo "Neue Änderungen gefunden, pulling..."
    git pull origin main
fi

# Docker Compose anwenden
echo "Container aktualisieren..."
docker compose pull
docker compose up -d --remove-orphans

# Alte Images aufräumen
docker image prune -f

echo ""
echo "=== Anwendung abgeschlossen ==="
docker compose ps
