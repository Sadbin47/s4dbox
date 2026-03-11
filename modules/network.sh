#!/usr/bin/env bash
# s4dbox - Network Manager
# Network status, VPN management, bandwidth monitoring

# ─── Network Status ───
network_status() {
    msg_header "Network Status"
    
    local ip_addr
    ip_addr="$(get_local_ip)"
    local gateway
    gateway="$(ip route | awk '/default/{print $3}')"
    local dns
    dns="$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | head -1 | awk '{print $2}')"
    
    printf "  %-18s %s\n" "IP Address:" "$ip_addr"
    printf "  %-18s %s\n" "Gateway:" "$gateway"
    printf "  %-18s %s\n" "DNS:" "$dns"
    printf "  %-18s %s\n" "Interface:" "$S4D_NIC"
    
    # Tailscale IP if available
    if command -v tailscale &>/dev/null; then
        local ts_ip
        ts_ip="$(tailscale ip -4 2>/dev/null)"
        [[ -n "$ts_ip" ]] && printf "  %-18s %s\n" "Tailscale IP:" "$ts_ip"
    fi
    
    echo
    
    # Show speed (sample for 1 second)
    echo "  Measuring network throughput..."
    local nic
    nic="$(ip -o link show up 2>/dev/null | awk -F': ' '!/lo/{print $2; exit}' | cut -d'@' -f1)"
    if [[ -n "$nic" ]]; then
        local r1 t1 r2 t2
        r1=$(< "/sys/class/net/${nic}/statistics/rx_bytes")
        t1=$(< "/sys/class/net/${nic}/statistics/tx_bytes")
        sleep 1
        r2=$(< "/sys/class/net/${nic}/statistics/rx_bytes")
        t2=$(< "/sys/class/net/${nic}/statistics/tx_bytes")
        local rx_kb=$(( (r2 - r1) / 1024 ))
        local tx_kb=$(( (t2 - t1) / 1024 ))
        printf "  %-18s ↓ %d KB/s  ↑ %d KB/s\n" "Current Speed:" "$rx_kb" "$tx_kb"
    else
        printf "  %-18s N/A\n" "Current Speed:"
    fi
    echo
}

# ─── Port Check ───
network_ports() {
    msg_header "Listening Ports"
    ss -tlnp 2>/dev/null | awk 'NR>1{print "  "$4"\t"$1"\t"$6}' | column -t
    echo
}

# ─── VPN Status ───
network_vpn_status() {
    msg_header "VPN Status"
    
    if command -v tailscale &>/dev/null; then
        echo "  Tailscale:"
        tailscale status 2>/dev/null | head -10 | sed 's/^/    /'
    else
        echo "  Tailscale: not installed"
    fi
    
    if command -v wg &>/dev/null; then
        echo
        echo "  WireGuard:"
        wg show 2>/dev/null | head -10 | sed 's/^/    /'
    fi
    echo
}

# ─── Network Menu ───
network_menu() {
    while true; do
        local options=(
            "Network Status"
            "Listening Ports"
            "VPN Status"
            "Install Tailscale"
            "← Back"
        )
        
        tui_draw_menu "Network Manager" "${options[@]}"
        local choice=$?
        
        case $choice in
            0) clear; network_status; tui_pause ;;
            1) clear; network_ports; tui_pause ;;
            2) clear; network_vpn_status; tui_pause ;;
            3) app_install "tailscale"; tui_pause ;;
            *) return ;;
        esac
    done
}
