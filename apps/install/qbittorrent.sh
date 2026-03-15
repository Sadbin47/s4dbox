#!/usr/bin/env bash
# s4dbox - qBittorrent Installer
# Uses pre-compiled binaries from Seedbox-Components for ARM64 and x86_64
# Supports: qBit 4.3.9, 4.5.5, 4.6.7, 5.0.3, 5.1.0beta1

# ─── Version / Libtorrent Compatibility ───
declare -A QB_VERSIONS=(
    [1]="4.3.9"
    [2]="4.5.5"
    [3]="4.6.7"
    [4]="5.0.3"
    [5]="5.1.0beta1"
)

declare -A QB_LIB_COMPAT=(
    [4.3.9]="v1.2.20"
    [4.5.5]="v1.2.20 v2.0.11"
    [4.6.7]="v1.2.20 v2.0.11"
    [5.0.3]="v1.2.20 v2.0.11"
    [5.1.0beta1]="v1.2.20 v2.0.11"
)

QB_BINARY_BASE="https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent"
QB_PWGEN_URL="https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent"

# ─── Version Selection ───
qb_select_version() {
    local options=()
    for i in 1 2 3 4 5; do
        options+=("qBittorrent ${QB_VERSIONS[$i]}")
    done
    
    tui_draw_menu "Select qBittorrent Version" "${options[@]}"
    local choice=$?
    [[ $choice -eq 255 ]] && return 1
    
    QB_SELECTED_VER="${QB_VERSIONS[$(( choice + 1 ))]}"
    echo "$QB_SELECTED_VER"
}

# ─── Libtorrent Selection ───
qb_select_libtorrent() {
    local qb_ver="$1"
    local compat="${QB_LIB_COMPAT[$qb_ver]}"
    local options=()
    
    for lib in $compat; do
        options+=("libtorrent-${lib}")
    done
    
    if [[ ${#options[@]} -eq 1 ]]; then
        QB_SELECTED_LIB="${options[0]#libtorrent-}"
        echo "$QB_SELECTED_LIB"
        return
    fi
    
    tui_draw_menu "Select libtorrent Version" "${options[@]}"
    local choice=$?
    [[ $choice -eq 255 ]] && return 1
    
    QB_SELECTED_LIB="${options[$choice]#libtorrent-}"
    echo "$QB_SELECTED_LIB"
}

# ─── Disk Tuning Parameters ───
qb_get_tune_params() {
    local virt="$S4D_VIRT"
    
    if [[ "$virt" != "none" ]]; then
        QB_AIO=8
        QB_LOW_BUFFER=3072
        QB_BUFFER=15360
        QB_BUFFER_FACTOR=200
    else
        # Detect disk type
        local disk_name
        disk_name=$(lsblk -d -n -o NAME | head -1)
        local disk_type
        disk_type=$(cat "/sys/block/${disk_name}/queue/rotational" 2>/dev/null || echo 1)
        
        if [[ "$disk_type" -eq 0 ]]; then
            # SSD
            QB_AIO=12
            QB_LOW_BUFFER=5120
            QB_BUFFER=20480
            QB_BUFFER_FACTOR=250
        else
            # HDD
            QB_AIO=4
            QB_LOW_BUFFER=3072
            QB_BUFFER=10240
            QB_BUFFER_FACTOR=150
        fi
    fi
}

# ─── Generate Password Hash ───
qb_gen_password() {
    local password="$1"
    local arch="$S4D_ARCH"
    local arch_dir
    
    case "$arch" in
        x86_64) arch_dir="x86_64" ;;
        arm64)  arch_dir="ARM64" ;;
        *)      msg_error "Unsupported arch for qBittorrent: $arch"; return 1 ;;
    esac

    # Download password generator
    wget -q "${QB_PWGEN_URL}/${arch_dir}/qb_password_gen" -O /tmp/qb_password_gen
    if [[ $? -ne 0 ]]; then
        msg_error "Failed to download password generator"
        return 1
    fi
    chmod +x /tmp/qb_password_gen
    local hash
    hash=$(/tmp/qb_password_gen "$password")
    rm -f /tmp/qb_password_gen
    echo "$hash"
}

