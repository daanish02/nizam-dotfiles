#!/usr/bin/env bash
# Collect active SSH session count and per-session duration for Grafana.
# Runs every 30 seconds via metrics-sessions.timer.
set -euo pipefail

SCRIPT_NAME="metrics-sessions"
# shellcheck source=../shared/_log.sh
source "$(dirname "$0")/../shared/_log.sh"

OUT="/var/lib/prometheus/node-exporter/sessions.prom"
TMP=$(mktemp)
now=$(date +%s)

session_count=0
session_lines=()

while IFS= read -r line; do
    user=$(awk '{print $1}' <<< "$line")
    pts=$(awk '{print $2}' <<< "$line")
    login_date=$(awk '{print $3}' <<< "$line")
    login_time=$(awk '{print $4}' <<< "$line")
    from=$(awk '{gsub(/[()]/,"",$5); print $5}' <<< "$line")

    login_epoch=$(date -d "$login_date $login_time" +%s 2>/dev/null) || continue
    duration=$(( now - login_epoch ))
    pts_label="${pts//\//_}"

    session_lines+=("nizam_ssh_session_seconds{user=\"${user}\",pts=\"${pts_label}\",from=\"${from}\"} ${duration}")
    session_count=$(( session_count + 1 ))
done < <(who 2>/dev/null | grep ' pts/')

{
echo "# HELP nizam_ssh_active_sessions Number of active SSH sessions"
echo "# TYPE nizam_ssh_active_sessions gauge"
echo "nizam_ssh_active_sessions ${session_count}"

if [[ ${#session_lines[@]} -gt 0 ]]; then
    echo ""
    echo "# HELP nizam_ssh_session_seconds Duration of active SSH session in seconds"
    echo "# TYPE nizam_ssh_session_seconds gauge"
    for s in "${session_lines[@]}"; do
        echo "$s"
    done
fi
} > "$TMP"

mv "$TMP" "$OUT"
chmod 644 "$OUT"
if [[ $session_count -gt 1 ]]; then
    log_warn "wrote sessions.prom (sessions=${session_count}) — multiple simultaneous SSH sessions"
else
    log_info "wrote sessions.prom (sessions=${session_count})"
fi