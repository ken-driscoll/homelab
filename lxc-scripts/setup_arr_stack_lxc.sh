#!/bin/bash

# Run Docker LXC community script
echo "⚙️ Creating Docker LXC with community script..."
bash -c "$(wget -qLO - https://community-scripts.github.io/ProxmoxVE/scripts/docker-lxc.sh)"

# Prompt for container ID
read -p "🔢 Enter LXC container ID for *arr stack (e.g. 102): " CTID

# Create app-configs and docker-compose datasets
echo "📂 Creating ZFS datasets..."
zfs list core/app-configs/arrstack >/dev/null 2>&1 || zfs create core/app-configs/arrstack
zfs list core/docker-compose >/dev/null 2>&1 || zfs create core/docker-compose
zfs list core/media-downloads >/dev/null 2>&1 || zfs create core/media-downloads

# Mount ZFS datasets into the LXC
echo "📎 Binding datasets into LXC $CTID..."
grep -q "mp0:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp0 /core/app-configs/arrstack,mp=/opt/appdata
grep -q "mp1:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp1 /core/media-downloads,mp=/mnt/downloads
grep -q "mp2:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp2 /tank/media,mp=/mnt/media
grep -q "mp3:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp3 /core/docker-compose,mp=/opt/compose

# Add shared media user if not present
echo "👤 Adding shared media user (UID 1000)..."
pct exec "$CTID" -- id -u media >/dev/null 2>&1 || pct exec "$CTID" -- adduser --uid 1000 media

# Ensure Compose file exists
echo "🐳 Checking for Compose file..."
if ! pct exec "$CTID" -- test -f /opt/compose/arr-stack.yml; then
  echo "⬇️  Compose file not found. Downloading from GitHub..."
  pct exec "$CTID" -- wget -qO /opt/compose/arr-stack.yml https://raw.githubusercontent.com/ken-driscoll/homelab/main/docker-compose/arr-stack.yml
fi

# Deploy Docker Compose stack
echo "🚀 Launching Docker Compose..."
pct exec "$CTID" -- bash -c "cd /opt/compose && docker compose -f arr-stack.yml up -d"

echo "✅ *arr stack LXC setup complete."
