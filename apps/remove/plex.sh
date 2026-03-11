#!/usr/bin/env bash
# s4dbox - Plex Removal

remove_plex() {
    msg_step "Removing Plex"
    systemctl stop plexmediaserver 2>/dev/null
    systemctl disable plexmediaserver 2>/dev/null
    pkg_remove plexmediaserver 2>/dev/null
    msg_ok "Plex removed"
    return 0
}
