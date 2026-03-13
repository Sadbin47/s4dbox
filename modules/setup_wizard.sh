#!/usr/bin/env bash
# s4dbox - First-time setup wizard

# First-time setup app options and ID mapping (single source of truth)
declare -a S4D_SETUP_APP_OPTIONS=(
    "qBittorrent" "Transmission" "rTorrent" "ruTorrent" "Qui"
    "Jellyfin" "Plex" "Sonarr V4" "Prowlarr" "Jackett" "Readarr" "Jellyseerr"
    "FileBrowser" "Nextcloud" "Cloudreve" "MakeTorrent WebUI"
    "autobrr" "autodl-irssi" "CLI Tools Bundle"
    "Tailscale" "WireGuard" "OpenVPN" "VNC Desktop"
    "FileZilla GUI" "JDownloader2 GUI"
)

declare -A S4D_SETUP_APP_MAP=(
    ["qBittorrent"]="qbittorrent"
    ["Transmission"]="transmission"
    ["rTorrent"]="rtorrent"
    ["ruTorrent"]="rutorrent"
    ["Qui"]="qui"
    ["Jellyfin"]="jellyfin"
    ["Plex"]="plex"
    ["Sonarr V4"]="sonarr"
    ["Prowlarr"]="prowlarr"
    ["Jackett"]="jackett"
    ["Readarr"]="readarr"
    ["Jellyseerr"]="jellyseerr"
    ["FileBrowser"]="filebrowser"
    ["Nextcloud"]="nextcloud"
    ["Cloudreve"]="cloudreve"
    ["MakeTorrent WebUI"]="maketorrent_webui"
    ["autobrr"]="autobrr"
    ["autodl-irssi"]="autodl_irssi"
    ["CLI Tools Bundle"]="ssh_tools"
    ["Tailscale"]="tailscale"
    ["WireGuard"]="wireguard"
    ["OpenVPN"]="openvpn"
    ["VNC Desktop"]="vnc_desktop"
    ["FileZilla GUI"]="filezilla_gui"
    ["JDownloader2 GUI"]="jdownloader2_gui"
)

s4d_setup_access_url() {
    local app="$1"
    local ip="$2"
    local port ts_ip

    case "$app" in
        qbittorrent)
            port="$(config_get S4D_QB_PORT 8080)"
            echo "http://${ip}:${port}"
            ;;
        jellyfin)
            port="$(config_get S4D_JELLYFIN_PORT 8096)"
            echo "http://${ip}:${port}"
            ;;
        plex)
            echo "http://${ip}:32400/web"
            ;;
        filebrowser)
            port="$(config_get S4D_FILEBROWSER_PORT 8090)"
            echo "http://${ip}:${port}"
            ;;
        rtorrent)
            echo "SCGI only (no web UI)"
            ;;
        rutorrent)
            port="$(config_get S4D_RUTORRENT_PORT 8081)"
            echo "http://${ip}:${port}"
            ;;
        tailscale)
            ts_ip="$(tailscale ip -4 2>/dev/null || echo 'N/A')"
            echo "Tailscale IP: ${ts_ip}"
            ;;
        wireguard)
            echo "wg-quick@wg0"
            ;;
        openvpn)
            echo "openvpn-server@server"
            ;;
        transmission)
            port="$(config_get S4D_TRANSMISSION_PORT 9091)"
            echo "http://${ip}:${port}/web"
            ;;
        autodl_irssi)
            echo "irssi plugin"
            ;;
        maketorrent_webui)
            port="$(config_get S4D_MAKETORRENT_WEBUI_PORT 8899)"
            echo "http://${ip}:${port}"
            ;;
        sonarr)
            port="$(config_get S4D_SONARR_PORT 8989)"
            echo "http://${ip}:${port}"
            ;;
        prowlarr)
            port="$(config_get S4D_PROWLARR_PORT 9696)"
            echo "http://${ip}:${port}"
            ;;
        jackett)
            port="$(config_get S4D_JACKETT_PORT 9117)"
            echo "http://${ip}:${port}"
            ;;
        readarr)
            port="$(config_get S4D_READARR_PORT 8787)"
            echo "http://${ip}:${port}"
            ;;
        jellyseerr)
            port="$(config_get S4D_JELLYSEERR_PORT 5055)"
            echo "http://${ip}:${port}"
            ;;
        autobrr)
            port="$(config_get S4D_AUTOBRR_PORT 7474)"
            echo "http://${ip}:${port}"
            ;;
        vnc_desktop)
            port="$(config_get S4D_VNC_WEB_PORT 6080)"
            echo "http://${ip}:${port}"
            ;;
        filezilla_gui)
            port="$(config_get S4D_FILEZILLA_WEB_PORT 5801)"
            echo "http://${ip}:${port}"
            ;;
        jdownloader2_gui)
            port="$(config_get S4D_JDOWNLOADER2_WEB_PORT 5802)"
            echo "http://${ip}:${port}"
            ;;
        nextcloud)
            port="$(config_get S4D_NEXTCLOUD_PORT 8082)"
            echo "http://${ip}:${port}"
            ;;
        cloudreve)
            port="$(config_get S4D_CLOUDREVE_PORT 5212)"
            echo "http://${ip}:${port}"
            ;;
        qui)
            port="$(config_get S4D_QUI_PORT 7476)"
            echo "http://${ip}:${port}"
            ;;
        ssh_tools)
            echo "CLI tools installed"
            ;;
        *)
            echo "N/A"
            ;;
    esac
}

