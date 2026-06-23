# nizam-dotfiles

System configuration SSOT and restore reference for the Nizam setup.

This repo covers shell, git, systemd services, secrets management, and system inventory. It is one of three repos that together make up the full system:

| Repo | Purpose |
|---|---|
| `~/.nizam-dotfiles` | System configs, shell, services, inventory — this repo |
| `~/.nizam-os` | Core system: DB migrations, services layer, crons, Hermes orchestration |
| `~/.nizam-vault` | Obsidian notes |

---

## Repo structure

```
.nizam-dotfiles/
├── shell/              # Zsh config and aliases
├── systemd/            # Systemd unit files (symlinked to /etc/systemd/system/)
├── scripts/            # All automation scripts
├── inventory/          # Auto-generated software and service snapshots
├── secrets/            # Encrypted env file and age key
├── guides/             # Restore and reference documentation
├── .gitconfig          # Git identity and settings
└── .gitignore
```

---

## Symlinks

Config files live here and are symlinked to where the system expects them:

| Source (this repo) | Target |
|---|---|
| `shell/.zshrc` | `~/.zshrc` |
| `shell/.p10k.zsh` | `~/.p10k.zsh` |
| `.gitconfig` | `~/.gitconfig` |
| `systemd/watcher-env.service` | `/etc/systemd/system/watcher-env.service` |
| `systemd/watcher-inventory.service` | `/etc/systemd/system/watcher-inventory.service` |
| `systemd/watcher-inventory.timer` | `/etc/systemd/system/watcher-inventory.timer` |

---

## Services

Both are system services (survive logout, start on boot):

**`watcher-env.service`** — watches `secrets/nizam.env` via inotify and auto-encrypts it on every save using age.

**`watcher-inventory.timer`** + **`watcher-inventory.service`** — runs `watch-inventory.sh` hourly. Compares sha256 hashes of software and service snapshots, writes a diff to `inventory/last.diff` if anything changed.

---

## Secrets

`secrets/nizam.env` — plaintext env file, never committed (in `.gitignore`).
`secrets/nizam.env.enc` — age-encrypted version, committed.
`secrets/nizam-age-key.txt` — decryption key, never committed.

`watcher-env.service` handles encryption automatically on save. To decrypt manually:
```bash
scripts/decrypt-env.sh
```

---

## Fresh install

See `guides/restore.md` for the full step-by-step.
