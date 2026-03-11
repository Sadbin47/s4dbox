#!/usr/bin/env bash
# s4dbox - rTorrent Installer

install_rtorrent() {
    local username
    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"
    
    local scgi_port
    scgi_port="$(tui_input "rTorrent SCGI port" "$(config_get S4D_RTORRENT_PORT 5000)")"

    msg_step "Installing rTorrent"

    spinner_start "Installing rTorrent"
    case "$S4D_DISTRO_FAMILY" in
        debian)
            pkg_install rtorrent
            pkg_install screen
            ;;
        arch)
            pkg_install rtorrent
            pkg_install screen
            ;;
        rhel)
            # May need EPEL
            pkg_install epel-release 2>/dev/null || true
            pkg_install rtorrent
            pkg_install screen
            ;;
    esac
    spinner_stop $?

    # Create directories
    mkdir -p "/home/${username}/rtorrent/"{downloads,session,watch}
    chown -R "${username}:${username}" "/home/${username}/rtorrent"

    # Create .rtorrent.rc config
    cat > "/home/${username}/.rtorrent.rc" <<EOF
# s4dbox rTorrent Configuration

# Instance layout
method.insert = cfg.basedir,  private|const|string, (cat,"/home/${username}/rtorrent/")
method.insert = cfg.download, private|const|string, (cat,(cfg.basedir),"downloads/")
method.insert = cfg.session,  private|const|string, (cat,(cfg.basedir),"session/")
method.insert = cfg.watch,    private|const|string, (cat,(cfg.basedir),"watch/")

# Directories
directory.default.set = (cfg.download)
session.path.set = (cfg.session)

# Watch directory
schedule2 = watch_start, 10, 10, ((load.start, (cat, (cfg.watch), "*.torrent")))

# Listening port
network.port_range.set = 49164-49164
network.port_random.set = no

# SCGI - for ruTorrent
network.scgi.open_port = 127.0.0.1:${scgi_port}

# Limits
throttle.max_uploads.set = 100
throttle.max_uploads.global.set = 250
throttle.min_peers.normal.set = 20
throttle.max_peers.normal.set = 60
throttle.min_peers.seed.set = 30
throttle.max_peers.seed.set = 80

# Performance tuning
network.max_open_files.set = 600
network.max_open_sockets.set = 300
pieces.memory.max.set = 1800M
pieces.hash.on_completion.set = yes

# Encoding
encoding.add = UTF-8
system.umask.set = 0022

# DHT
dht.mode.set = disable
protocol.pex.set = no
trackers.use_udp.set = yes
EOF

    chown "${username}:${username}" "/home/${username}/.rtorrent.rc"

    # Create systemd service
    cat > /etc/systemd/system/rtorrent@.service <<EOF
[Unit]
Description=rTorrent for %i
After=network.target

[Service]
Type=forking
User=%i
KillMode=none
ExecStartPre=-/bin/rm -f /home/%i/rtorrent/session/rtorrent.lock
ExecStart=/usr/bin/screen -d -m -fa -S rtorrent /usr/bin/rtorrent
ExecStop=/usr/bin/killall -w -s INT rtorrent
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "rtorrent@${username}" 2>/dev/null
    systemctl start "rtorrent@${username}"

    config_set "S4D_RTORRENT_PORT" "$scgi_port"
    
    msg_ok "rTorrent installed"
    msg_info "SCGI: 127.0.0.1:${scgi_port}"
    msg_info "Downloads: /home/${username}/rtorrent/downloads/"
    
    return 0
}
