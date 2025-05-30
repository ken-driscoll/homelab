#!/bin/bash
# Set ERC/TLER on all spinning disks at startup

# ERC timeout values (tenths of a second): 70 = 7.0 seconds
readsetting=70
writesetting=70

# Find all /dev/sd? spinning disks (skip NVMe, loop, etc.)
for disk in /dev/sd?; do
  if smartctl -l scterc "$disk" 2>&1 | grep -q "not supported"; then
    echo "$disk: ERC not supported"
    continue
  fi
  echo "Setting ERC for $disk"
  smartctl -q silent -l scterc,"${readsetting}","${writesetting}" "$disk"
  smartctl -l scterc "$disk" | grep -E 'Read|Write'
done