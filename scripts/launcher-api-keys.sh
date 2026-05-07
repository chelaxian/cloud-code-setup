#!/bin/bash
# Модуль для управления API ключами в лаунчерах Qwen/Claude/OpenCode (Linux)

# ANSI цвета для TUI
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export GRAY='\033[0;37m'
export WHITE='\033[1;37m'
export RESET='\033[0m'

get_current_api_key() {
    local provider="$1"
    
    case "$provider" in
        "NVIDIA_NIM")
            local key="${NVIDIA_NIM_API_KEY:-}"
            if [ -z "$key" ]; then
                key=$(grep "^export NVIDIA_NIM_API_KEY=" "$HOME/.bashrc" 2>/dev/null | cut -d'"' -f2)
            fi
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
                echo ""
            else
                echo "$key" | xargs
            fi
            ;;
        "ZAI")
            local key="${ZAI_API_KEY:-}"
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
                key=$(grep "^export ZAI_API_KEY=" "$HOME/.bashrc" 2>/dev/null | cut -d'"' -f2)
            fi
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
                key="${OPENAI_API_KEY:-}"
            fi
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
                key=$(grep "^export OPENAI_API_KEY=" "$HOME/.bashrc" 2>/dev/null | cut -d'"' -f2)
            fi
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
                echo ""
            else
                echo "$key" | xargs
            fi
            ;;
        "GROQ")
            local key="${GROQ_API_KEY:-}"
            if [ -z "$key" ]; then
                key=$(grep "^export GROQ_API_KEY=" "$HOME/.bashrc" 2>/dev/null | cut -d'"' -f2)
            fi
            if [ -z "$key" ]; then echo "" ; else echo "$key" | xargs ; fi
            ;;
        "OPENROUTER")
            local key="${OPENROUTER_API_KEY:-}"
            if [ -z "$key" ]; then
                key=$(grep "^export OPENROUTER_API_KEY=" "$HOME/.bashrc" 2>/dev/null | cut -d'"' -f2)
            fi
            if [ -z "$key" ]; then echo "" ; else echo "$key" | xargs ; fi
            ;;
        *)
            echo ""
            ;;
    esac
}

read_secret_text() {
    local prompt="$1"
    printf "%s" "$prompt" >&3
    IFS= read -rs key < /dev/tty
    printf "\n" >&3
    echo "$key"
}

set_provider_api_key() {
    local provider="$1"
    local new_key="$2"
    local bashrc_file="$HOME/.bashrc"
    local zshrc_file="$HOME/.zshrc"
    
    if [ -z "$new_key" ]; then
        printf "${RED}Ошибка: API ключ не может быть пустым${RESET}\n" >&3
        return 1
    fi
    
    local env_var=""
    local export_line=""
    
    case "$provider" in
        "NVIDIA_NIM") env_var="NVIDIA_NIM_API_KEY" ;;
        "ZAI") env_var="ZAI_API_KEY" ;;
        "GROQ") env_var="GROQ_API_KEY" ;;
        "OPENROUTER") env_var="OPENROUTER_API_KEY" ;;
        *) printf "${RED}Неизвестный провайдер: $provider${RESET}\n" >&3; return 1 ;;
    esac
    
    export_line="export $env_var=\"$new_key\""
    
    for rc_file in "$bashrc_file" "$zshrc_file"; do
        if [ -f "$rc_file" ]; then
            sed -i "/^export $env_var=/d" "$rc_file"
            echo "$export_line" >> "$rc_file"
        fi
    done
    
    export "$env_var=$new_key"
    
    printf "${GREEN}${env_var} обновлён в ~/.bashrc и ~/.zshrc${RESET}\n" >&3
    return 0
}

