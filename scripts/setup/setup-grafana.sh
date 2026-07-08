#!/usr/bin/env bash
# Provision Grafana datasources and push the system dashboard. Idempotent.
# Reads GRAFANA_AUTH from secrets/nizam-dotfiles.env
# Override: GRAFANA_URL (default: http://localhost:3000), GRAFANA_AUTH (default: admin:admin)
set -euo pipefail

BLD='\033[1m'; CYN='\033[36m'; GRN='\033[32m'; YLW='\033[33m'; RED='\033[31m'; RST='\033[0m'
_step() { printf "\n${BLD}${CYN}==> %s${RST}\n" "$*"; }
_ok()   { printf "${GRN}  %s${RST}\n" "$*"; }
_note() { printf "${YLW}  %s${RST}\n" "$*"; }
_err()  { printf "${RED}  ERROR: %s${RST}\n" "$*" >&2; }

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_AUTH="${GRAFANA_AUTH:-admin:admin}"

DOTFILES="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS_FILE="$DOTFILES/secrets/nizam-dotfiles.env"

if [[ -f "$SECRETS_FILE" ]]; then
    set -a; source "$SECRETS_FILE"; set +a
fi

gapi() {
    local method="$1" path="$2" data="${3:-}"
    if [[ -n "$data" ]]; then
        curl -sf -u "$GRAFANA_AUTH" -X "$method" "$GRAFANA_URL$path" \
            -H 'Content-Type: application/json' -d "$data"
    else
        curl -sf -u "$GRAFANA_AUTH" -X "$method" "$GRAFANA_URL$path"
    fi
}

upsert_datasource() {
    local uid="$1" payload="$2" name="$3"
    local existing
    existing=$(curl -sf -u "$GRAFANA_AUTH" "$GRAFANA_URL/api/datasources/uid/$uid" 2>/dev/null || echo "")
    if [[ -n "$existing" ]]; then
        local id; id=$(echo "$existing" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
        local payload_with_id; payload_with_id=$(echo "$payload" | python3 -c "import sys,json; d=json.load(sys.stdin); d['id']=$id; print(json.dumps(d))")
        gapi PUT "/api/datasources/uid/$uid" "$payload_with_id" > /dev/null
        _ok "updated datasource: $name (uid=$uid)"
    else
        gapi POST /api/datasources "$payload" > /dev/null
        _ok "created datasource: $name (uid=$uid)"
    fi
}

# Datasources

_step "Provisioning datasources"

upsert_datasource "nizam-prometheus" "$(jq -n '{
    uid: "nizam-prometheus",
    name: "prometheus",
    type: "prometheus",
    access: "proxy",
    url: "http://localhost:9090",
    isDefault: true,
    jsonData: {}
}')" "Prometheus"

upsert_datasource "nizam-loki" "$(jq -n '{
    uid: "nizam-loki",
    name: "loki",
    type: "loki",
    access: "proxy",
    url: "http://localhost:3100",
    isDefault: false,
    jsonData: {}
}')" "Loki"

# Dashboard

_step "Pushing dashboard"

DASHBOARD_FILE="$DOTFILES/grafana/001-system-dashboard.json"
if [[ ! -f "$DASHBOARD_FILE" ]]; then
    _err "dashboard not found: $DASHBOARD_FILE"
    exit 1
fi

PAYLOAD=$(python3 -c "
import json
dash = json.load(open('$DASHBOARD_FILE'))
print(json.dumps({'dashboard': dash, 'overwrite': True, 'folderId': 0}))
")

VERSION=$(gapi POST /api/dashboards/db "$PAYLOAD" | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','?'))")
_ok "dashboard pushed: v${VERSION}"

_step "Done — open Grafana at ${GRAFANA_URL}"
