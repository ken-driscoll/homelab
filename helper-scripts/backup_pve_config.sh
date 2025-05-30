#!/bin/bash
# Backup Proxmox /etc/pve to ZFS dataset and keep only the latest 7 backups

BACKUP_DIR="/tank/proxmox-backups/pve-config"
NUM_KEEP=7

mkdir -p "$BACKUP_DIR"
tar czf "$BACKUP_DIR/pve-config-$(date +%F-%H%M).tar.gz" /etc/pve

# Remove old backups, keeping only the newest $NUM_KEEP
ls -tp "$BACKUP_DIR"/pve-config-*.tar.gz | grep -v '/$' | tail -n +$((NUM_KEEP+1)) | xargs -r rm --