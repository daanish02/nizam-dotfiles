#!/usr/bin/env bash
# Collect top CPU and memory consuming processes for Grafana.
# Runs on a 30-second timer via metrics-processes.timer.
set -euo pipefail

SCRIPT_NAME="metrics-processes"
# shellcheck source=../shared/_log.sh
source "$(dirname "$0")/../shared/_log.sh"

OUT="/var/lib/prometheus/node-exporter/processes.prom"
TMP=$(mktemp)

# Exclude transient collection processes that appear at 100% CPU for the
# brief instant they run inside this script.
EXCLUDE='/\/(ps|awk|grep|sh|bash|du)$|^(ps|awk|grep|du)$'

# For generic binary names (python, node, java…) walk the path backwards to
# find the first meaningful parent directory — gives "litellm/python" instead
# of just "python" for all three hermes + litellm instances.
NAME_FN='
function procname(path,    n, parts, base, i) {
    n = split(path, parts, "/")
    base = parts[n]
    if (base ~ /^(python[0-9.]*|node|java|ruby|perl)$/) {
        for (i = n-1; i >= 1; i--) {
            if (parts[i] !~ /^(bin|venv|lib|usr|local|share|tools|sbin|\.)$/ && parts[i] != "") {
                base = parts[i] "/" base
                break
            }
        }
    }
    gsub(/"/, "", base)
    return base
}'

{
echo "# HELP nizam_process_cpu_percent CPU usage percent per process"
echo "# TYPE nizam_process_cpu_percent gauge"
ps aux --sort=-%cpu | awk -v excl="$EXCLUDE" "$NAME_FN"'
    NR>1 && $11 !~ excl && $11 != "" {
        name = procname($11) "[" $2 "]"
        printf "nizam_process_cpu_percent{process=\"%s\"} %s\n", name, $3
        if (++n >= 5) exit
    }'

echo ""
echo "# HELP nizam_process_mem_rss_bytes Resident memory in bytes per process"
echo "# TYPE nizam_process_mem_rss_bytes gauge"
ps aux --sort=-%mem | awk -v excl="$EXCLUDE" "$NAME_FN"'
    NR>1 && $11 !~ excl && $11 != "" {
        name = procname($11) "[" $2 "]"
        printf "nizam_process_mem_rss_bytes{process=\"%s\"} %s\n", name, $6*1024
        if (++n >= 5) exit
    }'
} > "$TMP"

cpu_count=$(grep -c '^nizam_process_cpu_percent' "$TMP" || true)
mem_count=$(grep -c '^nizam_process_mem_rss_bytes' "$TMP" || true)
mv "$TMP" "$OUT"
chmod 644 "$OUT"

log_info "wrote processes.prom (cpu_top=${cpu_count}, mem_top=${mem_count})"
