# Runbook — nizam-dotfiles

Operational procedures for the machine layer. Dashboard, alerts, and metric reference live in [DASHBOARD](DASHBOARD.md).

**Contents**
- [Machine setup (fresh VPS)](#machine-setup-fresh-vps)

---

## Machine setup (fresh VPS)

**What this builds:** A hardened, monitored Ubuntu 24.04 VPS — SSH hardening, UFW, fail2ban, zsh, Prometheus, Grafana, Loki, Promtail, metric collectors — ready for **nizam-os** to install on top.

**Next phase:** [Nizam OS — rebuild plan](../../nizam-os/export/00-START-HERE.md)

### Prerequisites

- [ ] Fresh Ubuntu 24.04 VPS (Hostinger KVM2 or equivalent) with root SSH access
- [ ] SSH public key available on your local machine
- [ ] Tailscale account with at least one auth key available
- [ ] `~/nizam-dotfiles` repo URL

---

### Step 1 — Root bootstrap (manual)

Run as root on the fresh VPS. This step cannot be automated — it creates the user and installs the SSH key before anything else can run.

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

Verify SSH key access works from your local machine before proceeding:

```bash
ssh vazir@<vps-ip>   # must succeed
```

Log out of root. Everything from here runs as `vazir`.

---

### Step 2 — Clone repo

```bash
git clone <repo-url> ~/nizam-dotfiles
cd ~/nizam-dotfiles
```

Set up GitHub SSH for push access:

```bash
ssh-keygen -t ed25519 -C "your@email.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub  # add to GitHub → Settings → SSH Keys
cd ~/nizam-dotfiles && git push  # confirm push works
```

---

### Step 3 — Run `001-machine-setup.sh`

```bash
sudo bash ~/nizam-dotfiles/scripts/setup/001-machine-setup.sh
```

Takes 5–10 minutes. The script is idempotent — if it fails partway, fix the error and re-run.

**What it does (in order):**
1. SSH hardening — writes `/etc/ssh/sshd_config.d/50-cloud-init.conf`, reloads sshd
2. Security baseline — UFW (deny inbound, allow 22/tcp), fail2ban, unattended-upgrades
3. Packages — zsh, fzf, fd-find, zoxide, ripgrep, inotify-tools, jq, git, btop, eza, bat
4. Shell setup — symlinks `.zshrc`, `.p10k.zsh`, `.zsh-aliases`, `.gitconfig`; sets zsh as default shell
5. Monitoring stack — Prometheus, node-exporter, Grafana, Loki, Promtail; Grafana memory tuning
6. Wires symlinks — calls `install-symlinks.sh` (systemd units, logrotate, Loki/Promtail configs)
7. Enables metric timers — all collectors active
8. Installs Tailscale binary (does not run `tailscale up`)

---

### Step 4 — Post-script manual steps

**Open a new shell** — zsh and zinit bootstrap on first launch.

**Tailscale:**

```bash
sudo tailscale up
tailscale status  # → nizam-vps  <ip>  ...  online
tailscale ip -4  # note this IP for Grafana access
```

**Lock down public SSH** — only after Tailscale is confirmed working. Confirm SSH over Tailscale from a second terminal first:

```bash
ssh vazir@<tailscale-ip>  # must succeed before continuing
```

Once confirmed:

```bash
sudo ufw delete allow 22/tcp
sudo ufw status  # expected: no rule for port 22
```

---

### Step 5 — Grafana setup

Open Grafana at `http://<tailscale-ip>:3000` and change the default `admin/admin` password immediately.

**Provision datasources and dashboard:**

```bash
bash ~/nizam-dotfiles/scripts/setup/setup-grafana.sh
```

This creates the Prometheus (`nizam-prometheus`) and Loki (`nizam-loki`) datasources with the correct UIDs and pushes the system dashboard. Safe to re-run.

**Alerts:**

Fill `DISCORD_WEBHOOK_WARNING` and `DISCORD_WEBHOOK_CRITICAL` in `secrets/nizam-dotfiles.env`, then:

```bash
bash ~/nizam-dotfiles/scripts/setup/setup-alerts.sh
```

See [Alerts](DASHBOARD.md#alerts) for contact points, notification policy, and alert rules.

---

### Step 6 — Verify exit criteria

```bash
# SSH hardening
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication'
# → no / no / yes

# Firewall (after step 4)
sudo ufw status  # → no rule for 22/tcp

# Core services
systemctl is-active fail2ban prometheus grafana-server \ 
  prometheus-node-exporter loki promtail
# → all: active

# Loki ready
curl -s http://localhost:3100/ready  # → ready

# Metric collectors active
systemctl is-active \
  metrics-security.timer metrics-processes.timer metrics-disk.timer \ 
  metrics-sessions.timer metrics-services.timer
# → all: active

# Metric files present (wait 2 min after timers start)
ls /var/lib/prometheus/node-exporter/
# → disk-dirs.prom  processes.prom  security.prom  sessions.prom  services.prom

# Prometheus scraping nizam metrics
curl -s http://localhost:9100/metrics | grep nizam_ssh
# → nizam_ssh_failed_logins_total ...

# Loki receiving logs (wait 30s after Promtail starts)
curl -s 'http://localhost:3100/loki/api/v1/labels' \ 
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data'])"
# → ['host', 'job', 'level', 'scripts']

# Tailscale connected
tailscale status  # → nizam-vps  <tailscale-ip>  ...  online
```

---

### What's next

Machine is ready. Continue with:

**[Nizam OS — rebuild plan](../../nizam-os/export/00-START-HERE.md):** the nizam-os app is being rebuilt from scratch on top of this machine (old repo abandoned, see that doc's Phase 1 onward — PostgreSQL, Redis, LiteLLM, the `nizam` package, Hermes agents, Grafana).
