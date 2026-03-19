#!/bin/bash
set -e

# ============================================================
# 03-lcd-display.sh - 3.2" LCD Display (Hardkernel Ubuntu)
# ============================================================

CONFIG_FILE="/media/boot/config.ini"
OVERLAY_DIR="/media/boot/amlogic/overlays/odroidn2"

echo "=== 3.2 Zoll LCD Display Setup ==="

# Prüfe ob config.ini existiert
if [ ! -f "$CONFIG_FILE" ]; then
    echo "FEHLER: $CONFIG_FILE nicht gefunden!"
    exit 1
fi

# Prüfe ob Overlay-Dateien existieren
echo "Prüfe Overlay-Dateien..."
if [ ! -f "$OVERLAY_DIR/hktft32.dtbo" ]; then
    echo "FEHLER: $OVERLAY_DIR/hktft32.dtbo nicht gefunden!"
    echo "Verfügbare Overlays:"
    ls -la "$OVERLAY_DIR"/ 2>/dev/null || ls -la /media/boot/amlogic/overlays/
    exit 1
fi

if [ ! -f "$OVERLAY_DIR/ads7846.dtbo" ]; then
    echo "WARNUNG: $OVERLAY_DIR/ads7846.dtbo nicht gefunden (Touchscreen)"
fi

echo "Overlay-Dateien gefunden: OK"

# Backup erstellen
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
echo "Backup erstellt"

# overlay_profile setzen
if grep -q "^overlay_profile=" "$CONFIG_FILE"; then
    sed -i 's/^overlay_profile=.*/overlay_profile=hktft32/' "$CONFIG_FILE"
    echo "overlay_profile aktualisiert"
else
    # Nach overlay_resize einfügen
    sed -i '/^overlay_resize=/a overlay_profile=hktft32' "$CONFIG_FILE"
    echo "overlay_profile hinzugefügt"
fi

# Prüfe ob [overlay_hktft32] Sektion existiert
if ! grep -q "^\[overlay_hktft32\]" "$CONFIG_FILE"; then
    echo "WARNUNG: [overlay_hktft32] Sektion fehlt - füge hinzu..."
    cat >> "$CONFIG_FILE" << 'EOF'

[overlay_hktft32]
overlays="hktft32 ads7846"
EOF
    echo "[overlay_hktft32] Sektion hinzugefügt"
fi

echo ""
echo "=== Aktuelle config.ini (relevante Teile) ==="
grep -E "overlay_resize|overlay_profile|^\[overlay_|^overlays=" "$CONFIG_FILE"
echo ""
echo "=== Overlay-Dateien ==="
ls -la "$OVERLAY_DIR"/*.dtbo 2>/dev/null | head -10
echo ""
echo "Neustart erforderlich: sudo reboot"
echo ""
echo "Nach Neustart prüfen:"
echo "  dmesg | grep -i 'hktft\|ili9341\|fb'"
echo "  ls -la /dev/fb*"
echo "  cat /sys/class/graphics/fb1/name"
