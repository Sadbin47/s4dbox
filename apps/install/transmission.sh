#!/usr/bin/env bash
# s4dbox - Transmission installer

install_transmission() {
    local username rpc_port rpc_user rpc_pass service_name conf_file

    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"

    rpc_port="$(tui_input "Transmission RPC port" "9091")"
    rpc_user="$(tui_input "Transmission RPC username" "$username")"
    rpc_pass="$(tui_password "Transmission RPC password")"
    if [[ -z "$rpc_pass" ]]; then
        rpc_pass="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)"
        msg_warn "No RPC password entered; generated a random password for security"
    fi

    msg_step "Installing Transmission"
    spinner_start "Installing transmission packages"
    case "$S4D_DISTRO_FAMILY" in
        debian)
            pkg_install transmission-daemon
            service_name="transmission-daemon"
            conf_file="/etc/transmission-daemon/settings.json"
            ;;
        arch)
            pkg_install transmission-cli
            pkg_install transmission-daemon
            service_name="transmission"
            conf_file="/var/lib/transmission/.config/transmission-daemon/settings.json"
            ;;
        rhel|suse)
            pkg_install transmission-daemon
            service_name="transmission-daemon"
            conf_file="/var/lib/transmission/.config/transmission-daemon/settings.json"
            ;;
        *)
            spinner_stop 1
            msg_error "Unsupported distro for Transmission"
            return 1
            ;;
    esac
    local rc=$?
    spinner_stop $rc
    [[ $rc -ne 0 ]] && return 1

    # Start once so distros that generate settings.json on first boot have a config file.
    systemctl enable "$service_name" 2>/dev/null || true
    systemctl start "$service_name" 2>/dev/null || true

    local tries=10
    while [[ ! -f "$conf_file" && $tries -gt 0 ]]; do
        sleep 1
        tries=$((tries - 1))
    done

    systemctl stop "$service_name" 2>/dev/null || true

    mkdir -p "/home/${username}/transmission/downloads"
    chown -R "${username}:${username}" "/home/${username}/transmission"

    if [[ ! -f "$conf_file" ]]; then
        msg_error "Transmission settings file not found: ${conf_file}"
        msg_info "Check service status: systemctl status ${service_name}"
        return 1
    fi

    if command -v jq &>/dev/null; then
        local tmp_conf
        tmp_conf="$(mktemp)"
        if ! jq \
            --arg rpc_user "$rpc_user" \
            --arg rpc_pass "$rpc_pass" \
            --arg dl_dir "/home/${username}/transmission/downloads" \
            --argjson rpc_port "$rpc_port" \
            '."rpc-authentication-required"=true
            | ."rpc-username"=$rpc_user
            | ."rpc-password"=$rpc_pass
            | ."rpc-port"=$rpc_port
            | ."download-dir"=$dl_dir
            | ."rpc-bind-address"="0.0.0.0"
            | ."rpc-whitelist-enabled"=false
            | ."rpc-host-whitelist-enabled"=false' "$conf_file" > "$tmp_conf"; then
            rm -f "$tmp_conf"
            msg_error "Failed to update Transmission settings"
            return 1
        fi
        mv "$tmp_conf" "$conf_file"
    else
        sed -i "s|\"rpc-authentication-required\":.*|\"rpc-authentication-required\": true,|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"rpc-username\":.*|\"rpc-username\": \"${rpc_user}\",|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"rpc-password\":.*|\"rpc-password\": \"${rpc_pass}\",|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"rpc-port\":.*|\"rpc-port\": ${rpc_port},|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"download-dir\":.*|\"download-dir\": \"/home/${username}/transmission/downloads\",|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"rpc-bind-address\":.*|\"rpc-bind-address\": \"0.0.0.0\",|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"rpc-whitelist-enabled\":.*|\"rpc-whitelist-enabled\": false,|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"rpc-host-whitelist-enabled\":.*|\"rpc-host-whitelist-enabled\": false,|" "$conf_file" 2>/dev/null || true
    fi

    systemctl enable "$service_name" 2>/dev/null || true
    if ! systemctl restart "$service_name" 2>/dev/null; then
        msg_error "Failed to start Transmission service"
        msg_info "Check: systemctl status ${service_name}"
        return 1
    fi

    config_set "S4D_TRANSMISSION_PORT" "$rpc_port"
    config_set "S4D_TRANSMISSION_USER" "$rpc_user"

    msg_ok "Transmission installed"
    msg_info "WebUI: http://$(get_local_ip):${rpc_port}/web"
    msg_info "Username: ${rpc_user}"
    msg_info "Password: ${rpc_pass}"
    return 0
}
