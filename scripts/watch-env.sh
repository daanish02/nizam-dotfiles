#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$HOME/.nizam-dotfiles/secrets/nizam.env"

while inotifywait -e close_write "$ENV_FILE"; do
    echo "Encrypting..."
    "$HOME/.nizam-dotfiles/scripts/encrypt-env.sh"
done
