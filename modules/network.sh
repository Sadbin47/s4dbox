#!/usr/bin/env bash
# s4dbox - Network Manager
# Network status, VPN management, bandwidth monitoring

# ─── Detailed Network Info (ISP, ASN, location) ───
network_info() {
    clear

    # Get public IP and geo info from ip-api.com (free, no key needed)
    local json=""
    if command -v curl &>/dev/null; then
        json="$(curl -s --max-time 10 'http://ip-api.com/json/?fields=status,query,isp,as,org,city,regionName,country,countryCode' 2>/dev/null)"
    elif command -v wget &>/dev/null; then
        json="$(wget -qO- --timeout=10 'http://ip-api.com/json/?fields=status,query,isp,as,org,city,regionName,country,countryCode' 2>/dev/null)"
    fi

    # Check IPv4
    local ipv4="" ipv4_status
    ipv4="$(curl -s --max-time 5 -4 https://ifconfig.me 2>/dev/null || curl -s --max-time 5 -4 https://api.ipify.org 2>/dev/null)"
    if [[ -n "$ipv4" ]]; then
        ipv4_status="${GREEN}✔ Online${RESET}"
    else
        ipv4_status="${RED}❌ Offline${RESET}"
    fi

    # Check IPv6
    local ipv6="" ipv6_status
    ipv6="$(curl -s --max-time 5 -6 https://ifconfig.me 2>/dev/null || curl -s --max-time 5 -6 https://api6.ipify.org 2>/dev/null)"
    if [[ -n "$ipv6" ]]; then
        ipv6_status="${GREEN}✔ Online${RESET}"
    else
        ipv6_status="${RED}❌ Offline${RESET}"
    fi

    # Primary network type
    local primary_net="IPv4"
    [[ -z "$ipv4" && -n "$ipv6" ]] && primary_net="IPv6"

    # Parse JSON (use jq if available, otherwise grep/sed)
    local isp="" asn="" org="" city="" region="" country="" country_code=""
    if command -v jq &>/dev/null && [[ -n "$json" ]]; then
        isp="$(echo "$json" | jq -r '.isp // "N/A"')"
        asn="$(echo "$json" | jq -r '.as // "N/A"')"
        org="$(echo "$json" | jq -r '.org // "N/A"')"
        city="$(echo "$json" | jq -r '.city // "N/A"')"
        region="$(echo "$json" | jq -r '.regionName // "N/A"')"
        country="$(echo "$json" | jq -r '.country // "N/A"')"
        country_code="$(echo "$json" | jq -r '.countryCode // ""')"
    elif [[ -n "$json" ]]; then
        # Fallback: manual parsing without jq
        _json_val() { echo "$json" | sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" | head -1; }
        isp="$(_json_val isp)"
        asn="$(_json_val as)"
        org="$(_json_val org)"
        city="$(_json_val city)"
        region="$(_json_val regionName)"
        country="$(_json_val country)"
        country_code="$(_json_val countryCode)"
    fi

    local location=""
    [[ -n "$city" ]] && location="${city}"
    [[ -n "$region" ]] && location="${location}, ${region}"
    [[ -n "$country_code" ]] && location="${location}, ${country_code}"

    local ipv4_location=""
    [[ -n "$city" ]] && ipv4_location="${city}, ${region:-$country}, ${country_code:-$country}"

    # Render
    printf "\n"
    printf "  ${BOLD}${CYAN}"
    printf ' ---------------------------------------------------------------------------\n'
    printf '  Basic Network Info\n'
    printf ' ---------------------------------------------------------------------------\n'
    printf "  ${RESET}"
    printf "  %-20s: %s\n" " Primary Network" "$primary_net"
    printf "  %-20s: %b\n" " IPv6 Access" "$ipv6_status"
    printf "  %-20s: %b\n" " IPv4 Access" "$ipv4_status"
    [[ -n "$ipv4" ]] && printf "  %-20s: %s\n" " IPv4 Address" "$ipv4"
    [[ -n "$ipv6" ]] && printf "  %-20s: %s\n" " IPv6 Address" "$ipv6"
    printf "  %-20s: %s\n" " ISP" "${isp:-N/A}"
    printf "  %-20s: %s\n" " ASN" "${asn:-N/A}"
    printf "  %-20s: %s\n" " Host" "${org:-N/A}"
    printf "  %-20s: %s\n" " Location" "${location:-N/A}"
    [[ -n "$ipv4" ]] && printf "  %-20s: %s\n" " Location (IPv4)" "${ipv4_location:-N/A}"
    printf "  ${BOLD}${CYAN}"
    printf ' ---------------------------------------------------------------------------\n'
    printf "  ${RESET}"
    echo
}

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
            "Network Info"
            "Network Status"
            "Listening Ports"
            "VPN Status"
            "Install Tailscale"
            "← Back"
        )
        
        tui_draw_menu "Network Manager" "${options[@]}"
        local choice=$?
        
        case $choice in
            0) network_info; tui_pause ;;
            1) clear; network_status; tui_pause ;;
            2) clear; network_ports; tui_pause ;;
            3) clear; network_vpn_status; tui_pause ;;
            4) app_install "tailscale"; tui_pause ;;
            *) return ;;
        esac
    done
}
