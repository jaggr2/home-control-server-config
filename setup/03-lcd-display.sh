#!/bin/bash
set -e

# ============================================================
# 03-lcd-display.sh - Hardkernel 3.2" LCD ili9341 für ODROID N2
# ============================================================

echo "=== 3.2 Zoll ili9341 LCD Setup ==="

apt install -y device-tree-compiler

OVERLAY_DIR="/boot/dtb/amlogic/overlay"
mkdir -p "$OVERLAY_DIR"

# Device Tree Overlay erstellen
# GPIO Pins basierend auf ODROID N2 Pinout:
# - Pin 13 = GPIOX.4 (#480) → Reset (active low)
# - Pin 15 = GPIOX.7 (#483) → DC/RS
# - Pin 19 = GPIOX.8 → SPI0_MOSI
# - Pin 21 = GPIOX.9 → SPI0_MISO  
# - Pin 23 = GPIOX.11 → SPI0_CLK
# - Pin 24 = GPIOX.10 → SPI0_SS0 (CS)

cat > /tmp/hktft32.dts << 'EOF'
/dts-v1/;
/plugin/;

#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/gpio/meson-g12a-gpio.h>

/ {
    compatible = "hardkernel,odroid-n2", "amlogic,g12b";

    fragment@0 {
        target = <&spicc0>;
        __overlay__ {
            status = "okay";
            pinctrl-names = "default";
            pinctrl-0 = <&spicc0_pins>;
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
                reset-gpios = <&gpio GPIOX_4 GPIO_ACTIVE_LOW>;
                dc-gpios = <&gpio GPIOX_7 GPIO_ACTIVE_HIGH>;
                debug = <0>;
                status = "okay";
            };
        };
    };
};
EOF

echo "Kompiliere Device Tree Overlay..."

# Mit Preprocessor kompilieren (für #include)
cpp -nostdinc -I /usr/src/linux-headers-$(uname -r)/include \
    -undef -x assembler-with-cpp /tmp/hktft32.dts | \
    dtc -@ -I dts -O dtb -o "$OVERLAY_DIR/meson-g12b-odroid-n2-hktft32.dtbo" - 2>/dev/null || {

    # Fallback: Ohne Preprocessor mit hardcoded Werten
    echo "Fallback: Verwende hardcoded GPIO-Werte..."

    cat > /tmp/hktft32.dts << 'EOF'
/dts-v1/;
/plugin/;

/ {
    compatible = "hardkernel,odroid-n2", "amlogic,g12b";

    fragment@0 {
        target-path = "/soc/bus@ffd00000/spi@13000";
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
                reset-gpios = <&gpio 4 1>;   /* GPIOX_4, active low */
                dc-gpios = <&gpio 7 0>;      /* GPIOX_7, active high */
                debug = <0>;
                status = "okay";
            };
        };
    };
};
EOF

    dtc -@ -I dts -O dtb -o "$OVERLAY_DIR/meson-g12b-odroid-n2-hktft32.dtbo" /tmp/hktft32.dts
}

# armbianEnv.txt aktualisieren
ENV_FILE="/boot/armbianEnv.txt"
if [ -f "$ENV_FILE" ]; then
    # Altes SPI-Overlay entfernen, neues hinzufügen
    sed -i 's/g12b-odroid-n2-spi/g12b-odroid-n2-hktft32/g' "$ENV_FILE"

    if ! grep -q "g12b-odroid-n2-hktft32" "$ENV_FILE"; then
        if grep -q "^overlays=" "$ENV_FILE"; then
            sed -i "s/^overlays=.*/& g12b-odroid-n2-hktft32/" "$ENV_FILE"
        else
            echo "overlays=g12b-odroid-n2-hktft32" >> "$ENV_FILE"
        fi
    fi
fi

# Module laden
cat > /etc/modules-load.d/lcd.conf << 'EOF'
spi_meson_spicc
fbtft
fb_ili9341
EOF

rm /tmp/hktft32.dts

echo ""
echo "=== Setup abgeschlossen ==="
cat "$ENV_FILE"
echo ""
echo "Neustart: sudo reboot"
