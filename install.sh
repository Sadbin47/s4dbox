#!/usr/bin/env bash
#═══════════════════════════════════════════════════════════════════════════════
#  s4dbox — One-Click Installer
#═══════════════════════════════════════════════════════════════════════════════
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/Sadbin47/s4dbox/main/install.sh | sudo bash
#    or:
#    wget -qO- https://raw.githubusercontent.com/Sadbin47/s4dbox/main/install.sh | sudo bash
#
#  Options (env vars):
#    S4D_BRANCH=main           Git branch to install from
#    S4D_INSTALL_DIR=/opt/s4dbox  Installation directory
#    S4D_SKIP_SETUP=1          Skip first-time guided setup
#
#═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

#── Defaults ──
S4D_BRANCH="${S4D_BRANCH:-main}"
S4D_INSTALL_DIR="${S4D_INSTALL_DIR:-/opt/s4dbox}"
S4D_BIN="/usr/local/bin/s4dbox"
S4D_SKIP_SETUP="${S4D_SKIP_SETUP:-0}"
S4D_REPO="https://github.com/Sadbin47/s4dbox"

#── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${CYAN}[INFO]${RESET}  %s\n" "$1"; }
ok()    { printf "${GREEN}[OK]${RESET}    %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${RESET}  %s\n" "$1"; }
error() { printf "${RED}[ERR]${RESET}   %s\n" "$1" >&2; }
die()   { error "$1"; exit 1; }

#── Root check ──
if [[ $EUID -ne 0 ]]; then
    die "This installer must be run as root (use sudo)"
fi

#── Banner ──
printf "${BOLD}${CYAN}"
cat <<'BANNER'

    ███████╗██╗  ██╗██████╗ ██████╗  ██████╗ ██╗  ██╗
    ██╔════╝██║  ██║██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝
    ███████╗███████║██║  ██║██████╔╝██║   ██║ ╚███╔╝ 
    ╚════██║╚════██║██║  ██║██╔══██╗██║   ██║ ██╔██╗ 
    ███████║     ██║██████╔╝██████╔╝╚██████╔╝██╔╝ ██╗
    ╚══════╝     ╚═╝╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝
                                         Installer
BANNER
printf "${RESET}\n"

#── Detect OS ──
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        die "Cannot detect OS: /etc/os-release not found"
    fi
    
    # shellcheck source=/dev/null
    source /etc/os-release
    
    local os_id="${ID:-unknown}"
    local os_like="${ID_LIKE:-}"
    
    if [[ "$os_id" =~ ^(debian|ubuntu|linuxmint|pop|zorin|kali)$ ]] || [[ "$os_like" =~ debian ]]; then
        PKG_MGR="apt"
    elif [[ "$os_id" =~ ^(arch|manjaro|endeavouros|garuda)$ ]] || [[ "$os_like" =~ arch ]]; then
        PKG_MGR="pacman"
    elif [[ "$os_id" =~ ^(fedora|rhel|centos|rocky|almalinux|ol)$ ]] || [[ "$os_like" =~ (rhel|fedora) ]]; then
        if command -v dnf &>/dev/null; then
            PKG_MGR="dnf"
        else
            PKG_MGR="yum"
        fi
    elif [[ "$os_id" =~ ^(opensuse|sles)$ ]] || [[ "$os_like" =~ suse ]]; then
        PKG_MGR="zypper"
    else
        die "Unsupported OS: ${os_id}. Supported: Debian, Ubuntu, Arch, Fedora, RHEL, Rocky"
    fi
    
    info "Detected: ${PRETTY_NAME:-$os_id} (package manager: ${PKG_MGR})"
}

#── Detect Architecture ──
detect_arch() {
    local machine
    machine="$(uname -m)"
    case "$machine" in
        x86_64|amd64) S4D_ARCH="x86_64" ;;
        aarch64|arm64) S4D_ARCH="aarch64" ;;
        *)
            die "Unsupported architecture: ${machine}. Supported: x86_64, aarch64"
            ;;
    esac
    info "Architecture: ${S4D_ARCH}"
}

#── Install Dependencies ──
install_deps() {
    info "Installing core dependencies..."
    
    local deps_common="git curl wget"
    
    case "$PKG_MGR" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y -qq ${deps_common} >/dev/null 2>&1
            ;;
        pacman)
            pacman -Sy --noconfirm --needed ${deps_common} >/dev/null 2>&1
            ;;
        dnf)
            dnf install -y -q ${deps_common} >/dev/null 2>&1
            ;;
        yum)
            yum install -y -q ${deps_common} >/dev/null 2>&1
            ;;
        zypper)
            zypper install -y -q ${deps_common} >/dev/null 2>&1
            ;;
    esac
    
    ok "Dependencies installed"
}

