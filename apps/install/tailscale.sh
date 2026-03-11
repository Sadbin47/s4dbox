#!/usr/bin/env bash
# s4dbox - Tailscale VPN Installer

install_tailscale() {
    msg_step "Installing Tailscale"

    spinner_start "Installing Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh 2>/dev/null
    if [[ $? -ne 0 ]]; then
        spinner_stop 1
        msg_error "Failed to install Tailscale"
        return 1
    fi
    spinner_stop 0

    # Enable and start
    systemctl enable tailscaled 2>/dev/null
    systemctl start tailscaled

    msg_ok "Tailscale installed"
    msg_info "Run 'tailscale up' to connect to your Tailscale network"

    if tui_confirm "Connect to Tailscale now?"; then
        tailscale up
        echo
        local ts_ip
        ts_ip="$(tailscale ip -4 2>/dev/null || echo 'N/A')"
        msg_info "Tailscale IP: ${ts_ip}"
    fi

    return 0
}
