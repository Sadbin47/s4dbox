#!/usr/bin/env bash
# s4dbox - Nginx Module
# Full nginx reverse proxy support for all seedbox applications

# ─── Install Nginx ───
nginx_install() {
    if command -v nginx &>/dev/null; then
        msg_info "Nginx already installed"
    else
        msg_step "Installing Nginx"
        spinner_start "Installing nginx"
        pkg_install nginx
        spinner_stop $?
    fi

    # Create sites directories if they don't exist (RHEL/Arch)
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled

    # ── Ensure a clean, working nginx.conf ──
    # If a previous s4dbox run corrupted the config, restore from package default
    if ! nginx -t &>/dev/null; then
        msg_warn "nginx.conf is broken — restoring default config"
        # Arch: pacman ships .pacnew or we can extract from package cache
        if [[ "$S4D_DISTRO_FAMILY" == "arch" ]]; then
            if [[ -f /etc/nginx/nginx.conf.pacnew ]]; then
                cp /etc/nginx/nginx.conf.pacnew /etc/nginx/nginx.conf
            else
                # Re-extract from package
                pacman -S --noconfirm nginx &>/dev/null
                # pacman may create .pacnew instead of overwriting; check both
                if [[ -f /etc/nginx/nginx.conf.pacnew ]]; then
                    mv /etc/nginx/nginx.conf.pacnew /etc/nginx/nginx.conf
                fi
            fi
        elif [[ "$S4D_DISTRO_FAMILY" == "debian" ]]; then
            if [[ -f /etc/nginx/nginx.conf.dpkg-dist ]]; then
                cp /etc/nginx/nginx.conf.dpkg-dist /etc/nginx/nginx.conf
            fi
        fi
    fi

    # ── Remove any prior s4dbox comments to start fresh ──
    if grep -q '#s4d#' /etc/nginx/nginx.conf 2>/dev/null; then
        sed -i 's/^#s4d#//' /etc/nginx/nginx.conf 2>/dev/null
    fi

    # Include sites-enabled in nginx.conf inside http block (if not already)
    if ! grep -q 'include.*/etc/nginx/sites-enabled' /etc/nginx/nginx.conf 2>/dev/null; then
        # Insert inside http{} block — find 'http {' and add after it
        if grep -q 'http\s*{' /etc/nginx/nginx.conf 2>/dev/null; then
            sed -i '/http\s*{/a\    include /etc/nginx/sites-enabled/*.conf;' /etc/nginx/nginx.conf 2>/dev/null
        fi
    fi

    # Remove default server block from nginx.conf on Arch (it conflicts with our sites)
    # Must use awk with brace-depth tracking — sed can't handle nested {} blocks
    if [[ "$S4D_DISTRO_FAMILY" == "arch" ]]; then
        if grep -qP '^\s*server\s*\{' /etc/nginx/nginx.conf 2>/dev/null; then
            awk '
                /^\s*server\s*\{/ && !in_server { in_server=1; depth=0 }
                in_server {
                    for(i=1;i<=length($0);i++){
                        c=substr($0,i,1)
                        if(c=="{") depth++
                        if(c=="}") depth--
                    }
                    print "#s4d#" $0
                    if(depth<=0) in_server=0
                    next
                }
                { print }
            ' /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp \
                && mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf
        fi
    fi

    systemctl enable nginx 2>/dev/null
    systemctl start nginx 2>/dev/null || systemctl reload nginx 2>/dev/null || true
    config_set "S4D_NGINX_ENABLED" "1"
    
    log_info "Nginx installed and enabled"
    return 0
}

# ─── Generate Reverse Proxy Config ───
nginx_create_proxy() {
    local app_name="$1"
    local upstream_port="$2"
    local location="${3:-/$app_name}"
    
    # Proxy location blocks go into apps/ subdir — included by main server block
    mkdir -p /etc/nginx/sites-available/apps
    
    cat > "/etc/nginx/sites-available/apps/${app_name}.conf" <<EOF
# s4dbox reverse proxy for ${app_name}
location ${location}/ {
    proxy_pass http://127.0.0.1:${upstream_port}/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_buffering off;
    client_max_body_size 0;
}
EOF
    
    # These are NOT symlinked to sites-enabled — they're included via the main server block
    
    if nginx -t &>/dev/null; then
        systemctl reload nginx 2>/dev/null || true
        log_info "Nginx proxy created for ${app_name} -> port ${upstream_port}"
        return 0
    else
        msg_error "Nginx config test failed for ${app_name}"
        rm -f "/etc/nginx/sites-available/apps/${app_name}.conf"
        return 1
    fi
}

# ─── Main Server Block ───
nginx_create_main_server() {
    local domain="${1:-_}"
    local port="${2:-80}"

    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled

    cat > /etc/nginx/sites-available/s4dbox-main.conf <<EOF
# s4dbox Main Server Block
server {
    listen ${port} default_server;
    listen [::]:${port} default_server;
    server_name ${domain};

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Default location
    location / {
        return 200 '{"status":"ok","service":"s4dbox"}';
        add_header Content-Type application/json;
    }

    # Include app-specific proxy configs
    include /etc/nginx/sites-available/apps/*.conf;
}
EOF
    
    mkdir -p /etc/nginx/sites-available/apps
    ln -sf /etc/nginx/sites-available/s4dbox-main.conf /etc/nginx/sites-enabled/
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null
    
    nginx -t &>/dev/null && systemctl reload nginx
}

# ─── Per-App Nginx Configs ───
nginx_qbittorrent() {
    local port
    port="$(config_get S4D_QB_PORT 8080)"
    nginx_create_proxy "qbittorrent" "$port" "/qbittorrent"
    msg_ok "Nginx proxy configured for qBittorrent"
}

nginx_jellyfin() {
    local port
    port="$(config_get S4D_JELLYFIN_PORT 8096)"
    nginx_create_proxy "jellyfin" "$port" "/jellyfin"
    msg_ok "Nginx proxy configured for Jellyfin"
}

nginx_plex() {
    nginx_create_proxy "plex" "32400" "/plex"
    msg_ok "Nginx proxy configured for Plex"
}

nginx_filebrowser() {
    local port
    port="$(config_get S4D_FILEBROWSER_PORT 8090)"
    nginx_create_proxy "filebrowser" "$port" "/files"
    msg_ok "Nginx proxy configured for FileBrowser"
}

nginx_transmission() {
    local port
    port="$(config_get S4D_TRANSMISSION_PORT 9091)"
    nginx_create_proxy "transmission" "$port" "/transmission"
    msg_ok "Nginx proxy configured for Transmission"
}

nginx_rutorrent() {
    local port
    port="$(config_get S4D_RUTORRENT_PORT 8081)"
    nginx_create_proxy "rutorrent" "$port" "/rutorrent"
    msg_ok "Nginx proxy configured for ruTorrent"
}

nginx_sonarr() {
    local port
    port="$(config_get S4D_SONARR_PORT 8989)"
    nginx_create_proxy "sonarr" "$port" "/sonarr"
    msg_ok "Nginx proxy configured for Sonarr"
}

nginx_prowlarr() {
    local port
    port="$(config_get S4D_PROWLARR_PORT 9696)"
    nginx_create_proxy "prowlarr" "$port" "/prowlarr"
    msg_ok "Nginx proxy configured for Prowlarr"
}

nginx_jackett() {
    local port
    port="$(config_get S4D_JACKETT_PORT 9117)"
    nginx_create_proxy "jackett" "$port" "/jackett"
    msg_ok "Nginx proxy configured for Jackett"
}

nginx_jellyseerr() {
    local port
    port="$(config_get S4D_JELLYSEERR_PORT 5055)"
    nginx_create_proxy "jellyseerr" "$port" "/jellyseerr"
    msg_ok "Nginx proxy configured for Jellyseerr"
}

nginx_autobrr() {
    local port
    port="$(config_get S4D_AUTOBRR_PORT 7474)"
    nginx_create_proxy "autobrr" "$port" "/autobrr"
    msg_ok "Nginx proxy configured for autobrr"
}

nginx_maketorrent_webui() {
    local port
    port="$(config_get S4D_MAKETORRENT_WEBUI_PORT 8899)"
    nginx_create_proxy "maketorrent_webui" "$port" "/maketorrent"
    msg_ok "Nginx proxy configured for MakeTorrent WebUI"
}

nginx_nextcloud() {
    local port
    port="$(config_get S4D_NEXTCLOUD_PORT 8082)"
    nginx_create_proxy "nextcloud" "$port" "/nextcloud"
    msg_ok "Nginx proxy configured for Nextcloud"
}

nginx_cloudreve() {
    local port
    port="$(config_get S4D_CLOUDREVE_PORT 5212)"
    nginx_create_proxy "cloudreve" "$port" "/cloudreve"
    msg_ok "Nginx proxy configured for Cloudreve"
}

nginx_qui() {
    local port
    port="$(config_get S4D_QUI_PORT 7476)"
    nginx_create_proxy "qui" "$port" "/qui"
    msg_ok "Nginx proxy configured for Qui"
}

nginx_vnc_desktop() {
    local port
    port="$(config_get S4D_VNC_WEB_PORT 6080)"
    nginx_create_proxy "vnc_desktop" "$port" "/vnc"
    msg_ok "Nginx proxy configured for VNC Desktop"
}

nginx_filezilla_gui() {
    local port
    port="$(config_get S4D_FILEZILLA_WEB_PORT 5801)"
    nginx_create_proxy "filezilla_gui" "$port" "/filezilla"
    msg_ok "Nginx proxy configured for FileZilla GUI"
}

nginx_jdownloader2_gui() {
    local port
    port="$(config_get S4D_JDOWNLOADER2_WEB_PORT 5802)"
    nginx_create_proxy "jdownloader2_gui" "$port" "/jdownloader"
    msg_ok "Nginx proxy configured for JDownloader2 GUI"
}

nginx_setup_all_installed_proxies() {
    local app
    local proxy_apps=(
        qbittorrent transmission rutorrent jellyfin plex filebrowser
        sonarr prowlarr jackett jellyseerr autobrr maketorrent_webui
        nextcloud cloudreve qui vnc_desktop filezilla_gui jdownloader2_gui
    )

    for app in "${proxy_apps[@]}"; do
        if app_is_installed "$app" && declare -F "nginx_${app}" >/dev/null; then
            "nginx_${app}" 2>/dev/null || true
        fi
    done
}

# ─── Nginx Menu ───
nginx_menu() {
    while true; do
        local options=(
            "Install/Enable Nginx"
            "Configure Main Server Block"
            "Setup Proxy for Installed Apps"
            "Test Nginx Configuration"
            "View Nginx Status"
            "Restart Nginx"
            "← Back"
        )
        
        tui_draw_menu "Nginx Management" "${options[@]}"
        local choice=$?
        
        case $choice in
            0)
                nginx_install
                tui_pause
                ;;
            1)
                local domain
                domain="$(tui_input "Server domain (or _ for any)" "_")"
                local port
                port="$(tui_input "Listen port" "80")"
                nginx_create_main_server "$domain" "$port"
                msg_ok "Main server block created"
                tui_pause
                ;;
            2)
                msg_step "Setting up proxies for installed apps"
                nginx_setup_all_installed_proxies
                msg_ok "All proxies configured"
                tui_pause
                ;;
            3)
                nginx -t
                tui_pause
                ;;
            4)
                systemctl status nginx --no-pager 2>/dev/null
                tui_pause
                ;;
            5)
                systemctl restart nginx
                msg_ok "Nginx restarted"
                tui_pause
                ;;
            *) return ;;
        esac
    done
}
