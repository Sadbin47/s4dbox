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

network_firewall_allow_port() {
    local port="$1"
    local proto="$2"

    [[ "$port" =~ ^[0-9]+$ ]] || return 1
    [[ "$port" -ge 1 && "$port" -le 65535 ]] || return 1
    [[ "$proto" == "TCP" || "$proto" == "UDP" ]] || return 1

    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -qi '^Status: active'; then
        ufw allow "${port}/${proto,,}" comment "s4dbox port-forward" >/dev/null 2>&1
        return $?
    fi

    if command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
        firewall-cmd --permanent --add-port="${port}/${proto,,}" >/dev/null 2>&1 || return 1
        firewall-cmd --reload >/dev/null 2>&1 || return 1
        return 0
    fi

    return 2
}

network_add_forward_entry() {
    local -n _entries_ref=$1
    local port="$2"
    local proto="$3"
    local name="$4"

    [[ "$port" =~ ^[0-9]+$ ]] || return 0
    [[ "$port" -ge 1 && "$port" -le 65535 ]] || return 0
    [[ "$proto" == "TCP" || "$proto" == "UDP" ]] || return 0
    _entries_ref+=("${port}:${proto}:${name}")
}

network_forward_port() {
    local backend="$1"
    local local_ip="$2"
    local port="$3"
    local proto="$4"
    local output rc

    NETWORK_FORWARD_LAST_ERROR=""

    case "$backend" in
        upnp)
            output="$(upnpc -a "$local_ip" "$port" "$port" "$proto" 2>&1)"
            rc=$?
            ;;
        natpmp)
            output="$(natpmpc -a "$port" "$port" "${proto,,}" 3600 2>&1)"
            rc=$?
            ;;
        *)
            NETWORK_FORWARD_LAST_ERROR="Unknown forwarding backend: ${backend}"
            return 1
            ;;
    esac

    NETWORK_FORWARD_LAST_ERROR="$(echo "$output" | head -1)"
    [[ $rc -eq 0 ]] || return 1

    if echo "$output" | grep -qiE 'failed|error|refused|unsupported|denied|no gateway|not found'; then
        return 1
    fi

    if [[ "$backend" == "natpmp" ]] && ! echo "$output" | grep -qiE 'Mapped public port|public address|is redirected'; then
        NETWORK_FORWARD_LAST_ERROR="$(echo "$output" | grep -m1 -E 'TRY AGAIN|timed out|refused|error|failed' || echo "$NETWORK_FORWARD_LAST_ERROR")"
        return 1
    fi

    return 0
}

