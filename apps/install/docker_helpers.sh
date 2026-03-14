#!/usr/bin/env bash
# s4dbox - Shared helpers for Docker-based app installers

s4d_ensure_docker() {
    if command -v docker &>/dev/null; then
        systemctl enable docker 2>/dev/null || true
        systemctl start docker 2>/dev/null || true
    else
        msg_step "Installing Docker"
        case "$S4D_DISTRO_FAMILY" in
            debian)
                pkg_install ca-certificates 2>/dev/null || true
                pkg_install docker.io
                pkg_install docker-compose-plugin 2>/dev/null || true
                ;;
            arch)
                pkg_install docker
                pkg_install docker-compose 2>/dev/null || true
                ;;
            rhel)
                pkg_install dnf-plugins-core 2>/dev/null || true
                pkg_install docker 2>/dev/null || pkg_install docker-ce 2>/dev/null || true
                pkg_install docker-compose-plugin 2>/dev/null || true
                ;;
            suse)
                pkg_install docker
                ;;
            *)
                msg_error "Unsupported distro for docker install: ${S4D_DISTRO_FAMILY}"
                return 1
                ;;
        esac

        if ! command -v docker &>/dev/null; then
            msg_error "Docker installation failed"
            return 1
        fi

        systemctl enable docker 2>/dev/null || true
        systemctl start docker 2>/dev/null || true
    fi

    if ! systemctl is-active docker &>/dev/null; then
        msg_error "Docker daemon is not running"
        msg_info "Check: systemctl status docker"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        msg_error "Docker CLI cannot talk to the daemon"
        msg_info "Check: journalctl -xeu docker.service"
        return 1
    fi

    if docker compose version &>/dev/null; then
        S4D_DOCKER_COMPOSE=(docker compose)
    elif command -v docker-compose &>/dev/null; then
        S4D_DOCKER_COMPOSE=(docker-compose)
    else
        msg_error "Docker Compose not found (docker compose or docker-compose)"
        return 1
    fi

    return 0
}

s4d_write_compose_service() {
    local app="$1"
    local compose_file="$2"
    local compose_dir
    compose_dir="${compose_file%/*}"

    cat > "/etc/systemd/system/s4d-${app}.service" <<EOF
[Unit]
Description=s4dbox ${app} container stack
After=docker.service network-online.target
Wants=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${compose_dir}
ExecStart=${S4D_DOCKER_COMPOSE[*]} -f ${compose_file} up -d
ExecStop=${S4D_DOCKER_COMPOSE[*]} -f ${compose_file} down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "s4d-${app}.service" 2>/dev/null || true

    if ! systemctl restart "s4d-${app}.service"; then
        msg_error "Failed to start s4d-${app}.service"
        msg_info "Check: systemctl status s4d-${app}.service"
        msg_info "Logs:  journalctl -xeu s4d-${app}.service"
        return 1
    fi

    # Validate that compose stack is actually running (not only oneshot service success).
    local tries=10 total running
    while [[ $tries -gt 0 ]]; do
        total="$(${S4D_DOCKER_COMPOSE[@]} -f "$compose_file" ps -q 2>/dev/null | wc -l)"
        running="$(${S4D_DOCKER_COMPOSE[@]} -f "$compose_file" ps --status running -q 2>/dev/null | wc -l)"

        if [[ "$total" -gt 0 && "$running" -ge "$total" ]]; then
            return 0
        fi

        sleep 2
        tries=$((tries - 1))
    done

    msg_error "Container stack for ${app} is not healthy"
    msg_info "Check: ${S4D_DOCKER_COMPOSE[*]} -f ${compose_file} ps"
    msg_info "Logs:  ${S4D_DOCKER_COMPOSE[*]} -f ${compose_file} logs --tail=80"
    return 1
}

s4d_remove_compose_service() {
    local app="$1"
    local compose_file="/opt/s4dbox/appsdata/${app}/docker-compose.yml"

    if command -v docker &>/dev/null; then
        if docker compose version &>/dev/null; then
            docker compose -f "$compose_file" down 2>/dev/null || true
        elif command -v docker-compose &>/dev/null; then
            docker-compose -f "$compose_file" down 2>/dev/null || true
        fi
    fi

    systemctl stop "s4d-${app}.service" 2>/dev/null || true
    systemctl disable "s4d-${app}.service" 2>/dev/null || true
    rm -f "/etc/systemd/system/s4d-${app}.service"
    systemctl daemon-reload
}
