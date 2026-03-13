#!/usr/bin/env bash
# s4dbox - FileZilla GUI removal

remove_filezilla_gui() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing FileZilla GUI"
    s4d_remove_compose_service "filezilla_gui"
    msg_ok "FileZilla GUI removed"
    return 0
}
