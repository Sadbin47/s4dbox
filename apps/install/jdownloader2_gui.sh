#!/usr/bin/env bash
# s4dbox - JDownloader2 GUI installer (Docker)

install_jdownloader2_gui() {
    local web_port vnc_port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    web_port="$(tui_input "JDownloader2 web access port" "5802")"
    vnc_port="$(tui_input "JDownloader2 VNC port" "5902")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/jdownloader2_gui"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/config" "${app_dir}/downloads"

    cat > "$compose_file" <<EOF
services:
  jdownloader2:
    image: jlesage/jdownloader-2:latest
    container_name: s4d-jdownloader2
    environment:
      - TZ=Etc/UTC
      - KEEP_APP_RUNNING=1
    volumes:
      - ${app_dir}/config:/config
      - ${app_dir}/downloads:/output
    ports:
      - "${web_port}:5800"
      - "${vnc_port}:5900"
    restart: unless-stopped
EOF

    s4d_write_compose_service "jdownloader2_gui" "$compose_file"

    config_set "S4D_JDOWNLOADER2_WEB_PORT" "$web_port"
    config_set "S4D_JDOWNLOADER2_VNC_PORT" "$vnc_port"
    msg_ok "JDownloader2 GUI installed"
    msg_info "Web GUI: http://$(get_local_ip):${web_port}"
    return 0
}
