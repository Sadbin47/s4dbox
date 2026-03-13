#!/usr/bin/env bash
# s4dbox - Application Manager
# Handles install/remove/update/status for all apps

S4D_APPS_DIR="${S4D_BASE_DIR}/apps"

# Available applications registry
declare -A S4D_APP_DESC=(
    [qbittorrent]="qBittorrent - Torrent Client"
    [jellyfin]="Jellyfin - Media Server"
    [plex]="Plex - Media Server"
    [filebrowser]="FileBrowser - Web File Manager"
    [rtorrent]="rTorrent - Torrent Client"
    [rutorrent]="ruTorrent - rTorrent Web UI"
    [tailscale]="Tailscale - VPN / Remote Access"
    [wireguard]="WireGuard - VPN Tools"
    [openvpn]="OpenVPN - VPN Server"
    [transmission]="Transmission - Torrent Client"
    [autodl_irssi]="autodl-irssi - IRC Auto Downloader"
    [maketorrent_webui]="MakeTorrent WebUI - Torrent Creator"
    [sonarr]="Sonarr V4 - TV Automation"
    [prowlarr]="Prowlarr - Indexer Manager"
    [jackett]="Jackett - Indexer Proxy"
    [jellyseerr]="Jellyseerr - Request Manager"
    [autobrr]="autobrr - Automation"
    [vnc_desktop]="VNC Desktop - Remote Desktop"
    [filezilla_gui]="FileZilla GUI - FTP/SFTP Client"
    [jdownloader2_gui]="JDownloader2 GUI - Downloader"
    [nextcloud]="Nextcloud - Personal Cloud"
    [cloudreve]="Cloudreve - Cloud File Manager"
    [qui]="Qui - Torrent WebUI"
    [ssh_tools]="CLI Tools Bundle - 7z/ffmpeg/mktorrent/etc"
)

# Curated install menu order (grouped by purpose for human-friendly UX)
S4D_INSTALL_MENU_APPS=(
    "qbittorrent" "transmission" "rtorrent" "rutorrent" "qui"
    "jellyfin" "plex" "sonarr" "prowlarr" "jackett" "jellyseerr"
    "filebrowser" "nextcloud" "cloudreve" "maketorrent_webui"
    "autobrr" "autodl_irssi" "ssh_tools"
    "tailscale" "wireguard" "openvpn" "vnc_desktop"
    "filezilla_gui" "jdownloader2_gui"
)

# List available apps
app_list_available() {
    for app in "${!S4D_APP_DESC[@]}"; do
        local status="not installed"
        app_is_installed "$app" && status="${GREEN}installed${RESET}"
        printf "  %-15s %s  [%b]\n" "$app" "${S4D_APP_DESC[$app]}" "$status"
    done | sort
}

app_docker_container_name() {
    local app="$1"
    case "$app" in
        sonarr) echo "s4d-sonarr" ;;
        prowlarr) echo "s4d-prowlarr" ;;
        jackett) echo "s4d-jackett" ;;
        jellyseerr) echo "s4d-jellyseerr" ;;
        autobrr) echo "s4d-autobrr" ;;
        nextcloud) echo "s4d-nextcloud" ;;
        cloudreve) echo "s4d-cloudreve" ;;
        qui) echo "s4d-qui" ;;
        vnc_desktop) echo "s4d-vnc-desktop" ;;
        filezilla_gui) echo "s4d-filezilla" ;;
        jdownloader2_gui) echo "s4d-jdownloader2" ;;
        *) echo "" ;;
    esac
}

