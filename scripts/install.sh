#!/usr/bin/env bash
# Wire nizam-dotfiles system files into their runtime locations.
# Run once (or re-run safely — ln -sf overwrites stale links):
#   sudo bash scripts/install.sh
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"

# Systemd system units
ln -sf "$DOTFILES/systemd/metrics-security.service"  /etc/systemd/system/metrics-security.service
ln -sf "$DOTFILES/systemd/metrics-security.timer"    /etc/systemd/system/metrics-security.timer
ln -sf "$DOTFILES/systemd/metrics-processes.service" /etc/systemd/system/metrics-processes.service
ln -sf "$DOTFILES/systemd/metrics-processes.timer"   /etc/systemd/system/metrics-processes.timer
ln -sf "$DOTFILES/systemd/metrics-disk.service"      /etc/systemd/system/metrics-disk.service
ln -sf "$DOTFILES/systemd/metrics-disk.timer"        /etc/systemd/system/metrics-disk.timer
ln -sf "$DOTFILES/systemd/metrics-sessions.service"  /etc/systemd/system/metrics-sessions.service
ln -sf "$DOTFILES/systemd/metrics-sessions.timer"    /etc/systemd/system/metrics-sessions.timer
ln -sf "$DOTFILES/systemd/metrics-services.service"  /etc/systemd/system/metrics-services.service
ln -sf "$DOTFILES/systemd/metrics-services.timer"    /etc/systemd/system/metrics-services.timer

systemctl daemon-reload
echo "  reloaded systemd daemon"

# Logrotate — logrotate rejects config files not owned by root, so copy not symlink.
# After editing config/logrotate.nizam-dotfiles, re-run this script to push the change.
cp "$DOTFILES/config/logrotate.nizam-dotfiles" /etc/logrotate.d/nizam-dotfiles
chown root:root /etc/logrotate.d/nizam-dotfiles
chmod 644 /etc/logrotate.d/nizam-dotfiles
echo "  installed logrotate config"

# Loki and Promtail configs — copy to their expected locations.
# Promtail runs as root (see /etc/systemd/system/promtail.service.d/override.conf).
if [[ -d /etc/loki ]]; then
    cp "$DOTFILES/config/loki.yaml" /etc/loki/config.yaml
    echo "  installed loki config"
fi
if [[ -d /etc/promtail ]]; then
    cp "$DOTFILES/config/promtail.yaml" /etc/promtail/config.yaml
    echo "  installed promtail config"
    # Override promtail service: run as root (home dir is 750) and use .yaml extension.
    # The upstream unit hardcodes config.yml — clear ExecStart first, then set new path.
    mkdir -p /etc/systemd/system/promtail.service.d
    cat > /etc/systemd/system/promtail.service.d/override.conf << 'EOF'
    [Service]
    User=root
    Group=root
    ExecStart=
    ExecStart=/usr/bin/promtail -config.file /etc/promtail/config.yaml
    EOF
    echo "  installed promtail service override"
fi

echo ""
echo "Systemd symlinks:"
ls -la \
    /etc/systemd/system/metrics-security.service \
    /etc/systemd/system/metrics-security.timer \
    /etc/systemd/system/metrics-processes.service \
    /etc/systemd/system/metrics-processes.timer \
    /etc/systemd/system/metrics-disk.service \
    /etc/systemd/system/metrics-disk.timer \
    /etc/systemd/system/metrics-sessions.service \
    /etc/systemd/system/metrics-sessions.timer \
    /etc/systemd/system/metrics-services.service \
    /etc/systemd/system/metrics-services.timer

echo ""
echo "Next: sudo systemctl enable --now metrics-security.timer metrics-processes.timer metrics-disk.timer metrics-sessions.timer metrics-services.timer"