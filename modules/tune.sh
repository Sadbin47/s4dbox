#!/usr/bin/env bash
# s4dbox - System Tuning Module
# Integrates kernel tuning, network optimization from Tune project
# Optimizes seedbox based on CPU, memory, storage for best transfer speeds

# ─── Install Tuned ───
tune_install_tuned() {
    if command -v tuned &>/dev/null; then
        return 0
    fi
    pkg_install tuned 2>/dev/null || true
}

# ─── File Open Limit ───
tune_file_limits() {
    msg_step "Setting file open limits"
    
    # Check if already set
    if grep -q "# s4dbox file limits" /etc/security/limits.conf 2>/dev/null; then
        msg_info "File limits already configured"
        return 0
    fi
    
    cat >> /etc/security/limits.conf <<EOF

# s4dbox file limits
* soft nofile 655360
* hard nofile 655360
EOF
    log_info "Set file open limits to 655360"
    return 0
}

# ─── Ring Buffer (bare metal only) ───
tune_ring_buffer() {
    if ! command -v ethtool &>/dev/null; then
        pkg_install ethtool 2>/dev/null || return 1
    fi
    
    local nic="${S4D_NIC}"
    ethtool -G "$nic" rx 1024 2>/dev/null
    sleep 0.5
    ethtool -G "$nic" tx 2048 2>/dev/null
    log_info "Set ring buffer on $nic"
    return 0
}

# ─── Disable TSO (for VMs) ───
tune_disable_tso() {
    if ! command -v ethtool &>/dev/null; then
        pkg_install ethtool 2>/dev/null || return 1
    fi
    
    local nic="${S4D_NIC}"
    ethtool -K "$nic" tso off gso off gro off 2>/dev/null
    log_info "Disabled TSO/GSO/GRO on $nic"
    return 0
}

# ─── TX Queue Length ───
tune_txqueuelen() {
    if ! command -v ifconfig &>/dev/null; then
        pkg_install net-tools 2>/dev/null || return 1
    fi
    ifconfig "$S4D_NIC" txqueuelen 10000 2>/dev/null
    log_info "Set txqueuelen to 10000"
    return 0
}

# ─── Initial Congestion Window ───
tune_init_cwnd() {
    local iproute
    iproute=$(ip -o -4 route show to default)
    ip route change $iproute initcwnd 100 initrwnd 100 2>/dev/null
    log_info "Set initcwnd=100 initrwnd=100"
    return 0
}

