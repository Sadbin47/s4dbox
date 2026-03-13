#!/usr/bin/env bash
# s4dbox - Jackett installer (Docker)

install_jackett() {
    local username uid gid port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"
    uid="$(id -u "$username")"
    gid="$(id -g "$username")"
    port="$(tui_input "Jackett port" "9117")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/jackett"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/config" "${app_dir}/downloads"

    cat > "$compose_file" <<EOF
services:
  jackett:
    image: lscr.io/linuxserver/jackett:latest
    container_name: s4d-jackett
    environment:
      - PUID=${uid}
      - PGID=${gid}
      - TZ=Etc/UTC
    volumes:
      - ${app_dir}/config:/config
      - ${app_dir}/downloads:/downloads
    ports:
      - "${port}:9117"
    restart: unless-stopped
EOF

    s4d_write_compose_service "jackett" "$compose_file" || return 1
    config_set "S4D_JACKETT_PORT" "$port"
    msg_ok "Jackett installed"
    msg_info "WebUI: http://$(get_local_ip):${port}"
    return 0
}