#!/bin/bash
# Prüft auf Container-Updates und zeigt Differenzen

set -euo pipefail

COMPOSE_DIR="${HOME}/home-control-server-config"
cd "$COMPOSE_DIR"

echo "=== Container Update Check ==="
echo "Datum: $(date)"
echo ""

updates_found=0

# Alle Services dynamisch aus docker-compose.yml auslesen
while IFS= read -r service; do
    current=$(docker inspect --format='{{.Image}}' "$service" 2>/dev/null | cut -c8-19 || echo "")
    image=$(docker compose config --format json | jq -r ".services.\"${service}\".image // empty")

    if [ -z "$image" ]; then
        echo "WARNUNG: $service hat kein definiertes Image (build-only?)"
        continue
    fi

    # Remote Digest holen
    remote=$(docker manifest inspect "$image" 2>/dev/null | jq -r '.config.digest // .manifests[0].digest' 2>/dev/null | cut -c8-19 || echo "")

    if [ -z "$current" ]; then
        echo "INFO: $service läuft nicht oder existiert nicht"
    elif [ -z "$remote" ]; then
        echo "WARNUNG: Konnte Remote-Digest für $service ($image) nicht abrufen"
    elif [ "$current" != "$remote" ]; then
        echo "UPDATE VERFÜGBAR: $service"
        echo "  Image:   $image"
        echo "  Aktuell: $current"
        echo "  Remote:  $remote"
        echo ""
        ((updates_found++))
    fi
done < <(docker compose config --format json | jq -r '.services | keys[]')

echo "=== Check abgeschlossen ==="
echo "Updates gefunden: $updates_found"
