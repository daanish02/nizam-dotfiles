#!/usr/bin/env bash
# Idempotent VPS machine setup for nizam-dotfiles.
# Pre-requisite: root bootstrap complete (vazir user exists, SSH key installed, repo cloned).
# Run: sudo bash ~/nizam-dotfiles/scripts/setup/001-machine-setup.sh
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/../.." && pwd)"
VAZIR_HOME="/home/vazir"

BLD='\033[1m'
CYN='\033[36m'
GRN='\033[32m'
YLW='\033[33m'
RST='\033[0m'

_step() { printf "\n${BLD}${CYN}==> %s${RST}\n" "$*"; }
_ok()   { printf "${GRN}  %s${RST}\n" "$*"; }
_note() { printf "${YLW}  %s${RST}\n" "$*"; }

if [[ $EUID -ne 0 ]]; then
    echo "Run with: sudo bash scripts/setup/001-machine-setup.sh" >&2
    exit 1
fi

# Step 1: SSH hardening
_step "SSH hardening"
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/50-cloud-init.conf << 'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF
sshd -t && systemctl reload ssh
_ok "done"

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
_ok "done"

# Step 3: Packages
_step "Packages"
apt-get install -y \
    zsh fzf fd-find zoxide ripgrep inotify-tools \
    jq curl wget git btop tree eza bat
_ok "done"

# Step 4: Shell setup (as vazir)
_step "Shell setup"
sudo -u vazir ln -sf "$DOTFILES/shell/.zshrc"       "$VAZIR_HOME/.zshrc"
sudo -u vazir ln -sf "$DOTFILES/shell/.p10k.zsh"    "$VAZIR_HOME/.p10k.zsh"
sudo -u vazir ln -sf "$DOTFILES/shell/.zsh-aliases" "$VAZIR_HOME/.zsh-aliases"
sudo -u vazir ln -sf "$DOTFILES/config/.gitconfig"  "$VAZIR_HOME/.gitconfig"
if [ "$(getent passwd vazir | cut -d: -f7)" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)" vazir
    _ok "shell changed to zsh"
else
    _ok "shell already zsh"
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
    _note "grafana memory tuning applied"
fi

mkdir -p /var/lib/promtail
_ok "done"

# Step 6: Wire symlinks, logrotate, loki/promtail configs
_step "Wiring symlinks and configs"
bash "$DOTFILES/scripts/setup/install-symlinks.sh"

# Step 7: Enable metric timers
_step "Enabling metric timers"
systemctl daemon-reload
systemctl enable --now \
    metrics-security.timer \
    metrics-processes.timer \
    metrics-disk.timer \
    metrics-sessions.timer \
    metrics-services.timer
_ok "done"

# Step 8: Tailscale (install only — 'tailscale up' is manual)
_step "Tailscale"
if ! command -v tailscale &>/dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
    _ok "installed — run 'sudo tailscale up' manually"
else
    _ok "already installed"
fi

# Done
printf "\n${BLD}${CYN}====================================================================================${RST}\n"
printf "${BLD}${GRN}001-machine-setup.sh complete.${RST}\n"
printf "\n${BLD}Manual steps remaining:${RST}\n"
printf "  1. Open a new shell (zsh + zinit bootstrap on first launch)\n"
printf "  2. sudo tailscale up\n"
printf "  3. Verify: tailscale status && tailscale ip -4\n"
printf "  4. SSH over Tailscale from another terminal — confirm it works\n"
printf "  5. Lock down public SSH: sudo ufw delete allow 22/tcp\n"
printf "  6. Grafana: http://<tailscale-ip>:3000 — change default admin/admin password\n"
printf "     - Run: bash ~/nizam-dotfiles/scripts/setup/setup-grafana.sh\n"
printf "     - Run: bash ~/nizam-dotfiles/scripts/setup/setup-alerts.sh\n"
printf "${BLD}${CYN}====================================================================================${RST}\n"
