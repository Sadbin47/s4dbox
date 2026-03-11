#!/usr/bin/env bash
# s4dbox - TUI Menu System
# Simple numbered menus — works in any terminal
# All display output goes to /dev/tty so menus work inside $() subshells

# ─── Draw a box header ───
_tui_box_header() {
    local title="$1"
    local width=56

    printf "\n" >/dev/tty
    printf "  ${BOLD}${CYAN}┌" >/dev/tty
    printf '─%.0s' $(seq 1 $width) >/dev/tty
    printf "┐${RESET}\n" >/dev/tty

    local pad_left=$(( (width - ${#title}) / 2 ))
    local pad_right=$(( width - ${#title} - pad_left ))
    printf "  ${BOLD}${CYAN}│${RESET}" >/dev/tty
    printf '%*s' "$pad_left" '' >/dev/tty
    printf "${BOLD}${WHITE}%s${RESET}" "$title" >/dev/tty
    printf '%*s' "$pad_right" '' >/dev/tty
    printf "${BOLD}${CYAN}│${RESET}\n" >/dev/tty

    printf "  ${BOLD}${CYAN}├" >/dev/tty
    printf '─%.0s' $(seq 1 $width) >/dev/tty
    printf "┤${RESET}\n" >/dev/tty
}

_tui_box_footer() {
    local width=56
    printf "  ${BOLD}${CYAN}└" >/dev/tty
    printf '─%.0s' $(seq 1 $width) >/dev/tty
    printf "┘${RESET}\n" >/dev/tty
}

# ─── Numbered Menu (single selection) ───
# Returns the selected index (0-based) via exit code
tui_draw_menu() {
    local title="$1"
    shift
    local options=("$@")
    local num_options=${#options[@]}
    local width=56

    while true; do
        clear >/dev/tty
        _tui_box_header "$title"

        printf "  ${BOLD}${CYAN}│${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$width" "" >/dev/tty

        for i in "${!options[@]}"; do
            local num=$(( i + 1 ))
            printf "  ${BOLD}${CYAN}│${RESET}   ${BOLD}${GREEN}%2d${RESET}) %-*s${BOLD}${CYAN}│${RESET}\n" "$num" "$((width - 7))" "${options[$i]}" >/dev/tty
        done

        printf "  ${BOLD}${CYAN}│${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$width" "" >/dev/tty
        printf "  ${BOLD}${CYAN}│${RESET}    ${DIM}0) Cancel / Back${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$((width - 21))" "" >/dev/tty
        printf "  ${BOLD}${CYAN}│${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$width" "" >/dev/tty
        _tui_box_footer

        printf "\n  ${BOLD}Enter choice [0-%d]:${RESET} " "$num_options" >/dev/tty
        local choice
        read -r choice </dev/tty

        # Validate
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [[ "$choice" -eq 0 ]]; then
                return 255
            elif [[ "$choice" -ge 1 && "$choice" -le "$num_options" ]]; then
                return $(( choice - 1 ))
            fi
        fi

        printf "  ${RED}Invalid choice. Try again.${RESET}\n" >/dev/tty
        sleep 1
    done
}

# ─── Numbered Checkbox Menu (multi-select) ───
# Prints selected items to stdout (newline-separated)
tui_checkbox_menu() {
    local title="$1"
    shift
    local options=("$@")
    local num_options=${#options[@]}
    local width=56
    declare -A checked

    while true; do
        clear >/dev/tty
        _tui_box_header "$title"

        printf "  ${BOLD}${CYAN}│${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$width" "" >/dev/tty

        for i in "${!options[@]}"; do
            local num=$(( i + 1 ))
            local mark
            if [[ "${checked[$i]:-0}" == "1" ]]; then
                mark="${GREEN}[✓]${RESET}"
            else
                mark="${DIM}[ ]${RESET}"
            fi
            printf "  ${BOLD}${CYAN}│${RESET}   ${BOLD}${GREEN}%2d${RESET}) %b %-*s${BOLD}${CYAN}│${RESET}\n" "$num" "$mark" "$((width - 12))" "${options[$i]}" >/dev/tty
        done

        printf "  ${BOLD}${CYAN}│${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$width" "" >/dev/tty
        printf "  ${BOLD}${CYAN}│${RESET}    ${DIM} a) Select All${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$((width - 18))" "" >/dev/tty
        printf "  ${BOLD}${CYAN}│${RESET}    ${DIM} n) Select None${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$((width - 19))" "" >/dev/tty
        printf "  ${BOLD}${CYAN}│${RESET}    ${DIM} d) Done (confirm)${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$((width - 22))" "" >/dev/tty
        printf "  ${BOLD}${CYAN}│${RESET}    ${DIM} 0) Cancel${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$((width - 15))" "" >/dev/tty
        printf "  ${BOLD}${CYAN}│${RESET}%*s${BOLD}${CYAN}│${RESET}\n" "$width" "" >/dev/tty
        _tui_box_footer

        printf "\n  ${BOLD}Toggle item or action [1-%d/a/n/d/0]:${RESET} " "$num_options" >/dev/tty
        local choice
        read -r choice </dev/tty

        case "$choice" in
            0)
                return 255
                ;;
            a|A)
                for i in "${!options[@]}"; do checked[$i]=1; done
                ;;
            n|N)
                for i in "${!options[@]}"; do checked[$i]=0; done
                ;;
            d|D|"")
                # Output selected items to stdout (this IS what gets captured)
                for i in "${!options[@]}"; do
                    [[ "${checked[$i]:-0}" == "1" ]] && echo "${options[$i]}"
                done
                return 0
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le "$num_options" ]]; then
                    local idx=$(( choice - 1 ))
                    if [[ "${checked[$idx]:-0}" == "1" ]]; then
                        checked[$idx]=0
                    else
                        checked[$idx]=1
                    fi
                else
                    printf "  ${RED}Invalid choice.${RESET}\n" >/dev/tty
                    sleep 1
                fi
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
        printf "  %s [Y/n]: " "$question" >/dev/tty
        read -r answer </dev/tty
        answer="${answer:-y}"
    else
        printf "  %s [y/N]: " "$question" >/dev/tty
        read -r answer </dev/tty
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
        printf "  %s [%s]: " "$prompt" "$default" >/dev/tty
        read -r result </dev/tty
        result="${result:-$default}"
    else
        printf "  %s: " "$prompt" >/dev/tty
        read -r result </dev/tty
    fi
    echo "$result"
}

# ─── Password Input ───
tui_password() {
    local prompt="$1"
    local result
    printf "  %s: " "$prompt" >/dev/tty
    read -rs result </dev/tty
    printf "\n" >/dev/tty
    echo "$result"
}

# ─── Wait for Key ───
tui_pause() {
    local msg="${1:-Press any key to continue...}"
    printf "\n  ${DIM}%s${RESET}" "$msg" >/dev/tty
    read -rsn1 </dev/tty
    printf "\n" >/dev/tty
}

# ─── Display Info Box ───
tui_info_box() {
    local title="$1"
    shift
    local lines=("$@")
    local width=56
    
    printf "\n" >/dev/tty
    printf "  ${BOLD}${CYAN}┌" >/dev/tty
    printf '─%.0s' $(seq 1 $width) >/dev/tty
    printf "┐${RESET}\n" >/dev/tty
    
    local pad_left=$(( (width - ${#title}) / 2 ))
    printf "  ${BOLD}${CYAN}│${RESET}" >/dev/tty
    printf '%*s' "$pad_left" '' >/dev/tty
    printf "${BOLD}${WHITE}%s${RESET}" "$title" >/dev/tty
    printf '%*s' "$(( width - pad_left - ${#title} ))" '' >/dev/tty
    printf "${BOLD}${CYAN}│${RESET}\n" >/dev/tty
    
    printf "  ${BOLD}${CYAN}├" >/dev/tty
    printf '─%.0s' $(seq 1 $width) >/dev/tty
    printf "┤${RESET}\n" >/dev/tty
    
    for line in "${lines[@]}"; do
        printf "  ${BOLD}${CYAN}│${RESET}  %-*s${BOLD}${CYAN}│${RESET}\n" "$((width - 2))" "$line" >/dev/tty
    done
    
    printf "  ${BOLD}${CYAN}└" >/dev/tty
    printf '─%.0s' $(seq 1 $width) >/dev/tty
    printf "┘${RESET}\n" >/dev/tty
}
