#!/usr/bin/env bash
# s4dbox - VNC remote desktop installer (Docker)

install_vnc_desktop() {
    local web_port vnc_port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    web_port="$(tui_input "VNC web port (noVNC)" "6080")"
    vnc_port="$(tui_input "VNC raw port" "5900")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/vnc_desktop"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "$app_dir"

    cat > "$compose_file" <<EOF
services:
  vnc-desktop:
    image: dorowu/ubuntu-desktop-lxde-vnc:latest
    container_name: s4d-vnc-desktop
    shm_size: "1gb"
    ports:
      - "${web_port}:80"
      - "${vnc_port}:5900"
    restart: unless-stopped
EOF

    s4d_write_compose_service "vnc_desktop" "$compose_file" || return 1
    config_set "S4D_VNC_WEB_PORT" "$web_port"
    config_set "S4D_VNC_PORT" "$vnc_port"
    msg_ok "VNC desktop installed"
    msg_info "Web desktop: http://$(get_local_ip):${web_port}"
    msg_info "VNC: $(get_local_ip):${vnc_port}"
    return 0
}
