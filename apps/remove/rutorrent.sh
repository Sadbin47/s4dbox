#!/usr/bin/env bash
# s4dbox - ruTorrent Removal

remove_rutorrent() {
    msg_step "Removing ruTorrent"
    rm -rf /var/www/rutorrent
    rm -f /etc/nginx/sites-enabled/rutorrent.conf
    rm -f /etc/nginx/sites-available/rutorrent.conf
    rm -f /etc/nginx/.htpasswd_rutorrent
    systemctl reload nginx 2>/dev/null || true
    msg_ok "ruTorrent removed"
    return 0
}
