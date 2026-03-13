#!/usr/bin/env bash
# s4dbox - Jellyseerr removal

remove_jellyseerr() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing Jellyseerr"
    s4d_remove_compose_service "jellyseerr"
    msg_ok "Jellyseerr removed"
    return 0
}
