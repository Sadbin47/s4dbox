#!/usr/bin/env bash
# s4dbox - Nextcloud installer (Docker)

install_nextcloud() {
    local port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    port="$(tui_input "Nextcloud port" "8082")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/nextcloud"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/data"

    cat > "$compose_file" <<EOF
services:
  nextcloud:
    image: nextcloud:latest
    container_name: s4d-nextcloud
    ports:
      - "${port}:80"
    volumes:
      - ${app_dir}/data:/var/www/html
    restart: unless-stopped
EOF

    s4d_write_compose_service "nextcloud" "$compose_file"

    config_set "S4D_NEXTCLOUD_PORT" "$port"
    msg_ok "Nextcloud installed"
    msg_info "WebUI: http://$(get_local_ip):${port}"
    return 0
}
