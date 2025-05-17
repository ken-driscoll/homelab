#!/bin/bash

# Set variables
LXC_ID=101
OLD_DATASET="core/media-downloads"
NEW_DATASET="core/downloads"
MOUNTPOINT="/mnt/downloads"

echo "Unmounting old dataset from LXC $LXC_ID (if mounted)..."
pct set "$LXC_ID" -mp1 delete

echo "Destroying old dataset ($OLD_DATASET) and all contents..."
zfs destroy -r "$OLD_DATASET"

echo "Creating new ZFS dataset: $NEW_DATASET"
zfs create "$NEW_DATASET"

echo "Creating sabnzbd subdirectories..."
mkdir -p /$NEW_DATASET/sabnzbd/{complete,incomplete,watch}

echo "Setting ownership to media:media (UID/GID 1000)..."
chown -R 1000:1000 /$NEW_DATASET

echo "Mounting new dataset into LXC $LXC_ID as $MOUNTPOINT (mp1)..."
pct set "$LXC_ID" -mp1 /$NEW_DATASET,mp=$MOUNTPOINT

echo "Done! /$NEW_DATASET is now set up and mounted in LXC $LXC_ID at $MOUNTPOINT."