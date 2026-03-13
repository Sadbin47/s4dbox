#!/usr/bin/env bash
# s4dbox - Readarr removal

remove_readarr() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing Readarr"
    s4d_remove_compose_service "readarr"
    msg_ok "Readarr removed"
    return 0
}