# Проверяет наличие API ключа; если нет — предлагает ввести с ссылкой на URL
# $1 = env var name (NVIDIA_NIM, ZAI, GROQ, OPENROUTER)
# $2 = provider display name
# $3 = URL for getting key
# Returns 0 if key available, 1 if not
ensure_api_key_or_prompt() {
    local env_var_name="$1"
    local provider_name="$2"
    local provider_url="$3"
    
    local current_key=$(get_current_api_key "$env_var_name")
    
    if [ -n "$current_key" ]; then
        return 0
    fi
    
    # Нет ключа — показываем предупреждение и предлагаем ввести
    clear >&3
    printf "${YELLOW}═══════════════════════════════════════════════════${RESET}\n" >&3
    printf "${YELLOW}  API ключ $provider_name не задан${RESET}\n" >&3
    printf "${YELLOW}═══════════════════════════════════════════════════${RESET}\n" >&3
    printf "\n" >&3
    printf "${CYAN}  Получить ключ: ${provider_url}${RESET}\n" >&3
    printf "\n" >&3
    
    local new_key=$(read_secret_text "  Введите $provider_name API ключ (Enter = отмена): ")
    
    if [ -z "$new_key" ]; then
        printf "${YELLOW}  Отмена — ключ не введён.${RESET}\n" >&3
        IFS= read -r -p "" < /dev/tty
        return 1
    fi
    
    if set_provider_api_key "$env_var_name" "$new_key"; then
        printf "\n" >&3
        printf "${GREEN}  Нажмите Enter для продолжения...${RESET}\n" >&3
        IFS= read -r < /dev/tty
        return 0
    else
        printf "\n" >&3
        IFS= read -r -p "" < /dev/tty
        return 1
    fi
}

show_api_key_change_menu() {
    local app_brand="${1:-Qwen}"
    
    local items=(
        "NVIDIA NIM API ключ (https://build.nvidia.com/api-key)"
        "Z.AI API ключ (https://console.z.ai/)"
        "Groq API ключ (https://console.groq.com/keys)"
        "OpenRouter API ключ (https://openrouter.ai/settings/keys)"
    )
    
    local choice
    choice="$(show_tui_framed_menu "$app_brand" "Сменить ключ API провайдера" "Выберите провайдер" "${items[@]}")"
    
    if [ "${choice:-0}" -eq 0 ]; then
        return 0
    fi
    
    local provider_id=""
    local provider_name=""
    local env_var_name=""
    local provider_url=""
    
    case "$choice" in
        1) provider_name="NVIDIA NIM"; env_var_name="NVIDIA_NIM"; provider_url="https://build.nvidia.com/api-key" ;;
        2) provider_name="Z.AI"; env_var_name="ZAI"; provider_url="https://console.z.ai/" ;;
        3) provider_name="Groq"; env_var_name="GROQ"; provider_url="https://console.groq.com/keys" ;;
        4) provider_name="OpenRouter"; env_var_name="OPENROUTER"; provider_url="https://openrouter.ai/settings/keys" ;;
        *) return 0 ;;
    esac
    
    local current_key=$(get_current_api_key "$env_var_name")
    
    clear >&3
    printf "${CYAN}═══════════════════════════════════════════════════${RESET}\n" >&3
    printf "${CYAN}  Провайдер: $provider_name${RESET}\n" >&3
    printf "${CYAN}═══════════════════════════════════════════════════${RESET}\n" >&3
    
    if [ -z "$current_key" ]; then
        printf "${YELLOW}  Текущий ключ: (не задан)${RESET}\n" >&3
    else
        if [ ${#current_key} -gt 12 ]; then
            local masked="${current_key:0:6}...${current_key: -6}"
        else
            local masked="***"
        fi
        printf "${GREEN}  Текущий ключ: $masked${RESET}\n" >&3
    fi
    printf "\n" >&3
    printf "${CYAN}  Получить ключ: $provider_url${RESET}\n" >&3
    printf "\n" >&3
    
    local new_key=$(read_secret_text "  Введите новый API ключ (Enter = отмена): ")
    
    if [ -z "$new_key" ]; then
        printf "${YELLOW}  Отмена — ключ не изменён.${RESET}\n" >&3
        printf "${GREEN}  Нажмите Enter...${RESET}\n" >&3
        IFS= read -r < /dev/tty
        return 0
    fi
    
    if set_provider_api_key "$env_var_name" "$new_key"; then
        printf "\n" >&3
        printf "${GREEN}  Нажмите Enter...${RESET}\n" >&3
        IFS= read -r < /dev/tty
    else
        printf "\n" >&3
        IFS= read -r < /dev/tty
    fi
}
