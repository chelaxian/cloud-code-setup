#!/bin/bash
# TUI menu for launchers Qwen/Claude/OpenCode (Linux) - arrow-key navigation
# All UI output goes to FD 3 (=/dev/tty). Only the selected index goes to stdout.

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

# FD 3 = /dev/tty for UI output (stdout reserved for return value)
exec 3>/dev/tty

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
    printf '%s' "$line" >&3
}

move_cursor() {
    printf '\033[%d;%dH' "$1" "$2" >&3
}

hide_cursor() { printf '\033[?25l' >&3; }
show_cursor() { printf '\033[?25h' >&3; }

# Read a single keypress from /dev/tty - arrow keys only
read_key() {
    local key
    IFS= read -rsn1 key < /dev/tty
    case "$key" in
        $'\x1b')
            local seq=""
            if IFS= read -rsn1 -t 0.1 seq < /dev/tty; then
                case "$seq" in
                    '[')
                        local code=""
                        IFS= read -rsn1 -t 0.1 code < /dev/tty
                        case "$code" in
                            'A') echo "up"; return ;;
                            'B') echo "down"; return ;;
                            'C') echo "right"; return ;;
                            'D') echo "left"; return ;;
                            '5') IFS= read -rsn1 -t 0.1 code < /dev/tty; echo "pgup"; return ;;
                            '6') IFS= read -rsn1 -t 0.1 code < /dev/tty; echo "pgdn"; return ;;
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
        $'\n'|$'\r') echo "enter"; return ;;
        $'\x7f') echo "backspace"; return ;;
    esac
    echo "other"
}

