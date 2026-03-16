#!/bin/bash
set -e

# Systemd Service erstellen
cat > /etc/systemd/system/homelab-sync.service << 'EOF'
[Unit]
Description=Homelab Git Sync und Container Update
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
User=homelab
WorkingDirectory=/home/homelab/homelab
ExecStart=/home/homelab/homelab/scripts/apply-config.sh
StandardOutput=journal
StandardError=journal
EOF

# Systemd Timer erstellen
cat > /etc/systemd/system/homelab-sync.timer << 'EOF'
[Unit]
Description=Täglicher Homelab Sync

[Timer]
OnCalendar=*-*-* 04:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

# Aktivieren
systemctl daemon-reload
systemctl enable homelab-sync.timer
systemctl start homelab-sync.timer

echo "Systemd Timer aktiviert - läuft täglich um 04:00"
systemctl list-timers homelab-sync.timer
