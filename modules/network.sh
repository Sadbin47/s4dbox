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

# ─── Port Forwarding (UPnP/NAT-PMP) ───
network_port_forwarding() {
    msg_header "Port Forwarding Wizard"
    msg_warn "You are about to configure router port forwarding."
    msg_warn "Forwarded ports are reachable from the public internet."
    msg_info "Continue only if you understand the security impact."

    if ! tui_confirm "Proceed with port forwarding setup?"; then
        msg_info "Port forwarding skipped"
        return 0
    fi

    if ! command -v upnpc &>/dev/null; then
        msg_info "UPnP client not found (upnpc). Installing miniupnpc..."
        if ! pkg_install miniupnpc; then
            msg_error "Could not install miniupnpc/upnpc"
            return 1
        fi
    fi

    local local_ip
    local_ip="$(get_local_ip)"
    if [[ -z "$local_ip" ]]; then
        msg_error "Could not detect local IP"
        return 1
    fi

    local entries=()
    local p

    app_is_installed "qbittorrent" && {
        p="$(config_get S4D_QB_PORT 8080)"
        entries+=("${p}:TCP:qBittorrent-WebUI")
        p="$(config_get S4D_QB_INCOMING_PORT 45000)"
        entries+=("${p}:TCP:qBittorrent-Incoming")
        entries+=("${p}:UDP:qBittorrent-Incoming")
    }
    app_is_installed "transmission" && entries+=("$(config_get S4D_TRANSMISSION_PORT 9091):TCP:Transmission-WebUI")
    app_is_installed "rutorrent" && entries+=("$(config_get S4D_RUTORRENT_PORT 8081):TCP:ruTorrent")
    app_is_installed "jellyfin" && entries+=("$(config_get S4D_JELLYFIN_PORT 8096):TCP:Jellyfin")
    app_is_installed "plex" && entries+=("32400:TCP:Plex")
    app_is_installed "filebrowser" && entries+=("$(config_get S4D_FILEBROWSER_PORT 8090):TCP:FileBrowser")
    app_is_installed "sonarr" && entries+=("$(config_get S4D_SONARR_PORT 8989):TCP:Sonarr")
    app_is_installed "prowlarr" && entries+=("$(config_get S4D_PROWLARR_PORT 9696):TCP:Prowlarr")
    app_is_installed "jackett" && entries+=("$(config_get S4D_JACKETT_PORT 9117):TCP:Jackett")
    app_is_installed "jellyseerr" && entries+=("$(config_get S4D_JELLYSEERR_PORT 5055):TCP:Jellyseerr")
    app_is_installed "autobrr" && entries+=("$(config_get S4D_AUTOBRR_PORT 7474):TCP:autobrr")
    app_is_installed "maketorrent_webui" && entries+=("$(config_get S4D_MAKETORRENT_WEBUI_PORT 8899):TCP:MakeTorrent-WebUI")
    app_is_installed "nextcloud" && entries+=("$(config_get S4D_NEXTCLOUD_PORT 8082):TCP:Nextcloud")
    app_is_installed "cloudreve" && entries+=("$(config_get S4D_CLOUDREVE_PORT 5212):TCP:Cloudreve")
    app_is_installed "qui" && entries+=("$(config_get S4D_QUI_PORT 7476):TCP:Qui")
    app_is_installed "vnc_desktop" && {
        entries+=("$(config_get S4D_VNC_WEB_PORT 6080):TCP:VNC-Web")
        entries+=("$(config_get S4D_VNC_PORT 5900):TCP:VNC")
    }
    app_is_installed "filezilla_gui" && {
        entries+=("$(config_get S4D_FILEZILLA_WEB_PORT 5801):TCP:FileZilla-Web")
        entries+=("$(config_get S4D_FILEZILLA_VNC_PORT 5901):TCP:FileZilla-VNC")
    }
    app_is_installed "jdownloader2_gui" && {
        entries+=("$(config_get S4D_JDOWNLOADER2_WEB_PORT 5802):TCP:JDownloader2-Web")
        entries+=("$(config_get S4D_JDOWNLOADER2_VNC_PORT 5902):TCP:JDownloader2-VNC")
    }

    if [[ ${#entries[@]} -eq 0 ]]; then
        msg_warn "No installed app ports found to forward"
        return 0
    fi

    echo
    msg_info "Detected forward candidates:"
    local i=1
    local item
    for item in "${entries[@]}"; do
        IFS=':' read -r p proto name <<< "$item"
        printf "  %2d) %-5s %-4s (%s)\n" "$i" "$p" "$proto" "$name"
        i=$((i + 1))
    done
    echo

    local forward_all
    if tui_confirm "Forward all detected ports?"; then
        forward_all=1
    else
        forward_all=0
    fi

    local success=0 failed=0
    if [[ "$forward_all" -eq 1 ]]; then
        for item in "${entries[@]}"; do
            IFS=':' read -r p proto name <<< "$item"
            if upnpc -a "$local_ip" "$p" "$p" "$proto" >/dev/null 2>&1; then
                msg_ok "Forwarded ${name} on ${p}/${proto}"
                success=$((success + 1))
            else
                msg_warn "Failed to forward ${name} on ${p}/${proto}"
                failed=$((failed + 1))
            fi
        done
    else
        for item in "${entries[@]}"; do
            IFS=':' read -r p proto name <<< "$item"
            if tui_confirm "Forward ${name} on ${p}/${proto}?"; then
                if upnpc -a "$local_ip" "$p" "$p" "$proto" >/dev/null 2>&1; then
                    msg_ok "Forwarded ${name} on ${p}/${proto}"
                    success=$((success + 1))
                else
                    msg_warn "Failed to forward ${name} on ${p}/${proto}"
                    failed=$((failed + 1))
                fi
            fi
        done
    fi

    echo
    msg_info "Port forwarding completed: ${success} success, ${failed} failed"
    msg_info "If all fail, your router may not support UPnP/NAT-PMP or it is disabled"
    return 0
}

# ─── Network Menu ───
network_menu() {
    while true; do
        local options=(
            "Network Info"
            "Network Status"
            "Listening Ports"
            "VPN Status"
            "Port Forwarding (UPnP/NAT-PMP)"
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
            4) clear; network_port_forwarding; tui_pause ;;
            5) app_install "tailscale"; tui_pause ;;
            *) return ;;
        esac
    done
}
