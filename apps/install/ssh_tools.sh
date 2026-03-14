#!/usr/bin/env bash
# s4dbox - Seedbox CLI tools bundle installer

install_ssh_tools() {
    msg_step "Installing CLI tools bundle"

    local tools=(7z ffmpeg mediainfo mktorrent mkvtoolnix unrar unzip)
    local pkglist=()

    case "$S4D_DISTRO_FAMILY" in
        debian)
            pkglist=(p7zip-full ffmpeg mediainfo mktorrent mkvtoolnix unrar unzip)
            ;;
        arch)
            pkglist=(p7zip ffmpeg mediainfo mktorrent mkvtoolnix unrar unzip)
            ;;
        rhel|suse)
            pkglist=(p7zip ffmpeg mediainfo mktorrent mkvtoolnix unrar unzip)
            ;;
        *)
            msg_error "Unsupported distro for CLI tools bundle"
            return 1
            ;;
    esac

    spinner_start "Installing: ${tools[*]}"
    local rc=0
    for pkg in "${pkglist[@]}"; do
        pkg_install "$pkg" 2>/dev/null || true
    done
    spinner_stop $rc

    msg_ok "CLI tools installed"
    msg_info "Tools: ${tools[*]}"
    return 0
}
