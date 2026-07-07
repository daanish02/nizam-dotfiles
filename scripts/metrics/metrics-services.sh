#!/usr/bin/env bash
# Check active state of dotfiles-layer services for Grafana availability tracking.
# Runs every minute via metrics-services.timer.
set -euo pipefail

SCRIPT_NAME="metrics-services"
# shellcheck source=../shared/_log.sh
source "$(dirname "$0")/../shared/_log.sh"

OUT="/var/lib/prometheus/node-exporter/services.prom"
TMP=$(mktemp)

SERVICES=(
    prometheus
    grafana-server
    fail2ban
    prometheus-node-exporter
    loki
    promtail
    metrics-security.timer
    metrics-processes.timer
    metrics-disk.timer
    metrics-sessions.timer
    metrics-services.timer
)

{
echo "# HELP nizam_service_up Service active state (1=active, 0=inactive/failed)"
echo "# TYPE nizam_service_up gauge"

up_count=0
for svc in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        state=1
        up_count=$(( up_count + 1 ))
    else
        state=0
    fi
    label="${svc//./_}"
    echo "nizam_service_up{service=\"${label}\"} ${state}"
done
} > "$TMP"

mv "$TMP" "$OUT"
chmod 644 "$OUT"
if [[ $up_count -lt ${#SERVICES[@]} ]]; then
    log_error "wrote services.prom (up=${up_count}/${#SERVICES[@]}) — $(( ${#SERVICES[@]} - up_count )) service(s) down"
else
    log_info "wrote services.prom (up=${up_count}/${#SERVICES[@]})"
fi