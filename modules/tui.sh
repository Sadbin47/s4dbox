#!/usr/bin/env bash
# s4dbox - TUI Menu System
# Lightweight terminal UI using pure bash

# ─── Menu Drawing ───
tui_draw_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local num_options=${#options[@]}
    local key=""

    # Hide cursor
    tput civis 2>/dev/null || true

    while true; do
        clear
        local width=56
        
        # Header
        printf "\n"
        printf "  ${BOLD}${CYAN}┌"
        printf '─%.0s' $(seq 1 $width)
        printf "┐${RESET}\n"
        
        # Title
        local pad_left=$(( (width - ${#title}) / 2 ))
        local pad_right=$(( width - ${#title} - pad_left ))
        printf "  ${BOLD}${CYAN}│${RESET}"
        printf '%*s' "$pad_left" ''
        printf "${BOLD}${WHITE}%s${RESET}" "$title"
        printf '%*s' "$pad_right" ''
        printf "${BOLD}${CYAN}│${RESET}\n"
        
        # Separator
        printf "  ${BOLD}${CYAN}├"
        printf '─%.0s' $(seq 1 $width)
        printf "┤${RESET}\n"
        
        # Empty line
        printf "  ${BOLD}${CYAN}│${RESET}"
        printf '%*s' "$width" ''
        printf "${BOLD}${CYAN}│${RESET}\n"
        
        # Menu items
        for i in "${!options[@]}"; do
            local item="${options[$i]}"
            local display_len=${#item}
            local item_pad=$(( width - display_len - 6 ))
            
            if [[ $i -eq $selected ]]; then
                printf "  ${BOLD}${CYAN}│${RESET}  ${REV}${GREEN} ▸ %-*s ${RESET}" "$((width - 6))" "$item"
                printf "${BOLD}${CYAN}│${RESET}\n"
            else
                printf "  ${BOLD}${CYAN}│${RESET}    ${WHITE}%-*s${RESET}" "$((width - 4))" "$item"
                printf "${BOLD}${CYAN}│${RESET}\n"
            fi
        done
        
        # Empty line
        printf "  ${BOLD}${CYAN}│${RESET}"
        printf '%*s' "$width" ''
        printf "${BOLD}${CYAN}│${RESET}\n"
        
        # Footer
        printf "  ${BOLD}${CYAN}├"
        printf '─%.0s' $(seq 1 $width)
        printf "┤${RESET}\n"
        
        local hint="↑↓ Navigate  Enter Select  q Quit"
        local hint_pad=$(( (width - ${#hint}) / 2 ))
        printf "  ${BOLD}${CYAN}│${RESET}"
        printf '%*s' "$hint_pad" ''
        printf "${DIM}%s${RESET}" "$hint"
        printf '%*s' "$(( width - hint_pad - ${#hint} ))" ''
        printf "${BOLD}${CYAN}│${RESET}\n"
        
        printf "  ${BOLD}${CYAN}└"
        printf '─%.0s' $(seq 1 $width)
        printf "┘${RESET}\n"

        # Read input
        read -rsn1 key
        case "$key" in
            A|k) # Up arrow or k
                selected=$(( (selected - 1 + num_options) % num_options ))
                ;;
            B|j) # Down arrow or j
                selected=$(( (selected + 1) % num_options ))
                ;;
            "") # Enter
                tput cnorm 2>/dev/null || true
                return $selected
                ;;
            q|Q)
                tput cnorm 2>/dev/null || true
                return 255
                ;;
            $'\x1b') # Escape sequence
                read -rsn2 -t 0.1 key 2>/dev/null || true
                case "$key" in
                    '[A') selected=$(( (selected - 1 + num_options) % num_options )) ;;
                    '[B') selected=$(( (selected + 1) % num_options )) ;;
                esac
                ;;
        esac
    done
}

# ─── Checkbox Selection ───
tui_checkbox_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local num_options=${#options[@]}
    declare -A checked
    local key=""

    tput civis 2>/dev/null || true

    while true; do
        clear
        local width=56
        
        printf "\n"
        printf "  ${BOLD}${CYAN}┌"
        printf '─%.0s' $(seq 1 $width)
        printf "┐${RESET}\n"
        
        local pad_left=$(( (width - ${#title}) / 2 ))
        printf "  ${BOLD}${CYAN}│${RESET}"
        printf '%*s' "$pad_left" ''
        printf "${BOLD}${WHITE}%s${RESET}" "$title"
        printf '%*s' "$(( width - pad_left - ${#title} ))" ''
        printf "${BOLD}${CYAN}│${RESET}\n"
        
        printf "  ${BOLD}${CYAN}├"
        printf '─%.0s' $(seq 1 $width)
        printf "┤${RESET}\n"
        
        printf "  ${BOLD}${CYAN}│${RESET}"
        printf '%*s' "$width" ''
        printf "${BOLD}${CYAN}│${RESET}\n"
        
        for i in "${!options[@]}"; do
            local item="${options[$i]}"
            local check_mark="   "
            [[ "${checked[$i]:-}" == "1" ]] && check_mark="${GREEN}[✓]${RESET}"
            [[ "${checked[$i]:-}" != "1" ]] && check_mark="${DIM}[ ]${RESET}"
            
            if [[ $i -eq $selected ]]; then
                printf "  ${BOLD}${CYAN}│${RESET}  ${REV} %b %-*s ${RESET}" "$check_mark" "$((width - 10))" "$item"
                printf "${BOLD}${CYAN}│${RESET}\n"
            else
                printf "  ${BOLD}${CYAN}│${RESET}   %b %-*s" "$check_mark" "$((width - 9))" "$item"
                printf "${BOLD}${CYAN}│${RESET}\n"
            fi
        done
        
        printf "  ${BOLD}${CYAN}│${RESET}"
        printf '%*s' "$width" ''
        printf "${BOLD}${CYAN}│${RESET}\n"
        
        printf "  ${BOLD}${CYAN}├"
        printf '─%.0s' $(seq 1 $width)
        printf "┤${RESET}\n"
        
        local hint="↑↓ Nav  Space Toggle  Enter Confirm  q Cancel"
        local hint_pad=$(( (width - ${#hint}) / 2 ))
        printf "  ${BOLD}${CYAN}│${RESET}"
        printf '%*s' "$hint_pad" ''
        printf "${DIM}%s${RESET}" "$hint"
        printf '%*s' "$(( width - hint_pad - ${#hint} ))" ''
        printf "${BOLD}${CYAN}│${RESET}\n"
        
        printf "  ${BOLD}${CYAN}└"
        printf '─%.0s' $(seq 1 $width)
        printf "┘${RESET}\n"

        read -rsn1 key
        case "$key" in
            A|k) selected=$(( (selected - 1 + num_options) % num_options )) ;;
            B|j) selected=$(( (selected + 1) % num_options )) ;;
            " ") # Space - toggle
                if [[ "${checked[$selected]:-}" == "1" ]]; then
                    checked[$selected]=0
                else
                    checked[$selected]=1
                fi
                ;;
            "") # Enter - confirm
                tput cnorm 2>/dev/null || true
                # Return selected items as newline-separated list
                for i in "${!options[@]}"; do
                    [[ "${checked[$i]:-}" == "1" ]] && echo "${options[$i]}"
                done
                return 0
                ;;
            q|Q)
                tput cnorm 2>/dev/null || true
                return 255
                ;;
            $'\x1b')
                read -rsn2 -t 0.1 key 2>/dev/null || true
                case "$key" in
                    '[A') selected=$(( (selected - 1 + num_options) % num_options )) ;;
                    '[B') selected=$(( (selected + 1) % num_options )) ;;
                esac
                ;;
        esac
    done
}

# ─── Confirmation Dialog ───
tui_confirm() {
    local question="$1"
    local default="${2:-n}"
    local answer
    
    if [[ "$default" == "y" ]]; then
        read -rp "  ${question} [Y/n]: " answer
        answer="${answer:-y}"
    else
        read -rp "  ${question} [y/N]: " answer
        answer="${answer:-n}"
    fi
    
    [[ "$answer" =~ ^[Yy] ]]
}

# ─── Input Dialog ───
tui_input() {
    local prompt="$1"
    local default="${2:-}"
    local result

    if [[ -n "$default" ]]; then
        read -rp "  ${prompt} [${default}]: " result
        result="${result:-$default}"
    else
        read -rp "  ${prompt}: " result
    fi
    echo "$result"
}

# ─── Password Input ───
tui_password() {
    local prompt="$1"
    local result
    read -rsp "  ${prompt}: " result
    echo
    echo "$result"
}

# ─── Wait for Key ───
tui_pause() {
    local msg="${1:-Press any key to continue...}"
    printf "\n  ${DIM}%s${RESET}" "$msg"
    read -rsn1
    echo
}

# ─── Display Info Box ───
tui_info_box() {
    local title="$1"
    shift
    local lines=("$@")
    local width=56
    
    printf "\n"
    printf "  ${BOLD}${CYAN}┌"
    printf '─%.0s' $(seq 1 $width)
    printf "┐${RESET}\n"
    
    local pad_left=$(( (width - ${#title}) / 2 ))
    printf "  ${BOLD}${CYAN}│${RESET}"
    printf '%*s' "$pad_left" ''
    printf "${BOLD}${WHITE}%s${RESET}" "$title"
    printf '%*s' "$(( width - pad_left - ${#title} ))" ''
    printf "${BOLD}${CYAN}│${RESET}\n"
    
    printf "  ${BOLD}${CYAN}├"
    printf '─%.0s' $(seq 1 $width)
    printf "┤${RESET}\n"
    
    for line in "${lines[@]}"; do
        printf "  ${BOLD}${CYAN}│${RESET}  %-*s${BOLD}${CYAN}│${RESET}\n" "$((width - 2))" "$line"
    done
    
    printf "  ${BOLD}${CYAN}└"
    printf '─%.0s' $(seq 1 $width)
    printf "┘${RESET}\n"
}
