#!/bin/bash
set -e

cd ~/homelab

echo "=== Rollback Tool ==="
echo ""

# Letzte Commits anzeigen
echo "Verfügbare Versionen (letzte 10 Commits):"
git log --oneline -10
echo ""

read -p "Commit-Hash für Rollback eingeben: " COMMIT_HASH

if [ -z "$COMMIT_HASH" ]; then
    echo "Kein Commit angegeben, Abbruch."
    exit 1
fi

# Bestätigung
echo ""
echo "Rollback zu: $(git log --oneline -1 $COMMIT_HASH)"
read -p "Fortfahren? (y/n) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Rollback durchführen
git checkout $COMMIT_HASH -- docker-compose.yml services/

# Container neu starten
docker compose pull
docker compose up -d --remove-orphans

echo ""
echo "=== Rollback abgeschlossen ==="
echo "HINWEIS: Änderungen sind lokal. Für permanenten Rollback:"
echo "  git add -A && git commit -m 'Rollback to $COMMIT_HASH'"
echo "  git push origin main"
