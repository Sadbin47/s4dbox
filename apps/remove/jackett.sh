#!/usr/bin/env bash
# s4dbox - Jackett removal

remove_jackett() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing Jackett"
    s4d_remove_compose_service "jackett"
    msg_ok "Jackett removed"
    return 0
}