# ─── Kernel Network Settings ───
tune_kernel_settings() {
    msg_step "Applying kernel network tuning"
    
    local mem_size="${S4D_MEM_TOTAL_MB}"
    local adv_win_scale rmem_default rmem_max tcp_rmem
    local wmem_default wmem_max tcp_wmem
    local background_ratio dirty_ratio writeback_centisecs expire_centisecs swappiness

    # Scale parameters based on available memory
    if [[ $mem_size -le 128 ]]; then
        adv_win_scale=3
        rmem_default=262144; rmem_max=16777216
        tcp_rmem="8192 $rmem_default $rmem_max"
        wmem_default=262144; wmem_max=16777216
        tcp_wmem="8192 $wmem_default $wmem_max"
        background_ratio=5; dirty_ratio=20
        writeback_centisecs=100; expire_centisecs=100; swappiness=80
    elif [[ $mem_size -le 512 ]]; then
        adv_win_scale=2
        rmem_default=262144; rmem_max=16777216
        tcp_rmem="8192 $rmem_default $rmem_max"
        wmem_default=262144; wmem_max=16777216
        tcp_wmem="8192 $wmem_default $wmem_max"
        background_ratio=5; dirty_ratio=20
        writeback_centisecs=100; expire_centisecs=500; swappiness=60
    elif [[ $mem_size -le 1024 ]]; then
        adv_win_scale=1
        rmem_default=262144; rmem_max=33554432
        tcp_rmem="8192 $rmem_default $rmem_max"
        wmem_default=262144; wmem_max=33554432
        tcp_wmem="8192 $wmem_default $wmem_max"
        background_ratio=5; dirty_ratio=30
        writeback_centisecs=100; expire_centisecs=1000; swappiness=20
    else
        adv_win_scale=1
        rmem_default=262144; rmem_max=33554432
        tcp_rmem="8192 $rmem_default $rmem_max"
        wmem_default=262144; wmem_max=33554432
        tcp_wmem="8192 $wmem_default $wmem_max"
        background_ratio=5; dirty_ratio=30
        writeback_centisecs=100; expire_centisecs=1000; swappiness=10
    fi

    # Backup existing sysctl.conf
    [[ -f /etc/sysctl.conf ]] && cp /etc/sysctl.conf "/etc/sysctl.conf.bak.$(date +%s)"

    cat > /etc/sysctl.conf <<EOF
#### s4dbox Network & Kernel Tuning ####

### Network Security
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.tcp_syncookies=1
net.core.somaxconn=10000
net.ipv4.tcp_max_syn_backlog=10000
net.ipv4.tcp_max_orphans=10000
net.ipv4.tcp_orphan_retries=2
net.ipv4.tcp_invalid_ratelimit=500
net.ipv4.ip_forward=0
net.ipv6.conf.all.forwarding=0
net.ipv4.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv4.conf.all.log_martians=1
net.ipv4.tcp_rfc1337=0

### SoftIRQ / Backlog
net.core.netdev_max_backlog=10000
net.core.netdev_budget=50000
net.core.netdev_budget_usecs=8000

### Socket Buffer Sizes
net.ipv4.tcp_adv_win_scale=${adv_win_scale}
net.core.rmem_default=${rmem_default}
net.core.rmem_max=${rmem_max}
net.ipv4.tcp_rmem=${tcp_rmem}
net.core.wmem_default=${wmem_default}
net.core.wmem_max=${wmem_max}
net.ipv4.tcp_wmem=${tcp_wmem}
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_workaround_signed_windows=1

### MTU Discovery
net.ipv4.ip_no_pmtu_disc=0
net.ipv4.tcp_mtu_probing=2
net.ipv4.tcp_base_mss=1460
net.ipv4.tcp_min_snd_mss=536
net.ipv4.ipfrag_high_thresh=8388608

### TCP Reliability
net.ipv4.tcp_sack=1
net.ipv4.tcp_dsack=1
net.ipv4.tcp_early_retrans=3
net.ipv4.tcp_ecn=0
net.ipv4.tcp_reordering=10
net.ipv4.tcp_max_reordering=1000
net.ipv4.tcp_frto=2
net.ipv4.tcp_autocorking=1
net.ipv4.tcp_retries1=5
net.ipv4.tcp_retries2=20

### TCP Keepalive
net.ipv4.tcp_keepalive_time=7200
net.ipv4.tcp_keepalive_intvl=120
net.ipv4.tcp_keepalive_probes=15

### SYN Retries
net.ipv4.tcp_synack_retries=10
net.ipv4.tcp_syn_retries=7

### Connection Scaling
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_max_tw_buckets=10000
net.ipv4.tcp_fin_timeout=10

### Performance
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_fastopen_blackhole_timeout_sec=0
net.ipv4.tcp_notsent_lowat=131072
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_no_metrics_save=0

### ARP
net.ipv4.neigh.default.unres_qlen_bytes=16777216

### Buffer / Cache Management
vm.dirty_background_ratio=${background_ratio}
vm.dirty_ratio=${dirty_ratio}
vm.dirty_writeback_centisecs=${writeback_centisecs}
vm.dirty_expire_centisecs=${expire_centisecs}
vm.swappiness=${swappiness}

### Congestion Control
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl -p &>/dev/null
    log_info "Applied kernel tuning settings"
    return 0
}

