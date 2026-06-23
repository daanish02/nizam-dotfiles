#!/usr/bin/env bash
set -euo pipefail

TRACKED="$HOME/.nizam-dotfiles/inventory/tracked-services.txt"

[ -f "$TRACKED" ] || {
    echo "Missing tracked-services.txt"
    exit 1
}

grep -vE '^\s*#|^\s*$' "$TRACKED" | while read -r svc; do
    if systemctl status "$svc" >/dev/null 2>&1; then
        echo "$svc | system | $(systemctl is-active "$svc")"
    elif systemctl --user status "$svc" >/dev/null 2>&1; then
        echo "$svc | user | $(systemctl --user is-active "$svc")"
    else
        echo "$svc | - | not-found"
    fi
done | sort
