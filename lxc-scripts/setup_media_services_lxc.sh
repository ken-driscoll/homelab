#!/bin/bash

# Run Docker LXC community script
# echo "⚙️ Creating Docker LXC with community script..."
# bash -c "$(wget -qLO - https://community-scripts.github.io/ProxmoxVE/scripts/docker-lxc.sh)"

# Prompt for container ID
read -p "🔢 Enter LXC container ID for media-services (e.g. 102): " CTID

# Add shared media user if not present
echo "👤 Adding shared media user (UID 1000)..."
pct exec "$CTID" -- id -u media >/dev/null 2>&1 || pct exec "$CTID" -- adduser --uid 1000 media

# # Create app-configs and docker-compose datasets
# echo "📂 Creating ZFS datasets..."
# zfs list core/app-configs/media-services >/dev/null 2>&1 || zfs create core/app-configs/media-services
# zfs list core/docker-compose >/dev/null 2>&1 || zfs create core/docker-compose
# zfs list core/media-downloads >/dev/null 2>&1 || zfs create core/media-downloads

# # Ensure appdata subfolders exist and have proper ownership
# for dir in sabnzbd sonarr radarr readarr prowlarr overseerr homarr; do
#   mkdir -p "/core/app-configs/media-services/$dir"
#   chown -R 1000:1000 "/core/app-configs/media-services/$dir"
# done

# # Ensure media and download subfolders exist and have proper ownership
# for dir in complete incomplete; do
#   mkdir -p "/core/media-downloads/$dir"
#   chown -R 1000:1000 "/core/media-downloads/$dir"
# done

# mkdir -p "/tank/media"
# chown -R 1000:1000 "/tank/media"
# chmod g+s "/tank/media"

# Bind datasets into the LXC
echo "📎 Binding datasets into LXC $CTID..."
grep -q "mp0:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp0 /core/app-configs/media-services,mp=/opt/appdata
grep -q "mp1:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp1 /core/downloads,mp=/mnt/downloads
grep -q "mp2:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp2 /tank/media,mp=/mnt/media
grep -q "mp3:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp3 /core/scripts/homelab/docker-compose,mp=/opt/compose

# Copy Overseerr config backup before deploying
# BACKUP_PATH="/tank/app-configs-backup/overseerr"
# TARGET_PATH="/core/app-configs/media-services/overseerr"
# if [ -d "$BACKUP_PATH" ]; then
#     echo "📁 Copying Overseerr config backup to media-services..."
#     mkdir -p "$TARGET_PATH"
#     rsync -a "$BACKUP_PATH/" "$TARGET_PATH/"
#     echo "🔐 Setting permissions on Overseerr config..."
#     chown -R 1000:1000 "$TARGET_PATH"
# else
#     echo "⚠️ No Overseerr backup found at $BACKUP_PATH."
# fi

# Ensure Compose file exists
echo "🐳 Checking for Compose file..."
if ! pct exec "$CTID" -- test -f /opt/compose/media-services.yml; then
    echo "⬇️  Compose file not found. Downloading from GitHub..."
    pct exec "$CTID" -- wget -qO /opt/compose/media-services.yml https://raw.githubusercontent.com/ken-driscoll/homelab/main/docker-compose/media-services.yml
fi

# Deploy Docker Compose stack
echo "🚀 Launching Docker Compose..."
pct exec "$CTID" -- bash -c "docker compose -f /opt/compose/media-services.yml up -d"

echo "Creating media-services.local"
apt update
apt install avahi-daemon avahi-utils -y
hostnamectl set-hostname media-services
systemctl enable --now avahi-daemon
echo "media-services.local created"

echo "✅ media-services LXC setup complete."
