#!/usr/bin/env bash
# s4dbox - WireGuard removal

remove_wireguard() {
    msg_step "Removing WireGuard"
    case "$S4D_DISTRO_FAMILY" in
        debian) pkg_remove wireguard 2>/dev/null || true; pkg_remove wireguard-tools 2>/dev/null || true ;;
        arch|rhel|suse) pkg_remove wireguard-tools 2>/dev/null || true ;;
    esac
    msg_ok "WireGuard removed"
    return 0
}
