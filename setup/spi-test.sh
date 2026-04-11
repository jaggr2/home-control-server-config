
# Reset-Pin (GPIO 37 laut deiner dmesg-Ausgabe)
echo 37 | sudo tee /sys/class/gpio/export 2>/dev/null
echo out | sudo tee /sys/class/gpio/gpio37/direction
echo 0 | sudo tee /sys/class/gpio/gpio37/value   # Reset LOW
sleep 0.2
echo 1 | sudo tee /sys/class/gpio/gpio37/value   # Reset HIGH