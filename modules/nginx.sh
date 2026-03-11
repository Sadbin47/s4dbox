#!/usr/bin/env bash
# s4dbox - Nginx Module
# Full nginx reverse proxy support for all seedbox applications

# ─── Install Nginx ───
nginx_install() {
    if command -v nginx &>/dev/null; then
        msg_info "Nginx already installed"
        return 0
    fi    

    msg_step "Installing Nginx"
    spinner_start "Installing nginx"
    pkg_install nginx
    spinner_stop $?

    # Create sites directories if they don't exist (RHEL/Arch)
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled

    # Include sites-enabled in main config if not already
    if ! grep -q 'sites-enabled' /etc/nginx/nginx.conf 2>/dev/null; then
        # Add include before the last closing brace
        sed -i '/^}/i\    include /etc/nginx/sites-enabled/*.conf;' /etc/nginx/nginx.conf 2>/dev/null
    fi

    systemctl enable nginx 2>/dev/null
    systemctl start nginx
    config_set "S4D_NGINX_ENABLED" "1"
    
    log_info "Nginx installed and enabled"
    return 0
}

# ─── Generate Reverse Proxy Config ───
nginx_create_proxy() {
    local app_name="$1"
    local upstream_port="$2"
    local location="${3:-/$app_name}"
    
    cat > "/etc/nginx/sites-available/${app_name}.conf" <<EOF
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
    
    ln -sf "/etc/nginx/sites-available/${app_name}.conf" "/etc/nginx/sites-enabled/" 2>/dev/null
    
    if nginx -t &>/dev/null; then
        systemctl reload nginx
        log_info "Nginx proxy created for ${app_name} -> port ${upstream_port}"
        return 0
    else
        msg_error "Nginx config test failed for ${app_name}"
        rm -f "/etc/nginx/sites-enabled/${app_name}.conf"
        return 1
    fi
}

# ─── Main Server Block ───
nginx_create_main_server() {
    local domain="${1:-_}"
    local port="${2:-80}"

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
                for app in qbittorrent jellyfin plex filebrowser; do
                    if app_is_installed "$app"; then
                        "nginx_${app}" 2>/dev/null || true
                    fi
                done
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
