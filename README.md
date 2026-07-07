# nizam-dotfiles

The machine layer for **nizam-vps**. It configures the shell, secures remote access, pipes system health data into Grafana, and ships logs to Loki — before any application runs.

## What it does

- Sets up zsh with a consistent shell environment, prompt, and aliases
- Hardens SSH, configures a firewall, and enables automatic security updates from first boot
- Collects CPU, memory, disk, security, SSH session, and service availability metrics on short intervals via Prometheus textfile collectors
- Ships structured JSON logs from all scripts to Loki via Promtail
- Visualises everything in a live Grafana dashboard with Discord alerting
- Rotates logs and keeps the baseline clean

## Repo layout

```
nizam-dotfiles/
├── shell/      zsh config, prompt theme, aliases
├── scripts/    metric collectors, shared logger, setup scripts
├── systemd/    service and timer units for each metric collector
├── config/     logrotate, loki, promtail configs
├── grafana/    system dashboard JSON
├── secrets/    discord webhook URLs
├── docs/       vision, setup guide, and dashboard reference
└── logs/       runtime script output
```

## Symlinks

`scripts/install.sh` wires everything into place. Re-run after pulling changes.

| Source | Target |
|--------|--------|
| `shell/.zshrc` | `~/.zshrc` |
| `shell/.p10k.zsh` | `~/.p10k.zsh` |
| `shell/.zsh-aliases` | `~/.zsh-aliases` |
| `config/.gitconfig` | `~/.gitconfig` |
| `systemd/metrics-security.service` | `/etc/systemd/system/` |
| `systemd/metrics-security.timer` | `/etc/systemd/system/` |
| `systemd/metrics-processes.service` | `/etc/systemd/system/` |
| `systemd/metrics-processes.timer` | `/etc/systemd/system/` |
| `systemd/metrics-disk.service` | `/etc/systemd/system/` |
| `systemd/metrics-disk.timer` | `/etc/systemd/system/` |
| `systemd/metrics-sessions.service` | `/etc/systemd/system/` |
| `systemd/metrics-sessions.timer` | `/etc/systemd/system/` |
| `systemd/metrics-services.service` | `/etc/systemd/system/` |
| `systemd/metrics-services.timer` | `/etc/systemd/system/` |

`config/logrotate.nizam-dotfiles` is copied (not symlinked) to `/etc/logrotate.d/nizam-dotfiles` — logrotate rejects config files not owned by root.

`config/promtail.yaml` is copied to `/etc/promtail/config.yaml`. `install.sh` also writes a systemd override to run Promtail as root (required — `/home/vazir/` has 750 permissions).

## Alerts

Discord webhooks are read from `secrets/nizam-dotfiles.env`. To configure:

```bash
cp secrets/nizam-dotfiles.env.example secrets/nizam-dotfiles.env  # enter secrets
bash scripts/setup-alerts.sh
```

## Boundary

Would this file belong on this server even without **Nizam** running? Yes → here. No → nizam-os.

## Setup

See [MACHINE SETUP GUIDE](docs/001-machine-setup-guide.md) to go from a fresh VPS to a ready machine.  
Dashboard, alerts, and operational reference: [SYSTEM DASHBOARD](docs/001-system-dashboard.md)

---

## How it fits

| Repo | Handles |
|---|---|
| nizam-dotfiles | The machine — shell, security, monitoring (this repo) |
| nizam-os | The software — agents, services, databases |
| nizam-vault | The knowledge — notes, references, decisions |
