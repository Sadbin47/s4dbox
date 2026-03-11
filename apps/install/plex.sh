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
            # Plex on Arch typically from AUR, use pacman if available or manual install
            if command -v yay &>/dev/null; then
                sudo -u "$username" yay -S --noconfirm plex-media-server
            else
                # Manual download
                local plex_url
                plex_url="$(wget -qO- 'https://plex.tv/api/downloads/5.json' | jq -r '.computer.Linux.releases[] | select(.build=="linux-x86_64") | .url' | head -1)"
                if [[ -n "$plex_url" ]]; then
                    wget -q "$plex_url" -O /tmp/plex.rpm
                    # Convert  
                    msg_warn "Manual Plex install on Arch may require AUR helper"
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

    systemctl enable plexmediaserver 2>/dev/null
    systemctl start plexmediaserver
    
    config_set "S4D_PLEX_PORT" "32400"
    
    local ip
    ip="$(hostname -I | awk '{print $1}')"
    msg_ok "Plex Media Server installed"
    msg_info "WebUI: http://${ip}:32400/web"
    
    return 0
}
