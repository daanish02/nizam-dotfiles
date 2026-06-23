#!/usr/bin/env bash
set -euo pipefail

export SOPS_AGE_KEY_FILE="$HOME/.nizam-dotfiles/secrets/nizam-age-key.txt"

PUBKEY=$(grep "public key" "$SOPS_AGE_KEY_FILE" | awk '{print $NF}')

sops \
  --encrypt \
  --input-type dotenv \
  --output-type dotenv \
  --age "$PUBKEY" \
  "$HOME/.nizam-dotfiles/secrets/nizam.env" \
  > "$HOME/.nizam-dotfiles/secrets/nizam.env.enc"
