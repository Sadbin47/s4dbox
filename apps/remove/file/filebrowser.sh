#!/usr/bin/env bash
# s4dbox - FileBrowser Removal

remove_filebrowser() {
    msg_step "Removing FileBrowser"
    systemctl stop filebrowser 2>/dev/null
    systemctl disable filebrowser 2>/dev/null
    rm -f /etc/systemd/system/filebrowser.service
    rm -f /usr/local/bin/filebrowser
    rm -rf /etc/filebrowser
    systemctl daemon-reload
    msg_ok "FileBrowser removed"
    return 0
}
