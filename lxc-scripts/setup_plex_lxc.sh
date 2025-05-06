
#!/bin/bash

# -------------------------------
# Create Plex LXC Container
# -------------------------------
echo "📦 Launching updated Plex LXC setup script..."
bash -c "$(wget -qLO - https://community-scripts.github.io/ProxmoxVE/scripts/plex-lxc.sh)"

# Prompt user for container ID
read -p "🔢 Enter the Plex LXC container ID (e.g. 100): " CTID

# -------------------------------
# Create Plex config dataset on apps pool (if it doesn't exist)
# -------------------------------
echo "🗂 Ensuring apps/plexconfig dataset exists..."
zfs list apps/plexconfig >/dev/null 2>&1 || zfs create apps/plexconfig

# -------------------------------
# Bind-mount ZFS Datasets (skip if already present)
# -------------------------------
echo "📁 Mounting /tank/media to /mnt/media (mp0)..."
grep -q "mp0:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp0 /tank/media,mp=/mnt/media

echo "📁 Mounting /apps/plexconfig to /var/lib/plexmediaserver (mp1)..."
grep -q "mp1:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp1 /apps/plexconfig,mp=/var/lib/plexmediaserver

# -------------------------------
# Enable GPU passthrough for Quick Sync
# -------------------------------
echo "🎮 Enabling iGPU passthrough..."
grep -q "c 226:* rwm" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -device 'c 226:* rwm'
grep -q "mp2:" /etc/pve/lxc/$CTID.conf || pct set "$CTID" -mp2 /dev/dri,mp=/dev/dri

# -------------------------------
# Add Plex user to media group
# -------------------------------
echo "👥 Adding plex user to media group inside the container..."
pct exec "$CTID" -- bash -c "getent group 1000 || groupadd -g 1000 media"
pct exec "$CTID" -- bash -c "id -nG plex | grep -qw media || usermod -aG media plex"

# -------------------------------
# Restart container
# -------------------------------
echo "♻️ Restarting LXC $CTID..."
pct restart "$CTID"

echo "✅ Plex LXC setup complete. Please open the Plex web UI to finish configuration."