# ─── Boot Script for Persistent Network Tuning ───
tune_boot_script() {
    cat > /root/.s4dbox-boot-tune.sh <<'BOOTSCRIPT'
#!/bin/bash
sleep 5

# Detect NIC
NIC="$(ip -o link show up 2>/dev/null | awk -F': ' '!/lo/{print $2; exit}' | cut -d'@' -f1)"
[[ -z "$NIC" ]] && exit 0

# Detect virtualization
VIRT="$(systemd-detect-virt 2>/dev/null || echo 'none')"

if [[ "$VIRT" == "none" ]]; then
    ethtool -G "$NIC" rx 1024 2>/dev/null
    ethtool -G "$NIC" tx 2048 2>/dev/null
else
    ethtool -K "$NIC" tso off gso off gro off 2>/dev/null
fi

if [[ "$VIRT" != "lxc" ]]; then
    ifconfig "$NIC" txqueuelen 10000 2>/dev/null
    iproute=$(ip -o -4 route show to default)
    ip route change $iproute initcwnd 100 initrwnd 100 2>/dev/null
fi
BOOTSCRIPT
    chmod +x /root/.s4dbox-boot-tune.sh

    cat > /etc/systemd/system/s4dbox-tune.service <<EOF
[Unit]
Description=s4dbox Boot Network Tuning
After=network.target

[Service]
Type=oneshot
ExecStart=/root/.s4dbox-boot-tune.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable s4dbox-tune.service 2>/dev/null
    log_info "Installed boot tuning service"
    return 0
}

# ─── Full Tune Execution ───
tune_apply_all() {
    msg_header "System Tuning"
    
    spinner_start "Installing tuned"
    tune_install_tuned
    spinner_stop 0
    
    tune_file_limits
    tune_kernel_settings

    if [[ "$S4D_VIRT" == "none" ]]; then
        spinner_start "Tuning ring buffers"
        tune_ring_buffer
        spinner_stop $?
    else
        spinner_start "Disabling offloading (VM detected)"
        tune_disable_tso
        spinner_stop $?
    fi

    if [[ "$S4D_VIRT" != "lxc" ]]; then
        spinner_start "Setting TX queue length"
        tune_txqueuelen
        spinner_stop $?
        
        spinner_start "Setting initial congestion window"
        tune_init_cwnd
        spinner_stop $?
    fi

    spinner_start "Installing boot tuning service"
    tune_boot_script
    spinner_stop 0

    msg_ok "System tuning applied"
    echo
    msg_info "Memory-based profile: ${S4D_MEM_TOTAL_MB}MB detected"
    msg_info "Virtualization: ${S4D_VIRT}"
    msg_info "Network interface: ${S4D_NIC}"
    echo
}

# ─── Tune Menu ───
tune_menu() {
    while true; do
        local options=(
            "Apply Full Tuning (Recommended)"
            "Kernel Network Settings Only"
            "File Open Limits Only"
            "NIC Tuning Only"
            "View Current sysctl.conf"
            "← Back"
        )
        
        tui_draw_menu "System Tuning" "${options[@]}"
        local choice=$?
        
        case $choice in
            0) tune_apply_all; tui_pause ;;
            1) tune_kernel_settings; msg_ok "Kernel settings applied"; tui_pause ;;
            2) tune_file_limits; msg_ok "File limits applied"; tui_pause ;;
            3)
                if [[ "$S4D_VIRT" == "none" ]]; then
                    tune_ring_buffer
                else
                    tune_disable_tso
                fi
                tune_txqueuelen 2>/dev/null
                tune_init_cwnd 2>/dev/null
                msg_ok "NIC tuning applied"
                tui_pause
                ;;
            4)
                clear
                msg_header "Current sysctl.conf"
                cat /etc/sysctl.conf 2>/dev/null | head -80
                tui_pause
                ;;
            *) return ;;
        esac
    done
}
