#!/usr/bin/env bash
# s4dbox - Shared helpers for Docker-based app installers

s4d_detect_docker_compose_cmd() {
    if docker compose version &>/dev/null; then
        S4D_DOCKER_COMPOSE=(docker compose)
        return 0
    fi

    if command -v docker-compose &>/dev/null; then
        S4D_DOCKER_COMPOSE=(docker-compose)
        return 0
    fi

    return 1
}

s4d_install_docker_compose() {
    case "$S4D_DISTRO_FAMILY" in
        debian)
            pkg_install docker-compose-plugin 2>/dev/null || pkg_install docker-compose 2>/dev/null || true
            ;;
        arch)
            pkg_install docker-compose 2>/dev/null || true
            ;;
        rhel)
            pkg_install docker-compose-plugin 2>/dev/null || pkg_install docker-compose 2>/dev/null || true
            ;;
        suse)
            pkg_install docker-compose 2>/dev/null || true
            ;;
    esac
}

s4d_start_docker_runtime() {
    # Full purge may mask these units; unmask before trying to enable/start.
    systemctl unmask docker docker.service docker.socket 2>/dev/null || true
    systemctl unmask containerd containerd.service containerd.socket 2>/dev/null || true

    # Some distros need containerd up first; ignore if absent.
    systemctl enable containerd 2>/dev/null || true
    systemctl start containerd 2>/dev/null || true

    systemctl enable docker.socket 2>/dev/null || true
    systemctl start docker.socket 2>/dev/null || true
    systemctl enable docker 2>/dev/null || true
    if ! systemctl start docker 2>/dev/null; then
        systemctl restart docker 2>/dev/null || true
    fi

    if ! systemctl is-active docker &>/dev/null; then
        msg_error "Docker daemon is not running"
        msg_info "Check: systemctl status docker"
        msg_info "Logs:  journalctl -xeu docker.service"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        msg_error "Docker CLI cannot talk to daemon"
        msg_info "Check: docker info"
        return 1
    fi

    return 0
}

s4d_ensure_docker() {
    if command -v docker &>/dev/null; then
        s4d_start_docker_runtime || return 1
    else
        msg_step "Installing Docker"
        case "$S4D_DISTRO_FAMILY" in
            debian)
                pkg_install ca-certificates 2>/dev/null || true
                pkg_install docker.io
                ;;
            arch)
                pkg_install docker
                ;;
            rhel)
                pkg_install dnf-plugins-core 2>/dev/null || true
                pkg_install docker 2>/dev/null || pkg_install docker-ce 2>/dev/null || true
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

        s4d_start_docker_runtime || return 1
    fi

    if ! s4d_detect_docker_compose_cmd; then
        msg_step "Installing Docker Compose"
        s4d_install_docker_compose
    fi

    if ! s4d_detect_docker_compose_cmd; then
        msg_error "Docker Compose not found (docker compose or docker-compose)"
        case "$S4D_DISTRO_FAMILY" in
            debian)
                msg_info "Try: apt-get update && apt-get install -y docker-compose-plugin"
                msg_info "Fallback: apt-get install -y docker-compose"
                ;;
            arch)
                msg_info "Try: pacman -S --needed docker-compose"
                ;;
            rhel)
                msg_info "Try: dnf install -y docker-compose-plugin"
                ;;
            suse)
                msg_info "Try: zypper install -y docker-compose"
                ;;
        esac
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

    s4d_start_docker_runtime || return 1

    if ! systemctl restart "s4d-${app}.service"; then
        msg_error "Failed to start s4d-${app}.service"
        msg_info "Check: systemctl status s4d-${app}.service"
        msg_info "Logs:  journalctl -xeu s4d-${app}.service"
        return 1
    fi

    # Validate that compose stack is actually running (not only oneshot service success).
    # Fresh servers may need extra time for image pulls + first boot initialization.
    local tries=120 total running restarting check_count=0
    local ids cid state
    msg_info "Waiting for ${app} container(s) to become healthy (first run can take several minutes)..."
    while [[ $tries -gt 0 ]]; do
        total=0
        running=0
        restarting=0

        ids="$(${S4D_DOCKER_COMPOSE[@]} -f "$compose_file" ps -q 2>/dev/null)"
        if [[ -n "$ids" ]]; then
            while IFS= read -r cid; do
                [[ -z "$cid" ]] && continue
                total=$((total + 1))
                state="$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || echo unknown)"
                case "$state" in
                    running)
                        running=$((running + 1))
                        ;;
                    restarting)
                        restarting=$((restarting + 1))
                        ;;
                esac
            done <<< "$ids"
        fi

        check_count=$((check_count + 1))
        if (( check_count % 15 == 0 )); then
            msg_info "${app}: running ${running}/${total}, restarting ${restarting}"
        fi

        # restarting containers are not healthy for WebUI usage and usually lead to 502.
        if [[ "$total" -gt 0 && "$running" -eq "$total" && "$restarting" -eq 0 ]]; then
            msg_ok "${app} container stack is healthy"
            return 0
        fi

        sleep 2
        tries=$((tries - 1))
    done

    msg_error "Container stack for ${app} is not healthy"
    msg_info "Check: ${S4D_DOCKER_COMPOSE[*]} -f ${compose_file} ps"
    msg_info "Logs:  ${S4D_DOCKER_COMPOSE[*]} -f ${compose_file} logs --tail=80"
    msg_info "Service: systemctl status s4d-${app}.service"
    echo
    msg_warn "Recent ${app} container logs:"
    ${S4D_DOCKER_COMPOSE[@]} -f "$compose_file" logs --tail=80 2>/dev/null || true
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
