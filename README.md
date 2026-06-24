# nizam-dotfiles

Machine config for nizam-vps — shell, git identity, security monitoring. Nothing more.

This is one of three repos:

| Repo | Purpose |
|---|---|
| `nizam-dotfiles` | The machine — shell, git, security monitoring (this repo) |
| `nizam-os` | The software — agents, services, configs, databases |
| `nizam-vault` | Obsidian notes |

## What it covers

- **Shell** — zsh, Powerlevel10k, aliases, key bindings
- **Git** — `.gitconfig` identity and preferences
- **Security monitoring** — `metrics-security` collects SSH failures, fail2ban bans, UFW block counts → node-exporter textfile → Grafana

## Repo layout

```bash
nizam-dotfile/
├── shell/      .zshrc, .p10k.zsh, aliases-zsh
├── systemd/    metrics-security.service + .timer — symlinked to /etc/systemd/system/
├── scripts/    metrics-security.sh, git-status.sh
├── grafana/    system-dashboard.json — machine + security metrics
├── docs/       startup guide, dashboard guide
└──.gitconfig   git identity and settings
```

## Symlinks

| Source | Target |
|---|---|
| `shell/.zshrc` | `~/.zshrc` |
| `shell/.p10k.zsh` | `~/.p10k.zsh` |
| `.gitconfig` | `~/.gitconfig` |
| `systemd/metrics-security.service` | `/etc/systemd/system/` |
| `systemd/metrics-security.timer` | `/etc/systemd/system/` |

## Boundary

**What belongs here:** Config that would exist on this server even without Nizam-OS — shell, git identity, security monitoring.

**What belongs in nizam-os:** Everything needed to run Nizam — agents, services, databases, secrets.

Test: *Would this file belong on a server where I'm not running Nizam-OS?* Yes → here. No → `nizam-os`.

## Setup

See [`docs/startup.md`](docs/startup.md).
