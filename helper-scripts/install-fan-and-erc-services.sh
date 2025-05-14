#!/bin/bash

set -e

# Copy fan control and ERC scripts to /usr/local/bin
echo "📁 Copying scripts to /usr/local/bin..."
install -m 755 /fan-control/stepped-fan-control.sh /usr/local/bin/stepped-fan-control.sh
install -m 755 /erc-script/set-erc.sh /usr/local/bin/set-erc.sh

# Copy systemd service units
echo "📁 Copying systemd services to /etc/systemd/system..."
cp /fan-control/stepped-fan-control.service /etc/systemd/system/
cp /erc-script/set-erc.service /etc/systemd/system/

# Reload systemd and enable services
echo "🔧 Enabling services..."
systemctl daemon-reexec
systemctl enable stepped-fan-control.service
systemctl enable set-erc.service

echo "🚀 Services installed and enabled. You can now reboot or start them manually:"
echo "  systemctl start stepped-fan-control.service"
echo "  systemctl start set-erc.service"
