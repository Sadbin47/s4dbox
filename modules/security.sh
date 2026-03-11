#!/usr/bin/env bash
# s4dbox - SSH Security & Firewall Module
# Enhanced SSH security, fail2ban, and firewall baseline

# ─── SSH Hardening ───
ssh_harden() {
    msg_header "SSH Security Hardening"
    
    local sshd_conf="/etc/ssh/sshd_config"
    
    # Backup
    cp "$sshd_conf" "${sshd_conf}.bak.$(date +%s)"

    # Change SSH port
    if tui_confirm "Change SSH port from default?"; then
        local new_port
        new_port="$(tui_input "New SSH port" "2222")"
        
        # Validate port number
        while ! [[ "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1024 ]] || [[ "$new_port" -gt 65535 ]]; do
            msg_warn "Invalid port. Use 1024-65535"
            new_port="$(tui_input "New SSH port" "2222")"
        done
        
        # Replace or add Port directive (remove all existing, add new)
        sed -i '/^#\?Port /d' "$sshd_conf"
        echo "Port ${new_port}" >> "$sshd_conf"
        
        # Validate the config before restarting
        if sshd -t 2>/dev/null; then
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
            config_set "S4D_SSH_PORT" "$new_port"
            msg_ok "SSH port changed to ${new_port}"
            msg_warn "IMPORTANT: Connect with: ssh -p ${new_port} user@server"
        else
            msg_error "Invalid sshd config — reverting port change"
            sed -i "/^Port ${new_port}$/d" "$sshd_conf"
            echo "Port 22" >> "$sshd_conf"
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
        fi
    fi

    # Disable root password login
    if tui_confirm "Disable root password authentication? (SSH keys required)"; then
        if [[ -s /root/.ssh/authorized_keys ]]; then
            sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' "$sshd_conf"
            sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' "$sshd_conf"
            sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin prohibit-password/' "$sshd_conf"
            if sshd -t 2>/dev/null; then
                systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
                msg_ok "Root password login disabled (key-only)"
            else
                msg_error "Config validation failed — skipping this change"
            fi
        else
            msg_error "No SSH keys found in /root/.ssh/authorized_keys"
            msg_warn "Add your SSH key first, then re-run this option"
        fi
    fi

    # Additional hardening
    spinner_start "Applying SSH hardening"
    
    # Disable empty passwords
    sed -i 's/^#\?PermitEmptyPasswords .*/PermitEmptyPasswords no/' "$sshd_conf"
    
    # Limit authentication attempts
    sed -i 's/^#\?MaxAuthTries .*/MaxAuthTries 3/' "$sshd_conf"
    
    # Disable X11 forwarding
    sed -i 's/^#\?X11Forwarding .*/X11Forwarding no/' "$sshd_conf"
    
    # Set login grace time
    sed -i 's/^#\?LoginGraceTime .*/LoginGraceTime 30/' "$sshd_conf"
    
    # Client alive settings
    sed -i 's/^#\?ClientAliveInterval .*/ClientAliveInterval 300/' "$sshd_conf"
    sed -i 's/^#\?ClientAliveCountMax .*/ClientAliveCountMax 2/' "$sshd_conf"
    
    if sshd -t 2>/dev/null; then
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
        spinner_stop 0
        msg_ok "SSH security hardening complete"
    else
        spinner_stop 1
        msg_error "SSH config validation failed — restoring backup"
        local latest_bak
        latest_bak="$(ls -t ${sshd_conf}.bak.* 2>/dev/null | head -1)"
        if [[ -n "$latest_bak" ]]; then
            cp "$latest_bak" "$sshd_conf"
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
        fi
    fi
    
    log_info "SSH hardening applied"
    return 0
}

# ─── Fail2ban ───
security_fail2ban() {
    msg_step "Installing Fail2ban"
    
    spinner_start "Installing fail2ban"
    pkg_install fail2ban
    if [[ $? -ne 0 ]]; then
        spinner_stop 1
        return 1
    fi
    
    pkg_install iptables 2>/dev/null || true
    spinner_stop 0
    
    # Get current SSH port
    local ssh_port
    ssh_port="$(config_get S4D_SSH_PORT 22)"
    [[ "$ssh_port" == "22" ]] && ssh_port="$(ss -tlnp | grep sshd | awk '{print $4}' | grep -oP '\d+$' | head -1)"
    [[ -z "$ssh_port" ]] && ssh_port=22

    # Configure fail2ban jail
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = -1
maxretry = 3
findtime = 24h
backend = systemd

[sshd]
enabled = true
filter = sshd
mode = aggressive
port = ${ssh_port}
logpath = %(sshd_log)s
banaction = iptables-multiport
EOF

    systemctl enable fail2ban 2>/dev/null
    systemctl restart fail2ban
    
    msg_ok "Fail2ban installed and configured"
    msg_info "SSH port ${ssh_port} protected (3 attempts, permanent ban)"
    log_info "Fail2ban configured for SSH port ${ssh_port}"
    return 0
}

# ─── Firewall Baseline ───
firewall_setup() {
    msg_step "Setting up firewall baseline"
    
    local fw_tool=""
    
    if command -v ufw &>/dev/null; then
        fw_tool="ufw"
    elif command -v firewall-cmd &>/dev/null; then
        fw_tool="firewalld"
    else
        # Install ufw on Debian, firewalld on RHEL/Arch
        case "$S4D_DISTRO_FAMILY" in
            debian)
                pkg_install ufw
                fw_tool="ufw"
                ;;
            rhel|arch)
                pkg_install firewalld
                fw_tool="firewalld"
                ;;
        esac
    fi

    local ssh_port
    ssh_port="$(config_get S4D_SSH_PORT 22)"
    [[ "$ssh_port" == "22" ]] && ssh_port="$(ss -tlnp | grep sshd | awk '{print $4}' | grep -oP '\d+$' | head -1)"
    [[ -z "$ssh_port" ]] && ssh_port=22

    case "$fw_tool" in
        ufw)
            spinner_start "Configuring UFW firewall"
            ufw default deny incoming 2>/dev/null
            ufw default allow outgoing 2>/dev/null
            
            # SSH
            ufw allow "$ssh_port"/tcp comment 's4dbox SSH' 2>/dev/null
            
            # Allow ports for installed apps
            app_is_installed "qbittorrent" && {
                ufw allow "$(config_get S4D_QB_PORT 8080)"/tcp comment 'qBittorrent WebUI' 2>/dev/null
                ufw allow "$(config_get S4D_QB_INCOMING_PORT 45000)"/tcp comment 'qBittorrent Incoming' 2>/dev/null
                ufw allow "$(config_get S4D_QB_INCOMING_PORT 45000)"/udp comment 'qBittorrent Incoming' 2>/dev/null
            }
            app_is_installed "jellyfin"   && ufw allow "$(config_get S4D_JELLYFIN_PORT 8096)"/tcp comment 'Jellyfin' 2>/dev/null
            app_is_installed "plex"       && ufw allow 32400/tcp comment 'Plex' 2>/dev/null
            app_is_installed "filebrowser" && ufw allow "$(config_get S4D_FILEBROWSER_PORT 8090)"/tcp comment 'FileBrowser' 2>/dev/null
            app_is_installed "rutorrent"  && ufw allow "$(config_get S4D_RUTORRENT_PORT 8081)"/tcp comment 'ruTorrent' 2>/dev/null
            
            # Nginx
            [[ "$(config_get S4D_NGINX_ENABLED 0)" == "1" ]] && {
                ufw allow 80/tcp comment 'HTTP' 2>/dev/null
                ufw allow 443/tcp comment 'HTTPS' 2>/dev/null
            }
            
            echo "y" | ufw enable 2>/dev/null
            spinner_stop 0
            msg_ok "UFW firewall configured"
            ;;
            
        firewalld)
            spinner_start "Configuring firewalld"
            systemctl enable firewalld 2>/dev/null
            systemctl start firewalld
            
            firewall-cmd --permanent --add-port="${ssh_port}/tcp" 2>/dev/null
            
            app_is_installed "qbittorrent" && {
                firewall-cmd --permanent --add-port="$(config_get S4D_QB_PORT 8080)/tcp" 2>/dev/null
                firewall-cmd --permanent --add-port="$(config_get S4D_QB_INCOMING_PORT 45000)/tcp" 2>/dev/null
                firewall-cmd --permanent --add-port="$(config_get S4D_QB_INCOMING_PORT 45000)/udp" 2>/dev/null
            }
            app_is_installed "jellyfin"    && firewall-cmd --permanent --add-port="$(config_get S4D_JELLYFIN_PORT 8096)/tcp" 2>/dev/null
            app_is_installed "plex"        && firewall-cmd --permanent --add-port="32400/tcp" 2>/dev/null
            app_is_installed "filebrowser" && firewall-cmd --permanent --add-port="$(config_get S4D_FILEBROWSER_PORT 8090)/tcp" 2>/dev/null
            app_is_installed "rutorrent"   && firewall-cmd --permanent --add-port="$(config_get S4D_RUTORRENT_PORT 8081)/tcp" 2>/dev/null
            
            [[ "$(config_get S4D_NGINX_ENABLED 0)" == "1" ]] && {
                firewall-cmd --permanent --add-service=http 2>/dev/null
                firewall-cmd --permanent --add-service=https 2>/dev/null
            }
            
            firewall-cmd --reload 2>/dev/null
            spinner_stop 0
            msg_ok "Firewalld configured"
            ;;
        *)
            msg_error "No supported firewall tool found"
            return 1
            ;;
    esac
    
    log_info "Firewall baseline configured"
    return 0
}

