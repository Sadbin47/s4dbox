#!/usr/bin/env bash
# s4dbox - Prowlarr removal

remove_prowlarr() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing Prowlarr"
    s4d_remove_compose_service "prowlarr"
    msg_ok "Prowlarr removed"
    return 0
}