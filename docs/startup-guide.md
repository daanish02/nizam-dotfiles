# Machine Setup — nizam-vps

Fresh Ubuntu 24.04 to a ready machine. Covers the base layer only — shell, security, monitoring.  
For Nizam services, continue with `nizam-os/docs/README.md`.

---

## 0. Root bootstrap

Run as root on the fresh VPS.

```bash
ssh root@<nizam-vps-ip>
apt update && apt -y upgrade
timedatectl set-timezone UTC
hostnamectl set-hostname nizam-vps
```

```bash
# Add user and add to sudo list
adduser vazir
usermod -aG sudo vazir

# Copy your public key in
install -d -m 700 -o vazir -g vazir /home/vazir/.ssh
nano /home/vazir/.ssh/authorized_keys   # paste public key
chown -R vazir:vazir /home/vazir/.ssh
chmod 600 /home/vazir/.ssh/authorized_keys

# Generate new SSH key
ssh-keygen -t ed25519 -C "<key-name>"
ssh-copy-id vazir@<nizam-vps-ip>

# Let key expire, edit server's `~/.ssh/authorized_keys`, belt-and-braces
# expiry-time="YYYYMMDD" ssh-ed25519 AAAA...  
```

Log out of root. Everything below runs as `vazir`.

---

## 1. SSH hardening

Ubuntu cloud-init drops its own sshd config that overrides `sshd_config` — writing to `sshd_config.d/` takes precedence over it.

```bash
sudo nano /etc/ssh/sshd_config.d/99-local.conf

# Paste
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

```bash
sudo sshd -t && sudo systemctl restart ssh  # test ssh config and restart

# All three must show the expected values
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication'
```

---

## 2. Security baseline

```bash
# Firewall, brute-force, security updates
sudo apt install -y ufw fail2ban unattended-upgrades

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp  # MUST enable before firewall; can close after Tailscale setup
sudo ufw enable

sudo systemctl enable --now fail2ban
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## 3. Packages

```bash
sudo apt install -y \
  zsh fzf fd-find zoxide ripgrep inotify-tools \
  jq curl wget git btop tree eza bat \
  prometheus-node-exporter
```

`bat` installs as `batcat` on Ubuntu — the shell config aliases it.

---

## 4. Dotfiles

```bash
git clone <repo-url> ~/.nizam-dotfiles

# Shell
ln -sf ~/.nizam-dotfiles/shell/.zshrc ~/.zshrc
ln -sf ~/.nizam-dotfiles/shell/.p10k.zsh ~/.p10k.zsh

# Git identity
ln -sf ~/.nizam-dotfiles/.gitconfig ~/.gitconfig

# Switch default shell
chsh -s $(which zsh)
```

Open a new shell — zinit bootstraps itself on first launch.

```bash
# GitHub SSH key for push access
ssh-keygen -t ed25519 -C "your@email.com"
eval "$(ssh-agent -s)"  # authc and capture
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub   # add to GitHub → Settings → SSH Keys

cd ~/.nizam-dotfiles && git push   # confirm it works
```

---

## 5. Security monitoring

Collects SSH failures, fail2ban bans, and UFW block counts into a Prometheus-compatible textfile for node-exporter.

```bash
sudo bash ~/.nizam-dotfiles/scripts/install.sh
sudo systemctl enable --now prometheus-node-exporter metrics-security.timer
```

`install.sh` symlinks systemd units and copies `config/logrotate.dotfiles` to `/etc/logrotate.d/dotfiles` (copy not symlink — logrotate requires root ownership). Re-run after editing `config/logrotate.dotfiles` to push changes.

---

## 6. Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

tailscale status
tailscale ip -4  # note Tailscale IP
```

---

## 7. Lock down public SSH

**Do this after Tailscale is running — not before.**  

Before touching UFW, open a **second terminal** and confirm SSH over Tailscale works:

```bash
ssh vazir@<tailscale-ip>   # MUST succeed before you continue
```

Once confirmed, remove the public port:

```bash
sudo ufw delete allow 22/tcp
sudo ufw status   # expected: no rule for port 22
```

> This takes the server off every internet-wide port scanner and brute-force bot permanently. With the public port open, bots hammer it constantly — key-only auth handles it, but it's still noise and attack surface. Tailscale replaces it with an encrypted tunnel: only devices on your tailnet can reach the server at all, regardless of what's running.

---

## 8. Verify

```bash
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication'
sudo ufw status
sudo systemctl is-active fail2ban prometheus-node-exporter metrics-security.timer
bash ~/.nizam-dotfiles/scripts/git-status.sh
```

---

## Next

Machine is ready. Continue with `nizam-os/docs/README.md`.
