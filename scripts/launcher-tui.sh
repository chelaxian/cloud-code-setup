#!/bin/bash
# TUI menu for launchers Qwen/Claude/OpenCode (Linux) - arrow-key navigation

# ANSI colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export GRAY='\033[0;37m'
export WHITE='\033[1;37m'
export RESET='\033[0m'
export BOLD='\033[1m'
export BG_SELECTED='\033[44m'

get_terminal_width() {
    if command -v tput &> /dev/null; then
        tput cols 2>/dev/null || echo 80
    else
        echo 80
    fi
}

draw_box_line() {
    local char="$1"
    local width="$2"
    local line=""
    for ((i=0; i<width; i++)); do
        line+="$char"
    done
    printf '%s' "$line"
}

# Move cursor to row, col (1-based)
move_cursor() {
    printf '\033[%d;%dH' "$1" "$2"
}

# Hide/show cursor
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }

# Read a single keypress; returns: up/down/left/right/enter/esc/number/space/pgup/pgdn/home/end/tab/other
read_key() {
    local key
    IFS= read -rsn1 key
    case "$key" in
        $'\x1b')
            local seq=""
            # Read rest of escape sequence with tiny timeout
            if IFS= read -rsn1 -t 0.1 seq; then
                case "$seq" in
                    '[')
                        local code=""
                        IFS= read -rsn1 -t 0.1 code
                        case "$code" in
                            'A') echo "up"; return ;;
                            'B') echo "down"; return ;;
                            'C') echo "right"; return ;;
                            'D') echo "left"; return ;;
                            '5') IFS= read -rsn1 -t 0.1 code; echo "pgup"; return ;;
                            '6') IFS= read -rsn1 -t 0.1 code; echo "pgdn"; return ;;
                            'H') echo "home"; return ;;
                            'F') echo "end"; return ;;
                            *)   echo "other"; return ;;
                        esac
                        ;;
                esac
            fi
            echo "esc"; return
            ;;
        '') echo "enter"; return ;;
        $'\x7f') echo "backspace"; return ;;
        [0-9]) echo "num_$key"; return ;;
    esac
    echo "other"
}

