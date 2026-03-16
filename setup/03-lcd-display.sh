#!/bin/bash
set -e

# ============================================================
# 03-lcd-display.sh - 3.2" LCD ili9341 Device Tree Overlay
# Für ODROID N2 mit Hardkernel 3.2" TFT Shield
# ============================================================

echo "=== 3.2 Zoll ili9341 LCD Setup ==="

# Device Tree Compiler installieren
apt install -y device-tree-compiler

# Overlay-Verzeichnis
OVERLAY_DIR="/boot/dtb/amlogic/overlay"
mkdir -p "$OVERLAY_DIR"

# Custom Device Tree Overlay erstellen
# GPIO Pins basierend auf Hardkernel 3.2" Shield Pinout:
# - RST (Reset): Pin 13 = GPIOX.4 (Offset 480)
# - DC (RS):     Pin 15 = GPIOX.7 (Offset 483)
# - CS:          Pin 24 = GPIOX.10 (SPI0_SS0)

cat > /tmp/hktft32.dts << 'EOF'
/dts-v1/;
/plugin/;

/ {
    compatible = "hardkernel,odroid-n2";

    fragment@0 {
        target = <&spicc0>;
        __overlay__ {
            status = "okay";
            #address-cells = <1>;
            #size-cells = <0>;

            hktft32: hktft32@0 {
                compatible = "ilitek,ili9341";
                reg = <0>;
                spi-max-frequency = <32000000>;
                rotate = <270>;
                bgr;
                fps = <30>;
                buswidth = <8>;
                reset-gpios = <&gpio 80 1>;   /* GPIOX.4, active low */
                dc-gpios = <&gpio 83 0>;      /* GPIOX.7, active high */
                debug = <0>;
                status = "okay";
            };
        };
    };
};
EOF

echo "Kompiliere Device Tree Overlay..."
dtc -@ -I dts -O dtb -o "$OVERLAY_DIR/meson-g12b-odroid-n2-hktft32.dtbo" /tmp/hktft32.dts

# Kernel-Module beim Boot laden
cat > /etc/modules-load.d/lcd.conf << 'EOF'
fbtft
fb_ili9341
EOF

# boot.cmd modifizieren um Overlay zu laden
BOOT_CMD="/boot/boot.cmd"
BOOT_SCR="/boot/boot.scr"

if [ -f "$BOOT_CMD" ]; then
    cp "$BOOT_CMD" "${BOOT_CMD}.bak"

    if ! grep -q "hktft32" "$BOOT_CMD"; then
        echo "Füge Overlay zu boot.cmd hinzu..."

        # Vor 'booti' einfügen
        sed -i '/^booti /i \
# LCD Overlay laden\
fdt addr ${fdt_addr_r}\
if test -e ${devtype} ${devnum}:${distro_bootpart} /dtb/amlogic/overlay/meson-g12b-odroid-n2-hktft32.dtbo; then\
    echo "Loading hktft32 LCD overlay..."\
    load ${devtype} ${devnum}:${distro_bootpart} ${loadaddr} /dtb/amlogic/overlay/meson-g12b-odroid-n2-hktft32.dtbo\
    fdt apply ${loadaddr}\
fi\
' "$BOOT_CMD"
    fi

    # boot.scr neu generieren
    mkimage -C none -A arm64 -T script -d "$BOOT_CMD" "$BOOT_SCR"
    echo "boot.scr aktualisiert"
fi

rm /tmp/hktft32.dts

echo ""
echo "=== Setup abgeschlossen ==="
echo ""
echo "Nach Neustart prüfen:"
echo "  ls -la /dev/fb*          # Sollte fb0 UND fb1 zeigen"
echo "  dmesg | grep ili9341"
echo "  cat /sys/class/graphics/fb1/name"
echo ""
echo "Neustart: sudo reboot"
