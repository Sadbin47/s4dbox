#!/usr/bin/env bash
# s4dbox - User management utilities

create_seedbox_user() {
    local username="$1"
    local password="$2"

    if id "$username" &>/dev/null; then
        msg_warn "User '$username' already exists"
        return 0
    fi

    useradd -m -s /bin/bash "$username"
    echo "${username}:${password}" | chpasswd
    
    # Create standard directories
    mkdir -p "/home/${username}/downloads"
    mkdir -p "/home/${username}/media"
    mkdir -p "/home/${username}/.config"
    chown -R "${username}:${username}" "/home/${username}"

    config_set "S4D_USER" "$username"
    log_info "Created seedbox user: $username"
    msg_ok "User '$username' created"
}

get_seedbox_user() {
    local user
    user="$(config_get 'S4D_USER')"
    if [[ -z "$user" ]]; then
        # Try to detect from installed apps
        if [[ -d /etc/s4dbox/installed_apps ]]; then
            user="$(ls /home/ 2>/dev/null | head -1)"
        fi
    fi
    echo "$user"
}

prompt_user_setup() {
    local username password password2

    echo
    msg_step "User Setup"
    echo
    
    read -rp "  Enter seedbox username: " username
    while [[ -z "$username" ]] || [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; do
        msg_warn "Invalid username. Use lowercase letters, numbers, underscores, hyphens."
        read -rp "  Enter seedbox username: " username
    done

    while true; do
        read -rsp "  Enter password: " password
        echo
        read -rsp "  Confirm password: " password2
        echo
        if [[ "$password" == "$password2" ]] && [[ ${#password} -ge 6 ]]; then
            break
        fi
        msg_warn "Passwords don't match or too short (min 6 chars). Try again."
    done

    create_seedbox_user "$username" "$password"
    echo "$username"
}
