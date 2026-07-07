#!/usr/bin/env bash
# Configure Grafana alert rules and Discord contact points.
# Run once after monitoring stack is up, or re-run to update.
#
# Required env vars:
#   DISCORD_WEBHOOK_WARNING   — Discord webhook URL for warning alerts
#   DISCORD_WEBHOOK_CRITICAL  — Discord webhook URL for critical alerts
#
# Optional:
#   GRAFANA_URL   (default: http://localhost:3000)
#   GRAFANA_AUTH  (default: admin:admin)
set -euo pipefail

SCRIPT_NAME="setup-alerts"
source "$(dirname "$0")/../shared/_log.sh"

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_AUTH="${GRAFANA_AUTH:-admin:admin}"

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_FILE="$DOTFILES/secrets/nizam-dotfiles.env"

if [[ ! -f "$SECRETS_FILE" ]]; then
    log_error "secrets file not found: $SECRETS_FILE"
    log_error "copy secrets/nizam-dotfiles.env.example → secrets/nizam-dotfiles.env and fill in values"
    exit 1
fi

# shellcheck source=../secrets/nizam-dotfiles.env
set -a; source "$SECRETS_FILE"; set +a

: "${DISCORD_WEBHOOK_WARNING:?DISCORD_WEBHOOK_WARNING missing from $SECRETS_FILE}"
: "${DISCORD_WEBHOOK_CRITICAL:?DISCORD_WEBHOOK_CRITICAL missing from $SECRETS_FILE}"

gapi() {
    local method="$1" path="$2" data="${3:-}"
    if [[ -n "$data" ]]; then
        curl -sf -u "$GRAFANA_AUTH" -X "$method" "$GRAFANA_URL$path" \
            -H 'Content-Type: application/json' -d "$data"
    else
        curl -sf -u "$GRAFANA_AUTH" -X "$method" "$GRAFANA_URL$path"
    fi
}

# Contact points

log_info "creating contact points"

gapi PUT /api/v1/provisioning/contact-points/nizam-warn \
    "$(jq -n --arg url "$DISCORD_WEBHOOK_WARNING" '{
        name: "nizam-warn",
        type: "discord",
        settings: { url: $url, message: "{{ template \"discord.default.message\" . }}" }
    }')" > /dev/null 2>&1 || \
gapi POST /api/v1/provisioning/contact-points \
    "$(jq -n --arg url "$DISCORD_WEBHOOK_WARNING" '{
        name: "nizam-warn",
        type: "discord",
        settings: { url: $url, message: "{{ template \"discord.default.message\" . }}" }
    }')" > /dev/null

gapi PUT /api/v1/provisioning/contact-points/nizam-crit \
    "$(jq -n --arg url "$DISCORD_WEBHOOK_CRITICAL" '{
        name: "nizam-crit",
        type: "discord",
        settings: { url: $url, message: "{{ template \"discord.default.message\" . }}" }
    }')" > /dev/null 2>&1 || \
gapi POST /api/v1/provisioning/contact-points \
    "$(jq -n --arg url "$DISCORD_WEBHOOK_CRITICAL" '{
        name: "nizam-crit",
        type: "discord",
        settings: { url: $url, message: "{{ template \"discord.default.message\" . }}" }
    }')" > /dev/null

log_info "contact points ok"

# Notification policy

log_info "setting notification policy"

gapi PUT /api/v1/provisioning/policies '{
  "receiver": "nizam-crit",
  "group_by": ["alertname", "severity"],
  "group_wait": "10s",
  "group_interval": "1m",
  "repeat_interval": "1h",
  "routes": [
    {
      "receiver": "nizam-warn",
      "matchers": ["severity = warning"],
      "group_wait": "30s",
      "repeat_interval": "4h"
    },
    {
      "receiver": "nizam-crit",
      "matchers": ["severity = critical"],
      "group_wait": "10s",
      "repeat_interval": "1h"
    }
  ]
}' > /dev/null

log_info "notification policy ok"

# Alert folder

