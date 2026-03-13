#!/usr/bin/env bash
# s4dbox - First-time setup wizard

# First-time setup app options and ID mapping (single source of truth)
declare -a S4D_SETUP_APP_OPTIONS=(
    "qBittorrent" "Transmission" "rTorrent" "ruTorrent" "Qui"
    "Jellyfin" "Plex" "Sonarr V4" "Readarr" "Jellyseerr"
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
            local status port url status_color
            status="$(app_status "$app")"

            if [[ "$status" == "running" ]]; then
                status_color="${GREEN}"
            else
                status_color="${RED}"
            fi

            case "$app" in
                qbittorrent)
                    port="$(config_get S4D_QB_PORT 8080)"
                    url="http://${ip}:${port}"
                    ;;
                jellyfin)
                    port="$(config_get S4D_JELLYFIN_PORT 8096)"
                    url="http://${ip}:${port}"
                    ;;
                plex)
                    url="http://${ip}:32400/web"
                    ;;
                filebrowser)
                    port="$(config_get S4D_FILEBROWSER_PORT 8090)"
                    url="http://${ip}:${port}"
                    ;;
                rtorrent)
                    url="(SCGI - no web UI)"
                    ;;
                rutorrent)
                    port="$(config_get S4D_RUTORRENT_PORT 8081)"
                    url="http://${ip}:${port}"
                    ;;
                tailscale)
                    local ts_ip
                    ts_ip="$(tailscale ip -4 2>/dev/null || echo 'N/A')"
                    url="IP: ${ts_ip}"
                    ;;
                wireguard)
                    url="wg-quick@wg0"
                    ;;
                openvpn)
                    url="openvpn-server@server"
                    ;;
                transmission)
                    port="$(config_get S4D_TRANSMISSION_PORT 9091)"
                    url="http://${ip}:${port}/web"
                    ;;
                autodl_irssi)
                    url="irssi plugin"
                    ;;
                maketorrent_webui)
                    port="$(config_get S4D_MAKETORRENT_WEBUI_PORT 8899)"
                    url="http://${ip}:${port}"
                    ;;
                sonarr)
                    port="$(config_get S4D_SONARR_PORT 8989)"
                    url="http://${ip}:${port}"
                    ;;
                readarr)
                    port="$(config_get S4D_READARR_PORT 8787)"
                    url="http://${ip}:${port}"
                    ;;
                jellyseerr)
                    port="$(config_get S4D_JELLYSEERR_PORT 5055)"
                    url="http://${ip}:${port}"
                    ;;
                autobrr)
                    port="$(config_get S4D_AUTOBRR_PORT 7474)"
                    url="http://${ip}:${port}"
                    ;;
                vnc_desktop)
                    port="$(config_get S4D_VNC_WEB_PORT 6080)"
                    url="http://${ip}:${port}"
                    ;;
                filezilla_gui)
                    port="$(config_get S4D_FILEZILLA_WEB_PORT 5801)"
                    url="http://${ip}:${port}"
                    ;;
                jdownloader2_gui)
                    port="$(config_get S4D_JDOWNLOADER2_WEB_PORT 5802)"
                    url="http://${ip}:${port}"
                    ;;
                nextcloud)
                    port="$(config_get S4D_NEXTCLOUD_PORT 8082)"
                    url="http://${ip}:${port}"
                    ;;
                cloudreve)
                    port="$(config_get S4D_CLOUDREVE_PORT 5212)"
                    url="http://${ip}:${port}"
                    ;;
                qui)
                    port="$(config_get S4D_QUI_PORT 7476)"
                    url="http://${ip}:${port}"
                    ;;
                ssh_tools)
                    url="CLI tools installed"
                    ;;
                *)
                    url="N/A"
                    ;;
            esac

            printf "  ${BOLD}${GREEN}│${RESET} %-16s ${BOLD}${GREEN}│${RESET} ${status_color}%-10s${RESET} ${BOLD}${GREEN}│${RESET} %-22s ${BOLD}${GREEN}│${RESET}\n" "$app" "$status" "$url"
        done <<< "$installed_apps"

        printf "  ${BOLD}${GREEN}└──────────────────┴────────────┴────────────────────────┘${RESET}\n"
    fi

    echo

    # Credentials
    printf "  ${BOLD}${YELLOW}┌────────────────────────────────────────────────────────┐${RESET}\n"
    printf "  ${BOLD}${YELLOW}│${RESET}  ${BOLD}Credentials & Access${RESET}                                ${BOLD}${YELLOW}│${RESET}\n"
    printf "  ${BOLD}${YELLOW}├────────────────────────────────────────────────────────┤${RESET}\n"
    printf "  ${BOLD}${YELLOW}│${RESET}  ${BOLD}Seedbox User:${RESET} %-40s${BOLD}${YELLOW}│${RESET}\n" "$username"
    printf "  ${BOLD}${YELLOW}│${RESET}  ${BOLD}Password:${RESET}     %-40s${BOLD}${YELLOW}│${RESET}\n" "(the password you set during user creation)"
    printf "  ${BOLD}${YELLOW}│${RESET}                                                        ${BOLD}${YELLOW}│${RESET}\n"

    if app_is_installed "qbittorrent"; then
        local qb_port
        qb_port="$(config_get S4D_QB_PORT 8080)"
        printf "  ${BOLD}${YELLOW}│${RESET}  ${CYAN}qBittorrent${RESET}                                          ${BOLD}${YELLOW}│${RESET}\n"
        printf "  ${BOLD}${YELLOW}│${RESET}    URL:  ${BOLD}http://${ip}:${qb_port}${RESET}%-*s${BOLD}${YELLOW}│${RESET}\n" "$((35 - ${#ip} - ${#qb_port}))" ""
        printf "  ${BOLD}${YELLOW}│${RESET}    User: ${BOLD}${username}${RESET}%-*s${BOLD}${YELLOW}│${RESET}\n" "$((45 - ${#username}))" ""
        printf "  ${BOLD}${YELLOW}│${RESET}                                                        ${BOLD}${YELLOW}│${RESET}\n"
    fi

    if app_is_installed "jellyfin"; then
        local jf_port
        jf_port="$(config_get S4D_JELLYFIN_PORT 8096)"
        printf "  ${BOLD}${YELLOW}│${RESET}  ${CYAN}Jellyfin${RESET}                                             ${BOLD}${YELLOW}│${RESET}\n"
        printf "  ${BOLD}${YELLOW}│${RESET}    URL:  ${BOLD}http://${ip}:${jf_port}${RESET}%-*s${BOLD}${YELLOW}│${RESET}\n" "$((35 - ${#ip} - ${#jf_port}))" ""
        printf "  ${BOLD}${YELLOW}│${RESET}    (Complete setup via web wizard on first visit)       ${BOLD}${YELLOW}│${RESET}\n"
        printf "  ${BOLD}${YELLOW}│${RESET}                                                        ${BOLD}${YELLOW}│${RESET}\n"
    fi

    if app_is_installed "plex"; then
        printf "  ${BOLD}${YELLOW}│${RESET}  ${CYAN}Plex${RESET}                                                 ${BOLD}${YELLOW}│${RESET}\n"
        printf "  ${BOLD}${YELLOW}│${RESET}    URL:  ${BOLD}http://${ip}:32400/web${RESET}%-*s${BOLD}${YELLOW}│${RESET}\n" "$((25 - ${#ip}))" ""
        printf "  ${BOLD}${YELLOW}│${RESET}    (Login with your Plex account)                      ${BOLD}${YELLOW}│${RESET}\n"
        printf "  ${BOLD}${YELLOW}│${RESET}                                                        ${BOLD}${YELLOW}│${RESET}\n"
    fi

    if app_is_installed "filebrowser"; then
        local fb_port
        fb_port="$(config_get S4D_FILEBROWSER_PORT 8090)"
        printf "  ${BOLD}${YELLOW}│${RESET}  ${CYAN}FileBrowser${RESET}                                          ${BOLD}${YELLOW}│${RESET}\n"
        printf "  ${BOLD}${YELLOW}│${RESET}    URL:  ${BOLD}http://${ip}:${fb_port}${RESET}%-*s${BOLD}${YELLOW}│${RESET}\n" "$((35 - ${#ip} - ${#fb_port}))" ""
        printf "  ${BOLD}${YELLOW}│${RESET}    User: ${BOLD}${username}${RESET}%-*s${BOLD}${YELLOW}│${RESET}\n" "$((45 - ${#username}))" ""
        printf "  ${BOLD}${YELLOW}│${RESET}                                                        ${BOLD}${YELLOW}│${RESET}\n"
    fi

    if app_is_installed "tailscale"; then
        local ts_ip
        ts_ip="$(tailscale ip -4 2>/dev/null || echo 'not connected')"
        printf "  ${BOLD}${YELLOW}│${RESET}  ${CYAN}Tailscale${RESET}                                            ${BOLD}${YELLOW}│${RESET}\n"
        printf "  ${BOLD}${YELLOW}│${RESET}    Tailscale IP: ${BOLD}${ts_ip}${RESET}%-*s${BOLD}${YELLOW}│${RESET}\n" "$((37 - ${#ts_ip}))" ""
        printf "  ${BOLD}${YELLOW}│${RESET}                                                        ${BOLD}${YELLOW}│${RESET}\n"
    fi

    printf "  ${BOLD}${YELLOW}└────────────────────────────────────────────────────────┘${RESET}\n"
    echo

    printf "  ${BOLD}${GREEN}Setup complete!${RESET} Run ${BOLD}sudo s4dbox${RESET} to manage your seedbox.\n"
    echo
    tui_pause
}
