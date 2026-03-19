#!/bin/bash
set -e

# ============================================================
# 03-lcd-display.sh - 3.2" LCD Display (Hardkernel Ubuntu)
# ============================================================

CONFIG_FILE="/media/boot/config.ini"

echo "=== 3.2 Zoll LCD Display Setup ==="

if [ ! -f "$CONFIG_FILE" ]; then
    echo "FEHLER: $CONFIG_FILE nicht gefunden!"
    exit 1
fi

# Backup
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# overlay_profile auf hktft32 setzen
if grep -q "^overlay_profile=" "$CONFIG_FILE"; then
    sed -i 's/^overlay_profile=.*/overlay_profile=hktft32/' "$CONFIG_FILE"
else
    # Falls Zeile nicht existiert, nach overlay_resize einfügen
    sed -i '/^overlay_resize=/a overlay_profile=hktft32' "$CONFIG_FILE"
fi

echo "=== config.ini aktualisiert ==="
grep -E "overlay_profile|overlay_resize|\[overlay_hktft32\]" "$CONFIG_FILE"
echo ""
echo "Neustart erforderlich: sudo reboot"
echo ""
echo "Nach Neustart prüfen:"
echo "  ls -la /dev/fb*"
echo "  cat /sys/class/graphics/fb1/name"
