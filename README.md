# nizam-dotfiles

The machine layer for nizam-vps. It configures the shell, secures remote access, and pipes system health data into a Grafana dashboard — before any application runs.

## What it does

- Sets up zsh with a consistent shell environment, prompt, and aliases
- Hardens SSH, configures a firewall, and enables automatic security updates from first boot
- Collects CPU, memory, disk, and security metrics on short intervals and feeds them to Prometheus
- Visualises everything in a live Grafana dashboard
- Rotates logs and keeps the baseline clean

## Repo layout

```bash
nizam-dotfiles/
├── shell/      zsh config, prompt theme, aliases
├── scripts/    metric collectors, shared logger, install script
├── systemd/    service and timer units for each metric collector
├── config/     logrotate config
├── grafana/    system dashboard JSON
├── docs/       setup, dashboard, alerts, and debugging guides
└── logs/       runtime script output (gitignored)
```

## Symlinks

`scripts/install.sh` wires everything into place. Re-run after pulling changes.

| Source | Target |
|---|---|
| `shell/.zshrc` | `~/.zshrc` |
| `shell/.p10k.zsh` | `~/.p10k.zsh` |
| `.gitconfig` | `~/.gitconfig` |
| `systemd/metrics-security.service` | `/etc/systemd/system/` |
| `systemd/metrics-security.timer` | `/etc/systemd/system/` |
| `systemd/metrics-processes.service` | `/etc/systemd/system/` |
| `systemd/metrics-processes.timer` | `/etc/systemd/system/` |
| `systemd/metrics-disk.service` | `/etc/systemd/system/` |
| `systemd/metrics-disk.timer` | `/etc/systemd/system/` |

`config/logrotate.dotfiles` is copied (not symlinked) to `/etc/logrotate.d/dotfiles` — logrotate rejects config files not owned by root.

## Boundary

Would this file belong on this server even without Nizam-OS running? Yes → here. No → nizam-os.

## Setup

See [`docs/startup-guide.md`](docs/startup-guide.md) to go from a fresh VPS to a ready machine.
Dashboard: [`docs/dashboard.md`](docs/dashboard.md) · Alerts: [`docs/alerts.md`](docs/alerts.md) · Debugging: [`docs/debugging.md`](docs/debugging.md)

---

## How it fits

| Repo | Handles |
|---|---|
| nizam-dotfiles | The machine — shell, security, monitoring (this repo) |
| nizam-os | The software — agents, services, databases |
| nizam-vault | The knowledge — notes, references, decisions |
