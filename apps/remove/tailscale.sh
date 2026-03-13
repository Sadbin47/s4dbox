#!/usr/bin/env bash
# s4dbox - Tailscale Removal

remove_tailscale() {
    msg_step "Removing Tailscale"
    tailscale down 2>/dev/null
    systemctl stop tailscaled 2>/dev/null
    systemctl disable tailscaled 2>/dev/null
    
    case "$S4D_DISTRO_FAMILY" in
        debian) pkg_remove tailscale ;;
        arch)   pkg_remove tailscale ;;
        rhel)   pkg_remove tailscale ;;
    esac
    
    msg_ok "Tailscale removed"
    return 0
}
