# Vision

**nizam-dotfiles** is the machine layer for **nizam-vps**. It secures, configures, and observes the server before any application runs.

Every service in **nizam-os** depends on a baseline that is already hardened, already observable, and already clean. **nizam-dotfiles** establishes that baseline — and nothing more. It has no awareness of agents, services, or AI infrastructure. Those are nizam-os's concern.

---

## Goals

**Reproducible setup.** A fresh Ubuntu 24.04 VPS reaches a ready, verified state by following one runbook section. No tribal knowledge, no manual steps outside it.

**Security from first boot.** SSH is hardened, a firewall is active, and brute-force mitigation is running before any application is installed. The public SSH port is eliminated once Tailscale is up — the server becomes invisible to internet scanners entirely.

**Observability before applications.** Metrics, logs, and alerts are live in Grafana before **nizam-os** installs. If something is wrong at the infrastructure layer, it is visible before application complexity is added.

**Consistent shell environment.** zsh, a tuned prompt, and a shared set of aliases are identical across local machine and server. No cognitive switching cost.

---

## Non-goals

- **Application configuration.** Database setup, service deployment, agent profiles — those are **nizam-os**.
- **Multi-machine or multi-user.** This is built for a single VPS operated by a single person. Nothing here is designed to scale horizontally or be shared across a team.
- **AI infrastructure.** LiteLLM, Hermes, MCP services — none of these are installed or configured here.
- **Secret management.** sops, age, and encrypted secrets are **nizam-os's** domain. **nizam-dotfiles** holds only the Discord webhook URLs needed for Grafana alerts — nothing beyond that.

---

## Success criteria

- A fresh VPS reaches a ready machine state via [RUNBOOK → Machine setup](RUNBOOK.md#machine-setup-fresh-vps) with no steps outside it.
- Public SSH port is closed. The server is reachable only over Tailscale.
- `systemctl is-active prometheus prometheus-node-exporter grafana-server loki promtail fail2ban metrics-security.timer metrics-processes.timer metrics-disk.timer metrics-sessions.timer metrics-services.timer` → all active.
- The system dashboard is live in Grafana showing real metric and log data before nizam-os installs.
- Grafana alerts are configured and routed to Discord via `scripts/setup/setup-alerts.sh`.

---

## How it fits

| Repo | Layer | Responsibility |
|---|---|---|
| nizam-dotfiles | Machine | Shell, security, monitoring |
| nizam-os | Software | Agents, services, databases |
| nizam-vault | Knowledge | Notes, references, decisions |

**nizam-os** assumes **nizam-dotfiles** is already in place. Setup order is: nizam-dotfiles → nizam-os.