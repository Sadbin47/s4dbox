#!/usr/bin/env bash
# s4dbox - OpenVPN installer

install_openvpn() {
    msg_step "Installing OpenVPN"

    spinner_start "Installing OpenVPN packages"
    case "$S4D_DISTRO_FAMILY" in
        debian)
            pkg_install openvpn
            pkg_install easy-rsa 2>/dev/null || true
            ;;
        arch)
            pkg_install openvpn
            pkg_install easy-rsa 2>/dev/null || true
            ;;
        rhel|suse)
            pkg_install openvpn
            pkg_install easy-rsa 2>/dev/null || true
            ;;
        *)
            spinner_stop 1
            msg_error "Unsupported distro for OpenVPN"
            return 1
            ;;
    esac
    spinner_stop $?

    mkdir -p /etc/openvpn/server

    msg_ok "OpenVPN installed"
    msg_info "Place server config in /etc/openvpn/server/server.conf then: systemctl enable --now openvpn-server@server"
    return 0
}
