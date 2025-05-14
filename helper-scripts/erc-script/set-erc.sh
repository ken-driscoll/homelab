#!/bin/bash

# Configure SCT Error Recovery Control (ERC) on SMART-enabled SATA drives
# Recommended for ZFS systems with consumer/NAS drives (e.g., WD Red, Seagate IronWolf)

readsetting=70   # 7.0 seconds
writesetting=70  # 7.0 seconds

get_smart_drives() {
  drives=$(smartctl --scan | grep "dev" | grep -v "nvme" | grep -v "ses" | awk '{print $1}' | sed 's|/dev/||')
  smartdrives=""
  for drive in $drives; do
    if smartctl -i "/dev/$drive" | grep -q "SMART support is: Enabled"; then
      smartdrives+="$drive "
    fi
  done
  echo "$smartdrives"
}

set_erc() {
  echo "🛠 Setting ERC on: /dev/$1"
  smartctl -q silent -l scterc,"${readsetting}","${writesetting}" "/dev/$1"
  smartctl -l scterc "/dev/$1" | grep "SCT\|Write\|Read"
}

main() {
  drives=$(get_smart_drives)
  for drive in $drives; do
    set_erc "$drive"
  done
}

main