# ─── Security Menu ───
security_menu() {
    while true; do
        local options=(
            "SSH Hardening"
            "Install Fail2ban"
            "Setup Firewall Baseline"
            "Apply All Security (Recommended)"
            "View Firewall Rules"
            "View Fail2ban Status"
            "← Back"
        )
        
        tui_draw_menu "Security & Firewall" "${options[@]}"
        local choice=$?
        
        case $choice in
            0) ssh_harden; tui_pause ;;
            1) security_fail2ban; tui_pause ;;
            2) firewall_setup; tui_pause ;;
            3)
                ssh_harden
                security_fail2ban
                firewall_setup
                msg_ok "All security measures applied"
                tui_pause
                ;;
            4)
                clear
                msg_header "Firewall Rules"
                if command -v ufw &>/dev/null; then
                    ufw status verbose 2>/dev/null
                elif command -v firewall-cmd &>/dev/null; then
                    firewall-cmd --list-all 2>/dev/null
                else
                    msg_info "No firewall configured"
                fi
                tui_pause
                ;;
            5)
                clear
                msg_header "Fail2ban Status"
                if command -v fail2ban-client &>/dev/null; then
                    fail2ban-client status 2>/dev/null
                    echo
                    fail2ban-client status sshd 2>/dev/null
                else
                    msg_info "Fail2ban not installed"
                fi
                tui_pause
                ;;
            *) return ;;
        esac
    done
}
