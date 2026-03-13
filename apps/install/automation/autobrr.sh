#!/usr/bin/env bash
# s4dbox - autobrr installer (Docker)

install_autobrr() {
    local username uid gid port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"
    uid="$(id -u "$username")"
    gid="$(id -g "$username")"
    port="$(tui_input "autobrr port" "7474")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/autobrr"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/config"

    cat > "$compose_file" <<EOF
services:
  autobrr:
    image: ghcr.io/autobrr/autobrr:latest
    container_name: s4d-autobrr
    user: "${uid}:${gid}"
    volumes:
      - ${app_dir}/config:/config
    ports:
      - "${port}:7474"
    restart: unless-stopped
EOF

    s4d_write_compose_service "autobrr" "$compose_file"

    config_set "S4D_AUTOBRR_PORT" "$port"
    msg_ok "autobrr installed"
    msg_info "WebUI: http://$(get_local_ip):${port}"
    return 0
}
