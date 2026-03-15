#!/usr/bin/env bash
# s4dbox - Plex Media Server Installer

install_plex() {
    local username
    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"
    local install_rc=0

    msg_step "Installing Plex Media Server"

    case "$S4D_DISTRO_FAMILY" in
        debian)
            spinner_start "Adding Plex repository"
            wget -qO- https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor -o /etc/apt/keyrings/plex.gpg 2>/dev/null
            echo "deb [signed-by=/etc/apt/keyrings/plex.gpg] https://downloads.plex.tv/repo/deb public main" > /etc/apt/sources.list.d/plexmediaserver.list
            pkg_update
            spinner_stop 0
            
            spinner_start "Installing Plex"
            pkg_install plexmediaserver
            install_rc=$?
            spinner_stop $install_rc
            ;;
        arch)
            spinner_start "Installing Plex"
            # Try AUR helpers in order: yay, paru, then manual AUR build
            if command -v yay &>/dev/null; then
                sudo -u "$username" yay -S --noconfirm plex-media-server 2>/dev/null
                spinner_stop $?
            elif command -v paru &>/dev/null; then
                sudo -u "$username" paru -S --noconfirm plex-media-server 2>/dev/null
                spinner_stop $?
            else
                # Build directly from AUR without a helper
                spinner_stop 0
                msg_info "No AUR helper found — building plex-media-server from AUR directly"
                # Ensure base-devel + git are installed
                pacman -S --needed --noconfirm base-devel git &>/dev/null
                local build_dir="/tmp/s4dbox-plex-aur"
                rm -rf "$build_dir"
                mkdir -p "$build_dir"
                chown "$username":"$username" "$build_dir"
                if sudo -u "$username" git clone https://aur.archlinux.org/plex-media-server.git "$build_dir/plex-media-server" 2>/dev/null; then
                    pushd "$build_dir/plex-media-server" >/dev/null
                    if sudo -u "$username" makepkg -si --noconfirm 2>&1; then
                        msg_ok "Built plex-media-server from AUR"
                    else
                        msg_error "Failed to build plex-media-server from AUR"
                        popd >/dev/null
                        rm -rf "$build_dir"
                        return 1
                    fi
                    popd >/dev/null
                    rm -rf "$build_dir"
                else
                    msg_error "Failed to clone plex-media-server AUR repo"
                    rm -rf "$build_dir"
                    return 1
                fi
            fi
            ;;
        rhel)
            spinner_start "Adding Plex repository"
            cat > /etc/yum.repos.d/plex.repo <<EOF
[PlexRepo]
name=PlexRepo
baseurl=https://downloads.plex.tv/repo/rpm/\$basearch/
enabled=1
gpgkey=https://downloads.plex.tv/plex-keys/PlexSign.key
gpgcheck=1
EOF
            spinner_stop 0
            
            spinner_start "Installing Plex"
            if command -v dnf &>/dev/null; then
                dnf install -y -q --disablerepo=jellyfin plexmediaserver >/dev/null 2>&1
                install_rc=$?
            elif command -v yum &>/dev/null; then
                yum install -y -q --disablerepo=jellyfin plexmediaserver >/dev/null 2>&1
                install_rc=$?
            else
                pkg_install plexmediaserver
                install_rc=$?
            fi
            spinner_stop $install_rc
            ;;
        *)
            msg_error "Unsupported distro family: $S4D_DISTRO_FAMILY"
            return 1
            ;;
    esac

    if [[ "$install_rc" -ne 0 ]]; then
        msg_error "Plex package installation failed"
        return 1
    fi

    # Create media directories
    mkdir -p "/home/${username}/media/"{movies,shows,music}
    chown -R "${username}:${username}" "/home/${username}/media"

    # Service name varies by distro
    local plex_svc=""
    for svc in plexmediaserver plexmediaserver.service plex-media-server; do
        if systemctl list-unit-files "$svc" &>/dev/null 2>&1; then
            plex_svc="$svc"
            break
        fi
    done
    
    if [[ -n "$plex_svc" ]]; then
        systemctl enable "$plex_svc" 2>/dev/null || true
        if ! systemctl start "$plex_svc" 2>/dev/null; then
            msg_error "Failed to start ${plex_svc}"
            msg_info "Check: systemctl status ${plex_svc}"
            msg_info "Logs:  journalctl -xeu ${plex_svc}"
            return 1
        fi
    else
        msg_error "Plex service not found after installation"
        return 1
    fi
    
    config_set "S4D_PLEX_PORT" "32400"
    
    local ip
    ip="$(get_local_ip)"
    msg_ok "Plex Media Server installed"
    msg_info "WebUI: http://${ip}:32400/web"
    
    return 0
}
