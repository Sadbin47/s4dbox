#!/usr/bin/env bash
# s4dbox - Transmission removal

remove_transmission() {
    local username
    username="$(get_seedbox_user 2>/dev/null || true)"

    msg_step "Removing Transmission"

    # Stop and disable service variants across distros.
    for svc in transmission-daemon transmission; do
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
    done

    # Remove packages (ignore missing package names on non-matching distros).
    pkg_remove transmission-daemon 2>/dev/null || true
    pkg_remove transmission-cli 2>/dev/null || true
    pkg_remove transmission-remote-cli 2>/dev/null || true

    # Remove runtime/config/state directories.
    rm -rf /etc/transmission-daemon 2>/dev/null || true
    rm -rf /var/lib/transmission 2>/dev/null || true
    rm -rf /var/lib/transmission-daemon 2>/dev/null || true
    rm -rf /var/log/transmission-daemon* 2>/dev/null || true

    if [[ -n "$username" ]]; then
        rm -rf "/home/${username}/.config/transmission-daemon" 2>/dev/null || true
        rm -rf "/home/${username}/transmission" 2>/dev/null || true
    fi

    # Remove nginx proxy route if present.
    rm -f /etc/nginx/sites-available/apps/transmission.conf 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/transmission.conf 2>/dev/null || true
    systemctl reload nginx 2>/dev/null || true

    # Clean s4dbox metadata keys if config file exists.
    if [[ -n "$S4D_CONF_FILE" && -f "$S4D_CONF_FILE" ]]; then
        sed -i '/^S4D_TRANSMISSION_PORT=/d;/^S4D_TRANSMISSION_USER=/d' "$S4D_CONF_FILE" 2>/dev/null || true
    fi

    msg_ok "Transmission removed"
    return 0
}
