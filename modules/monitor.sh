#!/usr/bin/env bash
# s4dbox - System Monitoring Module
# Reads directly from /proc and /sys for minimal resource usage
# No heavy dependencies — pure bash + coreutils

# ─── CPU Usage ───
get_cpu_usage() {
    local cpu_line1 cpu_line2
    local user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1
    local user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2
    local total1 total2 idle_total1 idle_total2 diff_total diff_idle

    read -r _ user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 _ < /proc/stat
    sleep 0.5
    read -r _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat

    total1=$(( user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1 ))
    total2=$(( user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2 ))
    idle_total1=$(( idle1 + iowait1 ))
    idle_total2=$(( idle2 + iowait2 ))
    
    diff_total=$(( total2 - total1 ))
    diff_idle=$(( idle_total2 - idle_total1 ))

    if [[ $diff_total -gt 0 ]]; then
        echo $(( (diff_total - diff_idle) * 100 / diff_total ))
    else
        echo 0
    fi
}

# ─── CPU Core Count ───
get_cpu_cores() {
    nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1
}

# ─── CPU Load Average ───
get_load_average() {
    awk '{printf "%s %s %s", $1, $2, $3}' /proc/loadavg 2>/dev/null
}

# ─── RAM Usage ───
get_ram_info() {
    local total available used percent
    total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    available=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    used=$(( total - available ))
    percent=$(( used * 100 / total ))
    
    # Convert to MB
    local used_mb=$(( used / 1024 ))
    local total_mb=$(( total / 1024 ))
    
    printf "%d %d %d" "$used_mb" "$total_mb" "$percent"
}

# ─── Disk Usage ───
get_disk_usage() {
    df -h --output=source,size,used,avail,pcent,target 2>/dev/null | \
        grep -E '^/dev/' | \
        awk '{printf "%-12s %6s %6s %6s %5s %s\n", $1, $2, $3, $4, $5, $6}'
}

# ─── Disk Count ───
get_disk_count() {
    lsblk -d -n -o NAME,TYPE 2>/dev/null | grep -c 'disk' || echo 0
}

# ─── Disk IO ───
get_disk_io() {
    # Read /proc/diskstats twice with interval
    local read1 write1 read2 write2
    local dev
    
    dev=$(lsblk -d -n -o NAME | head -1)
    [[ -z "$dev" ]] && { echo "0 0"; return; }

    read1=$(awk -v d="$dev" '$3==d{print $6}' /proc/diskstats)
    write1=$(awk -v d="$dev" '$3==d{print $10}' /proc/diskstats)
    sleep 1
    read2=$(awk -v d="$dev" '$3==d{print $6}' /proc/diskstats)
    write2=$(awk -v d="$dev" '$3==d{print $10}' /proc/diskstats)

    # Sectors are 512 bytes, convert to KB/s
    local read_kbs=$(( (read2 - read1) * 512 / 1024 ))
    local write_kbs=$(( (write2 - write1) * 512 / 1024 ))
    
    printf "%d %d" "$read_kbs" "$write_kbs"
}

