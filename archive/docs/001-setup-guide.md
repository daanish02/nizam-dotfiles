# Machine Setup — Guide

**What this builds:** A hardened, monitored Ubuntu 24.04 VPS with a consistent shell environment, security baseline, and live Grafana dashboard — ready for nizam-os to install on top.

**Reference:** [docs/001-system-dashboard.md](system-dashboard.md) for dashboard panels, alert rules, and operational reference.  
**Next:** nizam-os [docs/guides/001-foundation-guide.md](../../nizam-os/docs/guides/001-foundation.md)

---

## Prerequisites

- [ ] Fresh Ubuntu 24.04 VPS (Hostinger KVM2 or equivalent) with root SSH access
- [ ] SSH public key available on your local machine
- [ ] Tailscale account with at least one auth key available
- [ ] `~/nizam-dotfiles` repo URL

---

## Step 1 — Root bootstrap

Run as root on the fresh VPS.

```bash
ssh root@<vps-ip>
apt update && apt -y upgrade
timedatectl set-timezone UTC
hostnamectl set-hostname nizam-vps
```

Create the `vazir` user and install your SSH key:

```bash
adduser vazir
usermod -aG sudo vazir

install -d -m 700 -o vazir -g vazir /home/vazir/.ssh
nano /home/vazir/.ssh/authorized_keys   # paste your public key
chown -R vazir:vazir /home/vazir/.ssh
chmod 600 /home/vazir/.ssh/authorized_keys

# Generate new SSH key
ssh-keygen -t ed25519 -C "<key-name>"
ssh-copy-id vazir@<nizam-vps-ip>

# Let key expire, edit server's `~/.ssh/authorized_keys`, belt-and-braces
# expiry-time="YYYYMMDD" ssh-ed25519 AAAA...  
```

Log out of root. Everything from here runs as `vazir`.

---

## Step 2 — SSH hardening

Ubuntu cloud-init drops its own sshd config that overrides `sshd_config`. Writing to `sshd_config.d/` takes precedence.

```bash
sudo nano /etc/ssh/sshd_config.d/*.conf

# Paste
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

```bash
sudo sshd -t && sudo systemctl restart ssh

# Verify — all three must show the expected value
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication'
```

Expected output:
```
permitrootlogin no
passwordauthentication no
pubkeyauthentication yes
```

---

## Step 3 — Security baseline

```bash
sudo apt install -y ufw fail2ban unattended-upgrades

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp   # close this after Tailscale is confirmed working (Step 8)
sudo ufw enable

sudo systemctl enable --now fail2ban
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## Step 4 — Packages

```bash
sudo apt install -y \
  zsh fzf fd-find zoxide ripgrep inotify-tools \
  jq curl wget git btop tree eza bat
```

> `bat` installs as `batcat` on Ubuntu. The shell config aliases it to `bat` — no manual fix needed.

---

## Step 5 — Dotfiles

```bash
git clone <repo-url> ~/nizam-dotfiles
```

Wire symlinks and shell config:

```bash
ln -sf ~/nizam-dotfiles/shell/.zshrc ~/.zshrc
ln -sf ~/nizam-dotfiles/shell/.p10k.zsh ~/.p10k.zsh
ln -sf ~/nizam-dotfiles/shell/.zsh-aliases ~/.zsh-aliases
ln -sf ~/nizam-dotfiles/config/.gitconfig ~/.gitconfig
chsh -s $(which zsh)
```

Open a new shell — zinit bootstraps itself on first launch.

Set up GitHub SSH for push access:

```bash
ssh-keygen -t ed25519 -C "your@email.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub   # add to GitHub → Settings → SSH Keys
```

Confirm push works:

```bash
cd ~/nizam-dotfiles && git push
```

---

## Step 6 — Monitoring stack

```bash
# Prometheus
sudo apt install -y prometheus prometheus-node-exporter

# Grafana + Loki + Promtail (Grafana repo)
sudo mkdir -p /etc/apt/keyrings

wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt update && sudo apt install -y grafana loki promtail
sudo systemctl enable --now prometheus grafana-server
```

Tune Grafana memory — without this, Go's runtime retains 800 MB+ of heap:

```bash
sudo tee -a /etc/default/grafana-server << 'EOF'
GOGC=20
GOMEMLIMIT=350MiB
EOF

sudo systemctl restart grafana-server
```

