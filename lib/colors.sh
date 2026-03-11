#!/usr/bin/env bash
# s4dbox - Color and output formatting library
# Uses ANSI-C quoting to store actual escape bytes

# Colors (ANSI-C quoting — works with printf '%s' and '%b')
export RED=$'\033[0;31m'
export GREEN=$'\033[0;32m'
export YELLOW=$'\033[0;33m'
export BLUE=$'\033[0;34m'
export MAGENTA=$'\033[0;35m'
export CYAN=$'\033[0;36m'
export WHITE=$'\033[1;37m'
export DIM=$'\033[2m'
export BOLD=$'\033[1m'
export RESET=$'\033[0m'

# Reverse / highlight
export REV=$'\033[7m'

msg_info() {
    printf "${GREEN}[INFO]${RESET} %s\n" "$1"
}

msg_warn() {
    printf "${YELLOW}[WARN]${RESET} %s\n" "$1" >&2
}

msg_error() {
    printf "${RED}[ERROR]${RESET} %s\n" "$1" >&2
}

msg_ok() {
    printf "${GREEN}[  OK  ]${RESET} %s\n" "$1"
}

msg_fail() {
    printf "${RED}[FAILED]${RESET} %s\n" "$1" >&2
}

msg_step() {
    printf "${CYAN}>>>${RESET} %s\n" "$1"
}

msg_header() {
    local text="$1"
    local width=${2:-60}
    local pad=$(( (width - ${#text} - 2) / 2 ))
    printf "\n${BOLD}${CYAN}"
    printf '%*s' "$width" '' | tr ' ' '─'
    printf "\n"
    printf '%*s' "$pad" '' 
    printf " %s " "$text"
    printf "\n"
    printf '%*s' "$width" '' | tr ' ' '─'
    printf "${RESET}\n\n"
}

# Spinner for background tasks
spinner_start() {
    local msg="${1:-Working...}"
    _spinner_msg="$msg"
    printf "${CYAN}%s ${RESET}" "$msg"
    (
        local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        while true; do
            for (( i=0; i<${#chars}; i++ )); do
                printf "\r${CYAN}%s ${YELLOW}%s${RESET}" "$_spinner_msg" "${chars:$i:1}"
                sleep 0.1
            done
        done
    ) &
    _spinner_pid=$!
    disown $_spinner_pid 2>/dev/null
}

spinner_stop() {
    local status="${1:-0}"
    [[ -n "$_spinner_pid" ]] && kill "$_spinner_pid" 2>/dev/null
    wait "$_spinner_pid" 2>/dev/null
    _spinner_pid=""
    if [[ "$status" -eq 0 ]]; then
        printf "\r${GREEN}%s ✓${RESET}\n" "$_spinner_msg"
    else
        printf "\r${RED}%s ✗${RESET}\n" "$_spinner_msg"
    fi
}
