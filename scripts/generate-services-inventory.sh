#!/usr/bin/env bash
set -euo pipefail

TRACKED="$HOME/.nizam-dotfiles/inventory/tracked-services.txt"

[ -f "$TRACKED" ] || {
    echo "Missing tracked-services.txt"
    exit 1
}

service_status() {
    local svc="$1"

    if systemctl --user list-unit-files "$svc" --no-legend 2>/dev/null | grep -q "^$svc"; then
        printf '%s | user | %s\n' \
            "$svc" \
            "$(systemctl --user is-active "$svc" 2>/dev/null || echo inactive)"
    elif systemctl list-unit-files "$svc" --no-legend 2>/dev/null | grep -q "^$svc"; then
        printf '%s | system | %s\n' \
            "$svc" \
            "$(systemctl is-active "$svc" 2>/dev/null || echo inactive)"
    else
        printf '%s | - | not-found\n' "$svc"
    fi
}

grep -vE '^\s*#|^\s*$' "$TRACKED" |
while read -r svc; do
    service_status "$svc"
done | sort
