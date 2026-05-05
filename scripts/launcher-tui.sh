#!/bin/bash
# TUI-меню для лаунчеров Qwen/Claude (Linux)

# ANSI цвета
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export GRAY='\033[0;37m'
export WHITE='\033[1;37m'
export RESET='\033[0m'

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
    echo "$line"
}

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
        echo -e "${CYAN}║${line}║${RESET}"
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
        echo -e "${MAGENTA}║${line}║${RESET}"
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
        echo -e "${GREEN}║${line}║${RESET}"
    done
}

show_tui_framed_menu() {
    local app_brand="$1"
    local title="$2"
    local subtitle="$3"
    shift 3
    local items=("$@")
    
    local term_width=$(get_terminal_width)
    local frame_width=$(( (term_width < 90 ? term_width : 90) ))
    local inner_width=$((frame_width - 2))
    
    local num_items=${#items[@]}
    local visible=$((num_items > 12 ? 12 : num_items))
    
    local banner_color="$CYAN"
    if [ "$app_brand" = "Claude" ]; then
        banner_color="$MAGENTA"
    elif [ "$app_brand" = "OpenCode" ]; then
        banner_color="$GREEN"
    fi
    
    while true; do
        clear
        
        # Верхняя рамка
        echo -e "${banner_color}╔$(draw_box_line '═' $inner_width)╗${RESET}"
        echo -e "${banner_color}║$(printf '%*s' $inner_width)║${RESET}"
        
        # Баннер
        if [ "$app_brand" = "Qwen" ]; then
            draw_tui_banner_qwen "$inner_width"
        elif [ "$app_brand" = "Claude" ]; then
            draw_tui_banner_claude "$inner_width"
        elif [ "$app_brand" = "OpenCode" ]; then
            draw_tui_banner_opencode "$inner_width"
        fi
        
        echo -e "${banner_color}║$(printf '%*s' $inner_width)║${RESET}"
        echo -e "${banner_color}╠$(draw_box_line '═' $inner_width)╣${RESET}"
        
        # Заголовок
        echo -e "${banner_color}║ ${title}$(printf '%*s' $((inner_width - ${#title} - 1)))║${RESET}"
        if [ -n "$subtitle" ]; then
            echo -e "${banner_color}║ ${subtitle}$(printf '%*s' $((inner_width - ${#subtitle} - 1)))║${RESET}"
        fi
        
        echo -e "${banner_color}╠$(draw_box_line '═' $inner_width)╣${RESET}"
        echo -e "${banner_color}║$(printf '%*s' $inner_width)║${RESET}"
        
        # Пункты меню
        local i=1
        for item in "${items[@]}"; do
            printf "${banner_color}║${RESET}   [${GREEN}%d${RESET}] ${GRAY}%s${RESET}" "$i" "$item"
            local item_len=$((3 + ${#i} + ${#item}))
            printf "${banner_color}$(printf '%*s' $((inner_width - item_len - 1)))║${RESET}\n"
            ((i++))
        done
        
        echo -e "${banner_color}║   [0] ${GRAY}Выход${RESET}$(printf '%*s' $((inner_width - 8 - 1)))${banner_color}║${RESET}"
        echo -e "${banner_color}║$(printf '%*s' $inner_width)║${RESET}"
        echo -e "${banner_color}╚$(draw_box_line '═' $inner_width)╝${RESET}"
        echo -ne "${GRAY}Ваш выбор: ${RESET}"
        
        read -r choice
        
        if [ "$choice" = "0" ] || [ -z "$choice" ]; then
            return 0
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$num_items" ]; then
            return "$choice"
        else
            echo -e "${RED}Неверный выбор${RESET}"
            sleep 1
        fi
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
    echo -e "${banner_color}╔$(draw_box_line '═' $inner_width)╗${RESET}"
    echo -e "${banner_color}║$(printf '%*s' $inner_width)║${RESET}"
    
    if [ "$app_brand" = "Qwen" ]; then
        draw_tui_banner_qwen "$inner_width"
    elif [ "$app_brand" = "Claude" ]; then
        draw_tui_banner_claude "$inner_width"
    elif [ "$app_brand" = "OpenCode" ]; then
        draw_tui_banner_opencode "$inner_width"
    fi
    
    echo -e "${banner_color}║$(printf '%*s' $inner_width)║${RESET}"
    echo -e "${banner_color}║  ${YELLOW}${message}${RESET}$(printf '%*s' $((inner_width - ${#message} - 3)))${banner_color}║${RESET}"
    echo -e "${banner_color}║$(printf '%*s' $inner_width)║${RESET}"
    echo -e "${banner_color}╚$(draw_box_line '═' $inner_width)╝${RESET}"
}
