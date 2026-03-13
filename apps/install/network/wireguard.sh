#!/usr/bin/env bash
# s4dbox - WireGuard tools installer

install_wireguard() {
    msg_step "Installing WireGuard tools"

    spinner_start "Installing wireguard packages"
    case "$S4D_DISTRO_FAMILY" in
        debian)
            pkg_install wireguard
            pkg_install wireguard-tools 2>/dev/null || true
            ;;
        arch)
            pkg_install wireguard-tools
            ;;
        rhel|suse)
            pkg_install wireguard-tools
            ;;
        *)
            spinner_stop 1
            msg_error "Unsupported distro for WireGuard"
            return 1
            ;;
    esac
    spinner_stop $?

    mkdir -p /etc/wireguard
    chmod 700 /etc/wireguard

    msg_ok "WireGuard installed"
    msg_info "Create configs in /etc/wireguard and use: systemctl enable --now wg-quick@wg0"
    return 0
}