app_get_web_port() {
    local app="$1"
    case "$app" in
        qbittorrent) echo "$(config_get S4D_QB_PORT 8080)" ;;
        transmission) echo "$(config_get S4D_TRANSMISSION_PORT 9091)" ;;
        rutorrent) echo "$(config_get S4D_RUTORRENT_PORT 8081)" ;;
        jellyfin) echo "$(config_get S4D_JELLYFIN_PORT 8096)" ;;
        plex) echo "32400" ;;
        filebrowser) echo "$(config_get S4D_FILEBROWSER_PORT 8090)" ;;
        sonarr) echo "$(config_get S4D_SONARR_PORT 8989)" ;;
        prowlarr) echo "$(config_get S4D_PROWLARR_PORT 9696)" ;;
        jackett) echo "$(config_get S4D_JACKETT_PORT 9117)" ;;
        jellyseerr) echo "$(config_get S4D_JELLYSEERR_PORT 5055)" ;;
        autobrr) echo "$(config_get S4D_AUTOBRR_PORT 7474)" ;;
        maketorrent_webui) echo "$(config_get S4D_MAKETORRENT_WEBUI_PORT 8899)" ;;
        nextcloud) echo "$(config_get S4D_NEXTCLOUD_PORT 8082)" ;;
        cloudreve) echo "$(config_get S4D_CLOUDREVE_PORT 5212)" ;;
        qui) echo "$(config_get S4D_QUI_PORT 7476)" ;;
        vnc_desktop) echo "$(config_get S4D_VNC_WEB_PORT 6080)" ;;
        filezilla_gui) echo "$(config_get S4D_FILEZILLA_WEB_PORT 5801)" ;;
        jdownloader2_gui) echo "$(config_get S4D_JDOWNLOADER2_WEB_PORT 5802)" ;;
        *) echo "" ;;
    esac
}

app_webui_reachable() {
    local app="$1"
    local port url code

    port="$(app_get_web_port "$app")"
    [[ -z "$port" ]] && return 2

    url="http://127.0.0.1:${port}/"
    code="$(curl -sS -m 6 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo 000)"
    [[ "$code" != "000" ]]
}

# Install an app
app_install() {
    local app="$1"
    shift
    local install_script="${S4D_APPS_DIR}/install/${app}.sh"
    
    if [[ ! -f "$install_script" ]]; then
        msg_error "No installer found for: $app"
        return 1
    fi

    if app_is_installed "$app"; then
        msg_warn "$app is already installed"
        if ! tui_confirm "Reinstall $app?"; then
            return 0
        fi
    fi

    msg_step "Installing ${S4D_APP_DESC[$app]:-$app}..."
    log_info "Starting installation: $app"
    
    # Source and run the installer
    source "$install_script"
    if "install_${app}" "$@"; then
        app_mark_installed "$app"
        msg_ok "${app} installed successfully"
        log_info "Installation complete: $app"

        # If firewall is already active, refresh rules so newly installed app ports are reachable.
        if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -qi '^Status: active'; then
            firewall_setup >/dev/null 2>&1 || true
        elif command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
            firewall_setup >/dev/null 2>&1 || true
        fi
        
        # Install nginx config if nginx is enabled
        if [[ "$(config_get S4D_NGINX_ENABLED 0)" == "1" ]]; then
            if declare -F "nginx_${app}" >/dev/null; then
                "nginx_${app}" 2>/dev/null || true
            fi
        fi

        # Verify local WebUI reachability for web apps to avoid false "installed" states.
        if app_webui_reachable "$app"; then
            local _web_port
            _web_port="$(app_get_web_port "$app")"
            [[ -n "$_web_port" ]] && msg_ok "${app} WebUI reachable on localhost:${_web_port}"
        else
            if [[ $? -ne 2 ]]; then
                local _web_port
                _web_port="$(app_get_web_port "$app")"
                [[ -n "$_web_port" ]] && msg_warn "${app} installed but WebUI is not reachable on localhost:${_web_port}"
                msg_info "Try: systemctl status, docker ps, and app restart from Application Manager"
            fi
        fi
        return 0
    else
        msg_fail "${app} installation failed"
        log_error "Installation failed: $app"
        return 1
    fi
}