# ─── Network Speed ───
get_network_speed() {
    local nic="${1:-$S4D_NIC}"
    [[ -z "$nic" ]] && nic="$(ip -o link show up 2>/dev/null | awk -F': ' '!/lo/{print $2; exit}' | cut -d'@' -f1)"
    [[ -z "$nic" ]] && { echo "0 0"; return; }

    local rx1 tx1 rx2 tx2
    rx1=$(cat "/sys/class/net/${nic}/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx1=$(cat "/sys/class/net/${nic}/statistics/tx_bytes" 2>/dev/null || echo 0)
    sleep 1
    rx2=$(cat "/sys/class/net/${nic}/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx2=$(cat "/sys/class/net/${nic}/statistics/tx_bytes" 2>/dev/null || echo 0)

    local rx_kbs=$(( (rx2 - rx1) / 1024 ))
    local tx_kbs=$(( (tx2 - tx1) / 1024 ))

    printf "%d %d" "$rx_kbs" "$tx_kbs"
}

# ─── IO Wait ───
get_iowait() {
    local iowait1 iowait2 total1 total2
    read -r _ _ _ _ _ iowait1 _ < /proc/stat
    local line1
    line1=$(head -1 /proc/stat)
    local sum1=0
    for val in ${line1#cpu }; do sum1=$(( sum1 + val )); done
    
    sleep 0.5
    
    local line2
    line2=$(head -1 /proc/stat)
    read -r _ _ _ _ _ iowait2 _ <<< "$line2"
    local sum2=0
    for val in ${line2#cpu }; do sum2=$(( sum2 + val )); done

    local diff_total=$(( sum2 - sum1 ))
    local diff_iowait=$(( iowait2 - iowait1 ))

    if [[ $diff_total -gt 0 ]]; then
        echo $(( diff_iowait * 100 / diff_total ))
    else
        echo 0
    fi
}

# ─── Uptime ───
get_uptime() {
    local seconds
    seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
    local days=$(( seconds / 86400 ))
    local hours=$(( (seconds % 86400) / 3600 ))
    local mins=$(( (seconds % 3600) / 60 ))
    printf "%dd %dh %dm" "$days" "$hours" "$mins"
}

# ─── Format Speed ───
format_speed() {
    local kbs=$1
    if [[ $kbs -ge 1048576 ]]; then
        printf "%.1f GB/s" "$(echo "scale=1; $kbs / 1048576" | bc)"
    elif [[ $kbs -ge 1024 ]]; then
        printf "%.1f MB/s" "$(echo "scale=1; $kbs / 1024" | bc)"
    else
        printf "%d KB/s" "$kbs"
    fi
}

# ─── Progress Bar ───
draw_bar() {
    local percent=$1
    local width=${2:-30}
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    local color

    if [[ $percent -lt 50 ]]; then
        color="$GREEN"
    elif [[ $percent -lt 80 ]]; then
        color="$YELLOW"
    else
        color="$RED"
    fi

    printf "${color}"
    printf '█%.0s' $(seq 1 $filled 2>/dev/null) 2>/dev/null
    printf "${DIM}"
    printf '░%.0s' $(seq 1 $empty 2>/dev/null) 2>/dev/null
    printf "${RESET}"
    printf " %3d%%" "$percent"
}

# ─── Full Dashboard (single snapshot) ───
monitor_snapshot() {
    local cpu_pct ram_info ram_used ram_total ram_pct
    local io_info io_read io_write
    local net_info net_rx net_tx
    local iowait uptime disk_count cores load

    cores=$(get_cpu_cores)
    load=$(get_load_average)
    uptime=$(get_uptime)
    disk_count=$(get_disk_count)
    cpu_pct=$(get_cpu_usage)
    
    read -r ram_used ram_total ram_pct <<< "$(get_ram_info)"
    
    iowait=$(get_iowait)
    
    read -r io_read io_write <<< "$(get_disk_io)"
    read -r net_rx net_tx <<< "$(get_network_speed)"

    clear
    printf "\n"
    printf "  ${BOLD}${CYAN}┌──────────────────────────────────────────────────────────┐${RESET}\n"
    printf "  ${BOLD}${CYAN}│${RESET}  ${BOLD}s4dbox System Monitor${RESET}             Uptime: %-14s ${BOLD}${CYAN}│${RESET}\n" "$uptime"
    printf "  ${BOLD}${CYAN}├──────────────────────────────────────────────────────────┤${RESET}\n"
    printf "  ${BOLD}${CYAN}│${RESET}                                                          ${BOLD}${CYAN}│${RESET}\n"
    printf "  ${BOLD}${CYAN}│${RESET}  ${BOLD}CPU${RESET}  [$(draw_bar "$cpu_pct" 25)]  %d cores    ${BOLD}${CYAN}│${RESET}\n" "$cores"
    printf "  ${BOLD}${CYAN}│${RESET}  ${BOLD}RAM${RESET}  [$(draw_bar "$ram_pct" 25)]  %dMB/%dMB  ${BOLD}${CYAN}│${RESET}\n" "$ram_used" "$ram_total"
    printf "  ${BOLD}${CYAN}│${RESET}  ${BOLD}IO ${RESET}  Wait: %2d%%                                        ${BOLD}${CYAN}│${RESET}\n" "$iowait"
    printf "  ${BOLD}${CYAN}│${RESET}  ${BOLD}Load${RESET} %s                                    ${BOLD}${CYAN}│${RESET}\n" "$load"
    printf "  ${BOLD}${CYAN}│${RESET}                                                          ${BOLD}${CYAN}│${RESET}\n"
    printf "  ${BOLD}${CYAN}├──────────────────────────────────────────────────────────┤${RESET}\n"
    printf "  ${BOLD}${CYAN}│${RESET}  ${BOLD}Disk IO${RESET}    Read: $(format_speed "$io_read")   Write: $(format_speed "$io_write")\n"
    printf "  ${BOLD}${CYAN}│${RESET}  ${BOLD}Network${RESET}    ↓ $(format_speed "$net_rx")     ↑ $(format_speed "$net_tx")\n"
    printf "  ${BOLD}${CYAN}│${RESET}  ${BOLD}Disks${RESET}      %d detected\n" "$disk_count"
    printf "  ${BOLD}${CYAN}│${RESET}                                                          ${BOLD}${CYAN}│${RESET}\n"
    printf "  ${BOLD}${CYAN}├──────────────────────────────────────────────────────────┤${RESET}\n"
    printf "  ${BOLD}${CYAN}│${RESET}  ${DIM}Disk Usage:${RESET}\n"
    
    while IFS= read -r line; do
        printf "  ${BOLD}${CYAN}│${RESET}    %s\n" "$line"
    done <<< "$(get_disk_usage)"
    
    printf "  ${BOLD}${CYAN}│${RESET}                                                          ${BOLD}${CYAN}│${RESET}\n"
    printf "  ${BOLD}${CYAN}└──────────────────────────────────────────────────────────┘${RESET}\n"
    printf "\n  ${DIM}Press 'q' to return to menu${RESET}\n"
}

# ─── Live Monitor Loop ───
monitor_live() {
    local running=1
    
    # Set terminal to raw mode for non-blocking input
    stty -echo -icanon min 0 time 0 2>/dev/null || true
    
    while [[ $running -eq 1 ]]; do
        monitor_snapshot
        
        # Check for keypress
        local key=""
        read -rsn1 -t 2 key 2>/dev/null || true
        if [[ "$key" == "q" ]] || [[ "$key" == "Q" ]]; then
            running=0
        fi
    done
    
    # Restore terminal
    stty echo icanon 2>/dev/null || true
}
