#!/bin/bash
set -e

echo "=== 3.2 Zoll TFT LCD Display Setup ==="

# 1. config.ini bearbeiten für Device Tree Overlay
CONFIG_FILE="/media/boot/config.ini"

if [ -f "$CONFIG_FILE" ]; then
    # Backup erstellen
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

    # overlay_profile auf hktft32 setzen
    sed -i 's/overlay_profile=.*/overlay_profile=hktft32/' "$CONFIG_FILE"

    echo "config.ini aktualisiert - overlay_profile=hktft32"
else
    echo "WARNUNG: $CONFIG_FILE nicht gefunden!"
fi

# 2. fbset installieren
apt install -y fbset

# 3. Touchscreen-Modul aus Blacklist entfernen
BLACKLIST_FILE="/etc/modprobe.d/blacklist-odroid.conf"
if [ -f "$BLACKLIST_FILE" ]; then
    sed -i 's/^blacklist ads7846/#blacklist ads7846/' "$BLACKLIST_FILE"
    echo "ads7846 aus Blacklist entfernt"
fi

# 4. X11-Konfiguration für Framebuffer erstellen
mkdir -p /usr/share/X11/xorg.conf.d

cat > /usr/share/X11/xorg.conf.d/99-odroid-lcd.conf << 'XORGEOF'
Section "Device"
    Identifier      "FBTURBO"
    Driver          "fbturbo"
    Option          "fbdev" "/dev/fb0"
    Option          "SwapbuffersWait" "true"
    Option          "alpha_swap" "true"
EndSection
XORGEOF

# 5. Touchscreen-Kalibrierung vorbereiten
apt install -y xserver-xorg-input-evdev xinput-calibrator

cat > /usr/share/X11/xorg.conf.d/99-calibration.conf << 'CALIBEOF'
Section "InputClass"
    Identifier      "calibration"
    MatchProduct    "ADS7846 Touchscreen"
    Driver "evdev"
EndSection
CALIBEOF

echo ""
echo "=== LCD Setup abgeschlossen ==="
echo "Bitte System neu starten: sudo reboot"
echo ""
echo "Nach dem Neustart:"
echo "1. Framebuffer finden: grep -Hri 'hktft' /sys/class/graphics/fb*/name"
echo "2. Konsole mappen: sudo con2fbmap 1 0"
echo "3. Zur Konsole wechseln: sudo chvt 1"
echo ""
echo "Für Touchscreen-Kalibrierung: xinput_calibrator"
