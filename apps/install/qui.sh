#!/usr/bin/env bash
# s4dbox - Qui installer (Docker)

install_qui() {
    local port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    port="$(tui_input "Qui port" "7476")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/qui"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/config"

    cat > "$compose_file" <<EOF
services:
  qui:
    image: ghcr.io/autobrr/qui:latest
    container_name: s4d-qui
    ports:
      - "${port}:7476"
    volumes:
      - ${app_dir}/config:/config
    restart: unless-stopped
EOF

    s4d_write_compose_service "qui" "$compose_file"

    config_set "S4D_QUI_PORT" "$port"
    msg_ok "Qui installed"
    msg_info "WebUI: http://$(get_local_ip):${port}"
    return 0
}