FOLDER_UID=$(gapi GET /api/folders | python3 -c "
import json,sys
folders = json.load(sys.stdin)
match = next((f for f in folders if f['title'] == 'nizam-alerts'), None)
print(match['uid'] if match else '')
")

if [[ -z "$FOLDER_UID" ]]; then
    FOLDER_UID=$(gapi POST /api/folders '{"uid":"nizam-alerts","title":"nizam-alerts"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['uid'])")
    log_info "created folder nizam-alerts (uid=$FOLDER_UID)"
else
    log_info "folder nizam-alerts exists (uid=$FOLDER_UID)"
fi

# Helper: build a classic-condition alert rule 

make_rule() {
    local title="$1" expr="$2" threshold_type="$3" threshold="$4"
    local severity="$5" for_duration="$6" summary="$7" description="$8"
    jq -n \
        --arg title "$title" \
        --arg expr "$expr" \
        --arg ttype "$threshold_type" \
        --argjson tval "$threshold" \
        --arg sev "$severity" \
        --arg ford "$for_duration" \
        --arg summary "$summary" \
        --arg desc "$description" \
        --arg folder "$FOLDER_UID" \
        '{
            title: $title,
            condition: "B",
            for: $ford,
            folderUID: $folder,
            ruleGroup: "nizam-system",
            noDataState: "NoData",
            execErrState: "Error",
            labels: { severity: $sev },
            annotations: { summary: $summary, description: $desc },
            data: [
                {
                    refId: "A",
                    queryType: "",
                    relativeTimeRange: { from: 600, to: 0 },
                    datasourceUid: "nizam-prometheus",
                    model: { expr: $expr, instant: true, refId: "A" }
                },
                {
                    refId: "B",
                    queryType: "",
                    relativeTimeRange: { from: 0, to: 0 },
                    datasourceUid: "__expr__",
                    model: {
                        type: "classic_conditions",
                        refId: "B",
                        datasource: { type: "__expr__", uid: "__expr__" },
                        conditions: [{
                            evaluator: { type: $ttype, params: [$tval] },
                            operator: { type: "and" },
                            query: { params: ["A"] },
                            reducer: { type: "last" },
                            type: "query"
                        }]
                    }
                }
            ]
        }'
}

push_rule() {
    local rule="$1"
    local title; title=$(echo "$rule" | python3 -c "import json,sys; print(json.load(sys.stdin)['title'])")
    gapi POST /api/v1/provisioning/alert-rules "$rule" > /dev/null
    log_info "rule created: $title"
}

# Delete existing rules in group so re-runs are idempotent
existing=$(gapi GET /api/v1/provisioning/alert-rules 2>/dev/null | python3 -c "
import json,sys
rules = json.load(sys.stdin)
for r in rules:
    if r.get('ruleGroup') == 'nizam-system':
        print(r['uid'])
" 2>/dev/null || true)
for uid in $existing; do
    gapi DELETE "/api/v1/provisioning/alert-rules/$uid" > /dev/null
done
[[ -n "$existing" ]] && log_info "cleared existing nizam-system rules"

# CPU

CPU_EXPR='100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'

push_rule "$(make_rule \
    "CPU High Warning" "$CPU_EXPR" gt 70 \
    warning "5m" "CPU above 70%" "CPU usage is above 70%")"

push_rule "$(make_rule \
    "CPU High Critical" "$CPU_EXPR" gt 90 \
    critical "5m" "CPU above 90%" "CPU usage is above 90%")"

# Memory 

MEM_EXPR='(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100'

push_rule "$(make_rule \
    "Memory High Warning" "$MEM_EXPR" gt 75 \
    warning "5m" "Memory above 75%" "Memory usage is above 75%")"

push_rule "$(make_rule \
    "Memory High Critical" "$MEM_EXPR" gt 90 \
    critical "5m" "Memory above 90%" "Memory usage is above 90%")"

# Disk

DISK_EXPR='(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100'

push_rule "$(make_rule \
    "Disk Full Warning" "$DISK_EXPR" gt 70 \
    warning "1m" "Disk above 70%" "Root partition usage is above 70%")"

push_rule "$(make_rule \
    "Disk Full Critical" "$DISK_EXPR" gt 90 \
    critical "1m" "Disk above 90%" "Root partition usage is above 90%")"

# Service down

push_rule "$(make_rule \
    "Service Down" "min(nizam_service_up)" eq 0 \
    critical "2m" "Service down" "One or more tracked services is inactive")"

# SSH sessions

push_rule "$(make_rule \
    "SSH Session Count" "nizam_ssh_active_sessions" gt 1 \
    critical "30s" "Multiple SSH sessions" "More than one simultaneous SSH session detected")"

log_info "setup complete — 8 rules active"