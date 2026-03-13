#!/usr/bin/env bash
# s4dbox - Sonarr removal

remove_sonarr() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing Sonarr"
    s4d_remove_compose_service "sonarr"
    msg_ok "Sonarr removed"
    return 0
}
