# Dashboard Guide — Nizam System

## Stat tiles (top row)
Six tiles giving a live snapshot. Color = health: green is fine, orange is a warning, red needs attention.

| Tile | What it means |
|---|---|
| Uptime | Time since last boot. If this resets unexpectedly, the server rebooted. |
| CPU Usage | % of CPU in use. Above 90% = red. Normal idle should be under 20%. |
| RAM Usage | % of RAM used. Above 90% = red. Consistently there means you're close to swapping. |
| Disk Usage | % of root partition used. A full disk can crash services silently — watch this one. |
| Load Avg (1m) | Processes waiting to run. Above 2.0 on a 2-core VPS means the CPU is oversubscribed. |
| TCP Connections | Active connections right now. A sudden spike = traffic surge or a connection leak. |

## CPU & Memory
Time series over the last 6 hours.

- **CPU** — one line per core. One core pinned at 100% while the other is idle = single-threaded bottleneck.
- **Memory** — three lines: red (used), yellow (cache/buffer — reclaimed freely), green (available). Watch for red creeping up and green shrinking over time — that's a memory leak.

## Network & Disk I/O
Mirrored layout: positive = in/read, negative = out/write.

- **Network** — bytes/s in and out. Unexpected sustained inbound = unwanted traffic.
- **Disk** — bytes/s read and written to disk. Sustained writes you can't explain = runaway logging or a DB process.

## Load Average + Disk Space
- **Load avg** — 1m (yellow), 5m (orange), 15m (red). Read them together: all three rising = sustained pressure. 1m spike with 5m/15m flat = short burst, probably a cron job.
- **Disk space** — bar per partition, green → red as it fills.

## Security tiles
All-time counters except Currently Banned which is live.

| Tile | What it means |
|---|---|
| SSH Failed Logins | Total failed password attempts in auth.log. High total is normal on a public VPS. |
| SSH Invalid Users | Attempts using usernames that don't exist. Same — expected noise. |
| Currently Banned | IPs fail2ban has blocked right now. Goes up and down as bans expire. |
| UFW Blocked Packets | Total packets the firewall has dropped. Climbs constantly — that's normal. |

## Security Events timeline
Shows **1-hour increase** in each metric — turns flat counters into activity spikes. This is the useful one for spotting attacks. A coordinated spike across SSH failures + UFW blocks at the same time = active scan or brute-force attempt. fail2ban handles it automatically but this is how you know it happened.