# Banner functions - псевдографика
draw_tui_banner_qwen() {
    local inner_width="$1"
    local lines=(
        " ██████╗ ██╗    ██╗███████╗███╗   ██╗"
        "██╔═══██╗██║    ██║██╔════╝████╗  ██║"
        "██║   ██║██║ █╗ ██║█████╗  ██╔██╗ ██║"
        "██║▄▄ ██║██║███╗██║██╔══╝  ██║╚██╗██║"
        "╚██████╔╝╚███╔███╔╝███████╗██║ ╚████║"
        " ╚══▀▀═╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═══╝"
    )
    for line in "${lines[@]}"; do
        local len=${#line}
        if [ $len -gt $inner_width ]; then
            line="${line:0:$((inner_width-1))}…"
        else
            local pad_left=$(( (inner_width - len) / 2 ))
            local pad_right=$((inner_width - len - pad_left ))
            line=$(printf '%*s%s%*s' "$pad_left" '' "$line" "$pad_right" '')
        fi
        printf "${CYAN}║${line}║${RESET}\n" >&3
    done
}

draw_tui_banner_claude() {
    local inner_width="$1"
    local lines=(
        "   ██████╗██╗     ██╗      █████╗ ██╗   ██╗██████╗ ███████╗"
        "  ██╔════╝██║     ██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝"
        "  ██║     ██║     ██║     ███████║██║   ██║██║  ██║█████╗  "
        "  ██║     ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  "
        "  ╚██████╗███████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗"
        "   ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝"
    )
    for line in "${lines[@]}"; do
        local len=${#line}
        if [ $len -gt $inner_width ]; then
            line="${line:0:$((inner_width-1))}…"
        else
            local pad_left=$(( (inner_width - len) / 2 ))
            local pad_right=$((inner_width - len - pad_left ))
            line=$(printf '%*s%s%*s' "$pad_left" '' "$line" "$pad_right" '')
        fi
        printf "${MAGENTA}║${line}║${RESET}\n" >&3
    done
}

draw_tui_banner_opencode() {
    local inner_width="$1"
    local lines=(
        " ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗"
        "██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝"
        "██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║   ██║██║  ██║█████╗  "
        "██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║   ██║██║  ██║██╔══╝  "
        "╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗╚██████╔╝██████╔╝███████╗"
        " ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝"
    )
    for line in "${lines[@]}"; do
        local len=${#line}
        if [ $len -gt $inner_width ]; then
            line="${line:0:$((inner_width-1))}…"
        else
            local pad_left=$(( (inner_width - len) / 2 ))
            local pad_right=$((inner_width - len - pad_left))
            line=$(printf '%*s%s%*s' "$pad_left" '' "$line" "$pad_right" '')
        fi
        printf "${GREEN}║${line}║${RESET}\n" >&3
    done
}

# Main TUI menu with arrow-key navigation
# Args: app_brand title subtitle item1 item2 item3 ...
# Prints selected index (1-based) to stdout. Prints 0 for Esc/exit.
# All visual output goes to FD 3 (/dev/tty).
# Always returns 0.
show_tui_framed_menu() {
    local app_brand="$1"
    local title="$2"
    local subtitle="$3"
    shift 3
    local items=("$@")

    local num_items=${#items[@]}
    if [ "$num_items" -eq 0 ]; then
        printf '0\n'
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
    local idx=0
    local scroll_top=0

    trap 'show_cursor; printf "${RESET}\n" >&3; stty echo 2>/dev/null' EXIT

    # Flush any pending input
    while IFS= read -rsn1 -t 0.01 _ < /dev/tty 2>/dev/null; do :; done

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

        printf "${banner_color}╔${RESET}" >&3
        draw_box_line '═' "$inner_width" >&3
        printf "${banner_color}╗${RESET}\n" >&3

        printf "${banner_color}║${RESET}" >&3
        printf '%*s' "$inner_width" '' >&3
        printf "${banner_color}║${RESET}\n" >&3

        case "$app_brand" in
            "Qwen")   draw_tui_banner_qwen "$inner_width" ;;
            "Claude") draw_tui_banner_claude "$inner_width" ;;
            "OpenCode") draw_tui_banner_opencode "$inner_width" ;;
        esac

        printf "${banner_color}║${RESET}" >&3
        printf '%*s' "$inner_width" '' >&3
        printf "${banner_color}║${RESET}\n" >&3

        printf "${banner_color}╠${RESET}" >&3
        draw_box_line '═' "$inner_width" >&3
        printf "${banner_color}╣${RESET}\n" >&3

        local title_text=" $title"
        local title_len=${#title_text}
        printf "${banner_color}║${RESET} ${WHITE}${title}${RESET}" >&3
        if [ "$title_len" -lt "$inner_width" ]; then
            printf '%*s' "$((inner_width - title_len))" '' >&3
        fi
        printf "${banner_color}║${RESET}\n" >&3

        if [ -n "$subtitle" ]; then
            local sub_text=" $subtitle"
            local sub_len=${#sub_text}
            printf "${banner_color}║${RESET} ${GRAY}${subtitle}${RESET}" >&3
            if [ "$sub_len" -lt "$inner_width" ]; then
                printf '%*s' "$((inner_width - sub_len))" '' >&3
            fi
            printf "${banner_color}║${RESET}\n" >&3
        fi

        printf "${banner_color}╠${RESET}" >&3
        draw_box_line '═' "$inner_width" >&3
        printf "${banner_color}╣${RESET}\n" >&3

        printf "${banner_color}║${RESET}" >&3
        printf '%*s' "$inner_width" '' >&3
        printf "${banner_color}║${RESET}\n" >&3

        local r
        for ((r=0; r<visible; r++)); do
            local i=$((scroll_top + r))
            if [ "$i" -ge "$num_items" ]; then
                printf "${banner_color}║${RESET}" >&3
                printf '%*s' "$inner_width" '' >&3
                printf "${banner_color}║${RESET}\n" >&3
                continue
            fi

            local label="${items[$i]}"
            if [ "$i" -eq "$idx" ]; then
                local mark="  ▶ "
                local row="${mark}${label}"
                local row_len=$(( ${#mark} + ${#label} ))
                printf "${banner_color}║${RESET}${YELLOW}${BG_SELECTED}${row}${RESET}" >&3
                if [ "$row_len" -lt "$inner_width" ]; then
                    printf '%*s' "$((inner_width - row_len))" '' >&3
                fi
                printf "${banner_color}║${RESET}\n" >&3
            else
                local row="     ${label}"
                local row_len=${#row}
                printf "${banner_color}║${RESET}${GRAY}${row}${RESET}" >&3
                if [ "$row_len" -lt "$inner_width" ]; then
                    printf '%*s' "$((inner_width - row_len))" '' >&3
                fi
                printf "${banner_color}║${RESET}\n" >&3
            fi
        done

        printf "${banner_color}║${RESET}" >&3
        printf '%*s' "$inner_width" '' >&3
        printf "${banner_color}║${RESET}\n" >&3

        local hint="  ↑↓ выбор · Enter · Esc"
        local hint_len=${#hint}
        printf "${banner_color}║${RESET}${GRAY}${hint}${RESET}" >&3
        if [ "$hint_len" -lt "$inner_width" ]; then
            printf '%*s' "$((inner_width - hint_len))" '' >&3
        fi
        printf "${banner_color}║${RESET}\n" >&3

        if [ "$num_items" -gt "$visible" ]; then
            local pg_start=$((scroll_top + 1))
            local pg_end=$((scroll_top + visible))
            if [ "$pg_end" -gt "$num_items" ]; then pg_end=$num_items; fi
            local pg="  строки ${pg_start}-${pg_end} из ${num_items}"
            local pg_len=${#pg}
            printf "${banner_color}║${RESET}  ${CYAN}${pg}${RESET}" >&3
            if [ "$((pg_len + 2))" -lt "$inner_width" ]; then
                printf '%*s' "$((inner_width - pg_len - 2))" '' >&3
            fi
            printf "${banner_color}║${RESET}\n" >&3
        fi

        printf "${banner_color}╚${RESET}" >&3
        draw_box_line '═' "$inner_width" >&3
        printf "${banner_color}╝${RESET}\n" >&3
    }

    hide_cursor
    clear >&3
    draw_menu

    while true; do
        local key=$(read_key)
        case "$key" in
            up)
                if [ "$idx" -gt 0 ]; then idx=$((idx - 1)); fi
                draw_menu
                ;;
            down)
                if [ "$idx" -lt $((num_items - 1)) ]; then idx=$((idx + 1)); fi
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
                # Flush any remaining input before returning
                while IFS= read -rsn1 -t 0.01 _ < /dev/tty 2>/dev/null; do :; done
                printf '%s\n' "$((idx + 1))"
                return 0
                ;;
            esc)
                show_cursor
                trap - EXIT
                while IFS= read -rsn1 -t 0.01 _ < /dev/tty 2>/dev/null; do :; done
                printf '0\n'
                return 0
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
    if [ "$app_brand" = "Claude" ]; then banner_color="$MAGENTA"
    elif [ "$app_brand" = "OpenCode" ]; then banner_color="$GREEN"; fi

    clear >&3
    printf "${banner_color}╔${RESET}" >&3
    draw_box_line '═' "$inner_width" >&3
    printf "${banner_color}╗${RESET}\n" >&3

    printf "${banner_color}║${RESET}" >&3
    printf '%*s' "$inner_width" '' >&3
    printf "${banner_color}║${RESET}\n" >&3

    case "$app_brand" in
        "Qwen")   draw_tui_banner_qwen "$inner_width" ;;
        "Claude") draw_tui_banner_claude "$inner_width" ;;
        "OpenCode") draw_tui_banner_opencode "$inner_width" ;;
    esac

    printf "${banner_color}║${RESET}" >&3
    printf '%*s' "$inner_width" '' >&3
    printf "${banner_color}║${RESET}\n" >&3

    local msg="  ${message}"
    local msg_len=${#msg}
    printf "${banner_color}║${RESET}${YELLOW}${msg}${RESET}" >&3
    if [ "$msg_len" -lt "$inner_width" ]; then
        printf '%*s' "$((inner_width - msg_len))" '' >&3
    fi
    printf "${banner_color}║${RESET}\n" >&3

    printf "${banner_color}║${RESET}" >&3
    printf '%*s' "$inner_width" '' >&3
    printf "${banner_color}║${RESET}\n" >&3

    printf "${banner_color}╚${RESET}" >&3
    draw_box_line '═' "$inner_width" >&3
    printf "${banner_color}╝${RESET}\n" >&3
}
