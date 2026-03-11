#!/usr/bin/env bash
# s4dbox - System Monitor (btop-inspired)
# Live dashboard with per-core CPU, memory, network, disk, processes
# Pure bash + /proc + /sys — refreshes every 1 second

# ─── Constants ───
_MW=68  # inner content width

# ─── Box drawing ───
_box_top() {
    local label="$1"
    local label_len=${#label}
    local dashes=$(( _MW - label_len - 1 ))
    printf '  %s╭─ %s%s%s %s' "$CYAN" "$BOLD$WHITE" "$label" "$CYAN" ""
    local i; for (( i=0; i<dashes; i++ )); do printf '─'; done
    printf '╮%s\n' "$RESET"
}

_box_mid() {
    printf '  %s├' "$CYAN"
    local i; for (( i=0; i<_MW+2; i++ )); do printf '─'; done
    printf '┤%s\n' "$RESET"
}

_box_bot() {
    printf '  %s╰' "$CYAN"
    local i; for (( i=0; i<_MW+2; i++ )); do printf '─'; done
    printf '╯%s\n' "$RESET"
}

# Print a row with left/right borders.
# Automatically strips ANSI codes to compute visible width.
_row() {
    local content="$1"
    # Strip ANSI escape sequences to get visible length
    local stripped="$content"
    while [[ "$stripped" == *$'\e['* ]]; do
        local pre="${stripped%%$'\e['*}"
        local rest="${stripped#*$'\e['}"
        rest="${rest#*m}"
        stripped="${pre}${rest}"
    done
    local vis_len=${#stripped}
    local pad=$(( _MW - vis_len ))
    [[ $pad -lt 0 ]] && pad=0
    printf '  %s│%s %s%*s %s│%s\n' "$CYAN" "$RESET" "$content" "$pad" "" "$CYAN" "$RESET"
}

_row_empty() {
    printf '  %s│%s%*s%s│%s\n' "$CYAN" "$RESET" "$(( _MW + 2 ))" "" "$CYAN" "$RESET"
}

# ─── Draw bar ───
_bar() {
    local pct=${1:-0} width=${2:-35}
    [[ $pct -gt 100 ]] && pct=100
    [[ $pct -lt 0 ]] && pct=0
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local color
    if [[ $pct -lt 50 ]]; then color="$GREEN"
    elif [[ $pct -lt 80 ]]; then color="$YELLOW"
    else color="$RED"; fi
    local bar="$color"
    local i
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    bar+="$DIM"
    for (( i=0; i<empty; i++ )); do bar+="░"; done
    bar+="$RESET"
    printf '%s' "$bar"
}

# ─── Format KB to human ───
_hsize() {
    local kb=${1:-0}
    if [[ $kb -ge 1048576 ]]; then
        printf '%d.%d GB' "$(( kb / 1048576 ))" "$(( (kb % 1048576) * 10 / 1048576 ))"
    elif [[ $kb -ge 1024 ]]; then
        printf '%d.%d MB' "$(( kb / 1024 ))" "$(( (kb % 1024) * 10 / 1024 ))"
    else
        printf '%d KB' "$kb"
    fi
}

# ─── Format speed ───
_hspeed() {
    local kbs=${1:-0}
    if [[ $kbs -ge 1048576 ]]; then
        printf '%d.%d GB/s' "$(( kbs / 1048576 ))" "$(( (kbs % 1048576) * 10 / 1048576 ))"
    elif [[ $kbs -ge 1024 ]]; then
        printf '%d.%d MB/s' "$(( kbs / 1024 ))" "$(( (kbs % 1024) * 10 / 1024 ))"
    else
        printf '%d KB/s' "$kbs"
    fi
}

# ─── Uptime ───
_uptime() {
    local s; s=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
    printf '%dd %dh %dm' "$(( s/86400 ))" "$(( s%86400/3600 ))" "$(( s%3600/60 ))"
}

# ─── Read all CPU counters from /proc/stat ───
# Populates arrays: _cpu_user _cpu_nice _cpu_sys _cpu_idle _cpu_iow _cpu_irq _cpu_sirq _cpu_steal
_read_cpu() {
    local -n _u=$1 _n=$2 _s=$3 _id=$4 _w=$5 _q=$6 _si=$7 _st=$8 _nc=$9
    _nc=0
    while IFS=' ' read -r label u n s id w q si st _; do
        if [[ "$label" == "cpu" ]]; then
            _u[t]=$u; _n[t]=$n; _s[t]=$s; _id[t]=$id; _w[t]=$w; _q[t]=$q; _si[t]=$si; _st[t]=$st
        elif [[ "$label" =~ ^cpu([0-9]+)$ ]]; then
            local c="${BASH_REMATCH[1]}"
            _u[$c]=$u; _n[$c]=$n; _s[$c]=$s; _id[$c]=$id; _w[$c]=$w; _q[$c]=$q; _si[$c]=$si; _st[$c]=$st
            (( c >= _nc )) && _nc=$(( c + 1 ))
        fi
    done < /proc/stat
}

# Compute CPU percent between two snapshots for a given index
_cpu_pct() {
    local idx=$1
    local t1=$(( p_u[$idx]+p_n[$idx]+p_s[$idx]+p_i[$idx]+p_w[$idx]+p_q[$idx]+p_si[$idx]+p_st[$idx] ))
    local t2=$(( c_u[$idx]+c_n[$idx]+c_s[$idx]+c_i[$idx]+c_w[$idx]+c_q[$idx]+c_si[$idx]+c_st[$idx] ))
    local d=$(( t2 - t1 ))
    local di=$(( (c_i[$idx]+c_w[$idx]) - (p_i[$idx]+p_w[$idx]) ))
    [[ $d -le 0 ]] && { echo 0; return; }
    echo $(( (d - di) * 100 / d ))
}

# ─── Live Monitor ───
monitor_live() {
    # Detect NIC
    local nic
    nic="$(ip -o link show up 2>/dev/null | awk -F': ' '!/lo/{print $2; exit}' | cut -d'@' -f1)"

    # Detect primary disk (not cd-rom, not loop)
    local dev
    dev="$(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1; exit}')"

    # Initial CPU snapshot
    declare -A p_u p_n p_s p_i p_w p_q p_si p_st
    local num_cores=0
    _read_cpu p_u p_n p_s p_i p_w p_q p_si p_st num_cores

    # Initial network counters
    local rx_prev=0 tx_prev=0
    [[ -n "$nic" ]] && { rx_prev=$(< "/sys/class/net/${nic}/statistics/rx_bytes"); tx_prev=$(< "/sys/class/net/${nic}/statistics/tx_bytes"); }

    # Initial disk IO counters
    local dr_prev=0 dw_prev=0
    [[ -n "$dev" ]] && { dr_prev=$(awk -v d="$dev" '$3==d{print $6}' /proc/diskstats 2>/dev/null); dw_prev=$(awk -v d="$dev" '$3==d{print $10}' /proc/diskstats 2>/dev/null); }

    local running=1
    trap 'running=0' INT TERM

    # Hide cursor, ensure it's restored on exit
    printf '\e[?25l' >/dev/tty
    trap 'printf "\e[?25h" >/dev/tty; running=0' INT TERM EXIT

    while [[ $running -eq 1 ]]; do
        sleep 1

        # ── Collect CPU ──
        declare -A c_u c_n c_s c_i c_w c_q c_si c_st
        _read_cpu c_u c_n c_s c_i c_w c_q c_si c_st num_cores

        local total_pct; total_pct=$(_cpu_pct t)
        local iow_t1=$(( p_w[t] )); local iow_t2=$(( c_w[t] ))
        local cpu_t1=$(( p_u[t]+p_n[t]+p_s[t]+p_i[t]+p_w[t]+p_q[t]+p_si[t]+p_st[t] ))
        local cpu_t2=$(( c_u[t]+c_n[t]+c_s[t]+c_i[t]+c_w[t]+c_q[t]+c_si[t]+c_st[t] ))
        local cpu_dt=$(( cpu_t2 - cpu_t1 ))
        local iow_pct=0
        [[ $cpu_dt -gt 0 ]] && iow_pct=$(( (iow_t2 - iow_t1) * 100 / cpu_dt ))

        local -a core_pct=()
        for (( ci=0; ci<num_cores; ci++ )); do
            core_pct[$ci]=$(_cpu_pct "$ci")
        done

        # Save for next iteration
        for key in "${!c_u[@]}"; do p_u[$key]=${c_u[$key]}; p_n[$key]=${c_n[$key]}; p_s[$key]=${c_s[$key]}; p_i[$key]=${c_i[$key]}; p_w[$key]=${c_w[$key]}; p_q[$key]=${c_q[$key]}; p_si[$key]=${c_si[$key]}; p_st[$key]=${c_st[$key]}; done

        local load; load=$(awk '{printf "%s  %s  %s", $1, $2, $3}' /proc/loadavg)

        # ── Memory ──
        local mt=0 mf=0 ma=0 mb=0 mc=0 st=0 sf=0
        while IFS=': ' read -r k v _; do
            case "$k" in
                MemTotal) mt=$v;; MemFree) mf=$v;; MemAvailable) ma=$v;;
                Buffers) mb=$v;; Cached) mc=$v;; SwapTotal) st=$v;; SwapFree) sf=$v;;
            esac
        done < /proc/meminfo
        local mu=$(( mt - ma )) mp=0 su=$(( st - sf )) sp=0
        [[ $mt -gt 0 ]] && mp=$(( mu * 100 / mt ))
        [[ $st -gt 0 ]] && sp=$(( su * 100 / st ))

        # ── Network ──
        local rx_now=0 tx_now=0 rx_kbs=0 tx_kbs=0
        if [[ -n "$nic" ]]; then
            rx_now=$(< "/sys/class/net/${nic}/statistics/rx_bytes")
            tx_now=$(< "/sys/class/net/${nic}/statistics/tx_bytes")
            rx_kbs=$(( (rx_now - rx_prev) / 1024 ))
            tx_kbs=$(( (tx_now - tx_prev) / 1024 ))
            rx_prev=$rx_now; tx_prev=$tx_now
        fi

        # ── Disk IO ──
        local dr_now=0 dw_now=0 dr_kbs=0 dw_kbs=0
        if [[ -n "$dev" ]]; then
            dr_now=$(awk -v d="$dev" '$3==d{print $6}' /proc/diskstats 2>/dev/null)
            dw_now=$(awk -v d="$dev" '$3==d{print $10}' /proc/diskstats 2>/dev/null)
            dr_kbs=$(( (dr_now - dr_prev) * 512 / 1024 ))
            dw_kbs=$(( (dw_now - dw_prev) * 512 / 1024 ))
            dr_prev=$dr_now; dw_prev=$dw_now
        fi

        # ── Render ──
        {
        printf '\e[H\e[2J'  # move cursor home + clear

        local up; up="$(_uptime)"

        # Title bar
        printf '\n  %s%s s4dbox monitor %s' "$BOLD" "$WHITE" "$RESET"
        printf '%*s' "$(( _MW - 14 - ${#up} - 9 ))" ""
        printf '%sUptime: %s%s\n\n' "$DIM" "$up" "$RESET"

        # ── CPU Section ──
        _box_top "CPU"

        # Total CPU bar
        local tbar; tbar="$(_bar $total_pct 40)"
        local tline="${BOLD}Total${RESET}  ${tbar}  ${BOLD}${total_pct}%${RESET}   ${num_cores} cores"
        _row "$tline"

        # Per-core bars (2 cores per row)
        local ci=0
        while (( ci < num_cores )); do
            local line=""
            # Core A
            local cpct=${core_pct[$ci]}
            local cbar; cbar="$(_bar $cpct 14)"
            local cid_str="#${ci}"
            line+="${DIM}${cid_str}${RESET} ${cbar} ${BOLD}${cpct}%${RESET}"
            ci=$(( ci + 1 ))

            if (( ci < num_cores )); then
                local cpct2=${core_pct[$ci]}
                local cbar2; cbar2="$(_bar $cpct2 14)"
                local cid_str2="#${ci}"
                line+="$(printf '%*s' 10 '')${DIM}${cid_str2}${RESET} ${cbar2} ${BOLD}${cpct2}%${RESET}"
                ci=$(( ci + 1 ))
            fi
            _row "$line"
        done

        # Load + IO Wait
        local loadline="${DIM}Load:${RESET} ${load}          ${DIM}IO Wait:${RESET} ${iow_pct}%"
        _row "$loadline"
        _box_bot

        # ── Memory Section ──
        _box_top "Memory"
        local rbar; rbar="$(_bar $mp 40)"
        local rsize; rsize="$(_hsize $mu)/$(_hsize $mt)"
        _row "${BOLD}RAM ${RESET}  ${rbar}  ${BOLD}${mp}%${RESET}  ${rsize}"

        if [[ $st -gt 0 ]]; then
            local sbar; sbar="$(_bar $sp 40)"
            local ssize; ssize="$(_hsize $su)/$(_hsize $st)"
            _row "${BOLD}Swap${RESET}  ${sbar}  ${BOLD}${sp}%${RESET}  ${ssize}"
        fi

        local bstr; bstr="$(_hsize $mb)"
        local cstr; cstr="$(_hsize $mc)"
        _row "${DIM}Buffers:${RESET} ${bstr}    ${DIM}Cached:${RESET} ${cstr}"
        _box_bot

        # ── Network Section ──
        _box_top "Network (${nic:-none})"
        local dspeed; dspeed="$(_hspeed $rx_kbs)"
        local uspeed; uspeed="$(_hspeed $tx_kbs)"
        _row "${GREEN}↓${RESET} ${BOLD}Download${RESET}  ${dspeed}          ${RED}↑${RESET} ${BOLD}Upload${RESET}  ${uspeed}"
        _box_bot

        # ── Disk Section ──
        _box_top "Disk (${dev:-none})"
        local drsp; drsp="$(_hspeed $dr_kbs)"
        local dwsp; dwsp="$(_hspeed $dw_kbs)"
        _row "${DIM}IO${RESET}  Read: ${BOLD}${drsp}${RESET}     Write: ${BOLD}${dwsp}${RESET}"
        _box_mid

        # Disk usage rows
        while IFS= read -r dline; do
            [[ -z "$dline" ]] && continue
            local dsrc dsz dused davail dpct dmnt
            read -r dsrc dsz dused davail dpct dmnt <<< "$dline"
            local dpn="${dpct%%%*}"
            local dbar; dbar="$(_bar $dpn 20)"
            local dtxt; dtxt="${dmnt}"
            [[ ${#dtxt} -gt 10 ]] && dtxt="${dtxt:0:10}"
            local dinfo="${dused}/${dsz}"
            _row "$(printf '%-10s' "$dtxt") ${dbar}  ${BOLD}${dpn}%${RESET}  ${dinfo}"
        done < <(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -E '^/dev/' | grep -v '/dev/loop')
        _box_bot

        # ── Top Processes ──
        _box_top "Processes (Top 5 by CPU)"
        _row "$(printf "${BOLD}%-8s %-10s %5s %5s  %-30s${RESET}" PID USER 'CPU%' 'MEM%' COMMAND)"
        while IFS= read -r pline; do
            [[ -z "$pline" ]] && continue
            local ppid puser pcpu pmem pcmd
            read -r ppid puser pcpu pmem pcmd <<< "$pline"
            _row "$(printf '%-8s %-10s %5s %5s  %-30s' "$ppid" "$puser" "$pcpu" "$pmem" "${pcmd:0:30}")"
        done < <(ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=6 {print $2, $1, $3, $4, $11}')
        _box_bot

        printf '\n  %s q: quit │ Refreshing every 1s%s\n' "$DIM" "$RESET"
        } >/dev/tty

        # Non-blocking key check
        local key=""
        read -rsn1 -t 0.1 key </dev/tty 2>/dev/null || true
        [[ "$key" == "q" || "$key" == "Q" ]] && running=0
    done

    # Restore cursor and trap
    printf '\e[?25h' >/dev/tty
    trap - INT TERM EXIT
}

# ─── Alias for backward compat ───
monitor_snapshot() {
    monitor_live
}