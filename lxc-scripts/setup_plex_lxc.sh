#!/bin/bash

# Prompt for container ID
read -p "🔢 Enter Plex LXC container ID (e.g. 101): " CTID

# Run community Plex LXC script
echo "📦 Creating Plex LXC using community script..."
bash -c "$(wget -qLO - https://community-scripts.github.io/ProxmoxVE/scripts/plex-lxc.sh)"

# Stop Plex service right after creation
echo "⏹ Stopping Plex service inside container..."
pct exec "$CTID" -- systemctl stop plexmediaserver

# Create dataset if missing
echo "📂 Ensuring dataset exists..."
zfs list core/app-configs/plex >/dev/null 2>&1 || zfs create core/app-configs/plex

# Bind Plex config dataset and media mount into container
echo "🔗 Binding datasets into Plex LXC..."
grep -q "mp0:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp0 /core/app-configs/plex,mp=/var/lib/plexmediaserver
grep -q "mp1:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp1 /tank/media,mp=/media

# Enable Quick Sync GPU passthrough
echo "🎮 Enabling GPU passthrough for Intel Quick Sync..."
grep -q "/dev/dri" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -device /dev/dri

# Restore Plex config if valid
BACKUP_PATH="/tank/app-config-backup/plex-app/config"
TARGET_PATH="/core/app-configs/plex"

echo "📥 Copying valid backup into place..."
mkdir -p "$(dirname "$TARGET_PATH")"
rsync -a "$BACKUP_PATH/" "$TARGET_PATH/"
echo "✅ Plex configuration restored into mounted dataset."

# Create media group if it doesn't exist, then add plex to it
echo "👥 Ensuring 'media' group (GID 1000) exists..."
pct exec "$CTID" -- getent group 1000 >/dev/null 2>&1 || pct exec "$CTID" -- addgroup --gid 1000 media

echo "👤 Adding 'plex' user to 'media' group..."
pct exec "$CTID" -- usermod -aG media plex

echo "🔐 Fixing ownership of config files..."
pct exec "$CTID" -- chown -R plex:plex /var/lib/plexmediaserver

# Start Plex service
echo "▶️ Starting Plex service..."
pct exec "$CTID" -- systemctl start plexmediaserver

echo "🚀 Plex LXC setup complete and running with GPU passthrough and media group access."