# Banner functions - ASCII art using regular characters
draw_tui_banner_qwen() {
    local inner_width="$1"
    local lines=(
        "  _ _ _         "
        "  (_) |__  ___  "
        "  | |  _ \ / __|"
        "  | | |_) | (__ "
        "  |_|_.__/ \___|"
    )
    for line in "${lines[@]}"; do
        local len=${#line}
        local pad_left=$(( (inner_width - len) / 2 ))
        local pad_right=$((inner_width - len - pad_left ))
        printf "${CYAN}║${RESET}"
        printf '%*s' "$pad_left" ''
        printf '%s' "$line"
        printf '%*s' "$pad_right" ''
        printf "${CYAN}║${RESET}\n"
    done
}

draw_tui_banner_claude() {
    local inner_width="$1"
    local lines=(
        "   ___ _   _ ___ ___ ___ _   _   __ _ _   _  __ "
        "  / __| | | / __|_ _| __| | | | / _\` | | | |/ _ \\"
        " | (__| |_| \__ \| || _|| |_| | (_| | |_| |  __/"
        "  \___|\___/|___/___|_|  \___/ \__, |\__,_|\___|"
        "                                  |_|           "
    )
    for line in "${lines[@]}"; do
        local len=${#line}
        local pad_left=$(( (inner_width - len) / 2 ))
        local pad_right=$((inner_width - len - pad_left ))
        printf "${MAGENTA}║${RESET}"
        printf '%*s' "$pad_left" ''
        printf '%s' "$line"
        printf '%*s' "$pad_right" ''
        printf "${MAGENTA}║${RESET}\n"
    done
}

draw_tui_banner_opencode() {
    local inner_width="$1"
    local lines=(
        "   ___                   ____                  "
        "  / _ \ _ __   ___ _ __ / ___|___  _ __ ___  _ "
        " | | | | '_ \ / _ \ '_ \ |   / _ \| '__/ _ \(_)"
        " | |_| | |_) |  __/ | | | |__| (_) | | |  __/ _ "
        "  \___/| .__/ \___|_| |_|\____\___/|_|  \___|(_)"
        "       |_|                                       "
    )
    for line in "${lines[@]}"; do
        local len=${#line}
        local pad_left=$(( (inner_width - len) / 2 ))
        local pad_right=$((inner_width - len - pad_left ))
        printf "${GREEN}║${RESET}"
        printf '%*s' "$pad_left" ''
        printf '%s' "$line"
        printf '%*s' "$pad_right" ''
        printf "${GREEN}║${RESET}\n"
    done
}

# Main TUI menu with arrow-key navigation
# Args: app_brand title subtitle item1 item2 item3 ...
# Returns selected index (1-based) via $? or 0 for Esc/exit
show_tui_framed_menu() {
    local app_brand="$1"
    local title="$2"
    local subtitle="$3"
    shift 3
    local items=("$@")

    local num_items=${#items[@]}
    if [ "$num_items" -eq 0 ]; then
        return 0
    fi

    local term_width=$(get_terminal_width)
    local frame_width=$(( (term_width < 100 ? term_width : 100) ))
    local inner_width=$((frame_width - 2))

    local banner_color="$CYAN"
    if [ "$app_brand" = "Claude" ]; then
        banner_color="$MAGENTA"
    elif [ "$app_brand" = "OpenCode" ]; then
        banner_color="$GREEN"
    fi

    local visible=$((num_items > 20 ? 20 : num_items))
    local idx=0        # currently selected (0-based)
    local scroll_top=0 # first visible item

    trap 'show_cursor; echo -e "${RESET}"; stty echo 2>/dev/null' EXIT

    sync_scroll() {
        if [ "$idx" -lt "$scroll_top" ]; then
            scroll_top=$idx
        fi
        local max_top=$(( num_items - visible ))
        if [ "$max_top" -lt 0 ]; then max_top=0; fi
        if [ "$idx" -ge $((scroll_top + visible)) ]; then
            scroll_top=$(( idx - visible + 1 ))
        fi
        if [ "$scroll_top" -gt "$max_top" ]; then
            scroll_top=$max_top
        fi
        if [ "$scroll_top" -lt 0 ]; then
            scroll_top=0
        fi
    }

    draw_menu() {
        sync_scroll
        move_cursor 1 1

        # Top border
        printf "${banner_color}╔${RESET}"
        draw_box_line '═' "$inner_width"
        printf "${banner_color}╗${RESET}\n"

        # Empty line
        printf "${banner_color}║${RESET}"
        printf '%*s' "$inner_width" ''
        printf "${banner_color}║${RESET}\n"

        # Banner
        case "$app_brand" in
            "Qwen")   draw_tui_banner_qwen "$inner_width" ;;
            "Claude") draw_tui_banner_claude "$inner_width" ;;
            "OpenCode") draw_tui_banner_opencode "$inner_width" ;;
        esac

        # Empty line
        printf "${banner_color}║${RESET}"
        printf '%*s' "$inner_width" ''
        printf "${banner_color}║${RESET}\n"

        # Separator
        printf "${banner_color}╠${RESET}"
        draw_box_line '═' "$inner_width"
        printf "${banner_color}╣${RESET}\n"

        # Title
        local title_text=" $title"
        local title_len=${#title_text}
        printf "${banner_color}║${RESET} ${WHITE}${title}${RESET}"
        if [ "$title_len" -lt "$inner_width" ]; then
            printf '%*s' "$((inner_width - title_len))" ''
        fi
        printf "${banner_color}║${RESET}\n"

        # Subtitle
        if [ -n "$subtitle" ]; then
            local sub_text=" $subtitle"
            local sub_len=${#sub_text}
            printf "${banner_color}║${RESET} ${GRAY}${subtitle}${RESET}"
            if [ "$sub_len" -lt "$inner_width" ]; then
                printf '%*s' "$((inner_width - sub_len))" ''
            fi
            printf "${banner_color}║${RESET}\n"
        fi

        # Separator
        printf "${banner_color}╠${RESET}"
        draw_box_line '═' "$inner_width"
        printf "${banner_color}╣${RESET}\n"

        # Empty line
        printf "${banner_color}║${RESET}"
        printf '%*s' "$inner_width" ''
        printf "${banner_color}║${RESET}\n"

        # Menu items
        local r
        for ((r=0; r<visible; r++)); do
            local i=$((scroll_top + r))
            if [ "$i" -ge "$num_items" ]; then
                printf "${banner_color}║${RESET}"
                printf '%*s' "$inner_width" ''
                printf "${banner_color}║${RESET}\n"
                continue
            fi

            local label="${items[$i]}"
            if [ "$i" -eq "$idx" ]; then
                local mark="  ▶ "
                local row="${mark}${label}"
                local row_len=$(( ${#mark} + ${#label} ))
                printf "${banner_color}║${RESET}${YELLOW}${BG_SELECTED}${row}${RESET}"
                if [ "$row_len" -lt "$inner_width" ]; then
                    printf '%*s' "$((inner_width - row_len))" ''
                fi
                printf "${banner_color}║${RESET}\n"
            else
                local row="     ${label}"
                local row_len=${#row}
                printf "${banner_color}║${RESET}${GRAY}${row}${RESET}"
                if [ "$row_len" -lt "$inner_width" ]; then
                    printf '%*s' "$((inner_width - row_len))" ''
                fi
                printf "${banner_color}║${RESET}\n"
            fi
        done

        # Empty line
        printf "${banner_color}║${RESET}"
        printf '%*s' "$inner_width" ''
        printf "${banner_color}║${RESET}\n"

        # Hint
        local hint="  ↑↓ выбор   Enter - OK   Esc - выход"
        local hint_len=${#hint}
        printf "${banner_color}║${RESET}${GRAY}${hint}${RESET}"
        if [ "$hint_len" -lt "$inner_width" ]; then
            printf '%*s' "$((inner_width - hint_len))" ''
        fi
        printf "${banner_color}║${RESET}\n"

        # Pagination
        if [ "$num_items" -gt "$visible" ]; then
            local pg_start=$((scroll_top + 1))
            local pg_end=$((scroll_top + visible))
            if [ "$pg_end" -gt "$num_items" ]; then pg_end=$num_items; fi
            local pg="  строки ${pg_start}-${pg_end} из ${num_items}"
            local pg_len=${#pg}
            printf "${banner_color}║${RESET}  ${CYAN}${pg}${RESET}"
            if [ "$((pg_len + 2))" -lt "$inner_width" ]; then
                printf '%*s' "$((inner_width - pg_len - 2))" ''
            fi
            printf "${banner_color}║${RESET}\n"
        fi

        # Bottom border
        printf "${banner_color}╚${RESET}"
        draw_box_line '═' "$inner_width"
        printf "${banner_color}╝${RESET}\n"
    }

    # Main loop
    hide_cursor
    clear
    draw_menu

    while true; do
        local key=$(read_key)
        case "$key" in
            up)
                if [ "$idx" -gt 0 ]; then
                    idx=$((idx - 1))
                fi
                draw_menu
                ;;
            down)
                if [ "$idx" -lt $((num_items - 1)) ]; then
                    idx=$((idx + 1))
                fi
                draw_menu
                ;;
            pgup)
                idx=$((idx - visible))
                if [ "$idx" -lt 0 ]; then idx=0; fi
                draw_menu
                ;;
            pgdn)
                idx=$((idx + visible))
                if [ "$idx" -ge "$num_items" ]; then idx=$((num_items - 1)); fi
                draw_menu
                ;;
            home)
                idx=0
                draw_menu
                ;;
            end)
                idx=$((num_items - 1))
                draw_menu
                ;;
            enter)
                show_cursor
                trap - EXIT
                return $((idx + 1))
                ;;
            esc)
                show_cursor
                trap - EXIT
                return 0
                ;;
            num_*)
                local num="${key#num_}"
                # Accumulate digits for multi-digit selection
                local typed="$num"
                local timeout=0.5
                while true; do
                    local next_key=$(read_key)
                    case "$next_key" in
                        num_*) typed+="${next_key#num_}" ;;
                        enter) break ;;
                        *) break ;;
                    esac
                done
                if [[ "$typed" =~ ^[0-9]+$ ]] && [ "$typed" -ge 1 ] && [ "$typed" -le "$num_items" ]; then
                    show_cursor
                    trap - EXIT
                    return "$typed"
                elif [ "$typed" = "0" ]; then
                    show_cursor
                    trap - EXIT
                    return 0
                fi
                # Invalid number, redraw
                draw_menu
                ;;
            *)
                # Unknown key, ignore
                ;;
        esac
    done
}

