#!/usr/bin/env bash
# s4dbox - Jellyfin Removal

remove_jellyfin() {
    msg_step "Removing Jellyfin"
    systemctl stop jellyfin 2>/dev/null
    systemctl disable jellyfin 2>/dev/null
    
    case "$S4D_DISTRO_FAMILY" in
        debian) pkg_remove jellyfin ;;
        arch)   pkg_remove jellyfin-server; pkg_remove jellyfin-web ;;
        rhel)   pkg_remove jellyfin-server; pkg_remove jellyfin-web ;;
    esac

    msg_ok "Jellyfin removed"
    return 0
}
