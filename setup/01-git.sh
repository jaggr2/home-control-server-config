#!/bin/bash
set -e

# ============================================================
# 01-git.sh - Docker Installation (Ubuntu)
# ============================================================

# generate key pair
ssh-keygen -t ed25519

# show public key and add to github as deployment key
# optional with write access to backup config to github repository
cat ~/.ssh/id_ed25519.pub

# wait until key is added to github and can be used for cloning
echo "Bitte fügen Sie den öffentlichen Schlüssel zu GitHub als Deployment Key hinzu und drücken Sie Enter..."
read -p "Drücken Sie Enter, um fortzufahren..."

# create repository, add deployment key and clone it
git clone git@github.com:jaggr2/home-control-server-config.git

# initial git configuration
git config --global user.name "derog-hc"
git config --global user.email "derog-hc@jaggi.xyz"

# create service directory structure
cd ~/home-control-server-config
# mkdir -p services/{cloudflared,homeassistant,freepbx,nodered}

# make all scripts executable
chmod +x setup/*.sh

# push changes to github
git add .
git commit -m "Execute permissions on setup scripts"
git push origin main

exit 0
#./setup/01-git.sh
./setup/02-docker.sh
./setup/03-webhookd.sh
./setup/04-auto-update-cron.sh
./setup/09-lcd-display.sh
