#!/usr/bin/env bash
# s4dbox - Plex Media Server Installer

install_plex() {
    local username
    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"

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
            spinner_stop $?
            ;;
        arch)
            spinner_start "Installing Plex"
            # Try AUR helpers in order: yay, paru, then manual
            if command -v yay &>/dev/null; then
                sudo -u "$username" yay -S --noconfirm plex-media-server 2>/dev/null
            elif command -v paru &>/dev/null; then
                sudo -u "$username" paru -S --noconfirm plex-media-server 2>/dev/null
            else
                # Install via Flatpak as fallback
                if command -v flatpak &>/dev/null || pkg_install flatpak 2>/dev/null; then
                    flatpak install -y --noninteractive flathub tv.plex.PlexMediaServer 2>/dev/null
                else
                    spinner_stop 1
                    msg_error "Plex requires an AUR helper (yay/paru) or flatpak on Arch"
                    msg_info "Install with: yay -S plex-media-server"
                    return 1
                fi
            fi
            spinner_stop $?
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
            pkg_install plexmediaserver
            spinner_stop $?
            ;;
        *)
            msg_error "Unsupported distro family: $S4D_DISTRO_FAMILY"
            return 1
            ;;
    esac

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
        systemctl enable "$plex_svc" 2>/dev/null
        systemctl start "$plex_svc" 2>/dev/null
    else
        msg_warn "Plex service not found. You may need to start it manually."
    fi
    
    config_set "S4D_PLEX_PORT" "32400"
    
    local ip
    ip="$(get_local_ip)"
    msg_ok "Plex Media Server installed"
    msg_info "WebUI: http://${ip}:32400/web"
    
    return 0
}
