#!/usr/bin/env bash
# s4dbox - Configuration management
# Central config store at /etc/s4dbox/

S4D_CONF_DIR="/etc/s4dbox"
S4D_CONF_FILE="${S4D_CONF_DIR}/s4dbox.conf"
S4D_APP_STATE="${S4D_CONF_DIR}/installed_apps"
S4D_DATA_DIR="/opt/s4dbox"

config_init() {
    mkdir -p "$S4D_CONF_DIR"
    mkdir -p "$S4D_APP_STATE"
    mkdir -p "$S4D_DATA_DIR"

    if [[ ! -f "$S4D_CONF_FILE" ]]; then
        cat > "$S4D_CONF_FILE" <<'CONF'
# s4dbox configuration
# Generated automatically

# Default seedbox user
S4D_USER=""

# Default download directory
S4D_DOWNLOAD_DIR="/home/${S4D_USER}/downloads"

# Default media directory
S4D_MEDIA_DIR="/home/${S4D_USER}/media"

# qBittorrent WebUI port
S4D_QB_PORT=8080

# qBittorrent incoming port
S4D_QB_INCOMING_PORT=45000

# Jellyfin port
S4D_JELLYFIN_PORT=8096

# Plex port
S4D_PLEX_PORT=32400

# FileBrowser port
S4D_FILEBROWSER_PORT=8090

# rTorrent SCGI port
S4D_RTORRENT_PORT=5000

# ruTorrent port
S4D_RUTORRENT_PORT=8081

# Nginx enabled
S4D_NGINX_ENABLED=0

# SSH port
S4D_SSH_PORT=22
CONF
        chmod 600 "$S4D_CONF_FILE"
    fi
}

config_load() {
    [[ -f "$S4D_CONF_FILE" ]] && source "$S4D_CONF_FILE"
}

config_set() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$S4D_CONF_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$S4D_CONF_FILE"
    else
        echo "${key}=\"${value}\"" >> "$S4D_CONF_FILE"
    fi
}

config_get() {
    local key="$1"
    local default="${2:-}"
    local val
    val=$(grep "^${key}=" "$S4D_CONF_FILE" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"')
    echo "${val:-$default}"
}

# Track installed apps
app_mark_installed() {
    local app="$1"
    touch "${S4D_APP_STATE}/${app}"
    log_info "Marked app as installed: $app"
}

app_mark_removed() {
    local app="$1"
    rm -f "${S4D_APP_STATE}/${app}"
    log_info "Marked app as removed: $app"
}

app_is_installed() {
    local app="$1"
    [[ -f "${S4D_APP_STATE}/${app}" ]]
}

app_list_installed() {
    ls -1 "${S4D_APP_STATE}/" 2>/dev/null
}
