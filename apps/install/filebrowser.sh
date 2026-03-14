#!/usr/bin/env bash
# s4dbox - FileBrowser Installer
# Lightweight web-based file manager

install_filebrowser() {
    local username
    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"

    local fb_user
    fb_user="$(tui_input "FileBrowser admin username" "$(config_get S4D_FILEBROWSER_USER "$username")")"
    [[ -z "$fb_user" ]] && fb_user="$username"
    
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

    # Recreate DB on install/reinstall so configured credentials match what user enters now.
    rm -f /etc/filebrowser/filebrowser.db
    "$fb_bin" config init --database /etc/filebrowser/filebrowser.db >/dev/null 2>&1 || true
    "$fb_bin" config set --database /etc/filebrowser/filebrowser.db \
        --address 0.0.0.0 \
        --port "$port" \
        --root "/home/${username}" >/dev/null 2>&1
    
    # Create admin user
    local fb_password
    while true; do
        fb_password="$(tui_password "FileBrowser admin password")"
        if [[ -z "$fb_password" ]]; then
            fb_password="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)"
            msg_warn "No FileBrowser password entered; generated a random password"
            break
        fi

        if [[ ${#fb_password} -lt 12 ]]; then
            msg_warn "FileBrowser requires at least 12 characters for password"
            continue
        fi

        break
    done
    
    if ! "$fb_bin" users add "$fb_user" "$fb_password" --perm.admin \
        --database /etc/filebrowser/filebrowser.db 2>/dev/null; then
        if ! "$fb_bin" users update "$fb_user" --password "$fb_password" \
            --perm.admin --database /etc/filebrowser/filebrowser.db 2>/dev/null; then
            msg_error "Failed to create/update FileBrowser admin credentials"
            msg_info "Try manually: ${fb_bin} users add ${fb_user} '<PASSWORD>' --perm.admin --database /etc/filebrowser/filebrowser.db"
            return 1
        fi
    fi

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
    if ! systemctl restart filebrowser; then
        msg_error "Failed to start FileBrowser service"
        msg_info "Check: systemctl status filebrowser"
        return 1
    fi

    config_set "S4D_FILEBROWSER_PORT" "$port"
    config_set "S4D_FILEBROWSER_USER" "$fb_user"

    local ip
    ip="$(get_local_ip)"
    msg_ok "FileBrowser installed"
    msg_info "WebUI: http://${ip}:${port}"
    msg_info "Username: ${fb_user}"
    msg_info "Password: ${fb_password}"
    
    return 0
}
