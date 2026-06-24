# nizam-dotfiles

Machine configuration for the server that runs Nizam-OS.

This repo makes the server behave the way you like. It is one of three repos:

| Repo | Purpose |
|---|---|
| `nizam-dotfiles` | The machine — shell, git, security monitoring — this repo |
| `nizam-os` | The software — agents, services, configs, dashboards, secrets |
| `nizam-vault` | Obsidian notes |

**What belongs here:** Config that would exist on this server even without Nizam-OS — shell, git identity, security monitoring.

**What belongs in nizam-os:** Everything needed to run Nizam, including secrets and credentials.

Test: *Would this file belong on a server where I'm not running Nizam-OS?* Yes → here. No → nizam-os.

---

## Repo structure

```
.nizam-dotfiles/
├── shell/              # Zsh config and aliases
├── systemd/            # metrics-security units (symlinked)
├── scripts/            # metrics-security.sh, git-status.sh
├── grafana/            # system-dashboard.json — machine/security metrics only
├── docs/               # System restore guide, dashboard guide
├── .gitconfig          # Git identity and settings
└── .gitignore
```

---

## Symlinks

| Source (this repo) | Target |
|---|---|
| `shell/.zshrc` | `~/.zshrc` |
| `shell/.p10k.zsh` | `~/.p10k.zsh` |
| `.gitconfig` | `~/.gitconfig` |

Nizam-OS manages its own symlinks via `~/.nizam-os/scripts/setup/install-symlinks.sh`.

---

## Services

**`metrics-security.timer`** + **`metrics-security.service`** — runs `metrics-security.sh` every minute. Collects SSH failures, fail2ban bans, and UFW block counts into a Prometheus-compatible file for node-exporter.

---

## Grafana

`grafana/system-dashboard.json` — system resources and security metrics dashboard. See `docs/dashboard.md` for how to read it.

---

## Fresh install

See `docs/restore.md` for the full step-by-step.
