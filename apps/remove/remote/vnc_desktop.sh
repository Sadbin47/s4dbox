#!/usr/bin/env bash
# s4dbox - VNC desktop removal

remove_vnc_desktop() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing VNC Desktop"
    s4d_remove_compose_service "vnc_desktop"
    msg_ok "VNC Desktop removed"
    return 0
}
