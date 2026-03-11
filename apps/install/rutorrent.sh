#!/usr/bin/env bash
# s4dbox - ruTorrent Installer (Web UI for rTorrent)
# Requires: rTorrent, nginx, php-fpm

install_rutorrent() {
    local username
    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"
    
    local port
    port="$(tui_input "ruTorrent port" "$(config_get S4D_RUTORRENT_PORT 8081)")"
    
    # Check rTorrent dependency
    if ! app_is_installed "rtorrent"; then
        msg_warn "rTorrent is not installed. Installing it first..."
        app_install "rtorrent"
    fi

    msg_step "Installing ruTorrent"

    # Install nginx and PHP
    spinner_start "Installing web server dependencies"
    case "$S4D_DISTRO_FAMILY" in
        debian)
            pkg_install nginx
            pkg_install php-fpm
            pkg_install php-cli
            pkg_install php-curl
            pkg_install php-geoip 2>/dev/null || true
            pkg_install php-xml
            pkg_install php-mbstring
            pkg_install mediainfo
            pkg_install unrar-free 2>/dev/null || pkg_install unrar 2>/dev/null || true
            pkg_install ffmpeg 2>/dev/null || true
            ;;
        arch)
            pkg_install nginx
            pkg_install php-fpm
            pkg_install php
            pkg_install mediainfo
            pkg_install ffmpeg
            ;;
        rhel)
            pkg_install nginx
            pkg_install php-fpm
            pkg_install php-cli
            pkg_install php-curl
            pkg_install php-xml
            pkg_install php-mbstring
            pkg_install mediainfo
            pkg_install ffmpeg 2>/dev/null || true
            ;;
    esac
    spinner_stop 0

    # Download ruTorrent
    spinner_start "Downloading ruTorrent"
    local rutorrent_dir="/var/www/rutorrent"
    rm -rf "$rutorrent_dir"
    
    wget -q "https://github.com/Novik/ruTorrent/archive/refs/heads/master.tar.gz" -O /tmp/rutorrent.tar.gz
    if [[ $? -ne 0 ]]; then
        spinner_stop 1
        msg_error "Failed to download ruTorrent"
        return 1
    fi
    
    mkdir -p "$rutorrent_dir"
    tar -xzf /tmp/rutorrent.tar.gz -C "$rutorrent_dir" --strip-components=1
    rm -f /tmp/rutorrent.tar.gz
    spinner_stop 0

    # Set permissions
    chown -R www-data:www-data "$rutorrent_dir" 2>/dev/null || chown -R http:http "$rutorrent_dir" 2>/dev/null || chown -R nginx:nginx "$rutorrent_dir" 2>/dev/null

    # Configure ruTorrent SCGI
    local scgi_port
    scgi_port="$(config_get S4D_RTORRENT_PORT 5000)"
    
    # Update ruTorrent config
    if [[ -f "${rutorrent_dir}/conf/config.php" ]]; then
        sed -i "s|\$scgi_port = .*|\$scgi_port = ${scgi_port};|" "${rutorrent_dir}/conf/config.php"
        sed -i "s|\$scgi_host = .*|\$scgi_host = \"127.0.0.1\";|" "${rutorrent_dir}/conf/config.php"
    fi

    # Create nginx config for ruTorrent
    local php_sock
    php_sock="$(find /var/run/php/ /run/php-fpm/ /run/php/ /var/run/ -name 'php*.sock' 2>/dev/null | head -1)"
    [[ -z "$php_sock" ]] && php_sock="/run/php-fpm/php-fpm.sock"

    cat > /etc/nginx/sites-available/rutorrent.conf <<EOF
server {
    listen ${port};
    server_name _;
    root ${rutorrent_dir};
    index index.html index.php;

    auth_basic "ruTorrent";
    auth_basic_user_file /etc/nginx/.htpasswd_rutorrent;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \\.php\$ {
        fastcgi_pass unix:${php_sock};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location /RPC2 {
        scgi_pass 127.0.0.1:${scgi_port};
        include scgi_params;
    }
}
EOF

    # Create htpasswd
    local rt_password
    rt_password="$(tui_password "ruTorrent web password")"
    [[ -z "$rt_password" ]] && rt_password="rutorrent"
    
    if command -v htpasswd &>/dev/null; then
        htpasswd -bc /etc/nginx/.htpasswd_rutorrent "$username" "$rt_password" 2>/dev/null
    else
        # Fallback: install apache2-utils / httpd-tools
        case "$S4D_DISTRO_FAMILY" in
            debian) pkg_install apache2-utils ;;
            arch)   pkg_install apache ;;
            rhel)   pkg_install httpd-tools ;;
        esac
        htpasswd -bc /etc/nginx/.htpasswd_rutorrent "$username" "$rt_password" 2>/dev/null
    fi

    # Enable site
    mkdir -p /etc/nginx/sites-available 2>/dev/null
    mkdir -p /etc/nginx/sites-enabled 2>/dev/null
    ln -sf /etc/nginx/sites-available/rutorrent.conf /etc/nginx/sites-enabled/ 2>/dev/null

    # Detect correct php-fpm service name
    local phpfpm_svc
    phpfpm_svc="$(systemctl list-unit-files 2>/dev/null | grep -oP 'php[0-9.]*-fpm\.service' | head -1)"
    [[ -z "$phpfpm_svc" ]] && phpfpm_svc="php-fpm.service"

    # Restart services
    systemctl enable nginx "${phpfpm_svc}" 2>/dev/null || true
    nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null || msg_warn "Nginx config test failed — check manually"
    systemctl restart "${phpfpm_svc}" 2>/dev/null || true

    config_set "S4D_RUTORRENT_PORT" "$port"
    config_set "S4D_NGINX_ENABLED" "1"
    
    local ip
    ip="$(get_local_ip)"
    msg_ok "ruTorrent installed"
    msg_info "WebUI: http://${ip}:${port}"
    msg_info "Username: ${username}"
    
    return 0
}
