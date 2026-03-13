#!/usr/bin/env bash
# s4dbox - autodl-irssi removal

remove_autodl_irssi() {
    local username
    username="$(get_seedbox_user)"

    msg_step "Removing autodl-irssi"
    if [[ -n "$username" ]]; then
        rm -rf "/home/${username}/.irssi/scripts/autodl-irssi"
        rm -f "/home/${username}/.irssi/scripts/autorun/autodl-irssi.pl"
    fi
    msg_ok "autodl-irssi removed"
    return 0
}