network_print_manual_forward_table() {
    local local_ip="$1"
    local -n _entries_ref=$2
    local item port proto name

    [[ ${#_entries_ref[@]} -gt 0 ]] || return 0

    echo
    msg_warn "Manual router forwarding is required"
    msg_info "Add these rules in your router (WAN -> ${local_ip}):"
    printf "  %-7s %-7s %-4s %s\n" "WAN" "LAN" "Proto" "Service"
    printf "  %-7s %-7s %-4s %s\n" "-------" "-------" "----" "----------------------"
    for item in "${_entries_ref[@]}"; do
        IFS=':' read -r port proto name <<< "$item"
        printf "  %-7s %-7s %-4s %s\n" "$port" "$port" "$proto" "$name"
    done
    echo
}

network_open_firewall_for_entries() {
    local -n _entries_ref=$1
    local item port proto name
    local opened=0 failed=0

    for item in "${_entries_ref[@]}"; do
        IFS=':' read -r port proto name <<< "$item"
        network_firewall_allow_port "$port" "$proto"
        case $? in
            0)
                msg_ok "Opened firewall for ${name} on ${port}/${proto}"
                opened=$((opened + 1))
                ;;
            1)
                msg_warn "Could not open firewall for ${name} on ${port}/${proto}"
                failed=$((failed + 1))
                ;;
        esac
    done

    msg_info "Firewall update completed: ${opened} opened, ${failed} failed"
}

network_is_private_ip() {
    local ip="$1"
    [[ "$ip" =~ ^10\. ]] && return 0
    [[ "$ip" =~ ^192\.168\. ]] && return 0
    [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && return 0
    [[ "$ip" =~ ^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\. ]] && return 0
    [[ "$ip" == "127.0.0.1" ]] && return 0
    return 1
}

network_firewall_port_state() {
    local port="$1"
    local proto="${2,,}"
    local svc_ports svc_services

    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -qi '^Status: active'; then
        if ufw status 2>/dev/null | grep -qiE "(^|[[:space:]])${port}/${proto}([[:space:]]|$)"; then
            echo "open"
        else
            echo "closed"
        fi
        return
    fi

    if command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
        svc_ports="$(firewall-cmd --list-ports 2>/dev/null || true)"
        svc_services="$(firewall-cmd --list-services 2>/dev/null || true)"

        if echo "$svc_ports" | grep -qiE "(^|[[:space:]])${port}/${proto}([[:space:]]|$)"; then
            echo "open"
            return
        fi

        if [[ "$proto" == "tcp" && "$port" == "80" ]] && echo "$svc_services" | grep -qw "http"; then
            echo "open"
            return
        fi
        if [[ "$proto" == "tcp" && "$port" == "443" ]] && echo "$svc_services" | grep -qw "https"; then
            echo "open"
            return
        fi

        echo "closed"
        return
    fi

    echo "n/a"
}

network_webui_doctor() {
    clear
    msg_header "WebUI Doctor"

    local installed app port status bind_state http_code http_state fw_state
    local ip_local ip_public gateway
    local upnp_state="unavailable"
    local ok_count=0 warn_count=0 fail_count=0

    ip_local="$(get_local_ip)"
    gateway="$(ip route | awk '/default/{print $3; exit}')"
    ip_public="$(curl -s --max-time 5 -4 https://ifconfig.me 2>/dev/null || curl -s --max-time 5 -4 https://api.ipify.org 2>/dev/null)"

    if command -v upnpc &>/dev/null; then
        if upnpc -l 2>/dev/null | grep -qiE 'No IGD UPnP Device found|No valid UPNP Internet Gateway Device|UPnP Device not found'; then
            upnp_state="not detected"
        else
            upnp_state="detected"
        fi
    fi

    printf "  %-16s %s\n" "Local IP:" "${ip_local:-N/A}"
    printf "  %-16s %s\n" "Public IP:" "${ip_public:-N/A}"
    printf "  %-16s %s\n" "Gateway:" "${gateway:-N/A}"
    printf "  %-16s %s\n" "UPnP IGD:" "${upnp_state}"
    if command -v docker &>/dev/null; then
        printf "  %-16s %s\n" "Docker daemon:" "$(systemctl is-active docker 2>/dev/null || echo inactive)"
    fi
    echo

    installed="$(app_list_installed)"
    if [[ -z "$installed" ]]; then
        msg_info "No installed applications found"
        echo
        return 0
    fi

    printf "  %-18s %-10s %-6s %-6s %-8s %-8s\n" "App" "Status" "Port" "Bind" "HTTP" "Firewall"
    printf "  %-18s %-10s %-6s %-6s %-8s %-8s\n" "------------------" "----------" "------" "------" "--------" "--------"

    while IFS= read -r app; do
        port="$(app_get_web_port "$app")"
        [[ -z "$port" ]] && continue

        status="$(app_status "$app")"

        if ss -tuln 2>/dev/null | grep -qE "[\.:]${port}[[:space:]]"; then
            bind_state="yes"
        else
            bind_state="no"
        fi

        http_code="$(curl -sS -m 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/" 2>/dev/null || echo 000)"
        if [[ "$http_code" == "000" ]]; then
            http_state="down"
        else
            http_state="$http_code"
        fi

        fw_state="$(network_firewall_port_state "$port" "tcp")"

        printf "  %-18s %-10s %-6s %-6s %-8s %-8s\n" "$app" "$status" "$port" "$bind_state" "$http_state" "$fw_state"

        if [[ "$status" == "running" && "$bind_state" == "yes" && "$http_state" != "down" ]]; then
            ok_count=$((ok_count + 1))
        elif [[ "$status" == "running" || "$bind_state" == "yes" ]]; then
            warn_count=$((warn_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done <<< "$installed"

    echo
    msg_info "Doctor summary: ${ok_count} healthy, ${warn_count} warning, ${fail_count} failing"

    if [[ -n "$gateway" ]] && ! network_is_private_ip "$gateway"; then
        msg_warn "Gateway looks provider-managed (${gateway}); router UPnP port-forward is usually unavailable"
        msg_info "Use provider firewall/NAT panel for public access rules"
    fi

    if command -v docker &>/dev/null && ! systemctl is-active docker &>/dev/null; then
        msg_warn "Docker daemon is inactive; Docker-based app WebUIs will fail"
        msg_info "Run: systemctl enable --now docker"
    fi

    if [[ "$upnp_state" != "detected" ]]; then
        msg_info "UPnP not detected; automatic forwarding may not work in this environment"
    fi

    echo
    msg_info "If app is down: Application Manager -> Restart Application"
    msg_info "If bind=no: check container/service logs (systemctl status, docker ps, journalctl)"
    msg_info "If firewall=closed: run Security & Firewall setup or open the listed port"
    return 0
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
        network_add_forward_entry entries "$p" "TCP" "qBittorrent-WebUI"
        p="$(config_get S4D_QB_INCOMING_PORT 45000)"
        network_add_forward_entry entries "$p" "TCP" "qBittorrent-Incoming"
        network_add_forward_entry entries "$p" "UDP" "qBittorrent-Incoming"
    }
    app_is_installed "transmission" && network_add_forward_entry entries "$(config_get S4D_TRANSMISSION_PORT 9091)" "TCP" "Transmission-WebUI"
    app_is_installed "rutorrent" && network_add_forward_entry entries "$(config_get S4D_RUTORRENT_PORT 8081)" "TCP" "ruTorrent"
    app_is_installed "jellyfin" && network_add_forward_entry entries "$(config_get S4D_JELLYFIN_PORT 8096)" "TCP" "Jellyfin"
    app_is_installed "plex" && network_add_forward_entry entries "32400" "TCP" "Plex"
    app_is_installed "filebrowser" && network_add_forward_entry entries "$(config_get S4D_FILEBROWSER_PORT 8090)" "TCP" "FileBrowser"
    app_is_installed "sonarr" && network_add_forward_entry entries "$(config_get S4D_SONARR_PORT 8989)" "TCP" "Sonarr"
    app_is_installed "prowlarr" && network_add_forward_entry entries "$(config_get S4D_PROWLARR_PORT 9696)" "TCP" "Prowlarr"
    app_is_installed "jackett" && network_add_forward_entry entries "$(config_get S4D_JACKETT_PORT 9117)" "TCP" "Jackett"
    app_is_installed "jellyseerr" && network_add_forward_entry entries "$(config_get S4D_JELLYSEERR_PORT 5055)" "TCP" "Jellyseerr"
    app_is_installed "autobrr" && network_add_forward_entry entries "$(config_get S4D_AUTOBRR_PORT 7474)" "TCP" "autobrr"
    app_is_installed "maketorrent_webui" && network_add_forward_entry entries "$(config_get S4D_MAKETORRENT_WEBUI_PORT 8899)" "TCP" "MakeTorrent-WebUI"
    app_is_installed "nextcloud" && network_add_forward_entry entries "$(config_get S4D_NEXTCLOUD_PORT 8082)" "TCP" "Nextcloud"
    app_is_installed "cloudreve" && network_add_forward_entry entries "$(config_get S4D_CLOUDREVE_PORT 5212)" "TCP" "Cloudreve"
    app_is_installed "qui" && network_add_forward_entry entries "$(config_get S4D_QUI_PORT 7476)" "TCP" "Qui"

    if [[ "$(config_get S4D_NGINX_ENABLED 0)" == "1" ]] || systemctl is-active nginx &>/dev/null; then
        network_add_forward_entry entries "80" "TCP" "HTTP"
        network_add_forward_entry entries "443" "TCP" "HTTPS"
    fi

    app_is_installed "vnc_desktop" && {
        network_add_forward_entry entries "$(config_get S4D_VNC_WEB_PORT 6080)" "TCP" "VNC-Web"
        network_add_forward_entry entries "$(config_get S4D_VNC_PORT 5900)" "TCP" "VNC"
    }
    app_is_installed "filezilla_gui" && {
        network_add_forward_entry entries "$(config_get S4D_FILEZILLA_WEB_PORT 5801)" "TCP" "FileZilla-Web"
        network_add_forward_entry entries "$(config_get S4D_FILEZILLA_VNC_PORT 5901)" "TCP" "FileZilla-VNC"
    }
    app_is_installed "jdownloader2_gui" && {
        network_add_forward_entry entries "$(config_get S4D_JDOWNLOADER2_WEB_PORT 5802)" "TCP" "JDownloader2-Web"
        network_add_forward_entry entries "$(config_get S4D_JDOWNLOADER2_VNC_PORT 5902)" "TCP" "JDownloader2-VNC"
    }

    if [[ ${#entries[@]} -eq 0 ]]; then
        msg_warn "No installed app ports found to forward"
        return 0
    fi

    local forward_backend=""
    local upnp_probe=""
    local natpmp_probe=""
    upnp_probe="$(upnpc -l 2>&1)"
    if [[ $? -eq 0 ]] && ! echo "$upnp_probe" | grep -qiE 'No IGD UPnP Device found|No valid UPNP Internet Gateway Device|UPnP Device not found'; then
        forward_backend="upnp"
        msg_info "Router mapping backend: UPnP"
    else
        if ! command -v natpmpc &>/dev/null; then
            pkg_install natpmpc >/dev/null 2>&1 || pkg_install libnatpmp >/dev/null 2>&1 || true
        fi

        if command -v natpmpc &>/dev/null; then
            natpmp_probe="$(natpmpc 2>&1 || true)"
            if echo "$natpmp_probe" | grep -qiE 'TRY AGAIN|timed out|refused|error|failed'; then
                msg_warn "NAT-PMP probe did not respond"
            else
                forward_backend="natpmp"
                msg_warn "UPnP gateway not found. Falling back to NAT-PMP."
            fi
        fi

        if [[ -z "$forward_backend" ]]; then
            msg_error "Router auto-port-forwarding unavailable (UPnP/NAT-PMP not responding)"
            msg_info "UPnP probe: $(echo "$upnp_probe" | head -1)"
            [[ -n "$natpmp_probe" ]] && msg_info "NAT-PMP probe: $(echo "$natpmp_probe" | grep -m1 -E 'TRY AGAIN|timed out|refused|error|failed' || echo 'no response')"
            msg_info "This is common on VPS/provider networks; use provider firewall/NAT panel instead"

            if tui_confirm "Open local firewall rules for detected ports now?"; then
                network_open_firewall_for_entries entries
            fi

            network_print_manual_forward_table "$local_ip" entries
            return 0
        fi
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

    local success=0 failed=0 fw_opened=0 fw_failed=0
    local failed_entries=()
    local first_forward_error=""
    if [[ "$forward_all" -eq 1 ]]; then
        for item in "${entries[@]}"; do
            IFS=':' read -r p proto name <<< "$item"
            if network_forward_port "$forward_backend" "$local_ip" "$p" "$proto"; then
                msg_ok "Forwarded ${name} on ${p}/${proto}"
                success=$((success + 1))

                network_firewall_allow_port "$p" "$proto"
                case $? in
                    0) fw_opened=$((fw_opened + 1)) ;;
                    1) fw_failed=$((fw_failed + 1)) ;;
                esac
            else
                msg_warn "Failed to forward ${name} on ${p}/${proto}"
                failed_entries+=("$item")
                [[ -z "$first_forward_error" ]] && first_forward_error="$NETWORK_FORWARD_LAST_ERROR"
                failed=$((failed + 1))
            fi
        done
    else
        for item in "${entries[@]}"; do
            IFS=':' read -r p proto name <<< "$item"
            if tui_confirm "Forward ${name} on ${p}/${proto}?"; then
                if network_forward_port "$forward_backend" "$local_ip" "$p" "$proto"; then
                    msg_ok "Forwarded ${name} on ${p}/${proto}"
                    success=$((success + 1))

                    network_firewall_allow_port "$p" "$proto"
                    case $? in
                        0) fw_opened=$((fw_opened + 1)) ;;
                        1) fw_failed=$((fw_failed + 1)) ;;
                    esac
                else
                    msg_warn "Failed to forward ${name} on ${p}/${proto}"
                    failed_entries+=("$item")
                    [[ -z "$first_forward_error" ]] && first_forward_error="$NETWORK_FORWARD_LAST_ERROR"
                    failed=$((failed + 1))
                fi
            fi
        done
    fi

    echo
    msg_info "Port forwarding completed: ${success} success, ${failed} failed"
    if [[ "$fw_opened" -gt 0 ]]; then
        msg_info "Local firewall rules opened for ${fw_opened} forwarded mappings"
    fi
    if [[ "$fw_failed" -gt 0 ]]; then
        msg_warn "${fw_failed} local firewall rules could not be added"
    fi
    if [[ "$failed" -gt 0 ]]; then
        [[ -n "$first_forward_error" ]] && msg_warn "Router reply: ${first_forward_error}"
        msg_info "If mappings fail, check router UPnP/NAT-PMP settings and run: upnpc -l"
        network_print_manual_forward_table "$local_ip" failed_entries
    fi
    msg_info "If website access still fails, verify service is listening: ss -tulpen | grep ':80\\|:443'"
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
            "WebUI Doctor"
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
            5) clear; network_webui_doctor; tui_pause ;;
            6) app_install "tailscale"; tui_pause ;;
            *) return ;;
        esac
    done
}
