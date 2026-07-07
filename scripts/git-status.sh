#!/usr/bin/env bash
# Show git status across all three nizam repos (dotfiles, os, vault).
# Prints branch, dirty file count, ahead/behind remote, and last commit.

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

REPOS=(
    "$HOME/nizam-dotfiles|dotfiles"
    "$HOME/nizam-vault|vault"
    "$HOME/nizam-os|os"
    "$HOME/.hermes|.hermes-src"
)

echo

for entry in "${REPOS[@]}"; do
    IFS='|' read -r path name <<< "$entry"

    if [ ! -d "$path/.git" ]; then
        echo -e "${RED}⚠ $name${RESET} ${DIM}($path)${RESET} — not a git repo"
        echo
        continue
    fi

    cd "$path" || continue

    branch=$(git branch --show-current 2>/dev/null || echo "detached")

    behind=0
    ahead=0

    if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        read -r behind ahead <<< \
            "$(git rev-list --left-right --count origin/$branch...$branch)"
    fi

    dirty=$(git status -s 2>/dev/null | wc -l)

    last_commit=$(git log --oneline -1 --format="%h %s — %an" 2>/dev/null)
    last_date=$(git log -1 --format="%cr" 2>/dev/null)

    if [ "$dirty" -gt 0 ]; then
        status="${YELLOW}● ${dirty} uncommitted${RESET}"
    else
        status="${GREEN}✓ clean${RESET}"
    fi

    if [ "$ahead" -gt 0 ]; then
        status="$status, ${CYAN}↑${ahead} unpushed${RESET}"
    fi

    if [ "$behind" -gt 0 ]; then
        status="$status, ${RED}↓${behind} behind${RESET}"
    fi

    echo -e "${BOLD}━━━ $name ${DIM}($branch)${RESET} ${BOLD}━━━${RESET}"
    echo -e "  $status"
    echo -e "  ${DIM}Last: $last_commit ($last_date)${RESET}"
    echo
done