show_tui_wait_frame() {
    local app_brand="$1"
    local message="$2"

    local term_width=$(get_terminal_width)
    local frame_width=$(( (term_width < 82 ? term_width : 82) ))
    local inner_width=$((frame_width - 2))

    local banner_color="$CYAN"
    if [ "$app_brand" = "Claude" ]; then
        banner_color="$MAGENTA"
    elif [ "$app_brand" = "OpenCode" ]; then
        banner_color="$GREEN"
    fi

    clear
    printf "${banner_color}╔${RESET}"
    draw_box_line '═' "$inner_width"
    printf "${banner_color}╗${RESET}\n"

    printf "${banner_color}║${RESET}"
    printf '%*s' "$inner_width" ''
    printf "${banner_color}║${RESET}\n"

    case "$app_brand" in
        "Qwen")   draw_tui_banner_qwen "$inner_width" ;;
        "Claude") draw_tui_banner_claude "$inner_width" ;;
        "OpenCode") draw_tui_banner_opencode "$inner_width" ;;
    esac

    printf "${banner_color}║${RESET}"
    printf '%*s' "$inner_width" ''
    printf "${banner_color}║${RESET}\n"

    local msg="  ${message}"
    local msg_len=${#msg}
    printf "${banner_color}║${RESET}${YELLOW}${msg}${RESET}"
    if [ "$msg_len" -lt "$inner_width" ]; then
        printf '%*s' "$((inner_width - msg_len))" ''
    fi
    printf "${banner_color}║${RESET}\n"

    printf "${banner_color}║${RESET}"
    printf '%*s' "$inner_width" ''
    printf "${banner_color}║${RESET}\n"

    printf "${banner_color}╚${RESET}"
    draw_box_line '═' "$inner_width"
    printf "${banner_color}╝${RESET}\n"
}
