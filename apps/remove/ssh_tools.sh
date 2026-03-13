#!/usr/bin/env bash
# s4dbox - CLI tools bundle removal (non-destructive)

remove_ssh_tools() {
    msg_step "Removing CLI tools bundle"
    case "$S4D_DISTRO_FAMILY" in
        debian)
            pkg_remove p7zip-full 2>/dev/null || true
            pkg_remove ffmpeg 2>/dev/null || true
            pkg_remove mediainfo 2>/dev/null || true
            pkg_remove mktorrent 2>/dev/null || true
            pkg_remove mkvtoolnix 2>/dev/null || true
            pkg_remove unrar 2>/dev/null || true
            pkg_remove unzip 2>/dev/null || true
            ;;
        arch|rhel|suse)
            pkg_remove p7zip 2>/dev/null || true
            pkg_remove ffmpeg 2>/dev/null || true
            pkg_remove mediainfo 2>/dev/null || true
            pkg_remove mktorrent 2>/dev/null || true
            pkg_remove mkvtoolnix 2>/dev/null || true
            pkg_remove unrar 2>/dev/null || true
            pkg_remove unzip 2>/dev/null || true
            ;;
    esac
    msg_ok "CLI tools bundle removed"
    return 0
}
