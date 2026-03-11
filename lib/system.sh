#!/usr/bin/env bash
# s4dbox - System detection and package manager abstraction
# Detects OS, arch, package manager, init system
# NOTE: Do NOT use 'set -e' here — this file is sourced by s4dbox,
# and tui_draw_menu returns selection index via exit code (>0 is valid).

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

# ─── Print System Summary (basic) ───
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

# ─── Detailed System Info (benchmark-style) ───
print_system_info_full() {
    clear

    # CPU info
    local cpu_model cpu_cores cpu_mhz cpu_cache aes_ni vmx
    cpu_model="$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null)"
    cpu_model="${cpu_model:-Unknown}"
    cpu_cores="$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)"
    cpu_mhz="$(awk -F': ' '/^cpu MHz/{printf "%.3f", $2; exit}' /proc/cpuinfo 2>/dev/null)"
    cpu_cache="$(awk -F': ' '/^cache size/{print $2; exit}' /proc/cpuinfo 2>/dev/null)"
    [[ -z "$cpu_cache" ]] && cpu_cache="$(lscpu 2>/dev/null | awk -F': +' '/L3 cache/{print $2}')"
    [[ -z "$cpu_cache" ]] && cpu_cache="N/A"

    if grep -qi 'aes' /proc/cpuinfo 2>/dev/null; then
        aes_ni="${GREEN}✔ Enabled${RESET}"
    else
        aes_ni="${RED}❌ Disabled${RESET}"
    fi

    if grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
        vmx="${GREEN}✔ Enabled${RESET}"
    else
        vmx="${RED}❌ Disabled${RESET}"
    fi

    # Disk info
    local disk_total disk_used
    disk_total="$(df -h --total 2>/dev/null | awk '/^total/{print $2}')"
    disk_used="$(df -h --total 2>/dev/null | awk '/^total/{print $3}')"
    [[ -z "$disk_total" ]] && disk_total="N/A"
    [[ -z "$disk_used" ]] && disk_used="N/A"

    # Memory
    local mem_total_h mem_used_h swap_total_h swap_used_h
    local mt mf ma st sf
    mt=0; mf=0; ma=0; st=0; sf=0
    while IFS=': ' read -r k v _; do
        case "$k" in
            MemTotal) mt=$v;; MemAvailable) ma=$v;;
            SwapTotal) st=$v;; SwapFree) sf=$v;;
        esac
    done < /proc/meminfo
    local mu=$(( mt - ma )) su=$(( st - sf ))
    mem_total_h="$(awk -v v="$mt" 'BEGIN{printf "%.1f GB", v/1048576}')"
    mem_used_h="$(awk -v v="$mu" 'BEGIN{printf "%.1f GB", v/1048576}')"
    swap_total_h="$(awk -v v="$st" 'BEGIN{printf "%.1f GB", v/1048576}')"
    swap_used_h="$(awk -v t="$st" -v u="$su" 'BEGIN{printf "%.1f GB", t > 0 ? u/1048576 : 0}')"

    # Uptime
    local seconds days hours mins
    seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
    days=$(( seconds / 86400 ))
    hours=$(( (seconds % 86400) / 3600 ))
    mins=$(( (seconds % 3600) / 60 ))
    local uptime_str="${days} days, ${hours} hour ${mins} min"

    # Load
    local loadavg
    loadavg="$(awk '{printf "%s, %s, %s", $1, $2, $3}' /proc/loadavg 2>/dev/null)"

    # Kernel
    local kernel
    kernel="$(uname -r)"

    # Virt type (uppercase)
    local virt_name
    virt_name="$(echo "${S4D_VIRT:-none}" | tr '[:lower:]' '[:upper:]')"

    # TCP congestion control
    local tcp_cc
    tcp_cc="$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo 'N/A')"

    # Render
    local W=68
    printf "\n"
    printf "  ${BOLD}${CYAN}"
    printf ' ---------------------------------------------------------------------------\n'
    printf '  Basic System Info\n'
    printf ' ---------------------------------------------------------------------------\n'
    printf "  ${RESET}"
    printf "  %-20s: %s\n" " CPU Model" "$cpu_model"
    printf "  %-20s: %s @ %s MHz\n" " CPU Cores" "$cpu_cores" "${cpu_mhz:-N/A}"
    printf "  %-20s: %s\n" " CPU Cache" "$cpu_cache"
    printf "  %-20s: %b\n" " AES-NI" "$aes_ni"
    printf "  %-20s: %b\n" " VM-x/AMD-V" "$vmx"
    printf "  %-20s: %s (%s Used)\n" " Total Disk" "$disk_total" "$disk_used"
    printf "  %-20s: %s (%s Used)\n" " Total RAM" "$mem_total_h" "$mem_used_h"
    printf "  %-20s: %s (%s Used)\n" " Total Swap" "$swap_total_h" "$swap_used_h"
    printf "  %-20s: %s\n" " System uptime" "$uptime_str"
    printf "  %-20s: %s\n" " Load average" "$loadavg"
    printf "  %-20s: %s\n" " OS" "$S4D_OS_PRETTY"
    printf "  %-20s: %s (%s Bit)\n" " Arch" "$S4D_ARCH" "$(getconf LONG_BIT 2>/dev/null || echo 64)"
    printf "  %-20s: %s\n" " Kernel" "$kernel"
    printf "  %-20s: %s\n" " Virtualization" "$virt_name"
    printf "  %-20s: %s\n" " TCP Control" "$tcp_cc"
    printf "  ${BOLD}${CYAN}"
    printf ' ---------------------------------------------------------------------------\n'
    printf "  ${RESET}"
    echo
}
