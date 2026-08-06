#!/bin/bash
# backup-sync.sh — Manual trigger for Tier 1 backup (used by udev for Tier 2 as well)
set -e

ACTION="${1:-tier1}"
LOG="/var/log/backup-manual.log"
NAS_BACKUP="/mnt/nas/backups/rack-server"
RCLONE_SCRIPT="/home/roger/config/backup/rclone-backup.sh"

echo "$(date): Manual backup triggered: ${ACTION}" | tee -a "$LOG"

case "$ACTION" in
    tier1|daily)
        /usr/local/bin/backup-tier1.sh
        ;;
    tier2|external)
        /usr/local/bin/backup-tier2.sh
        ;;
    tier3|offsite)
        bash "${RCLONE_SCRIPT}"
        ;;
    all)
        /usr/local/bin/backup-tier1.sh
        /usr/local/bin/backup-tier2.sh
        bash "${RCLONE_SCRIPT}"
        ;;
    status)
        echo "=== ZFS Snapshots ==="
        zfs list -t snapshot -r nas/backups 2>/dev/null | tail -20 || echo "  None"
        echo ""
        echo "=== Tier 1 backup contents ==="
        du -sh "${NAS_BACKUP}"/* 2>/dev/null || echo "  No backups yet"
        ;;
    *)
        echo "Usage: $0 {tier1|tier2|tier3|all|status}"
        exit 1
        ;;
esac

echo "$(date): Backup ${ACTION} complete" | tee -a "$LOG"