s4d_setup_print_cred_line() {
    local text="$1"
    printf "  ${BOLD}${YELLOW}│${RESET}  %-54.54s${BOLD}${YELLOW}│${RESET}\n" "$text"
}

# ─── First-Time Setup ───
first_time_setup() {
    clear
    show_banner
    msg_header "First-Time Setup"

    msg_info "Detected: ${S4D_OS_PRETTY} (${S4D_DISTRO_FAMILY}) on ${S4D_ARCH}"
    echo

    # Update packages
    if tui_confirm "Update system packages?"; then
        spinner_start "Updating packages"
        pkg_update 2>/dev/null
        spinner_stop 0
    fi

    # Install dependencies
    spinner_start "Installing core dependencies"
    install_core_deps 2>/dev/null
    spinner_stop 0

    # User setup
    local username
    if [[ -z "$(get_seedbox_user)" ]]; then
        username="$(prompt_user_setup)"
    else
        username="$(get_seedbox_user)"
        msg_info "Existing user found: ${username}"
    fi

    echo

    # App selection
    msg_step "Select applications to install"
    echo
    local selected_apps
    selected_apps=$(tui_checkbox_menu "Select Applications" "${S4D_SETUP_APP_OPTIONS[@]}")

    if [[ $? -eq 0 ]] && [[ -n "$selected_apps" ]]; then
        while IFS= read -r app_display; do
            local app_id="${S4D_SETUP_APP_MAP[$app_display]:-}"
            [[ -z "$app_id" ]] && continue
            echo
            app_install "$app_id" || true
        done <<< "$selected_apps"
    fi

    echo

    # Tuning
    if tui_confirm "Apply system tuning for optimal seedbox performance?"; then
        tune_apply_all || true
    fi

    # Nginx
    if tui_confirm "Setup Nginx reverse proxy?"; then
        nginx_install || true
        nginx_create_main_server || true
        for app in qbittorrent jellyfin plex filebrowser; do
            app_is_installed "$app" && "nginx_${app}" 2>/dev/null || true
        done
    fi

    # Security
    if tui_confirm "Apply SSH security hardening and firewall?"; then
        ssh_harden || true
        security_fail2ban || true
        firewall_setup || true
    fi

    # Optional router/NAT forwarding step
    if tui_confirm "Configure router port forwarding now? (This exposes selected ports to the public internet)"; then
        network_port_forwarding || true
    fi

    echo

    # ─── Final Summary ───
    clear
    show_banner

    local ip
    ip="$(get_local_ip)"
    local username
    username="$(get_seedbox_user)"

    msg_header "Installation Summary"
    echo
    printf "  ${BOLD}${CYAN}┌────────────────────────────────────────────────────────┐${RESET}\n"
    printf "  ${BOLD}${CYAN}│${RESET}  ${BOLD}Server Information${RESET}                                   ${BOLD}${CYAN}│${RESET}\n"
    printf "  ${BOLD}${CYAN}├────────────────────────────────────────────────────────┤${RESET}\n"
    printf "  ${BOLD}${CYAN}│${RESET}  %-16s %-37s${BOLD}${CYAN}│${RESET}\n" "OS:" "$S4D_OS_PRETTY"
    printf "  ${BOLD}${CYAN}│${RESET}  %-16s %-37s${BOLD}${CYAN}│${RESET}\n" "Architecture:" "$S4D_ARCH"
    printf "  ${BOLD}${CYAN}│${RESET}  %-16s %-37s${BOLD}${CYAN}│${RESET}\n" "IP Address:" "$ip"
    printf "  ${BOLD}${CYAN}│${RESET}  %-16s %-37s${BOLD}${CYAN}│${RESET}\n" "Seedbox User:" "$username"
    printf "  ${BOLD}${CYAN}│${RESET}  %-16s %-37s${BOLD}${CYAN}│${RESET}\n" "RAM:" "${S4D_MEM_TOTAL_MB}MB"
    printf "  ${BOLD}${CYAN}└────────────────────────────────────────────────────────┘${RESET}\n"
    echo

    # Installed Apps Table
    local installed_apps
    installed_apps="$(app_list_installed)"

    if [[ -n "$installed_apps" ]]; then
        printf "  ${BOLD}${GREEN}┌────────────────────────────────────────────────────────┐${RESET}\n"
        printf "  ${BOLD}${GREEN}│${RESET}  ${BOLD}Installed Applications${RESET}                               ${BOLD}${GREEN}│${RESET}\n"
        printf "  ${BOLD}${GREEN}├──────────────────┬────────────┬────────────────────────┤${RESET}\n"
        printf "  ${BOLD}${GREEN}│${RESET} %-16s ${BOLD}${GREEN}│${RESET} %-10s ${BOLD}${GREEN}│${RESET} %-22s ${BOLD}${GREEN}│${RESET}\n" "Application" "Status" "Access URL"
        printf "  ${BOLD}${GREEN}├──────────────────┼────────────┼────────────────────────┤${RESET}\n"

        while IFS= read -r app; do
            local status url status_color
            status="$(app_status "$app")"

            if [[ "$status" == "running" ]]; then
                status_color="${GREEN}"
            elif [[ "$status" == "configured" ]]; then
                status_color="${YELLOW}"
            else
                status_color="${RED}"
            fi
            url="$(s4d_setup_access_url "$app" "$ip")"

            printf "  ${BOLD}${GREEN}│${RESET} %-16s ${BOLD}${GREEN}│${RESET} ${status_color}%-10s${RESET} ${BOLD}${GREEN}│${RESET} %-22s ${BOLD}${GREEN}│${RESET}\n" "$app" "$status" "$url"
        done <<< "$installed_apps"

        printf "  ${BOLD}${GREEN}└──────────────────┴────────────┴────────────────────────┘${RESET}\n"
    fi

    echo

    if [[ -n "$installed_apps" ]]; then
        local needs_action=0
        while IFS= read -r app; do
            local status
            status="$(app_status "$app")"
            [[ "$status" == "stopped" || "$status" == "configured" ]] && needs_action=1
        done <<< "$installed_apps"

        if [[ $needs_action -eq 1 ]]; then
            printf "  ${BOLD}${MAGENTA}Action Required${RESET}\n"
            while IFS= read -r app; do
                local status
                status="$(app_status "$app")"

                case "$status" in
                    stopped)
                        if tui_confirm "${app} is installed but stopped. Start it now?"; then
                            if app_restart "$app"; then
                                msg_ok "${app} started"
                            else
                                msg_warn "Could not start ${app}. Check: systemctl status"
                            fi
                        fi
                        ;;
                    configured)
                        case "$app" in
                            wireguard)
                                msg_warn "wireguard needs /etc/wireguard/wg0.conf"
                                if tui_confirm "Try starting WireGuard now anyway?"; then
                                    app_restart "$app" || msg_warn "WireGuard start failed (likely missing config)"
                                fi
                                ;;
                            openvpn)
                                msg_warn "openvpn needs /etc/openvpn/server/server.conf"
                                if tui_confirm "Try starting OpenVPN now anyway?"; then
                                    app_restart "$app" || msg_warn "OpenVPN start failed (likely missing config)"
                                fi
                                ;;
                            autodl_irssi)
                                msg_info "autodl-irssi is a plugin and does not run as a service"
                                ;;
                            ssh_tools)
                                msg_info "CLI tools bundle installed (no long-running service)"
                                ;;
                        esac
                        ;;
                esac
            done <<< "$installed_apps"
        fi
    fi

    echo

    # Credentials
    printf "  ${BOLD}${YELLOW}┌────────────────────────────────────────────────────────┐${RESET}\n"
    printf "  ${BOLD}${YELLOW}│${RESET}  ${BOLD}Credentials & Access${RESET}                                ${BOLD}${YELLOW}│${RESET}\n"
    printf "  ${BOLD}${YELLOW}├────────────────────────────────────────────────────────┤${RESET}\n"
    s4d_setup_print_cred_line "Seedbox User: ${username}"
    s4d_setup_print_cred_line "Password: (you set this during user creation)"
    s4d_setup_print_cred_line ""

    if [[ -n "$installed_apps" ]]; then
        while IFS= read -r app; do
            local label url hint tx_user
            label="${S4D_APP_DESC[$app]:-$app}"
            label="${label%% - *}"
            url="$(s4d_setup_access_url "$app" "$ip")"
            s4d_setup_print_cred_line "${label}: ${url}"

            case "$app" in
                qbittorrent)
                    hint="User: ${username} | Pass: set during qB install"
                    ;;
                transmission)
                    tx_user="$(config_get S4D_TRANSMISSION_USER "$username")"
                    hint="User: ${tx_user} | Pass: set during Transmission install"
                    ;;
                rutorrent)
                    hint="User: ${username} | Pass: set during ruTorrent install"
                    ;;
                filebrowser)
                    hint="User: ${username} | Pass: set during FileBrowser install"
                    ;;
                jellyfin|plex|nextcloud|cloudreve|jellyseerr)
                    hint="Finish web setup wizard on first visit"
                    ;;
                sonarr|prowlarr|jackett|readarr|autobrr|qui)
                    hint="Configure app from the web UI"
                    ;;
                wireguard)
                    hint="Needs /etc/wireguard/wg0.conf before start"
                    ;;
                openvpn)
                    hint="Needs /etc/openvpn/server/server.conf before start"
                    ;;
                tailscale)
                    hint="Run: tailscale up (if not already connected)"
                    ;;
                autodl_irssi)
                    hint="Plugin for irssi/rTorrent; no standalone login"
                    ;;
                ssh_tools)
                    hint="CLI tools only; no web login"
                    ;;
                maketorrent_webui|vnc_desktop|filezilla_gui|jdownloader2_gui)
                    hint="Open URL and complete in-app setup"
                    ;;
                rtorrent)
                    hint="Managed via rTorrent session; pair with ruTorrent"
                    ;;
                *)
                    hint="See app documentation for auth/setup"
                    ;;
            esac

            s4d_setup_print_cred_line "${hint}"
            s4d_setup_print_cred_line ""
        done <<< "$installed_apps"
    fi

    printf "  ${BOLD}${YELLOW}└────────────────────────────────────────────────────────┘${RESET}\n"
    echo

    printf "  ${BOLD}${GREEN}Setup complete!${RESET} Run ${BOLD}sudo s4dbox${RESET} to manage your seedbox.\n"
    echo
    tui_pause
}
