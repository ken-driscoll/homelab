#!/bin/bash

set -e

if [[ -z "$1" ]]; then
  echo "Usage: $0 <CTID>"
  exit 1
fi

CTID=$1
CONF="/etc/pve/lxc/$CTID.conf"

if ! [[ -f "$CONF" ]]; then
  echo "Error: Container config $CONF does not exist."
  exit 1
fi

if ! grep -q '^unprivileged: 1' "$CONF"; then
  echo "Error: Container $CTID is not unprivileged."
  exit 1
fi

echo "Stopping container $CTID..."
pct stop "$CTID"

echo "Applying custom UID/GID mappings for UID/GID 1000..."
# Remove existing idmap lines
sed -i '/^lxc.idmap/d' "$CONF"

# Add custom idmap
cat <<EOF >> "$CONF"
lxc.idmap = u 0 100000 1000
lxc.idmap = u 1000 1000 1
lxc.idmap = u 1001 101001 64535
lxc.idmap = g 0 100000 1000
lxc.idmap = g 1000 1000 1
lxc.idmap = g 1001 101001 64535
EOF

echo "Custom idmap applied to $CONF."

# Ensure host user/group
if ! id -u media &>/dev/null || [[ $(id -u media) -ne 1000 ]] || [[ $(id -g media) -ne 1000 ]]; then
  echo "Creating media:1000 user/group on host..."
  getent group media >/dev/null || groupadd -g 1000 media
  id -u media &>/dev/null || useradd -u 1000 -g 1000 -M -N -r -s /usr/sbin/nologin media
else
  echo "Host user/group media:1000 already exists."
fi

# Ensure container user/group
echo "Creating media:1000 inside container $CTID..."
pct exec "$CTID" -- bash -c '
  if ! getent group media >/dev/null || [ "$(getent group media | cut -d: -f3)" -ne 1000 ]; then
    groupadd -g 1000 media
  fi

  if ! id -u media &>/dev/null || [ "$(id -u media)" -ne 1000 ]; then
    useradd -u 1000 -g 1000 -M -N -r -s /usr/sbin/nologin media
  fi
'

echo "All done. Start the container with:"
echo "  pct start $CTID"