Create the positions directory — the apt package does not create it:

```bash
sudo mkdir -p /var/lib/promtail
```

Install Loki and Promtail configs, then start both:

```bash
# Configs, systemd symlinks, promtail override (runs as root, uses config.yaml)
sudo bash ~/nizam-dotfiles/scripts/setup/install.sh
sudo systemctl enable --now loki promtail

curl -s http://localhost:3100/ready  # → ready
ls /var/lib/promtail/positions.yaml  # → /var/lib/promtail/positions.yaml
```

---

## Step 7 — Metric collectors

```bash
chmod +x ~/nizam-dotfiles/scripts/metrics/metrics-sessions.sh ~/nizam-dotfiles/scripts/metrics/metrics-services.sh

sudo systemctl enable --now \
  metrics-security.timer \
  metrics-processes.timer \
  metrics-disk.timer \
  metrics-sessions.timer \
  metrics-services.timer
```

`install.sh` (already run above) symlinks all systemd units from `systemd/` into `/etc/systemd/system/`. Re-run after pulling changes that touch `systemd/` or `config/`.

---

## Step 8 — Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

tailscale status
tailscale ip -4   # note the Tailscale IP
```

---

## Step 9 — Lock down public SSH

> Do this after Tailscale is running — not before. Removing the public port before Tailscale is confirmed working will lock you out.

Before touching UFW, open a second terminal and confirm SSH over Tailscale works:

```bash
ssh vazir@<tailscale-ip>   # must succeed before continuing
```

Once confirmed:

```bash
sudo ufw delete allow 22/tcp
sudo ufw status   # expected: no rule for port 22
```

The server is now unreachable from the public internet at the network layer. Only devices on your Tailscale tailnet can connect.

---

## Step 10 — Grafana dashboard and alerts

Open Grafana at `http://<tailscale-ip>:3000` (default login: admin/admin — change immediately).

**Datasources:**

1. Connections → Data Sources → Add → **Prometheus**
   - URL: `http://localhost:9090`
   - UID: `nizam-prometheus`
   - → Save & Test (green = healthy)

2. Connections → Data Sources → Add → **Loki**
   - URL: `http://localhost:3100`
   - UID: `nizam-loki`
   - → Save & Test

**Dashboard:**

3. Dashboards → New → Import → upload `grafana/001-system-dashboard.json`
   - Select the Prometheus datasource when prompted

**Alerts:**

4. Alerting → Contact points → Add — create `nizam-warn` and `nizam-crit` with your Discord webhook URLs
5. Alerting → Notification policies — route `severity=warning` to `nizam-warn`, `severity=critical` to `nizam-crit`
6. Import alert rules from `grafana/alert-rules.json` if available, or add manually per [001-system-dashboard.md](system-dashboard.md#alert-rules)

---

## Verify

Run after all steps complete:

```bash
# SSH hardening
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication'  # → no / no / yes

# Firewall
sudo ufw status  # → no rule for 22/tcp

# Core services
systemctl is-active fail2ban prometheus grafana-server prometheus-node-exporter loki promtail  # → all: active

# Loki ready
curl -s http://localhost:3100/ready  # → ready

# Metric collectors
systemctl is-active metrics-security.timer metrics-processes.timer metrics-disk.timer metrics-sessions.timer metrics-services.timer  # → all: active

# Metric files (wait 2 mins)
ls /var/lib/prometheus/node-exporter/  # → disk-dirs.prom  processes.prom  security.prom  sessions.prom  services.prom

# Prometheus scraping nizam metrics
curl -s http://localhost:9100/metrics | grep nizam_ssh  # → nizam_ssh_failed_logins_total ...

# Promtail tracking logs
ls /var/lib/promtail/positions.yaml  # → /var/lib/promtail/positions.yaml

# Loki receiving logs (wait 30s)
curl -s 'http://localhost:3100/loki/api/v1/labels' | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data'])"  # → ['host', 'job', 'level', 'service']

# Tailscale connected
tailscale status  # → nizam-vps  <tailscale-ip>  ...  online
```

---

## What's next

Machine is ready. Continue with nizam-os setup:

**[Nizam OS — Phase 1 Foundation](../../nizam-os/docs/guides/001-foundation.md):** PostgreSQL, Redis, LiteLLM, audit schema.