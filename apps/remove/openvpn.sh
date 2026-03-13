#!/usr/bin/env bash
# s4dbox - OpenVPN removal

remove_openvpn() {
    msg_step "Removing OpenVPN"
    systemctl stop openvpn-server@server 2>/dev/null || true
    systemctl disable openvpn-server@server 2>/dev/null || true
    pkg_remove openvpn 2>/dev/null || true
    msg_ok "OpenVPN removed"
    return 0
}
