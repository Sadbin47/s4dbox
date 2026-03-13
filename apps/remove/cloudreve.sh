#!/usr/bin/env bash
# s4dbox - Cloudreve removal

remove_cloudreve() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing Cloudreve"
    s4d_remove_compose_service "cloudreve"
    msg_ok "Cloudreve removed"
    return 0
}