#── Download s4dbox ──
download_s4dbox() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    
    if [[ -d "${S4D_INSTALL_DIR}" ]]; then
        warn "Existing installation found at ${S4D_INSTALL_DIR}"
        # Backup config
        if [[ -d /etc/s4dbox ]]; then
            info "Backing up configuration..."
            cp -r /etc/s4dbox "/etc/s4dbox.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        fi
        rm -rf "${S4D_INSTALL_DIR}"
    fi
    
    info "Downloading s4dbox (branch: ${S4D_BRANCH})..."
    
    if command -v git &>/dev/null; then
        git clone --depth 1 --branch "${S4D_BRANCH}" "${S4D_REPO}.git" "${tmp_dir}/s4dbox" 2>/dev/null && {
            mv "${tmp_dir}/s4dbox" "${S4D_INSTALL_DIR}"
            ok "Downloaded via git"
        } || {
            # Fallback: try archive
            warn "Git clone failed, trying archive download..."
            download_archive "${tmp_dir}"
        }
    else
        download_archive "${tmp_dir}"
    fi
    
    rm -rf "${tmp_dir}"
}

download_archive() {
    local tmp_dir="$1"
    local archive_url="${S4D_REPO}/archive/refs/heads/${S4D_BRANCH}.tar.gz"
    
    if command -v curl &>/dev/null; then
        curl -fsSL "${archive_url}" | tar -xz -C "${tmp_dir}"
    elif command -v wget &>/dev/null; then
        wget -qO- "${archive_url}" | tar -xz -C "${tmp_dir}"
    else
        die "Neither curl nor wget available"
    fi
    
    mv "${tmp_dir}"/s4dbox-* "${S4D_INSTALL_DIR}"
    ok "Downloaded via archive"
}

#── Install s4dbox for local development / already-downloaded ──
install_local() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [[ -f "${script_dir}/s4dbox" ]] && [[ -d "${script_dir}/lib" ]]; then
        info "Local s4dbox detected. Installing from local copy..."
        
        if [[ "${script_dir}" != "${S4D_INSTALL_DIR}" ]]; then
            mkdir -p "${S4D_INSTALL_DIR}"
            cp -r "${script_dir}"/* "${S4D_INSTALL_DIR}/"
        fi
        
        return 0
    fi
    return 1
}

#── Set Permissions & Link ──
setup_permissions() {
    info "Setting permissions..."
    
    # Make main script executable
    chmod +x "${S4D_INSTALL_DIR}/s4dbox"
    
    # Make all shell scripts executable
    find "${S4D_INSTALL_DIR}" -name "*.sh" -exec chmod +x {} \;
    
    # Create symlink
    ln -sf "${S4D_INSTALL_DIR}/s4dbox" "${S4D_BIN}"
    
    ok "Installed to ${S4D_INSTALL_DIR}"
    ok "Symlinked: ${S4D_BIN} → ${S4D_INSTALL_DIR}/s4dbox"
}

#── Create directories ──
setup_directories() {
    mkdir -p /etc/s4dbox/installed_apps
    mkdir -p /var/log/s4dbox
    mkdir -p /opt/s4dbox
    ok "Directories created"
}

#── Main ──
main() {
    detect_os
    detect_arch
    install_deps
    setup_directories
    
    # Try local install first (if running from cloned repo)
    if ! install_local; then
        download_s4dbox
    fi
    
    setup_permissions
    
    echo
    printf "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║   s4dbox installed successfully!         ║"
    echo "  ╠══════════════════════════════════════════╣"
    echo "  ║                                          ║"
    echo "  ║   Run: sudo s4dbox                       ║"
    echo "  ║   Setup: sudo s4dbox install             ║"
    echo "  ║   Help: sudo s4dbox help                 ║"
    echo "  ║                                          ║"
    echo "  ╚══════════════════════════════════════════╝"
    printf "${RESET}\n"
    
    # Launch setup unless skipped
    if [[ "${S4D_SKIP_SETUP}" != "1" ]]; then
        echo
        read -rp "Launch first-time setup now? [Y/n] " answer
        if [[ "${answer,,}" != "n" ]]; then
            exec "${S4D_BIN}" install
        fi
    fi
}

main
