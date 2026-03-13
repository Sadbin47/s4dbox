#!/usr/bin/env bash
# s4dbox - qBittorrent Removal

remove_qbittorrent() {
    local username
    username="$(get_seedbox_user)"

    msg_step "Removing qBittorrent"

    # Stop service
    systemctl stop "qbittorrent-nox@${username}" 2>/dev/null
    systemctl disable "qbittorrent-nox@${username}" 2>/dev/null

    # Remove binary and service
    rm -f /usr/bin/qbittorrent-nox
    rm -f /etc/systemd/system/qbittorrent-nox@.service
    systemctl daemon-reload

    # Remove config (keep downloads)
    rm -rf "/home/${username}/.config/qBittorrent"

    msg_ok "qBittorrent removed (downloads preserved)"
    return 0
}
