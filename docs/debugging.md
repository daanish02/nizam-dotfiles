# Debugging — nizam-dotfiles

Quick reference for the machine baseline layer (shell, security, monitoring).

---

## Security metrics

Runs every minute as root. Writes `/var/lib/prometheus/node-exporter/security.prom`.

```bash
sudo systemctl status metrics-security.timer --no-pager
sudo journalctl -u metrics-security.service -n 10 --no-pager
```

Healthy journal line:
```
metrics-security: wrote security.prom (ssh_failed=42, ssh_invalid=18, f2b_bans=7, f2b_current=1, ufw_blocked=9341)
```

```bash
# Trigger manually and verify output
sudo systemctl start metrics-security.service \
  && cat /var/lib/prometheus/node-exporter/security.prom

# Confirm Prometheus is scraping it
curl -s http://localhost:9100/metrics | grep nizam_ssh
```

---

## Process metrics

Runs every 30 seconds as root. Writes `/var/lib/prometheus/node-exporter/processes.prom`.

```bash
sudo systemctl status metrics-processes.timer --no-pager
sudo journalctl -u metrics-processes.service -n 10 --no-pager
```

Healthy journal line:
```
metrics-processes: wrote processes.prom
```

```bash
# Trigger manually and verify output
sudo systemctl start metrics-processes.service \
  && cat /var/lib/prometheus/node-exporter/processes.prom

# Confirm Prometheus is scraping it
curl -s http://localhost:9100/metrics | grep nizam_process
```

> If `du` or `ps` appear at 100% CPU in the Grafana panel, the EXCLUDE pattern in `scripts/metrics-processes.sh` is not filtering them. Check that both are present: `/\/(ps|awk|grep|sh|bash|du)$|^(ps|awk|grep|du)$`.

---

## Disk metrics

Runs every 5 minutes as root. Writes `/var/lib/prometheus/node-exporter/disk-dirs.prom`.

```bash
sudo systemctl status metrics-disk.timer --no-pager
sudo journalctl -u metrics-disk.service -n 10 --no-pager
```

Healthy journal line:
```
metrics-disk: wrote disk-dirs.prom
```

```bash
# Trigger manually and verify output
sudo systemctl start metrics-disk.service \
  && cat /var/lib/prometheus/node-exporter/disk-dirs.prom

# Confirm Prometheus is scraping it
curl -s http://localhost:9100/metrics | grep nizam_dir
```

---

## Script logs

All metric scripts write to:
```
~/.nizam-dotfiles/logs/scripts.log
```

Format: `TIMESTAMP [LEVEL] [script-name] message`

```bash
tail -f ~/.nizam-dotfiles/logs/scripts.log
grep ERROR ~/.nizam-dotfiles/logs/scripts.log
```

Rotated daily, 14 days kept. Config: `config/logrotate.dotfiles` (copied to `/etc/logrotate.d/dotfiles` by `scripts/install.sh`).

---

## Node exporter

```bash
sudo systemctl status prometheus-node-exporter --no-pager
curl -s http://localhost:9100/metrics | grep nizam_
```

---

## Symlinks

```bash
ls -la \
  /etc/systemd/system/metrics-security.service \
  /etc/systemd/system/metrics-security.timer \
  /etc/systemd/system/metrics-processes.service \
  /etc/systemd/system/metrics-processes.timer \
  /etc/systemd/system/metrics-disk.service \
  /etc/systemd/system/metrics-disk.timer
# all should show -> /home/vazir/.nizam-dotfiles/systemd/...
```

Re-run `sudo bash scripts/install.sh` if any symlinks are missing or stale.

---

## Common fixes

| Symptom | Fix |
|---|---|
| `.prom` file not updating | `sudo systemctl start metrics-<name>.service && sudo journalctl -u metrics-<name>.service -n 5 --no-pager` |
| Grafana panel shows >5 processes | Stale Prometheus series — wait 5 min for lookback window to expire |
| `du` or `ps` at 100% in CPU panel | Check EXCLUDE pattern in `metrics-processes.sh` includes `du`, `ps`, `awk`, `grep`, `sh`, `bash` |
| Symlinks missing after git pull | `sudo bash scripts/install.sh` |
| logrotate errors on dotfiles config | `sudo logrotate -d /etc/logrotate.d/dotfiles` — check owner is root (`ls -la /etc/logrotate.d/dotfiles`) |
| Prometheus not showing nizam metrics | Check node-exporter scrapes textfile dir: `curl -s http://localhost:9100/metrics \| grep nizam_` |
