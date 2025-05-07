#!/bin/bash

# Prompt for container ID
read -p "🔢 Enter Plex LXC container ID (e.g. 101): " CTID

# Run community Plex LXC script
echo "📦 Creating Plex LXC using community script..."
bash -c "$(wget -qLO - https://community-scripts.github.io/ProxmoxVE/scripts/plex-lxc.sh)"

echo "🛑 Stopping container immediately after creation..."
pct shutdown "$CTID" 2>/dev/null
sleep 3

# Create dataset if missing
echo "📂 Ensuring dataset exists..."
zfs list core/app-configs/plex >/dev/null 2>&1 || zfs create core/app-configs/plex

# Bind Plex config dataset and media mount into container
echo "🔗 Binding datasets into Plex LXC..."
grep -q "mp0:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp0 /core/app-configs/plex,mp=/config
grep -q "mp1:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp1 /tank/media,mp=/mnt/media

# Restore Plex config if valid
BACKUP_PATH="/tank/app-config-backup/plex-app/config/Library/Application Support/Plex Media Server"
TARGET_PATH="/core/app-configs/plex/Library/Application Support/Plex Media Server"

if [ -f "$BACKUP_PATH/Preferences.xml" ]; then
  echo "📥 Copying valid backup into place..."
  mkdir -p "$(dirname "$TARGET_PATH")"
  rsync -a "$BACKUP_PATH/" "$TARGET_PATH/"
  echo "✅ Plex configuration restored into mounted dataset."
else
  echo "⚠️ Preferences.xml not found in expected backup path. Skipping restore."
fi

echo "▶️ Starting container..."
pct start "$CTID"
sleep 3

# Add plex user to media group and set permissions
echo "👥 Adding 'plex' user to media group (GID 1000)..."
pct exec "$CTID" -- usermod -aG 1000 plex

echo "🔐 Fixing ownership of config files..."
pct exec "$CTID" -- chown -R plex:plex /config

echo "🚀 Plex LXC setup complete and started."
