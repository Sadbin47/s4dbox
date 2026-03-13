#!/usr/bin/env bash
# s4dbox - Sonarr installer (Docker)

install_sonarr() {
    local username uid gid port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"
    uid="$(id -u "$username")"
    gid="$(id -g "$username")"
    port="$(tui_input "Sonarr V4 port" "8989")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/sonarr"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/config" "/home/${username}/downloads" "/home/${username}/media"

    cat > "$compose_file" <<EOF
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: s4d-sonarr
    environment:
      - PUID=${uid}
      - PGID=${gid}
      - TZ=Etc/UTC
    volumes:
      - ${app_dir}/config:/config
      - /home/${username}/downloads:/downloads
      - /home/${username}/media:/media
    ports:
      - "${port}:8989"
    restart: unless-stopped
EOF

    s4d_write_compose_service "sonarr" "$compose_file"

    config_set "S4D_SONARR_PORT" "$port"
    msg_ok "Sonarr installed"
    msg_info "WebUI: http://$(get_local_ip):${port}"
    return 0
}
