#!/usr/bin/env bash
# s4dbox - autobrr removal

remove_autobrr() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing autobrr"
    s4d_remove_compose_service "autobrr"
    msg_ok "autobrr removed"
    return 0
}