# Remove an app
app_remove() {
    local app="$1"
    local remove_script="${S4D_APPS_DIR}/remove/${app}.sh"
    
    if ! app_is_installed "$app"; then
        msg_warn "$app is not installed"
        return 0
    fi
    
    if [[ ! -f "$remove_script" ]]; then
        msg_error "No removal script found for: $app"
        return 1
    fi

    if ! tui_confirm "Remove ${app}? This cannot be undone."; then
        return 0
    fi

    msg_step "Removing ${app}..."
    log_info "Starting removal: $app"
    
    source "$remove_script"
    if "remove_${app}"; then
        app_mark_removed "$app"
        
        # Remove nginx config
        rm -f "/etc/nginx/sites-enabled/${app}.conf" 2>/dev/null
        rm -f "/etc/nginx/sites-available/${app}.conf" 2>/dev/null
        systemctl reload nginx 2>/dev/null || true
        
        msg_ok "${app} removed successfully"
        log_info "Removal complete: $app"
        return 0
    else
        msg_fail "${app} removal failed"
        log_error "Removal failed: $app"
        return 1
    fi
}

# Get app service status
app_status() {
    local app="$1"
    if ! app_is_installed "$app"; then
        echo "not installed"
        return
    fi
    
    # Try systemd service check
    local service_name
    case "$app" in
        qbittorrent)
            local _qb_user
            _qb_user="$(get_seedbox_user)"
            service_name="qbittorrent-nox@${_qb_user}"
            ;;
        jellyfin)    service_name="jellyfin" ;;
        plex)        
            # Service name varies by distro/install method
            for _svc in plexmediaserver plex-media-server; do
                if systemctl is-active "$_svc" &>/dev/null; then
                    service_name="$_svc"
                    break
                fi
            done
            service_name="${service_name:-plexmediaserver}"
            ;;
        filebrowser) service_name="filebrowser" ;;
        rtorrent)
            local _rt_user
            _rt_user="$(get_seedbox_user)"
            service_name="rtorrent@${_rt_user}"
            ;;
        rutorrent)
            # ruTorrent is a PHP web app served by nginx + php-fpm + rTorrent
            local _php_svc
            _php_svc="$(systemctl list-unit-files 2>/dev/null | grep -oP 'php[0-9.]*-fpm\.service' | head -1)"
            [[ -z "$_php_svc" ]] && _php_svc="php-fpm.service"
            if systemctl is-active nginx &>/dev/null \
               && systemctl is-active "$_php_svc" &>/dev/null \
               && [[ -d /var/www/rutorrent ]]; then
                echo "running"
            else
                echo "stopped"
            fi
            return
            ;;
        tailscale)   service_name="tailscaled" ;;
        wireguard)
            if systemctl is-active wg-quick@wg0 &>/dev/null; then
                echo "running"
            else
                echo "configured"
            fi
            return
            ;;
        openvpn)
            if systemctl is-active openvpn-server@server &>/dev/null; then
                echo "running"
            else
                echo "configured"
            fi
            return
            ;;
        autodl_irssi|ssh_tools)
            echo "configured"
            return
            ;;
        sonarr|prowlarr|jackett|jellyseerr|autobrr|vnc_desktop|filezilla_gui|jdownloader2_gui|nextcloud|cloudreve|qui)
            service_name="s4d-${app}.service"
            ;;
        maketorrent_webui) service_name="maketorrent-webui" ;;
        transmission)
            if systemctl list-unit-files | grep -q '^transmission-daemon\.service'; then
                service_name="transmission-daemon"
            else
                service_name="transmission"
            fi
            ;;
        *)           service_name="$app" ;;
    esac

    if ! systemctl is-active "$service_name" &>/dev/null; then
        echo "stopped"
        return
    fi

    # Docker-backed apps need container health validation, not only systemd oneshot status.
    local container_name
    container_name="$(app_docker_container_name "$app")"
    if [[ -n "$container_name" ]]; then
        if command -v docker &>/dev/null && docker ps --format '{{.Names}}' 2>/dev/null | grep -Fxq "$container_name"; then
            echo "running"
        else
            echo "stopped"
        fi
        return
    fi

    echo "running"
}

