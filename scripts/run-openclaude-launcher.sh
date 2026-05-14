#!/bin/bash
# OpenClaude launcher (Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"

resolve_openclaude_exe() {
    if command -v openclaude >/dev/null 2>&1; then
        command -v openclaude
        return 0
    fi
    local npm_prefix
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    if [ -n "$npm_prefix" ] && [ -x "$npm_prefix/bin/openclaude" ]; then
        echo "$npm_prefix/bin/openclaude"
        return 0
    fi
    return 1
}

main() {
    local items=(
        "NVIDIA NIM - Qwen3.5-122B-A10B"
        "OpenClaude providers setup (/provider)"
        "Запустить OpenClaude без пресета"
    )

    local choice
    choice="$(show_tui_numbered_menu "OpenClaude" "OpenClaude - выбор профиля" "OpenAI-compatible providers · NIM Qwen preset" "${items[@]}")"
    if [ "${choice:-0}" -eq 0 ]; then
        echo -e "${YELLOW}Отменено.${RESET}"
        exit 0
    fi

    local openclaude_exe
    openclaude_exe="$(resolve_openclaude_exe)" || true
    if [ -z "$openclaude_exe" ]; then
        echo -e "${RED}OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude${RESET}"
        exit 1
    fi

    if [ "$choice" -eq 1 ]; then
        local key="${NVIDIA_NIM_API_KEY:-}"
        if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
            key="$(get_current_api_key "NVIDIA_NIM")"
        fi
        if [ -z "$key" ]; then
            echo -e "${YELLOW}NVIDIA NIM API ключ не задан.${RESET}"
            echo -e "${CYAN}Получить ключ: https://build.nvidia.com/api-key${RESET}"
            key="$(read_secret_text "NVIDIA NIM API key: ")"
            if [ -n "$key" ]; then
                set_provider_api_key "NVIDIA_NIM" "$key"
            fi
        fi
        export CLAUDE_CODE_USE_OPENAI=1
        export OPENAI_API_KEY="$key"
        export NVIDIA_API_KEY="$key"
        export OPENAI_BASE_URL="https://integrate.api.nvidia.com/v1"
        export OPENAI_MODEL="qwen/qwen3.5-122b-a10b"
    elif [ "$choice" -eq 2 ]; then
        echo -e "${CYAN}После запуска выполните /provider для настройки профиля.${RESET}" >&3
        sleep 1
    fi

    clear >&3
    echo -e "${CYAN}Запуск OpenClaude…${RESET}" >&3
    echo "" >&3
    exec "$openclaude_exe"
}

main "$@"
