#!/usr/bin/env bash
# Idempotent VPS machine setup for nizam-dotfiles.
# Pre-requisite: root bootstrap complete (vazir user exists, SSH key installed, repo cloned).
# Run: sudo bash ~/nizam-dotfiles/scripts/setup/001-machine-setup.sh
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
VAZIR_HOME="/home/vazir"

if [[ $EUID -ne 0 ]]; then
    echo "Run with: sudo bash scripts/setup/001-machine-setup.sh" >&2
    exit 1
fi

_step() { echo ""; echo "==> $*"; }

# Step 1: SSH hardening
_step "SSH hardening"
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/50-cloud-init.conf << 'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF
sshd -t && systemctl reload ssh
echo "  done"

# Step 2: Security baseline 
_step "Security baseline"
apt-get install -y ufw fail2ban unattended-upgrades
ufw --force default deny incoming
ufw --force default allow outgoing
if ! ufw status | grep -q "22/tcp.*ALLOW"; then
    ufw allow 22/tcp
fi
ufw --force enable
systemctl enable --now fail2ban
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades
echo "  done"

# Step 3: Packages
_step "Packages"
apt-get install -y \
    zsh fzf fd-find zoxide ripgrep inotify-tools \
    jq curl wget git btop tree eza bat
echo "  done"

# Step 4: Shell setup (as vazir) 
_step "Shell setup"
sudo -u vazir ln -sf "$DOTFILES/shell/.zshrc"       "$VAZIR_HOME/.zshrc"
sudo -u vazir ln -sf "$DOTFILES/shell/.p10k.zsh"    "$VAZIR_HOME/.p10k.zsh"
sudo -u vazir ln -sf "$DOTFILES/shell/.zsh-aliases" "$VAZIR_HOME/.zsh-aliases"
sudo -u vazir ln -sf "$DOTFILES/config/.gitconfig"  "$VAZIR_HOME/.gitconfig"
if [ "$(getent passwd vazir | cut -d: -f7)" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)" vazir
    echo "  shell changed to zsh"
else
    echo "  shell already zsh"
fi

# Step 5: Monitoring stack 
_step "Monitoring stack"
apt-get install -y prometheus prometheus-node-exporter

if ! [ -f /etc/apt/keyrings/grafana.gpg ]; then
    mkdir -p /etc/apt/keyrings
    wget -q -O - https://apt.grafana.com/gpg.key \
        | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
        | tee /etc/apt/sources.list.d/grafana.list
    apt-get update
fi
apt-get install -y grafana loki promtail
systemctl enable --now prometheus grafana-server

if ! grep -q "GOGC=20" /etc/default/grafana-server 2>/dev/null; then
    printf '\nGOGC=20\nGOMEMLIMIT=350MiB\n' >> /etc/default/grafana-server
    systemctl restart grafana-server
    echo "  grafana memory tuning applied"
fi

mkdir -p /var/lib/promtail
echo "  done"

# Step 6: Wire symlinks, logrotate, loki/promtail configs 
_step "Wiring symlinks and configs"
bash "$DOTFILES/scripts/setup/install.sh"

# Step 7: Enable metric timers 
_step "Enabling metric timers"
systemctl daemon-reload
systemctl enable --now \
    metrics-security.timer \
    metrics-processes.timer \
    metrics-disk.timer \
    metrics-sessions.timer \
    metrics-services.timer
echo "  done"

# Step 8: Tailscale (install only — 'tailscale up' is manual) 
_step "Tailscale"
if ! command -v tailscale &>/dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
    echo "  installed — run 'sudo tailscale up' manually"
else
    echo "  already installed"
fi

# Done
echo ""
echo "========================================================"
echo "001-machine-setup.sh complete."
echo ""
echo "Manual steps remaining:"
echo "  1. Open a new shell (zsh + zinit bootstrap on first launch)"
echo "  2. sudo tailscale up"
echo "  3. Verify: tailscale status && tailscale ip -4"
echo "  4. SSH over Tailscale from another terminal — confirm it works"
echo "  5. Lock down public SSH: sudo ufw delete allow 22/tcp"
echo "  6. Grafana: http://<tailscale-ip>:3000"
echo "     - Add Prometheus datasource (URL: http://localhost:9090, UID: nizam-prometheus)"
echo "     - Add Loki datasource (URL: http://localhost:3100, UID: nizam-loki)"
echo "     - Import grafana/001-system-dashboard.json"
echo "     - Run: bash ~/nizam-dotfiles/scripts/setup/setup-alerts.sh"
echo "========================================================"