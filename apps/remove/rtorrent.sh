#!/usr/bin/env bash
# s4dbox - rTorrent Removal

remove_rtorrent() {
    local username
    username="$(get_seedbox_user)"

    msg_step "Removing rTorrent"
    systemctl stop "rtorrent@${username}" 2>/dev/null
    systemctl disable "rtorrent@${username}" 2>/dev/null
    rm -f /etc/systemd/system/rtorrent@.service
    
    case "$S4D_DISTRO_FAMILY" in
        debian) pkg_remove rtorrent ;;
        arch)   pkg_remove rtorrent ;;
        rhel)   pkg_remove rtorrent ;;
    esac
    
    rm -f "/home/${username}/.rtorrent.rc"
    systemctl daemon-reload
    msg_ok "rTorrent removed (downloads preserved)"
    return 0
}
