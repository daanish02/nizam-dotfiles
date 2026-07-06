# System dashboard

Live system health via Prometheus + Loki → Grafana. Covers the metric pipeline, dashboard panels, alert rules, and operational reference.

---

## Metric pipeline

```mermaid
graph LR
    A[metrics-security.sh] --> P[textfile collector]
    B[metrics-processes.sh] --> P
    C[metrics-disk.sh] --> P
    D[metrics-sessions.sh] --> P
    E[metrics-services.sh] --> P
    P --> N[node-exporter :9100]
    N --> PR[Prometheus :9090]
    PR --> G[Grafana :3000]
    L[logs/*.log] --> PT[Promtail :9080]
    PT --> LK[Loki :3100]
    LK --> G
```

| Script | Output file | Fires at | Reason |
|---|---|---|---|
| `metrics-security.sh` | `security.prom` | `:00` each minute | Auth log counters are slow-moving |
| `metrics-processes.sh` | `processes.prom` | `:10` and `:40` each minute | CPU and RSS change at subsecond scale |
| `metrics-sessions.sh` | `sessions.prom` | `:15` and `:45` each minute | SSH sessions need near-realtime visibility |
| `metrics-disk.sh` | `disk-dirs.prom` | `:20` of every 5th minute | `du` walks entire directory trees — I/O heavy |
| `metrics-services.sh` | `services.prom` | `:30` each minute | Service state is polled, not event-driven |

Timers are staggered by second offset so no two collectors fire simultaneously.

All five write Prometheus textfiles to `/var/lib/prometheus/node-exporter/`. node-exporter exposes them; Prometheus scrapes node-exporter. Script logs are tailed by Promtail and shipped to Loki.

---

## Dashboard import

Grafana, Prometheus, Loki, and Promtail are installed in `docs/001-setup-guide.md`. Once running:

1. Connections → Data Sources → Add → **Prometheus** — URL: `http://localhost:9090`, UID: `nizam-prometheus` → Save & Test
2. Connections → Data Sources → Add → **Loki** — URL: `http://localhost:3100`, UID: `nizam-loki` → Save & Test
3. Dashboards → New → Import → upload `grafana/system-dashboard.json`

---

## Dashboard panels

### Stat tiles (top row)

Seven tiles giving a live snapshot. Color thresholds: green (normal), orange (warning), red (critical).

| Tile | Metric | Thresholds |
|---|---|---|
| Uptime | Time since last boot | — |
| CPU Usage | % CPU in use | Orange >70%, red >90% |
| RAM Usage | % RAM used | Orange >75%, red >90% |
| Disk Usage | % of root partition used | Orange >70%, red >90% |
| Load Avg (1m) | Processes waiting to run | Red >2.0 on a 2-core VPS |
| TCP Connections | Active TCP connections | — |
| Services | % of tracked services currently active | Yellow <100%, red <80% |

An unexpected uptime reset means the server rebooted. A full root partition silently crashes services that attempt writes.

### CPU & memory

Time series over the last 6 hours.

- **CPU** — one line per core. One core pinned at 100% with others idle indicates a single-threaded bottleneck.
- **Memory** — three lines: used (red), cache/buffer (yellow — freely reclaimed by the kernel), available (green). Available shrinking continuously without recovery indicates a memory leak.

### Network & disk I/O

Mirrored layout: positive = inbound/read, negative = outbound/write.

- **Network** — bytes/s in and out. Sustained unexpected inbound traffic warrants investigation.
- **Disk** — bytes/s read and written. Sustained unexplained writes indicate runaway logging or an uncontrolled database process.

### Load average + disk usage by directory

- **Load avg** — 1m (yellow), 5m (orange), 15m (red). All three rising together indicates sustained pressure. A 1m spike with 5m/15m flat is a short burst, typically a cron job.
- **Disk usage by directory** — top 5 directories stacked as a single bar against the total disk. Each segment is a directory path; hover for exact size. Updated every 5 min. `/var/lib` = database data, `/var/log` = logs, `/var/cache` = apt cache.

