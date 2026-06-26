# Debugging — nizam-dotfiles

Quick reference for the machine baseline layer (shell, security, monitoring).

---

## Security Metrics (metrics-security)

Runs every 5 min as root. Writes `/var/lib/prometheus/node-exporter/security.prom`.

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

## Script Logs

User-space dotfiles scripts (if any) write to:
```
~/.nizam-dotfiles/logs/scripts.log
```

Format: `TIMESTAMP [LEVEL] [script-name] message`

```bash
tail -f ~/.nizam-dotfiles/logs/scripts.log
grep ERROR ~/.nizam-dotfiles/logs/scripts.log
```

Rotated daily, 14 days kept. Config: `config/logrotate.dotfiles` (copied to `/etc/logrotate.d/dotfiles` by `scripts/install.sh`).

> `metrics-security.sh` runs as root — its output goes to the systemd journal, not `scripts.log`. Only user-space scripts that source `scripts/_log.sh` write to the log file.

---

## Symlinks

```bash
ls -la /etc/systemd/system/metrics-security.service \
       /etc/systemd/system/metrics-security.timer
# both should show -> /home/vazir/.nizam-dotfiles/systemd/...
```

Re-run `sudo bash scripts/install.sh` if symlinks are missing or stale.

---

## Node Exporter

```bash
sudo systemctl status prometheus-node-exporter --no-pager
curl -s http://localhost:9100/metrics | grep nizam_   # all nizam security metrics
```

---

## Common Fixes

| Symptom | Fix |
|---|---|
| `security.prom` not updating | `sudo systemctl start metrics-security.service && sudo journalctl -u metrics-security.service -n 5 --no-pager` |
| Symlinks missing after git pull | `sudo bash scripts/install.sh` |
| logrotate errors on dotfiles config | `sudo logrotate -d /etc/logrotate.d/dotfiles` — check owner is root (`ls -la /etc/logrotate.d/dotfiles`) |
| Prometheus not showing security metrics | Check node-exporter is scraping textfile dir: `curl -s http://localhost:9100/metrics \| grep nizam_ssh` |
