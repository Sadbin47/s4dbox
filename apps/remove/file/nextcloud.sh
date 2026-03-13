#!/usr/bin/env bash
# s4dbox - Nextcloud removal

remove_nextcloud() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing Nextcloud"
    s4d_remove_compose_service "nextcloud"
    msg_ok "Nextcloud removed"
    return 0
}
