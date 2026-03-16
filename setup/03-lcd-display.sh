#!/bin/bash
set -e

# ============================================================
# 03-lcd-display.sh - LCD Display Setup (boot.cmd Workaround)
# Für ODROID N2 wo armbianEnv.txt nicht funktioniert
# ============================================================

OVERLAY="${LCD_OVERLAY:-meson-g12b-odroid-n2-spi.dtbo}"
BOOT_CMD="/boot/boot.cmd"
BOOT_SCR="/boot/boot.scr"
OVERLAY_DIR="/boot/dtb/amlogic/overlay"

echo "=== LCD Display Setup (boot.cmd Methode) ==="
echo ""

# Backup erstellen
cp "$BOOT_CMD" "${BOOT_CMD}.bak.$(date +%Y%m%d%H%M%S)"
echo "Backup erstellt: ${BOOT_CMD}.bak.*"

# Prüfen ob Overlay existiert
if [ -f "$OVERLAY_DIR/$OVERLAY" ]; then
    echo "Overlay gefunden: $OVERLAY_DIR/$OVERLAY"
else
    echo "WARNUNG: Overlay $OVERLAY nicht gefunden in $OVERLAY_DIR"
    echo "Verfügbare Overlays:"
    ls -la "$OVERLAY_DIR"/*.dtbo 2>/dev/null || echo "  (keine)"
fi

# Overlay-Laden in boot.cmd einfügen (vor 'booti')
if ! grep -q "LCD Overlay" "$BOOT_CMD"; then
    echo "Füge Overlay-Laden zu boot.cmd hinzu..."

    sed -i '/^booti /i \
# LCD Overlay laden\
if test -e \${devtype} \${devnum}:\${distro_bootpart} /dtb/amlogic/overlay/'"$OVERLAY"'; then\
    echo "Loading LCD overlay..."\
    load \${devtype} \${devnum}:\${distro_bootpart} \${loadaddr} /dtb/amlogic/overlay/'"$OVERLAY"'\
    fdt apply \${loadaddr}\
fi\
' "$BOOT_CMD"

    echo "boot.cmd modifiziert"
else
    echo "LCD Overlay bereits in boot.cmd konfiguriert"
fi

# boot.scr neu generieren
echo "Generiere boot.scr..."
mkimage -C none -A arm64 -T script -d "$BOOT_CMD" "$BOOT_SCR"

# fbtft Module konfigurieren
echo "Konfiguriere Kernel-Module..."
cat > /etc/modules-load.d/lcd.conf << 'EOF'
spi-meson-spicc
spidev
fbtft
fb_ili9341
EOF

# Module-Parameter für ili9341 (3.2" Hardkernel LCD)
cat > /etc/modprobe.d/fbtft.conf << 'EOF'
options fbtft_device name=hktft32 busnum=1 rotate=270 speed=32000000
EOF

echo ""
echo "=== Setup abgeschlossen ==="
echo ""
echo "Nach Neustart prüfen:"
echo "  dmesg | grep -i 'spi\|fbtft\|ili9341\|fb'"
echo "  ls -la /dev/fb*"
echo ""
echo "Neustart erforderlich: sudo reboot"
