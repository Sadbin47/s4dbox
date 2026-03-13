#!/usr/bin/env bash
# s4dbox - Readarr installer (Docker)

install_readarr() {
    local username uid gid port app_dir compose_file

    source "${S4D_BASE_DIR}/apps/install/docker_helpers.sh"

    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"
    uid="$(id -u "$username")"
    gid="$(id -g "$username")"
    port="$(tui_input "Readarr port" "8787")"

    s4d_ensure_docker || return 1

    app_dir="/opt/s4dbox/appsdata/readarr"
    compose_file="${app_dir}/docker-compose.yml"
    mkdir -p "${app_dir}/config" "/home/${username}/downloads" "/home/${username}/media/books"

    cat > "$compose_file" <<EOF
services:
  readarr:
    image: lscr.io/linuxserver/readarr:develop
    container_name: s4d-readarr
    environment:
      - PUID=${uid}
      - PGID=${gid}
      - TZ=Etc/UTC
    volumes:
      - ${app_dir}/config:/config
      - /home/${username}/downloads:/downloads
      - /home/${username}/media/books:/books
    ports:
      - "${port}:8787"
    restart: unless-stopped
EOF

    s4d_write_compose_service "readarr" "$compose_file"

    config_set "S4D_READARR_PORT" "$port"
    msg_ok "Readarr installed"
    msg_info "WebUI: http://$(get_local_ip):${port}"
    return 0
}
