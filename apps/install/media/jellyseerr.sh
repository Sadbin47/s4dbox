#!/usr/bin/env bash
# s4dbox - Jellyseerr installer (Docker)

install_jellyseerr() {
    local port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    port="$(tui_input "Jellyseerr port" "5055")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/jellyseerr"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/config"

    cat > "$compose_file" <<EOF
services:
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: s4d-jellyseerr
    environment:
      - TZ=Etc/UTC
    volumes:
      - ${app_dir}/config:/app/config
    ports:
      - "${port}:5055"
    restart: unless-stopped
EOF

    s4d_write_compose_service "jellyseerr" "$compose_file"

    config_set "S4D_JELLYSEERR_PORT" "$port"
    msg_ok "Jellyseerr installed"
    msg_info "WebUI: http://$(get_local_ip):${port}"
    return 0
}
