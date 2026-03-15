#!/usr/bin/env bash
# s4dbox - Jellyfin Installer

install_jellyfin() {
    local username
    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"
    
    local port
    port="$(tui_input "Jellyfin port" "$(config_get S4D_JELLYFIN_PORT 8096)")"
    local install_rc=0

    msg_step "Installing Jellyfin Media Server"

    case "$S4D_DISTRO_FAMILY" in
        debian)
            spinner_start "Adding Jellyfin repository"
            # Install prerequisites
            pkg_install apt-transport-https
            pkg_install gnupg2

            # Add Jellyfin repo
            mkdir -p /etc/apt/keyrings
            wget -qO- https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg 2>/dev/null
            
            local codename
            codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
            local os_id
            os_id="$(. /etc/os-release && echo "$ID")"
            
            cat > /etc/apt/sources.list.d/jellyfin.list <<EOF
deb [signed-by=/etc/apt/keyrings/jellyfin.gpg] https://repo.jellyfin.org/${os_id} ${codename} main
EOF
            pkg_update
            spinner_stop 0
            
            spinner_start "Installing Jellyfin"
            pkg_install jellyfin
            install_rc=$?
            spinner_stop $install_rc
            ;;
        arch)
            spinner_start "Installing Jellyfin"
            if pkg_install jellyfin-server && pkg_install jellyfin-web; then
                install_rc=0
            else
                install_rc=1
            fi
            spinner_stop $install_rc
            ;;
        rhel)
            spinner_start "Adding Jellyfin repository"
            cat > /etc/yum.repos.d/jellyfin.repo <<EOF
[jellyfin]
name=Jellyfin
baseurl=https://repo.jellyfin.org/releases/server/centos/stable
gpgcheck=1
gpgkey=https://repo.jellyfin.org/jellyfin_team.gpg.key
enabled=1
EOF
            spinner_stop 0
            
            spinner_start "Installing Jellyfin"
            if pkg_install jellyfin-server && pkg_install jellyfin-web; then
                install_rc=0
            else
                install_rc=1
            fi
            spinner_stop $install_rc
            ;;
        *)
            msg_error "Unsupported distro family: $S4D_DISTRO_FAMILY"
            return 1
            ;;
    esac

    if [[ "$install_rc" -ne 0 ]]; then
        msg_error "Jellyfin package installation failed"
        return 1
    fi

    # Create media directories
    mkdir -p "/home/${username}/media/"{movies,shows,music}
    chown -R "${username}:${username}" "/home/${username}/media"

    # Enable and start service
    if ! systemctl list-unit-files jellyfin.service >/dev/null 2>&1; then
        msg_error "jellyfin.service not found after installation"
        return 1
    fi

    systemctl enable jellyfin 2>/dev/null || true
    if ! systemctl start jellyfin; then
        msg_error "Failed to start jellyfin.service"
        msg_info "Check: systemctl status jellyfin.service"
        msg_info "Logs:  journalctl -xeu jellyfin.service"
        return 1
    fi

    config_set "S4D_JELLYFIN_PORT" "$port"
    
    local ip
    ip="$(get_local_ip)"
    msg_ok "Jellyfin installed"
    msg_info "WebUI: http://${ip}:${port}"
    
    return 0
}
