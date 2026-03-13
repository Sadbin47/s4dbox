#!/usr/bin/env bash
# s4dbox - Transmission removal

remove_transmission() {
    msg_step "Removing Transmission"
    for svc in transmission-daemon transmission; do
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
    done
    pkg_remove transmission-daemon 2>/dev/null || true
    pkg_remove transmission-cli 2>/dev/null || true
    msg_ok "Transmission removed"
    return 0
}
