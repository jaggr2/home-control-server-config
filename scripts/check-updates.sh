#!/bin/bash
# Prüft auf Container-Updates und zeigt Differenzen

cd ~/homelab

echo "=== Container Update Check ==="
echo "Datum: $(date)"
echo ""

# Aktuelle Images prüfen
for service in cloudflared homeassistant freepbx nodered freepbx-db; do
    current=$(docker inspect --format='{{.Image}}' $service 2>/dev/null | cut -c8-19)
    image=$(docker compose config --format json | jq -r ".services.${service}.image // empty")

    if [ -n "$image" ]; then
        # Remote Digest holen
        remote=$(docker manifest inspect $image 2>/dev/null | jq -r '.config.digest // .manifests[0].digest' | cut -c8-19)

        if [ "$current" != "$remote" ] && [ -n "$remote" ]; then
            echo "UPDATE VERFÜGBAR: $service"
            echo "  Aktuell: $current"
            echo "  Remote:  $remote"
            echo ""
        fi
    fi
done

echo "=== Check abgeschlossen ==="
