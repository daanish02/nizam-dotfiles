#!/usr/bin/env bash
# Shared logger for user-space dotfiles scripts.
# Source this file, then call log_info / log_warn / log_error.
# Output goes to stdout AND ~/nizam-dotfiles/logs/scripts.log.
# Override log path: DOTFILES_LOG=/path/to/other.log source _log.sh

DOTFILES_LOG="${DOTFILES_LOG:-$HOME/nizam-dotfiles/logs/scripts.log}"
mkdir -p "$(dirname "$DOTFILES_LOG")"

_dotfiles_log() {
    local level="$1"; shift
    local msg="$*"
    local ts; ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local escaped_msg="${msg//\\/\\\\}"
    escaped_msg="${escaped_msg//\"/\\\"}"
    local line="{\"ts\":\"${ts}\",\"level\":\"${level}\",\"script\":\"${SCRIPT_NAME:-script}\",\"msg\":\"${escaped_msg}\"}"
    echo "$line"
    echo "$line" >> "$DOTFILES_LOG"
}
log_info()  { _dotfiles_log "INFO"  "$@"; }
log_warn()  { _dotfiles_log "WARNING"  "$@"; }
log_error() { _dotfiles_log "ERROR" "$@"; }
