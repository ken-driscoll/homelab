#!/bin/bash
echo "🔄 Updating homelab repo..."
cd /core/scripts/homelab || { echo '❌ homelab repo not found at /core/scripts/homelab'; exit 1; }
git pull
echo "✅ Update complete."
