#!/usr/bin/env bash
set -euo pipefail

TRACKED="$HOME/.nizam-dotfiles/inventory/tracked-services.txt"

[ -f "$TRACKED" ] || {
    echo "Missing tracked-services.txt"
    exit 1
}

grep -vE '^\s*#|^\s*$' "$TRACKED" | while read -r svc; do
    STATE=$(systemctl is-enabled "$svc" 2>/dev/null || true)
    echo "${svc} | ${STATE}"
done | sort
