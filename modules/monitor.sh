#!/usr/bin/env bash
# s4dbox - System Monitoring Module
# Live dashboard: CPU, RAM, Swap, Disk, Network, Buffers
# Reads from /proc and /sys — pure bash, refreshes every ~1s

# ─── Draw a bar ───
# Uses printf '%s' to avoid format-character bugs
_bar() {
    local pct=${1:-0} width=${2:-30}
    local filled=$(( pct * width / 100 ))
    [[ $filled -gt $width ]] && filled=$width
    local empty=$(( width - filled ))
    local color
    if [[ $pct -lt 50 ]]; then color="$GREEN"
    elif [[ $pct -lt 80 ]]; then color="$YELLOW"
    else color="$RED"; fi

    local bar=""
    local i
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    for (( i=0; i<empty;  i++ )); do bar+="░"; done
    printf '%s%s%s%s%s %3d%%' "$color" "" "$bar" "$RESET" "" "$pct"
}

# ─── Format bytes/sec into human-readable ───
_fmt_speed() {
    local val=${1:-0}
    if [[ $val -ge 1048576 ]]; then
        local gb=$(( val * 10 / 1048576 ))
        printf '%d.%d GB/s' "$(( gb / 10 ))" "$(( gb % 10 ))"
    elif [[ $val -ge 1024 ]]; then
        local mb=$(( val * 10 / 1024 ))
        printf '%d.%d MB/s' "$(( mb / 10 ))" "$(( mb % 10 ))"
    else
        printf '%d KB/s' "$val"
    fi
}

# ─── Format size in KB to human ───
_fmt_size() {
    local kb=${1:-0}
    if [[ $kb -ge 1048576 ]]; then
        local gb=$(( kb * 10 / 1048576 ))
        printf '%d.%d GB' "$(( gb / 10 ))" "$(( gb % 10 ))"
    elif [[ $kb -ge 1024 ]]; then
        local mb=$(( kb * 10 / 1024 ))
        printf '%d.%d MB' "$(( mb / 10 ))" "$(( mb % 10 ))"
    else
        printf '%d KB' "$kb"
    fi
}

# ─── Uptime ───
get_uptime() {
    local seconds
    seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
    local days=$(( seconds / 86400 ))
    local hours=$(( (seconds % 86400) / 3600 ))
    local mins=$(( (seconds % 3600) / 60 ))
    printf '%dd %dh %dm' "$days" "$hours" "$mins"
}

# ─── Detect primary NIC ───
_detect_nic() {
    ip -o link show up 2>/dev/null | awk -F': ' '!/lo/{print $2; exit}' | cut -d'@' -f1
}

