#!/usr/bin/env bash
# s4dbox - JDownloader2 GUI removal

remove_jdownloader2_gui() {
    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"
    msg_step "Removing JDownloader2 GUI"
    s4d_remove_compose_service "jdownloader2_gui"
    msg_ok "JDownloader2 GUI removed"
    return 0
}
