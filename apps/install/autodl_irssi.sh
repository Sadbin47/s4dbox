#!/usr/bin/env bash
# s4dbox - autodl-irssi installer

install_autodl_irssi() {
    local username
    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"

    msg_step "Installing autodl-irssi"

    spinner_start "Installing irssi and dependencies"
    case "$S4D_DISTRO_FAMILY" in
        debian)
            pkg_install irssi
            pkg_install perl
            pkg_install unzip
            pkg_install git
            ;;
        arch)
            pkg_install irssi
            pkg_install perl
            pkg_install unzip
            pkg_install git
            ;;
        rhel|suse)
            pkg_install irssi
            pkg_install perl
            pkg_install unzip
            pkg_install git
            ;;
        *)
            spinner_stop 1
            msg_error "Unsupported distro for autodl-irssi"
            return 1
            ;;
    esac
    local rc=$?
    spinner_stop $rc
    [[ $rc -ne 0 ]] && return 1

    local irssi_home="/home/${username}/.irssi"
    mkdir -p "${irssi_home}/scripts/autorun"

    rm -rf "${irssi_home}/scripts/autodl-irssi"
    git clone --depth 1 https://github.com/autodl-community/autodl-irssi.git "${irssi_home}/scripts/autodl-irssi" >/dev/null 2>&1 || {
        msg_error "Failed to clone autodl-irssi"
        return 1
    }

    if [[ -f "${irssi_home}/scripts/autodl-irssi/autodl-irssi.pl" ]]; then
        ln -sf "${irssi_home}/scripts/autodl-irssi/autodl-irssi.pl" "${irssi_home}/scripts/autorun/autodl-irssi.pl"
    fi

    chown -R "${username}:${username}" "$irssi_home"

    msg_ok "autodl-irssi installed"
    msg_info "Launch with: sudo -u ${username} irssi"
    return 0
}
