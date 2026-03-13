#!/usr/bin/env bash
# s4dbox - Prowlarr installer (Docker)

install_prowlarr() {
    local username uid gid port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"
    uid="$(id -u "$username")"
    gid="$(id -g "$username")"
    port="$(tui_input "Prowlarr port" "9696")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/prowlarr"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/config"

    cat > "$compose_file" <<EOF
services:
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: s4d-prowlarr
    environment:
      - PUID=${uid}
      - PGID=${gid}
      - TZ=Etc/UTC
    volumes:
      - ${app_dir}/config:/config
    ports:
      - "${port}:9696"
    restart: unless-stopped
EOF

    s4d_write_compose_service "prowlarr" "$compose_file" || return 1
    config_set "S4D_PROWLARR_PORT" "$port"
    msg_ok "Prowlarr installed"
    msg_info "WebUI: http://$(get_local_ip):${port}"
    return 0
}