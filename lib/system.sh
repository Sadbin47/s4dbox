#!/usr/bin/env bash
# s4dbox - System detection and package manager abstraction
# Detects OS, arch, package manager, init system

set -euo pipefail

# ─── OS Detection ───
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        S4D_OS_NAME="$NAME"
        S4D_OS_ID="${ID:-unknown}"
        S4D_OS_ID_LIKE="${ID_LIKE:-$S4D_OS_ID}"
        S4D_OS_VERSION="${VERSION_ID:-unknown}"
        S4D_OS_PRETTY="${PRETTY_NAME:-$S4D_OS_NAME $S4D_OS_VERSION}"
    elif command -v lsb_release &>/dev/null; then
        S4D_OS_NAME="$(lsb_release -si)"
        S4D_OS_ID="$(echo "$S4D_OS_NAME" | tr '[:upper:]' '[:lower:]')"
        S4D_OS_ID_LIKE="$S4D_OS_ID"
        S4D_OS_VERSION="$(lsb_release -sr)"
        S4D_OS_PRETTY="$S4D_OS_NAME $S4D_OS_VERSION"
    elif [[ -f /etc/debian_version ]]; then
        S4D_OS_NAME="Debian"
        S4D_OS_ID="debian"
        S4D_OS_ID_LIKE="debian"
        S4D_OS_VERSION="$(cat /etc/debian_version)"
        S4D_OS_PRETTY="Debian $S4D_OS_VERSION"
    elif [[ -f /etc/redhat-release ]]; then
        S4D_OS_NAME="Red Hat"
        S4D_OS_ID="rhel"
        S4D_OS_ID_LIKE="rhel"
        S4D_OS_VERSION="unknown"
        S4D_OS_PRETTY="$(cat /etc/redhat-release)"
    else
        S4D_OS_NAME="$(uname -s)"
        S4D_OS_ID="unknown"
        S4D_OS_ID_LIKE="unknown"
        S4D_OS_VERSION="$(uname -r)"
        S4D_OS_PRETTY="$S4D_OS_NAME $S4D_OS_VERSION"
    fi

    export S4D_OS_NAME S4D_OS_ID S4D_OS_ID_LIKE S4D_OS_VERSION S4D_OS_PRETTY
}

# ─── Distro Family Detection ───
detect_distro_family() {
    detect_os
    case "$S4D_OS_ID" in
        debian|ubuntu|linuxmint|pop|raspbian|kali|mx|zorin)
            S4D_DISTRO_FAMILY="debian" ;;
        arch|manjaro|endeavouros|garuda|artix)
            S4D_DISTRO_FAMILY="arch" ;;
        fedora|rhel|centos|rocky|alma|ol|amzn)
            S4D_DISTRO_FAMILY="rhel" ;;
        opensuse*|sles)
            S4D_DISTRO_FAMILY="suse" ;;
        *)
            # Fallback to ID_LIKE
            if [[ "$S4D_OS_ID_LIKE" == *"debian"* ]]; then
                S4D_DISTRO_FAMILY="debian"
            elif [[ "$S4D_OS_ID_LIKE" == *"arch"* ]]; then
                S4D_DISTRO_FAMILY="arch"
            elif [[ "$S4D_OS_ID_LIKE" == *"rhel"* ]] || [[ "$S4D_OS_ID_LIKE" == *"fedora"* ]] || [[ "$S4D_OS_ID_LIKE" == *"centos"* ]]; then
                S4D_DISTRO_FAMILY="rhel"
            elif [[ "$S4D_OS_ID_LIKE" == *"suse"* ]]; then
                S4D_DISTRO_FAMILY="suse"
            else
                S4D_DISTRO_FAMILY="unknown"
            fi
            ;;
    esac
    export S4D_DISTRO_FAMILY
}

# ─── Architecture Detection ───
detect_arch() {
    local machine
    machine="$(uname -m)"
    case "$machine" in
        x86_64|amd64)    S4D_ARCH="x86_64" ;;
        aarch64|arm64)   S4D_ARCH="arm64"  ;;
        armv7l|armhf)    S4D_ARCH="armv7"  ;;
        *)               S4D_ARCH="$machine" ;;
    esac
    export S4D_ARCH
}

# ─── Package Manager Abstraction ───
detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        S4D_PKG_MGR="apt"
    elif command -v pacman &>/dev/null; then
        S4D_PKG_MGR="pacman"
    elif command -v dnf &>/dev/null; then
        S4D_PKG_MGR="dnf"
    elif command -v yum &>/dev/null; then
        S4D_PKG_MGR="yum"
    elif command -v zypper &>/dev/null; then
        S4D_PKG_MGR="zypper"
    else
        S4D_PKG_MGR="unknown"
    fi
    export S4D_PKG_MGR
}

pkg_update() {
    case "$S4D_PKG_MGR" in
        apt)    apt-get update -qq ;;
        pacman) pacman -Sy --noconfirm ;;
        dnf)    dnf check-update -q || true ;;
        yum)    yum check-update -q || true ;;
        zypper) zypper refresh -q ;;
        *)      msg_error "Unsupported package manager: $S4D_PKG_MGR"; return 1 ;;
    esac
}

