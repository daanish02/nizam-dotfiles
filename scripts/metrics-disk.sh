#!/usr/bin/env bash
# Collect directory sizes for the Grafana disk usage panel.
# Runs every 5 minutes via metrics-disk.timer — du is slow on large trees.
set -euo pipefail

SCRIPT_NAME="metrics-disk"
# shellcheck source=_log.sh
source "$(dirname "$0")/_log.sh"

OUT="/var/lib/prometheus/node-exporter/disk-dirs.prom"
TMP=$(mktemp)

{
echo "# HELP nizam_dir_bytes Disk usage in bytes per directory"
echo "# TYPE nizam_dir_bytes gauge"
du -sb /var/log /var/lib /var/cache /home /root /opt /tmp /usr 2>/dev/null | \
    awk '{
        path=$2
        n=split(path, parts, "/"); dir=parts[n]
        gsub(/"/, "", dir)
        printf "nizam_dir_bytes{dir=\"%s\",path=\"%s\"} %s\n", dir, path, $1
    }'
} > "$TMP"

mv "$TMP" "$OUT"
chmod 644 "$OUT"

log_info "wrote disk-dirs.prom"
