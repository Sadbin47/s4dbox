#!/usr/bin/env bash
# s4dbox - MakeTorrent WebUI removal

remove_maketorrent_webui() {
    msg_step "Removing MakeTorrent WebUI"
    systemctl stop maketorrent-webui 2>/dev/null || true
    systemctl disable maketorrent-webui 2>/dev/null || true
    rm -f /etc/systemd/system/maketorrent-webui.service
    systemctl daemon-reload
    msg_ok "MakeTorrent WebUI removed"
    return 0
}
