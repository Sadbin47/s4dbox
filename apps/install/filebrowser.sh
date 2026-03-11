#!/usr/bin/env bash
# s4dbox - FileBrowser Installer
# Lightweight web-based file manager

install_filebrowser() {
    local username
    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"
    
    local port
    port="$(tui_input "FileBrowser port" "$(config_get S4D_FILEBROWSER_PORT 8090)")"

    msg_step "Installing FileBrowser"

    spinner_start "Downloading FileBrowser"
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash 2>/dev/null
    if [[ $? -ne 0 ]]; then
        spinner_stop 1
        msg_error "Failed to install FileBrowser"
        return 1
    fi
    spinner_stop 0

    # Create config directory
    mkdir -p /etc/filebrowser
    mkdir -p "/home/${username}/filebrowser"

    # Create database and config
    filebrowser config init --database /etc/filebrowser/filebrowser.db 2>/dev/null
    filebrowser config set --database /etc/filebrowser/filebrowser.db \
        --address 0.0.0.0 \
        --port "$port" \
        --root "/home/${username}" \
        --auth.method=json 2>/dev/null
    
    # Create admin user
    local fb_password
    fb_password="$(tui_password "FileBrowser admin password")"
    [[ -z "$fb_password" ]] && fb_password="admin"
    
    filebrowser users add "$username" "$fb_password" --perm.admin --database /etc/filebrowser/filebrowser.db 2>/dev/null

    # Create systemd service
    cat > /etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/filebrowser --database /etc/filebrowser/filebrowser.db
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable filebrowser 2>/dev/null
    systemctl start filebrowser

    config_set "S4D_FILEBROWSER_PORT" "$port"

    local ip
    ip="$(hostname -I | awk '{print $1}')"
    msg_ok "FileBrowser installed"
    msg_info "WebUI: http://${ip}:${port}"
    msg_info "Username: ${username}"
    
    return 0
}