pkg_install() {
    local pkg="$1"
    case "$S4D_PKG_MGR" in
        apt)    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" ;;
        pacman) pacman -S --noconfirm --needed "$pkg" ;;
        dnf)    dnf install -y -q "$pkg" ;;
        yum)    yum install -y -q "$pkg" ;;
        zypper) zypper install -y -q "$pkg" ;;
        *)      msg_error "Unsupported package manager: $S4D_PKG_MGR"; return 1 ;;
    esac
}

pkg_remove() {
    local pkg="$1"
    case "$S4D_PKG_MGR" in
        apt)    apt-get remove -y -qq "$pkg" ;;
        pacman) pacman -Rns --noconfirm "$pkg" ;;
        dnf)    dnf remove -y -q "$pkg" ;;
        yum)    yum remove -y -q "$pkg" ;;
        zypper) zypper remove -y -q "$pkg" ;;
        *)      msg_error "Unsupported package manager: $S4D_PKG_MGR"; return 1 ;;
    esac
}

pkg_is_installed() {
    local pkg="$1"
    case "$S4D_PKG_MGR" in
        apt)    dpkg -l "$pkg" 2>/dev/null | grep -q '^ii' ;;
        pacman) pacman -Qi "$pkg" &>/dev/null ;;
        dnf|yum) rpm -q "$pkg" &>/dev/null ;;
        zypper) rpm -q "$pkg" &>/dev/null ;;
        *)      return 1 ;;
    esac
}

# ─── Init System Detection ───
detect_init_system() {
    if [[ -d /run/systemd/system ]]; then
        S4D_INIT="systemd"
    elif [[ -f /sbin/openrc ]]; then
        S4D_INIT="openrc"
    elif [[ -f /sbin/init ]]; then
        S4D_INIT="sysvinit"
    else
        S4D_INIT="unknown"
    fi
    export S4D_INIT
}

# ─── Virtualization Detection ───
detect_virt() {
    if command -v systemd-detect-virt &>/dev/null; then
        S4D_VIRT="$(systemd-detect-virt 2>/dev/null || echo 'none')"
    elif [[ -f /proc/cpuinfo ]] && grep -qi 'hypervisor' /proc/cpuinfo; then
        S4D_VIRT="vm"
    else
        S4D_VIRT="none"
    fi
    export S4D_VIRT
}

# ─── Network Interface Detection ───
detect_nic() {
    S4D_NIC="$(ip -o link show up 2>/dev/null | awk -F': ' '!/lo/{print $2; exit}' | cut -d'@' -f1)"
    [[ -z "$S4D_NIC" ]] && S4D_NIC="eth0"
    export S4D_NIC
}

# ─── Memory Detection ───
detect_memory() {
    S4D_MEM_TOTAL_KB=$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
    S4D_MEM_TOTAL_MB=$(( S4D_MEM_TOTAL_KB / 1024 ))
    export S4D_MEM_TOTAL_KB S4D_MEM_TOTAL_MB
}

# ─── Full System Detection ───
detect_system() {
    detect_distro_family
    detect_arch
    detect_pkg_manager
    detect_init_system
    detect_virt
    detect_nic
    detect_memory
}

# ─── Install Core Dependencies ───
install_core_deps() {
    local deps=(curl wget jq bc procps)
    
    # Add distro-specific names
    case "$S4D_DISTRO_FAMILY" in
        debian) deps+=(coreutils net-tools ethtool iproute2 lsb-release) ;;
        arch)   deps+=(coreutils net-tools ethtool iproute2) ;;
        rhel)   deps+=(coreutils net-tools ethtool iproute) ;;
    esac

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null && ! pkg_is_installed "$dep"; then
            pkg_install "$dep" 2>/dev/null || true
        fi
    done
}

# ─── Get Local IP (works without hostname command) ───
get_local_ip() {
    # Try ip command first (most reliable)
    if command -v ip &>/dev/null; then
        ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1
        return
    fi
    # Fallback to hostname -I
    if command -v hostname &>/dev/null; then
        hostname -I 2>/dev/null | awk '{print $1}'
        return
    fi
    # Last resort
    echo "127.0.0.1"
}

# ─── Print System Summary ───
print_system_info() {
    msg_header "System Information"
    printf "  %-18s %s\n" "OS:" "$S4D_OS_PRETTY"
    printf "  %-18s %s\n" "Family:" "$S4D_DISTRO_FAMILY"
    printf "  %-18s %s\n" "Architecture:" "$S4D_ARCH"
    printf "  %-18s %s\n" "Package Manager:" "$S4D_PKG_MGR"
    printf "  %-18s %s\n" "Init System:" "$S4D_INIT"
    printf "  %-18s %s\n" "Virtualization:" "$S4D_VIRT"
    printf "  %-18s %s\n" "Network Interface:" "$S4D_NIC"
    printf "  %-18s %s MB\n" "Total Memory:" "$S4D_MEM_TOTAL_MB"
    echo
}
