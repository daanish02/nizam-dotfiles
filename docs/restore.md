# System Restore Guide

Step-by-step to recreate this machine setup on a fresh server.

> Secrets, credentials, and Nizam services are all in `~/.nizam-os`. Clone that repo and run its setup after this.

---

## 1. Clone the repo

```bash
git clone <repo-url> ~/.nizam-dotfiles
```

---

## 2. Shell

```bash
ln -sf ~/.nizam-dotfiles/shell/.zshrc ~/.zshrc
ln -sf ~/.nizam-dotfiles/shell/.p10k.zsh ~/.p10k.zsh
```

Zinit bootstraps itself on first shell launch — open a new shell and let it pull dependencies.

```bash
sudo apt install zsh fzf fd-find zoxide
```

---

## 3. Git

```bash
ln -sf ~/.nizam-dotfiles/.gitconfig ~/.gitconfig
```

---

## 4. Security monitoring

```bash
sudo ln -sf ~/.nizam-dotfiles/systemd/metrics-security.service /etc/systemd/system/metrics-security.service
sudo ln -sf ~/.nizam-dotfiles/systemd/metrics-security.timer /etc/systemd/system/metrics-security.timer
sudo systemctl daemon-reload
sudo systemctl enable --now metrics-security.timer
```

---

## 5. Verify

```bash
systemctl status metrics-security.timer
```

---

## 6. Nizam-OS

Clone nizam-os and run its setup:

```bash
git clone <repo-url> ~/.nizam-os
cd ~/.nizam-os

# Restore secrets (from encrypted backup)
scripts/decrypt-env.sh

# Install all symlinks (systemd units, watcher-env, watcher-inventory)
sudo bash scripts/setup/install-symlinks.sh

# Enable services
sudo systemctl enable --now watcher-env.service watcher-inventory.timer
```
