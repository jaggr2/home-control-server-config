# update and install git
apt update & apt upgrade -y
apt-get install git

# generate key pair
ssh-keygen -t ed25519

# show public key and add to github as deployment key
cat ~/.ssh/id_ed25519.pub

exit 0
##################################################################
################ manual steps from here on: ######################
##################################################################

# create repository, add deployment key and clone it
git clone git@github.com:jaggr2/home-control-server-config.git

# create service directory structure
cd ~/home-control-server-config
mkdir -p services/{cloudflared,homeassistant,freepbx,nodered}

# make all scripts executable
chmod +x setup/*.sh

#./setup/01-system.sh
./setup/02-docker.sh
./setup/03-lcd-display.sh
./setup/04-auto-update-cron.sh

reboot now

exit 0

###### after reboot, login again and run:
cd ~/home-control-server-config

git pull origin main

# Secrets in .env eintragen
cp .env.example .env
nano .env

# Container starten
docker compose up -d

# Status prüfen
docker compose ps
docker compose logs -f