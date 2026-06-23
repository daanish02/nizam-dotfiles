# System Restore Guide

Step-by-step to recreate this exact setup on a fresh machine.

---

## 1. Clone the repo

```bash
git clone <repo-url> ~/.nizam-dotfiles
```

---

## 2. Shell

Symlink zsh config:

```bash
ln -sf ~/.nizam-dotfiles/shell/.zshrc ~/.zshrc
ln -sf ~/.nizam-dotfiles/shell/.p10k.zsh ~/.p10k.zsh
```

Install zsh plugins — zinit bootstraps itself on first shell launch. Open a new shell and let it pull dependencies.

Install required tools:

```bash
sudo apt install zsh fzf fd-find zoxide
```

---

## 3. Git

```bash
ln -sf ~/.nizam-dotfiles/.gitconfig ~/.gitconfig
```

---

## 4. Secrets

Restore `nizam-age-key.txt` from secure backup into `secrets/`.

Decrypt the env file:

```bash
~/.nizam-dotfiles/scripts/decrypt-env.sh
```

The plaintext `nizam.env` is not committed — it must be restored from the encrypted copy.

---

## 5. Systemd services

Symlink units into `/etc/systemd/system/`:

```bash
sudo ln -s ~/.nizam-dotfiles/systemd/watcher-env.service /etc/systemd/system/watcher-env.service
sudo ln -s ~/.nizam-dotfiles/systemd/watcher-inventory.service /etc/systemd/system/watcher-inventory.service
sudo ln -s ~/.nizam-dotfiles/systemd/watcher-inventory.timer /etc/systemd/system/watcher-inventory.timer
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now watcher-env.service
sudo systemctl enable --now watcher-inventory.timer
```

Install required dependency for `watcher-env`:

```bash
sudo apt install inotify-tools age
```

---

## 6. Verify

```bash
systemctl status watcher-env.service
systemctl status watcher-inventory.timer

# Run inventory manually to confirm it works
~/.nizam-dotfiles/scripts/watch-inventory.sh
cat ~/.nizam-dotfiles/inventory/services.txt
