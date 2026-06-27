#!/usr/bin/env bash
# Wire nizam-dotfiles system files into their runtime locations.
# Run once (or re-run safely — ln -sf overwrites stale links):
#   sudo bash scripts/install.sh
set -euo pipefail

DOTFILES=/home/vazir/.nizam-dotfiles

# Systemd system units
ln -sf "$DOTFILES/systemd/metrics-security.service" /etc/systemd/system/metrics-security.service
ln -sf "$DOTFILES/systemd/metrics-security.timer"   /etc/systemd/system/metrics-security.timer

systemctl daemon-reload
echo "  reloaded system daemon"

# Logrotate
# logrotate rejects config files not owned by root — symlinks to user-owned files are refused.
# Copied (not symlinked) for the same reason as nizam-os/config/logrotate.nizam.
# After editing config/logrotate.dotfiles, re-run this script to push the change.
cp "$DOTFILES/config/logrotate.dotfiles" /etc/logrotate.d/dotfiles
chown root:root /etc/logrotate.d/dotfiles
chmod 644 /etc/logrotate.d/dotfiles
echo "  installed logrotate config"

echo ""
echo "Systemd symlinks:"
ls -la /etc/systemd/system/metrics-security.service \
       /etc/systemd/system/metrics-security.timer

echo ""
echo "Next: sudo systemctl enable --now prometheus-node-exporter metrics-security.timer"
