#!/usr/bin/env bash
# s4dbox - Qui removal

remove_qui() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing Qui"
    s4d_remove_compose_service "qui"
    msg_ok "Qui removed"
    return 0
}
