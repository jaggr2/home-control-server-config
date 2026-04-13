## HINT: For 3.2 lcd display compatibility, use ubuntu 18.04 image from hardkernel, not armbian
## Download: https://de.eu.odroid.in/ubuntu_18.04lts/n2/

##################################################################
################ armbian manual steps from here on: ##############
##################################################################
# put eMMC into ODROID-N2 and boot

# 1) answers for armbian initial setup:
# - root password: (set it and add to password manager)
# - create user: homecontrol
# - password for homecontrol: (set it and add to password manager)
# - locale: en_US.UTF-8 (Option 98)
# - timezone: Europe/Zurich
#
# 2) setup hostname and network
armbian-config --cmd BNS001 # set static IP (192.168.1.11/24)
armbian-config --cmd BNS002 # drop dhcp
armbian-config --cmd HOS001 # set hostname to derog-hc

armbian-config --cmd ACC001 # disable root login via ssh

# 3) update system
apt update 
apt upgrade -y
armbian-config --cmd GIT001 # install git
exit 0

##################################################################
################ ubuntu 18.04 manual steps from here on: #########
##################################################################
# create user and add to sudo group
adduser homecontrol
usermod -aG sudo homecontrol

# set hostname
hostnamectl set-hostname derog-hc

# set timezone
timedatectl set-timezone Europe/Zurich

# change root password
passwd

# update system
apt update 
apt upgrade -y
apt-get install git -y

# setup network (static IP)
INTERFACE="${STATIC_INTERFACE:-eth0}"
IP_ADDRESS="${STATIC_IP:-192.168.1.11}"
PREFIX="${STATIC_PREFIX:-24}"
GATEWAY="${STATIC_GATEWAY:-192.168.1.1}"
DNS1="${STATIC_DNS1:-1.1.1.1}"
DNS2="${STATIC_DNS2:-8.8.8.8}"

echo "=== Statische IP-Konfiguration ==="
echo "Interface:  $INTERFACE"
echo "IP:         $IP_ADDRESS/$PREFIX"
echo "Gateway:    $GATEWAY"
echo "DNS:        $DNS1, $DNS2"
echo ""

# Backup
mkdir -p /etc/netplan/backup
cp /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null || true

# Neue Konfiguration
cat > /etc/netplan/10-static.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      addresses:
        - ${IP_ADDRESS}/${PREFIX}
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses:
          - $DNS1
          - $DNS2
EOF

chmod 600 /etc/netplan/10-static.yaml

# Alte DHCP-Konfig deaktivieren
for f in /etc/netplan/*.yaml; do
    if [ "$f" != "/etc/netplan/10-static.yaml" ]; then
        mv "$f" "${f}.disabled" 2>/dev/null || true
    fi
done

netplan apply

echo "=== Konfiguration angewendet ==="
sleep 2
ip -4 addr show $INTERFACE | grep inet


echo "=== Erster Boot und Git Setup abgeschlossen ==="
echo "Bitte jetzt neu starten, als Benutzer 'homecontrol' anmelden und mit den nächsten Schritten fortfahren."
exit 0



# reboot now

# exit 0
# ##################################################################
# ###### after reboot, login again and run:
# cd ~/home-control-server-config

# git pull origin main

# # Secrets in .env eintragen
# cp .env.example .env
# nano .env

# # Container starten
# docker compose up -d

# # Status prüfen
# docker compose ps
# docker compose logs -f