### Top processes

Two bar gauges showing top 5 consumers, updated every 30 seconds.

- **Top CPU** — `%CPU` per process from `ps aux`. Process name includes PID (`grafana[892]`) so multiple instances of the same binary appear separately.
- **Top memory** — RSS per process proportional to total server RAM. Python and Node processes show their parent directory (`litellm/python`, `hermes-agent/python`) to distinguish multiple instances of the same binary.

Both panels use instant queries to avoid range queries returning >5 series when different processes enter the top 5 at different timestamps. `du`, `ps`, `awk`, `grep`, `sh`, and `bash` are excluded — they appear briefly at 100% CPU during collection and carry no diagnostic signal.

### Security tiles

All-time counters except Currently Banned and Active SSH Sessions, which reflect live state. The Availability tile also lives in this row.

| Tile | Metric |
|---|---|
| SSH Failed Logins | Total failed password attempts in `auth.log` |
| SSH Invalid Users | Attempts using non-existent usernames |
| Currently Banned | IPs currently blocked by fail2ban |
| UFW Blocked Packets | Total packets dropped by the firewall |
| Active SSH Sessions | Count of currently active SSH sessions; alert fires at >1 |
| Availability | % of tracked services active (`sum(nizam_service_up) / count(nizam_service_up) * 100`) |

High totals on a public-facing VPS are expected noise. Currently Banned rises and falls as bans expire.

### SSH session history

Table showing sessions from the last 24 hours: `max_over_time(nizam_ssh_session_seconds[24h])` per `{user, pts, from}`. Rows persist after a session ends — the Duration column shows the total session length at disconnect. Columns: User, Source (from IP), Terminal (pts), Duration.

### Service up/down

State timeline of `nizam_service_up` per service — gaps are immediately visible. Services tracked: `prometheus`, `grafana-server`, `fail2ban`, `prometheus-node-exporter`, `loki`, `promtail`, and all five metric timers.

### Security events timeline

Shows the **1-hour increase** in each security counter — converts flat all-time totals into activity spikes. A coordinated spike across SSH failures and UFW blocks indicates an active scan or brute-force attempt. fail2ban responds automatically; this panel shows that it happened.

### Logs (Loki)

- **Log volume by level** — stacked bars of `sum by (level) (count_over_time({job="nizam-dotfiles"} | json [$__interval]))`. Shows INFO/WARN/ERROR distribution over time.
- **Log stream** — `{job="nizam-dotfiles"}`. Live tail of all script output, pretty-printed JSON with colored level badge. Filter by `service` label to isolate a specific collector.

---

## Datasources

| Datasource | URL | UID |
|---|---|---|
| Prometheus | `http://localhost:9090` | `nizam-prometheus` |
| Loki | `http://localhost:3100` | `nizam-loki` |

---

## Alerts

Unified alerting via Grafana → Discord. Two severity levels, two contact points.

### Contact points

| Name | Env var | Routes |
|---|---|---|
| `nizam-warn` | `DISCORD_WEBHOOK_WARNING` | `severity=warning` |
| `nizam-crit` | `DISCORD_WEBHOOK_CRITICAL` | `severity=critical` |

Webhooks are read from `secrets/nizam-dotfiles.env` at run time. To configure:

```bash
cp ~/nizam-dotfiles/secrets/nizam-dotfiles.env.example ~/nizam-dotfiles/secrets/nizam-dotfiles.env
# fill in webhook URLs, then:
bash ~/nizam-dotfiles/scripts/setup-alerts.sh
```

The script is idempotent — safe to re-run. It deletes and recreates all rules in `nizam-system` group on each run.

### Routing

| Severity | Group wait | Repeat interval |
|---|---|---|
| warning | 30s | 4h |
| critical | 10s | 1h |

Critical fires immediately and repeats hourly until resolved. Warning batches within the group window.

### Alert rules

