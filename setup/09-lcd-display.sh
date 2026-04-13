#!/bin/bash
set -e

## HINT: For 3.2 lcd display, use ubuntu 20.04 image from hardkernel, not armbian
## Download: https://de.eu.odroid.in/ubuntu_20.04lts/n2/

# ============================================================
# 09-lcd-display.sh - 3.2" LCD Display (Hardkernel Ubuntu)
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

# fbset installieren
apt install fbset -y

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

exit 0

##### Kernel 6.6.0-odroidn2+ mit hktft32 Overlay funktioniert nicht mehr, da die Display-Treiber nicht mehr im Kernel enthalten sind. Es gibt aktuell keine Lösung, außer auf einen älteren Kernel zurückzugehen oder auf ein anderes Display umzusteigen.
##### Solution: Downgrade auf Kernel 6.1.0
# su
# apt-cache search linux-image | grep od                                                                                               roid

# ### falls image nicht gelistet:
# # sudo apt-get install linux-image-6.1.0-odroidn2+ linux-headers-6.1.0-odroidn2+

# nano /etc/apt/sources.list.d/linux
# apt-key adv --keyserver keyserver. ubuntu.com --recv-keys AB19BAC9

# # Linux Factory PPA hinzufügen
# mkdir -p /etc/apt/keyrings
# gpg --homedir /tmp --no-default-keyring --keyring /etc/apt/keyrings/odroid.gpg --keyserver keyserver.ubuntu.com --recv-keys 4F71126C02B8F823
# ls -la /etc/apt/keyrings/odroid.gpg

# # Linux Factory PPA hinzufügen
# cat "deb [arch=arm64 signed-by=/etc/apt/keyrings/odroid.gpg] http://ppa.linuxfactory.or.kr noble main" > /etc/apt/sources.list.d/linuxfactory.list
# apt update

# apt install linux-image-6.1.0-odroid-arm64
# apt install flash-kernel
# flash-kernel --force 6.1.0-odroid-arm64


# ### apt install odroid-grub2 does not work, because it depends on linux-image-6.6.0-odroidn2+ which is not compatible with the hktft32 overlay. Therefore, we have to manually install grub2 and configure it to boot the 6.1.0 kernel.
# ### update uboot configuration



# ls -la /media/boot/amlogic/overlays/odroidn2/

# load mmc ${devno}:1 ${k_addr} /boot/vmlinuz-6.1.0-odroid-arm64
# load mmc ${devno}:1 ${initrd_loadaddr} /boot/initrd.img-6.1.0-odroid-arm64
# load mmc ${devno}:1 ${dtb_loadaddr} /boot/dtbs/6.1.0-odroid-arm64/amlogic/meson64_odroidn2_plus.dtb



# reboot now

# # Nach Neustart, alten Kernel entfernen
# uname -r
# apt remove linux-image-6.6.0-odroidn2+ linux-headers-6.6.0-odroidn2+
# apt autoremove -y
