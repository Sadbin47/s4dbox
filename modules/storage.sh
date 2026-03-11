#!/usr/bin/env bash
# s4dbox - Storage Manager
# Disk detection, mounting, health checks

# ─── List Disks ───
storage_list_disks() {
    msg_header "Storage Devices"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL 2>/dev/null
    echo
}

# ─── Disk Health (SMART) ───
storage_smart_check() {
    if ! command -v smartctl &>/dev/null; then
        pkg_install smartmontools 2>/dev/null
    fi
    
    if ! command -v smartctl &>/dev/null; then
        msg_error "smartmontools not available"
        return 1
    fi

    msg_header "Disk Health (SMART)"
    
    local disks
    disks=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print $1}')
    
    while IFS= read -r disk; do
        [[ -z "$disk" ]] && continue
        echo "  ── /dev/${disk} ──"
        smartctl -H "/dev/${disk}" 2>/dev/null | grep -E "SMART|Health|result" || echo "  SMART not supported"
        echo
    done <<< "$disks"
}

# ─── Disk Usage Overview ───
storage_usage() {
    msg_header "Disk Usage"
    df -h --output=source,size,used,avail,pcent,target 2>/dev/null | \
        grep -E '^/dev/|Filesystem' | \
        column -t
    echo
}

# ─── Mount a Disk ───
storage_mount_disk() {
    echo
    storage_list_disks
    
    local device
    device="$(tui_input "Device to mount (e.g., /dev/sdb1)")"
    [[ -z "$device" ]] && return 1
    
    if [[ ! -b "$device" ]]; then
        msg_error "Device $device not found"
        return 1
    fi
    
    local mountpoint
    mountpoint="$(tui_input "Mount point (e.g., /mnt/data)")"
    [[ -z "$mountpoint" ]] && return 1
    
    mkdir -p "$mountpoint"
    
    mount "$device" "$mountpoint"
    if [[ $? -eq 0 ]]; then
        msg_ok "Mounted $device at $mountpoint"
        
        if tui_confirm "Add to /etc/fstab for persistent mount?"; then
            local uuid
            uuid=$(blkid -s UUID -o value "$device" 2>/dev/null)
            local fstype
            fstype=$(blkid -s TYPE -o value "$device" 2>/dev/null)
            
            if [[ -n "$uuid" ]]; then
                echo "UUID=${uuid} ${mountpoint} ${fstype} defaults 0 2" >> /etc/fstab
                msg_ok "Added to fstab"
            else
                echo "${device} ${mountpoint} auto defaults 0 2" >> /etc/fstab
                msg_ok "Added to fstab (by device path)"
            fi
        fi
    else
        msg_error "Failed to mount $device"
        return 1
    fi
}

# ─── Storage Menu ───
storage_menu() {
    while true; do
        local options=(
            "List Storage Devices"
            "Disk Usage Overview"
            "Disk Health Check (SMART)"
            "Mount a Disk"
            "← Back"
        )
        
        tui_draw_menu "Storage Manager" "${options[@]}"
        local choice=$?
        
        case $choice in
            0) clear; storage_list_disks; tui_pause ;;
            1) clear; storage_usage; tui_pause ;;
            2) clear; storage_smart_check; tui_pause ;;
            3) storage_mount_disk; tui_pause ;;
            *) return ;;
        esac
    done
}
