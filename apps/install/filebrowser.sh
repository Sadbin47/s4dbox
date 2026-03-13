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
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash >/dev/null 2>&1
    local rc=$?
    spinner_stop $rc
    if [[ $rc -ne 0 ]]; then
        msg_error "Failed to install FileBrowser"
        return 1
    fi

    # Verify binary exists
    local fb_bin
    fb_bin="$(command -v filebrowser 2>/dev/null)"
    if [[ -z "$fb_bin" ]]; then
        # Check common install locations
        for p in /usr/local/bin/filebrowser /usr/bin/filebrowser; do
            [[ -x "$p" ]] && { fb_bin="$p"; break; }
        done
    fi
    if [[ -z "$fb_bin" ]]; then
        msg_error "FileBrowser binary not found after install"
        return 1
    fi

    # Create config directory
    mkdir -p /etc/filebrowser
    mkdir -p "/home/${username}"

    # Create database and config (split commands so a single bad flag can't kill everything)
    "$fb_bin" config init --database /etc/filebrowser/filebrowser.db 2>/dev/null || true
    "$fb_bin" config set --database /etc/filebrowser/filebrowser.db \
        --address 0.0.0.0 \
        --port "$port" \
        --root "/home/${username}" 2>/dev/null
    
    # Create admin user
    local fb_password
    fb_password="$(tui_password "FileBrowser admin password")"
    [[ -z "$fb_password" ]] && fb_password="admin"
    
    "$fb_bin" users add "$username" "$fb_password" --perm.admin \
        --database /etc/filebrowser/filebrowser.db 2>/dev/null || true

    # Create systemd service — pass address/port on command line too (belt and suspenders)
    cat > /etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
Type=simple
ExecStart=${fb_bin} --database /etc/filebrowser/filebrowser.db --address 0.0.0.0 --port ${port}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable filebrowser 2>/dev/null
    systemctl restart filebrowser

    config_set "S4D_FILEBROWSER_PORT" "$port"

    local ip
    ip="$(get_local_ip)"
    msg_ok "FileBrowser installed"
    msg_info "WebUI: http://${ip}:${port}"
    msg_info "Username: ${username}"
    
    return 0
}