# ─── Main Install Function ───
install_qbittorrent() {
    local username password qb_ver lib_ver qb_port qb_incoming_port qb_cache

    username="$(get_seedbox_user)"
    if [[ -z "$username" ]]; then
        username="$(prompt_user_setup)"
    fi
    
    # Get password
    password="$(tui_password "Enter password for qBittorrent WebUI")"
    while [[ ${#password} -lt 4 ]]; do
        msg_warn "Password too short (min 4 chars)"
        password="$(tui_password "Enter password for qBittorrent WebUI")"
    done

    # Select version
    qb_ver="$(qb_select_version)"
    [[ -z "$qb_ver" ]] && return 1
    
    # Select libtorrent
    lib_ver="$(qb_select_libtorrent "$qb_ver")"
    [[ -z "$lib_ver" ]] && return 1

    # Ports
    qb_port="$(tui_input "WebUI port" "$(config_get S4D_QB_PORT 8080)")"
    qb_incoming_port="$(tui_input "Incoming connection port" "$(config_get S4D_QB_INCOMING_PORT 45000)")"
    
    # Cache - auto-detect based on RAM
    local mem_mb="$S4D_MEM_TOTAL_MB"
    if [[ $mem_mb -le 1024 ]]; then
        qb_cache=128
    elif [[ $mem_mb -le 2048 ]]; then
        qb_cache=256
    elif [[ $mem_mb -le 4096 ]]; then
        qb_cache=512
    else
        qb_cache=1024
    fi
    qb_cache="$(tui_input "Disk cache size (MB)" "$qb_cache")"

    msg_step "Installing qBittorrent ${qb_ver} with libtorrent-${lib_ver}"
    
    # Stop existing instance
    if pgrep -f qbittorrent-nox &>/dev/null; then
        msg_info "Stopping existing qBittorrent..."
        systemctl stop "qbittorrent-nox@${username}" 2>/dev/null || true
        pkill -f qbittorrent-nox 2>/dev/null || true
        sleep 2
    fi

    # Remove old binary
    rm -f /usr/bin/qbittorrent-nox

    # Download binary
    local arch_dir
    case "$S4D_ARCH" in
        x86_64) arch_dir="x86_64" ;;
        arm64)  arch_dir="ARM64" ;;
        *) msg_error "Unsupported architecture: $S4D_ARCH"; return 1 ;;
    esac

    local dl_url="${QB_BINARY_BASE}/${arch_dir}/qBittorrent-${qb_ver}%20-%20libtorrent-${lib_ver}/qbittorrent-nox"
    
    spinner_start "Downloading qBittorrent ${qb_ver}"
    wget -q "$dl_url" -O /tmp/qbittorrent-nox
    if [[ $? -ne 0 ]]; then
        spinner_stop 1
        msg_error "Failed to download qBittorrent binary"
        return 1
    fi
    spinner_stop 0

    chmod +x /tmp/qbittorrent-nox
    mv /tmp/qbittorrent-nox /usr/bin/qbittorrent-nox

    # Create directories
    mkdir -p "/home/${username}/qbittorrent/Downloads"
    chown -R "${username}:${username}" "/home/${username}/qbittorrent"
    mkdir -p "/home/${username}/.config/qBittorrent"
    chown "${username}:${username}" "/home/${username}/.config/qBittorrent"

    # Create systemd service
    cat > /etc/systemd/system/qbittorrent-nox@.service <<EOF
[Unit]
Description=qBittorrent-nox for %i
After=network.target

[Service]
Type=forking
User=%i
LimitNOFILE=infinity
ExecStart=/usr/bin/qbittorrent-nox -d
Restart=on-failure
TimeoutStopSec=20
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "qbittorrent-nox@${username}" 2>/dev/null

    # Get tuning parameters
    qb_get_tune_params

    # Generate config
    spinner_start "Configuring qBittorrent"
    
    # Generate password hash (PBKDF2 for 4.2+)
    local pw_hash
    pw_hash="$(qb_gen_password "$password")"
    
    if [[ "${qb_ver}" =~ ^4\.[34]\. ]]; then
        # qBit 4.3.x / 4.4.x style config
        cat > "/home/${username}/.config/qBittorrent/qBittorrent.conf" <<QBCONF
[BitTorrent]
Session\\AsyncIOThreadsCount=${QB_AIO}
Session\\SendBufferLowWatermark=${QB_LOW_BUFFER}
Session\\SendBufferWatermark=${QB_BUFFER}
Session\\SendBufferWatermarkFactor=${QB_BUFFER_FACTOR}

[LegalNotice]
Accepted=true

[Network]
Cookies=@Invalid()

[Preferences]
Connection\\PortRangeMin=${qb_incoming_port}
Downloads\\DiskWriteCacheSize=${qb_cache}
Downloads\\SavePath=/home/${username}/qbittorrent/Downloads/
Queueing\\QueueingEnabled=false
WebUI\\Password_PBKDF2="@ByteArray(${pw_hash})"
WebUI\\Port=${qb_port}
WebUI\\Username=${username}
QBCONF

    elif [[ "${qb_ver}" =~ ^4\.[56]\. ]]; then
        # qBit 4.5.x / 4.6.x style config
        cat > "/home/${username}/.config/qBittorrent/qBittorrent.conf" <<QBCONF
[Application]
MemoryWorkingSetLimit=${qb_cache}

[BitTorrent]
Session\\AsyncIOThreadsCount=${QB_AIO}
Session\\DefaultSavePath=/home/${username}/qbittorrent/Downloads/
Session\\DiskCacheSize=${qb_cache}
Session\\Port=${qb_incoming_port}
Session\\QueueingSystemEnabled=false
Session\\SendBufferLowWatermark=${QB_LOW_BUFFER}
Session\\SendBufferWatermark=${QB_BUFFER}
Session\\SendBufferWatermarkFactor=${QB_BUFFER_FACTOR}

[LegalNotice]
Accepted=true

[Network]
Cookies=@Invalid()

[Preferences]
WebUI\\Password_PBKDF2="@ByteArray(${pw_hash})"
WebUI\\Port=${qb_port}
WebUI\\Username=${username}
QBCONF

    elif [[ "${qb_ver}" =~ ^5\. ]]; then
        # qBit 5.x style config
        cat > "/home/${username}/.config/qBittorrent/qBittorrent.conf" <<QBCONF
[Application]
MemoryWorkingSetLimit=${qb_cache}

[BitTorrent]
Session\\AsyncIOThreadsCount=${QB_AIO}
Session\\DefaultSavePath=/home/${username}/qbittorrent/Downloads/
Session\\DiskCacheSize=${qb_cache}
Session\\Port=${qb_incoming_port}
Session\\QueueingSystemEnabled=false
Session\\SendBufferLowWatermark=${QB_LOW_BUFFER}
Session\\SendBufferWatermark=${QB_BUFFER}
Session\\SendBufferWatermarkFactor=${QB_BUFFER_FACTOR}

[LegalNotice]
Accepted=true

[Network]
Cookies=@Invalid()

[Preferences]
WebUI\\Password_PBKDF2="@ByteArray(${pw_hash})"
WebUI\\Port=${qb_port}
WebUI\\Username=${username}
QBCONF
    fi

    chown "${username}:${username}" "/home/${username}/.config/qBittorrent/qBittorrent.conf"
    
    spinner_stop 0

    # Start service
    if ! systemctl restart "qbittorrent-nox@${username}"; then
        msg_error "Failed to start qbittorrent-nox@${username}.service"
        msg_info "Check: systemctl status qbittorrent-nox@${username}.service"
        msg_info "Logs:  journalctl -xeu qbittorrent-nox@${username}.service"
        return 1
    fi
    
    # Save config
    config_set "S4D_QB_PORT" "$qb_port"
    config_set "S4D_QB_INCOMING_PORT" "$qb_incoming_port"
    config_set "S4D_QB_VERSION" "$qb_ver"
    config_set "S4D_QB_LIBTORRENT" "$lib_ver"
    
    msg_ok "qBittorrent ${qb_ver} installed"
    msg_info "WebUI: http://$(get_local_ip):${qb_port}"
    msg_info "Username: ${username}"
    
    return 0
}
