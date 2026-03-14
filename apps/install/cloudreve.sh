#!/usr/bin/env bash
# s4dbox - Cloudreve installer (Docker)

install_cloudreve() {
  local port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    port="$(tui_input "Cloudreve port" "5212")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/cloudreve"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/cloudreve" "${app_dir}/uploads" "${app_dir}/avatar"
    chmod -R u+rwX,go+rX "${app_dir}" >/dev/null 2>&1 || true

    cat > "$compose_file" <<EOF
services:
  cloudreve:
    image: cloudreve/cloudreve:latest
    container_name: s4d-cloudreve
    ports:
      - "${port}:5212"
    volumes:
      - ${app_dir}/cloudreve:/cloudreve
      - ${app_dir}/uploads:/cloudreve/uploads
      - ${app_dir}/avatar:/cloudreve/avatar
    restart: unless-stopped
EOF

    s4d_write_compose_service "cloudreve" "$compose_file" || return 1
    config_set "S4D_CLOUDREVE_PORT" "$port"
    msg_ok "Cloudreve installed"
    msg_info "WebUI: http://$(get_local_ip):${port}"
    return 0
}