All rules live in folder `nizam-alerts`, group `nizam-system`. Each threshold is a separate rule with a `severity` label — routing is driven entirely by that label.

| Rule | Warning | Critical | For |
|---|---|---|---|
| CPU High | >70% | >90% | 5m |
| RAM High | >75% | >90% | 5m |
| Disk Full | >70% | >90% | 1m |
| Service Down | — | any service inactive | 2m |
| SSH Session Count | — | >1 simultaneous | 30s |

### Managing alerts

**View rules:** Grafana → Alerting → Alert rules → folder `nizam-alerts`

**Silence an alert:** Grafana → Alerting → Silences → Add silence — set label matcher and duration

**Test a contact point:** Grafana → Alerting → Contact points → `nizam-warn` or `nizam-crit` → Test

**Update a threshold:** edit `scripts/setup-alerts.sh`, re-run the script

---

## Operational reference

### Check collector status

```bash
sudo systemctl status metrics-security.timer metrics-processes.timer metrics-disk.timer metrics-sessions.timer metrics-services.timer --no-pager
```

Trigger manually and inspect output:

```bash
sudo systemctl start metrics-security.service && cat /var/lib/prometheus/node-exporter/security.prom
sudo systemctl start metrics-processes.service && cat /var/lib/prometheus/node-exporter/processes.prom
sudo systemctl start metrics-disk.service && cat /var/lib/prometheus/node-exporter/disk-dirs.prom
sudo systemctl start metrics-sessions.service && cat /var/lib/prometheus/node-exporter/sessions.prom
sudo systemctl start metrics-services.service && cat /var/lib/prometheus/node-exporter/services.prom
```

Confirm Prometheus is scraping:

```bash
curl -s http://localhost:9100/metrics | grep nizam_
```

Recent logs:

```bash
sudo journalctl -u metrics-security.service -n 10 --no-pager
sudo journalctl -u metrics-processes.service -n 10 --no-pager
sudo journalctl -u metrics-disk.service -n 10 --no-pager
```

### Script logs

All metric scripts write structured JSON to `~/nizam-dotfiles/logs/scripts.log`.

Format: `{"ts":"...","level":"INFO","service":"script-name","msg":"..."}`

```bash
tail -f ~/nizam-dotfiles/logs/scripts.log
grep '"level":"ERROR"' ~/nizam-dotfiles/logs/scripts.log
```

Rotated daily, 14 days retained. Config: `config/logrotate.nizam-dotfiles`.

### Symlinks

```bash
ls -la \
  /etc/systemd/system/metrics-security.service \
  /etc/systemd/system/metrics-security.timer \
  /etc/systemd/system/metrics-processes.service \
  /etc/systemd/system/metrics-processes.timer \
  /etc/systemd/system/metrics-disk.service \
  /etc/systemd/system/metrics-disk.timer \
  /etc/systemd/system/metrics-sessions.service \
  /etc/systemd/system/metrics-sessions.timer \
  /etc/systemd/system/metrics-services.service \
  /etc/systemd/system/metrics-services.timer
```

All entries must point to `/home/vazir/nizam-dotfiles/systemd/...`. Re-run `sudo bash scripts/install.sh` if any symlink is missing or stale.

### Common fixes

| Symptom | Fix |
|---|---|
| `.prom` file not updating | `sudo systemctl start metrics-<name>.service && sudo journalctl -u metrics-<name>.service -n 5 --no-pager` |
| Grafana panel shows >5 processes | Stale Prometheus series — wait 5 min for the lookback window to expire |
| `du` or `ps` at 100% in CPU panel | EXCLUDE pattern in `metrics-processes.sh` missing `du` or `ps` |
| Symlinks missing after git pull | `sudo bash scripts/install.sh` |
| logrotate errors | `sudo logrotate -d /etc/logrotate.d/nizam-dotfiles` — confirm owner is root |
| Prometheus not showing nizam metrics | `curl -s http://localhost:9100/metrics \| grep nizam_` |
