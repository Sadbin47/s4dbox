#!/usr/bin/env bash
# s4dbox - Logging library
# File and console logging with levels

S4D_LOG_DIR="/var/log/s4dbox"
S4D_LOG_FILE="${S4D_LOG_DIR}/s4dbox.log"

log_init() {
    mkdir -p "$S4D_LOG_DIR"
    touch "$S4D_LOG_FILE"
    chmod 640 "$S4D_LOG_FILE"
}

_log() {
    local level="$1"
    shift
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "[%s] [%s] %s\n" "$timestamp" "$level" "$*" >> "$S4D_LOG_FILE" 2>/dev/null
}

log_info()  { _log "INFO"  "$@"; }
log_warn()  { _log "WARN"  "$@"; }
log_error() { _log "ERROR" "$@"; }
log_debug() { _log "DEBUG" "$@"; }

log_cmd() {
    local desc="$1"
    shift
    log_info "Running: $desc ($*)"
    local output
    if output=$("$@" 2>&1); then
        log_info "Success: $desc"
        return 0
    else
        log_error "Failed: $desc - $output"
        return 1
    fi
}