# ─── Live monitor ───
monitor_live() {
    local nic
    nic="$(_detect_nic)"

    # Stash initial CPU counters
    local cpu_u1 cpu_n1 cpu_s1 cpu_i1 cpu_w1 cpu_q1 cpu_si1 cpu_st1
    read -r _ cpu_u1 cpu_n1 cpu_s1 cpu_i1 cpu_w1 cpu_q1 cpu_si1 cpu_st1 _ < /proc/stat

    # Stash initial net counters
    local rx1=0 tx1=0
    if [[ -n "$nic" ]]; then
        rx1=$(< "/sys/class/net/${nic}/statistics/rx_bytes")
        tx1=$(< "/sys/class/net/${nic}/statistics/tx_bytes")
    fi

    # Stash initial disk IO
    local dev
    dev=$(lsblk -dn -o NAME 2>/dev/null | head -1)
    local dr1=0 dw1=0
    if [[ -n "$dev" ]]; then
        dr1=$(awk -v d="$dev" '$3==d{print $6}' /proc/diskstats 2>/dev/null)
        dw1=$(awk -v d="$dev" '$3==d{print $10}' /proc/diskstats 2>/dev/null)
    fi

    local running=1
    trap 'running=0' INT TERM

    while [[ $running -eq 1 ]]; do
        sleep 1

        # ── CPU ──
        local cpu_u2 cpu_n2 cpu_s2 cpu_i2 cpu_w2 cpu_q2 cpu_si2 cpu_st2
        read -r _ cpu_u2 cpu_n2 cpu_s2 cpu_i2 cpu_w2 cpu_q2 cpu_si2 cpu_st2 _ < /proc/stat
        local t1=$(( cpu_u1+cpu_n1+cpu_s1+cpu_i1+cpu_w1+cpu_q1+cpu_si1+cpu_st1 ))
        local t2=$(( cpu_u2+cpu_n2+cpu_s2+cpu_i2+cpu_w2+cpu_q2+cpu_si2+cpu_st2 ))
        local dt=$(( t2 - t1 ))
        local di=$(( (cpu_i2+cpu_w2) - (cpu_i1+cpu_w1) ))
        local cpu_pct=0
        [[ $dt -gt 0 ]] && cpu_pct=$(( (dt - di) * 100 / dt ))
        local iowait_pct=0
        [[ $dt -gt 0 ]] && iowait_pct=$(( (cpu_w2 - cpu_w1) * 100 / dt ))
        # Save for next iteration
        cpu_u1=$cpu_u2; cpu_n1=$cpu_n2; cpu_s1=$cpu_s2; cpu_i1=$cpu_i2
        cpu_w1=$cpu_w2; cpu_q1=$cpu_q2; cpu_si1=$cpu_si2; cpu_st1=$cpu_st2

        local cores
        cores=$(nproc 2>/dev/null || echo 1)
        local load
        load=$(awk '{printf "%s %s %s", $1, $2, $3}' /proc/loadavg 2>/dev/null)

        # ── Memory ──
        local mem_total mem_free mem_avail mem_buffers mem_cached swap_total swap_free
        while IFS=': ' read -r key val _; do
            case "$key" in
                MemTotal)     mem_total=$val ;;
                MemFree)      mem_free=$val ;;
                MemAvailable) mem_avail=$val ;;
                Buffers)      mem_buffers=$val ;;
                Cached)       mem_cached=$val ;;
                SwapTotal)    swap_total=$val ;;
                SwapFree)     swap_free=$val ;;
            esac
        done < /proc/meminfo

        local mem_used=$(( mem_total - mem_avail ))
        local mem_pct=0
        [[ $mem_total -gt 0 ]] && mem_pct=$(( mem_used * 100 / mem_total ))
        local swap_used=$(( swap_total - swap_free ))
        local swap_pct=0
        [[ $swap_total -gt 0 ]] && swap_pct=$(( swap_used * 100 / swap_total ))

        # ── Network ──
        local rx2=0 tx2=0 rx_kbs=0 tx_kbs=0
        if [[ -n "$nic" ]]; then
            rx2=$(< "/sys/class/net/${nic}/statistics/rx_bytes")
            tx2=$(< "/sys/class/net/${nic}/statistics/tx_bytes")
            rx_kbs=$(( (rx2 - rx1) / 1024 ))
            tx_kbs=$(( (tx2 - tx1) / 1024 ))
            rx1=$rx2; tx1=$tx2
        fi

        # ── Disk IO ──
        local dr2=0 dw2=0 dr_kbs=0 dw_kbs=0
        if [[ -n "$dev" ]]; then
            dr2=$(awk -v d="$dev" '$3==d{print $6}' /proc/diskstats 2>/dev/null)
            dw2=$(awk -v d="$dev" '$3==d{print $10}' /proc/diskstats 2>/dev/null)
            dr_kbs=$(( (dr2 - dr1) * 512 / 1024 ))
            dw_kbs=$(( (dw2 - dw1) * 512 / 1024 ))
            dr1=$dr2; dw1=$dw2
        fi

        local uptime_str
        uptime_str="$(get_uptime)"

        # ── Render ──
        clear
        local W=62  # box inner width
        local B="${BOLD}${CYAN}"
        local R="$RESET"

        echo
        printf '  %s┌──────────────────────────────────────────────────────────────┐%s\n' "$B" "$R"
        printf '  %s│%s  %ss4dbox System Monitor%s                  Uptime: %-10s %s│%s\n' "$B" "$R" "$BOLD" "$R" "$uptime_str" "$B" "$R"
        printf '  %s├──────────────────────────────────────────────────────────────┤%s\n' "$B" "$R"

        # CPU
        local cpu_bar
        cpu_bar="$(_bar "$cpu_pct" 28)"
        printf '  %s│%s  %sCPU%s   %s  %d cores  load %s %s│%s\n' \
            "$B" "$R" "$BOLD" "$R" "$cpu_bar" "$cores" "$load" "$B" "$R"

        # RAM
        local ram_bar
        ram_bar="$(_bar "$mem_pct" 28)"
        printf '  %s│%s  %sRAM%s   %s  %s / %s   %s│%s\n' \
            "$B" "$R" "$BOLD" "$R" "$ram_bar" "$(_fmt_size $mem_used)" "$(_fmt_size $mem_total)" "$B" "$R"

        # Swap
        if [[ $swap_total -gt 0 ]]; then
            local swap_bar
            swap_bar="$(_bar "$swap_pct" 28)"
            printf '  %s│%s  %sSwap%s  %s  %s / %s   %s│%s\n' \
                "$B" "$R" "$BOLD" "$R" "$swap_bar" "$(_fmt_size $swap_used)" "$(_fmt_size $swap_total)" "$B" "$R"
        fi

        # Buffers / Cached
        printf '  %s│%s  %sBuf/Cache%s  Buffers: %-10s  Cached: %-14s  %s│%s\n' \
            "$B" "$R" "$BOLD" "$R" "$(_fmt_size $mem_buffers)" "$(_fmt_size $mem_cached)" "$B" "$R"

        # IO Wait
        printf '  %s│%s  %sIO Wait%s    %d%%                                              %s│%s\n' \
            "$B" "$R" "$BOLD" "$R" "$iowait_pct" "$B" "$R"

        printf '  %s├──────────────────────────────────────────────────────────────┤%s\n' "$B" "$R"

        # Network
        printf '  %s│%s  %sNetwork%s (%s)                                          %s│%s\n' \
            "$B" "$R" "$BOLD" "$R" "${nic:-none}" "$B" "$R"
        printf '  %s│%s    ↓ Download: %-16s  ↑ Upload: %-14s  %s│%s\n' \
            "$B" "$R" "$(_fmt_speed $rx_kbs)" "$(_fmt_speed $tx_kbs)" "$B" "$R"

        printf '  %s├──────────────────────────────────────────────────────────────┤%s\n' "$B" "$R"

        # Disk IO
        printf '  %s│%s  %sDisk IO%s (%s)                                            %s│%s\n' \
            "$B" "$R" "$BOLD" "$R" "${dev:-?}" "$B" "$R"
        printf '  %s│%s    Read: %-18s  Write: %-16s    %s│%s\n' \
            "$B" "$R" "$(_fmt_speed $dr_kbs)" "$(_fmt_speed $dw_kbs)" "$B" "$R"

        printf '  %s├──────────────────────────────────────────────────────────────┤%s\n' "$B" "$R"

        # Disk Usage
        printf '  %s│%s  %sDisk Usage%s                                                  %s│%s\n' \
            "$B" "$R" "$BOLD" "$R" "$B" "$R"
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local d_src d_size d_used d_avail d_pct d_mount
            read -r d_src d_size d_used d_avail d_pct d_mount <<< "$line"
            local d_pct_num="${d_pct%%%*}"
            local d_bar
            d_bar="$(_bar "$d_pct_num" 15)"
            printf '  %s│%s    %-10s %s  %5s / %-5s  %s│%s\n' \
                "$B" "$R" "$d_mount" "$d_bar" "$d_used" "$d_size" "$B" "$R"
        done < <(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -E '^/dev/')

        printf '  %s└──────────────────────────────────────────────────────────────┘%s\n' "$B" "$R"
        printf '\n  %sRefreshing every 1s — press q to exit%s\n' "$DIM" "$R"

        # Non-blocking keypress check
        local key=""
        read -rsn1 -t 0.1 key 2>/dev/null || true
        if [[ "$key" == "q" ]] || [[ "$key" == "Q" ]]; then
            running=0
        fi
    done
}

# ─── Single snapshot (for non-interactive use) ───
monitor_snapshot() {
    monitor_live
}
}
