#!/usr/bin/env bash
# s4dbox - Transmission installer

install_transmission() {
    local username rpc_port rpc_user rpc_pass service_name conf_file

    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"

    rpc_port="$(tui_input "Transmission RPC port" "9091")"
    rpc_user="$(tui_input "Transmission RPC username" "$username")"
    rpc_pass="$(tui_password "Transmission RPC password")"
    [[ -z "$rpc_pass" ]] && rpc_pass="transmission"

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

    systemctl stop "$service_name" 2>/dev/null || true

    mkdir -p "/home/${username}/transmission/downloads"
    chown -R "${username}:${username}" "/home/${username}/transmission"

    if [[ -f "$conf_file" ]]; then
        sed -i "s|\"rpc-authentication-required\":.*|\"rpc-authentication-required\": true,|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"rpc-username\":.*|\"rpc-username\": \"${rpc_user}\",|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"rpc-password\":.*|\"rpc-password\": \"${rpc_pass}\",|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"rpc-port\":.*|\"rpc-port\": ${rpc_port},|" "$conf_file" 2>/dev/null || true
        sed -i "s|\"download-dir\":.*|\"download-dir\": \"/home/${username}/transmission/downloads\",|" "$conf_file" 2>/dev/null || true
    fi

    systemctl enable "$service_name" 2>/dev/null || true
    systemctl restart "$service_name" 2>/dev/null || true

    config_set "S4D_TRANSMISSION_PORT" "$rpc_port"

    msg_ok "Transmission installed"
    msg_info "WebUI: http://$(get_local_ip):${rpc_port}/web"
    msg_info "Username: ${rpc_user}"
    return 0
}