# Restart app service
app_restart() {
    local app="$1"
    local user
    user="$(get_seedbox_user)"
    
    case "$app" in
        qbittorrent) systemctl restart "qbittorrent-nox@${user}" ;;
        jellyfin)    systemctl restart jellyfin ;;
        plex)        systemctl restart plexmediaserver ;;
        filebrowser) systemctl restart filebrowser ;;
        rtorrent)    systemctl restart "rtorrent@${user}" ;;
        tailscale)   systemctl restart tailscaled ;;
        wireguard)   systemctl restart wg-quick@wg0 ;;
        openvpn)     systemctl restart openvpn-server@server ;;
        transmission)
            systemctl restart transmission-daemon 2>/dev/null || systemctl restart transmission 2>/dev/null
            ;;
        maketorrent_webui) systemctl restart maketorrent-webui ;;
        sonarr|prowlarr|jackett|jellyseerr|autobrr|vnc_desktop|filezilla_gui|jdownloader2_gui|nextcloud|cloudreve|qui)
            systemctl restart "s4d-${app}.service" ;;
        autodl_irssi|ssh_tools)
            msg_info "${app} does not run as a service"
            ;;
        *)           systemctl restart "$app" 2>/dev/null ;;
    esac
}

# ─── Interactive App Menu ───
app_menu_install() {
    local apps=("${S4D_INSTALL_MENU_APPS[@]}" "← Back")
    local labels=()
    
    for app in "${apps[@]}"; do
        if [[ "$app" == "← Back" ]]; then
            labels+=("$app")
        else
            local status=""
            app_is_installed "$app" && status=" [installed]"
            labels+=("${S4D_APP_DESC[$app]:-$app}${status}")
        fi
    done

    tui_draw_menu "Install Applications" "${labels[@]}"
    local choice=$?
    
    [[ $choice -eq 255 ]] && return
    [[ $choice -ge $(( ${#apps[@]} - 1 )) ]] && return
    
    local selected_app="${apps[$choice]}"
    app_install "$selected_app"
    tui_pause
}

app_menu_remove() {
    local installed
    installed=$(app_list_installed)
    
    if [[ -z "$installed" ]]; then
        msg_info "No applications installed"
        tui_pause
        return
    fi

    local apps=()
    while IFS= read -r app; do
        apps+=("${S4D_APP_DESC[$app]:-$app}")
    done <<< "$installed"
    apps+=("← Back")
    
    tui_draw_menu "Remove Applications" "${apps[@]}"
    local choice=$?
    
    [[ $choice -eq 255 ]] && return
    [[ $choice -ge $(( ${#apps[@]} - 1 )) ]] && return
    
    local app_names=()
    while IFS= read -r app; do
        app_names+=("$app")
    done <<< "$installed"
    
    app_remove "${app_names[$choice]}"
    tui_pause
}

app_menu_status() {
    clear
    msg_header "Application Status"
    
    local has_apps=0
    for app in "${!S4D_APP_DESC[@]}"; do
        if app_is_installed "$app"; then
            has_apps=1
            local status
            status="$(app_status "$app")"
            local color="$RED"
            [[ "$status" == "running" ]] && color="$GREEN"
            printf "  %-20s ${color}%-10s${RESET}\n" "${S4D_APP_DESC[$app]}" "$status"
        fi
    done
    
    [[ $has_apps -eq 0 ]] && msg_info "No applications installed"
    
    echo
    tui_pause
}

app_menu_manage() {
    while true; do
        local options=(
            "Install Application"
            "Remove Application"
            "Application Status"
            "Restart Application"
            "← Back"
        )
        
        tui_draw_menu "Application Manager" "${options[@]}"
        local choice=$?
        
        case $choice in
            0) app_menu_install ;;
            1) app_menu_remove ;;
            2) app_menu_status ;;
            3)
                local installed
                installed=$(app_list_installed)
                if [[ -n "$installed" ]]; then
                    local apps=()
                    while IFS= read -r app; do
                        apps+=("${S4D_APP_DESC[$app]:-$app}")
                    done <<< "$installed"
                    apps+=("← Back")
                    
                    tui_draw_menu "Restart Application" "${apps[@]}"
                    local rchoice=$?
                    if [[ $rchoice -ne 255 ]] && [[ $rchoice -lt $(( ${#apps[@]} - 1 )) ]]; then
                        local app_names=()
                        while IFS= read -r app; do
                            app_names+=("$app")
                        done <<< "$installed"
                        app_restart "${app_names[$rchoice]}"
                        msg_ok "Service restarted"
                        tui_pause
                    fi
                fi
                ;;
            *) return ;;
        esac
    done
}
