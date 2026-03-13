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

    if tui_confirm "Connect to Tailscale now?"; then
        msg_info "Opening Tailscale authentication..."
        msg_info "A URL will appear below — open it in your browser to authenticate."
        echo
        # Run with --timeout so it doesn't hang forever
        tailscale up --timeout 60s 2>&1 || true
        echo
        local ts_ip
        ts_ip="$(tailscale ip -4 2>/dev/null || echo 'N/A')"
        if [[ "$ts_ip" != "N/A" ]]; then
            msg_ok "Tailscale connected"
            msg_info "Tailscale IP: ${ts_ip}"
        else
            msg_warn "Tailscale not yet connected. Run 'sudo tailscale up' later to authenticate."
        fi
    else
        msg_info "Run 'sudo tailscale up' later to connect."
    fi

    return 0
}
