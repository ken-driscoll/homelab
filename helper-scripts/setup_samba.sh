#!/bin/bash

# Variables
SAMBA_CONF_DIR="/etc/samba"
COCKPIT_PORT=9090
UID=1111
GID=1111

# Ensure infra group and user exist
if ! getent group infra >/dev/null; then
  groupadd -g $GID infra
fi
if ! id -u infra >/dev/null 2>&1; then
  useradd -m -u $UID -g $GID infra
fi

# Ensure core/app-configs/infra-services/samba exists and is owned correctly
mkdir -p $SAMBA_CONF_DIR
chown -R $UID:$GID $SAMBA_CONF_DIR

# (Optional) Ensure mountpoints for Time Machine shares exist
mkdir -p /mnt/timemachine-mac1 /mnt/timemachine-mac2
chown -R $UID:$GID /mnt/timemachine-mac1 /mnt/timemachine-mac2

# Install Cockpit and Samba
apt update
apt install -y cockpit samba

# Enable and start Cockpit
systemctl enable --now cockpit.socket

# Sample Samba config with Time Machine
cat <<EOF > $SAMBA_CONF_DIR/smb.conf
[global]
  workgroup = WORKGROUP
  server string = Proxmox Infra-Services SMB
  vfs objects = fruit streams_xattr
  fruit:model = MacSamba
  log file = /var/log/samba/log.%m
  max log size = 1000
  logging = file

[timemachine-mac1]
  path = /mnt/timemachine-mac1
  browseable = yes
  writable = yes
  vfs objects = fruit streams_xattr
  fruit:time machine = yes
  fruit:time machine max size = 1T

[timemachine-mac2]
  path = /mnt/timemachine-mac2
  browseable = yes
  writable = yes
  vfs objects = fruit streams_xattr
  fruit:time machine = yes
  fruit:time machine max size = 1T
EOF

chown $UID:$GID $SAMBA_CONF_DIR/smb.conf

# Add samba users for each Mac
for macuser in mac1 mac2; do
  if ! id -u $macuser >/dev/null 2>&1; then
    useradd -m -g $GID $macuser
    echo "Set Samba password for user $macuser:"
    smbpasswd -a $macuser
  fi
done

# Restart Samba
systemctl restart smbd

echo "Cockpit is running at https://$(hostname -I | awk '{print $1}'):$COCKPIT_PORT"
echo "Samba is configured for Time Machine and persistent config at $SAMBA_CONF_DIR"