#!/usr/bin/env bash
# s4dbox - FileZilla GUI installer (Docker)

install_filezilla_gui() {
    local web_port vnc_port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    web_port="$(tui_input "FileZilla web access port" "5801")"
    vnc_port="$(tui_input "FileZilla VNC port" "5901")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/filezilla_gui"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/config"

    cat > "$compose_file" <<EOF
services:
  filezilla:
    image: jlesage/filezilla:latest
    container_name: s4d-filezilla
    environment:
      - TZ=Etc/UTC
      - KEEP_APP_RUNNING=1
    volumes:
      - ${app_dir}/config:/config
      - /home:/storage
    ports:
      - "${web_port}:5800"
      - "${vnc_port}:5900"
    restart: unless-stopped
EOF

    s4d_write_compose_service "filezilla_gui" "$compose_file" || return 1
    config_set "S4D_FILEZILLA_WEB_PORT" "$web_port"
    config_set "S4D_FILEZILLA_VNC_PORT" "$vnc_port"
    msg_ok "FileZilla GUI installed"
    msg_info "Web GUI: http://$(get_local_ip):${web_port}"
    return 0
}
