#!/bin/bash
# 06-backup-setup.sh — Configure 3-tier backup: ZFS sync + external disk + rclone
set -euo pipefail

USERNAME="${SUDO_USER:-$USER}"
CONFIG_DIR="/home/${USERNAME}/config/backup"
NAS_BACKUP="/mnt/nas/backups/rack-server"

echo "=== Creating backup directories ==="
mkdir -p "${CONFIG_DIR}" "${NAS_BACKUP}"
mkdir -p "${NAS_BACKUP}/vm-images"
mkdir -p "${NAS_BACKUP}/container-data"

# ============================================================
# Tier 1: Daily VM + container sync to ZFS pool
# ============================================================
echo ""
echo "=== Tier 1: Daily sync to ZFS ==="

cat > /usr/local/bin/backup-tier1.sh << 'SCRIPT'
#!/bin/bash
set -e

NAS_BACKUP="/mnt/nas/backups/rack-server"
LOG="/var/log/backup-tier1.log"
echo "$(date): Starting Tier 1 backup" >> "$LOG"

# Sync VM images
echo "Syncing VM images..." >> "$LOG"
rsync -av --delete /var/lib/libvirt/images/ "${NAS_BACKUP}/vm-images/" >> "$LOG" 2>&1

# Sync container configs (Quadlet files managed by Git, data volumes here)
echo "Syncing container configs..." >> "$LOG"
rsync -av --delete /home/*/config/ "${NAS_BACKUP}/container-data/" >> "$LOG" 2>&1

# Take ZFS snapshot
ZFS_SNAPSHOT="nas/backups@tier1-$(date +%Y%m%d)"
zfs snapshot "${ZFS_SNAPSHOT}" >> "$LOG" 2>&1
zfs list -t snapshot -r nas/backups | tail -20 >> "$LOG"

echo "$(date): Tier 1 backup complete" >> "$LOG"
SCRIPT

chmod +x /usr/local/bin/backup-tier1.sh

cat > /etc/cron.d/backup-tier1 << EOF
0 3 * * * root /usr/local/bin/backup-tier1.sh
EOF

echo "Tier 1: Daily at 3am to ${NAS_BACKUP}"

# ============================================================
# Tier 2: Monthly external USB disk backup (udev-triggered)
# ============================================================
echo ""
echo "=== Tier 2: External USB backup (monthly) ==="

cat > /usr/local/bin/backup-tier2.sh << 'SCRIPT'
#!/bin/bash
set -e

NAS_BACKUP="/mnt/nas/backups/rack-server"
LOG="/var/log/backup-tier2.log"

echo "$(date): === Tier 2 external disk backup started ===" | tee -a "$LOG"

# Find the mounted external disk
EXT_MOUNT=$(findmnt -rn -o TARGET -S UUID="${EXTERNAL_DISK_UUID:-}" 2>/dev/null || true)
if [ -z "$EXT_MOUNT" ]; then
    echo "ERROR: External disk not found or not mounted." | tee -a "$LOG"
    exit 1
fi

BACKUP_DEST="${EXT_MOUNT}/derog-rack-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DEST"

echo "Copying Tier 1 data to external disk..." | tee -a "$LOG"
rsync -av --progress "${NAS_BACKUP}/" "${BACKUP_DEST}/" | tee -a "$LOG"

echo "Unmounting external disk..." | tee -a "$LOG"
umount "$EXT_MOUNT"

echo "$(date): Tier 2 backup complete. Disk can be removed and returned to tresor." | tee -a "$LOG"
SCRIPT

chmod +x /usr/local/bin/backup-tier2.sh

echo ""
echo "To set up Tier 2:"
echo "  1. Identify external disk UUID: lsblk -f"
echo "  2. Create udev rule:"
echo "     echo 'ACTION==\"add\", ENV{ID_FS_UUID}==\"<UUID>\", RUN+=\"/usr/local/bin/backup-tier2.sh\"' \\"
echo "       > /etc/udev/rules.d/99-backup-disk.rules"
echo "  3. udevadm control --reload-rules"

# ============================================================
# Tier 3: Weekly rclone to cloud
# ============================================================
echo ""
echo "=== Tier 3: Weekly rclone (offsite) ==="

if command -v rclone &>/dev/null; then
    echo "rclone already installed."
else
    echo "Installing rclone..."
    curl https://rclone.org/install.sh | bash
fi

cat > "${CONFIG_DIR}/rclone-backup.sh" << 'SCRIPT'
#!/bin/bash
set -e

NAS_BACKUP="/mnt/nas/backups/rack-server"
REMOTE="offsite:derog-rack-backup"
LOG="/var/log/backup-tier3.log"

echo "$(date): Starting Tier 3 rclone sync" >> "$LOG"
rclone sync "${NAS_BACKUP}" "${REMOTE}" \
    --progress \
    --transfers 4 \
    --log-file="$LOG" \
    --log-level INFO

echo "$(date): Tier 3 backup complete" >> "$LOG"
SCRIPT

chmod +x "${CONFIG_DIR}/rclone-backup.sh"
chown "${USERNAME}:${USERNAME}" "${CONFIG_DIR}/rclone-backup.sh"

cat > /etc/cron.d/backup-tier3 << 'CRON'
0 4 * * 0 root /home/*/config/backup/rclone-backup.sh
CRON

echo ""
echo "To configure Tier 3:"
echo "  1. Run: rclone config (set up 'offsite' remote)"
echo "  2. Choose provider: B2, Wasabi, Google Drive, etc."
echo "  3. Test: rclone ls offsite:derog-rack-backup"
echo ""

echo "=== Backup setup complete ==="
echo "Tier 1: Daily 3am (ZFS sync + snapshot)"
echo "Tier 2: Monthly (udev-triggered external USB disk -> tresor)"
echo "Tier 3: Weekly Sunday 4am (rclone offsite)"
