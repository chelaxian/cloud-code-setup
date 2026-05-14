#!/bin/bash
# Freebuff launcher (Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/launcher-tui.sh"

resolve_freebuff_exe() {
    if command -v freebuff >/dev/null 2>&1; then
        command -v freebuff
        return 0
    fi
    local npm_prefix
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    if [ -n "$npm_prefix" ] && [ -x "$npm_prefix/bin/freebuff" ]; then
        echo "$npm_prefix/bin/freebuff"
        return 0
    fi
    return 1
}

main() {
    local items=(
        "DeepSeek V4 Pro - smartest"
        "DeepSeek V4 Flash - most efficient"
        "Kimi K2.6 - balanced"
        "MiniMax M2.7 - fastest"
        "Запустить Freebuff с встроенным выбором модели"
    )

    local choice
    choice="$(show_tui_numbered_menu "Freebuff" "Freebuff - выбор модели" "DeepSeek V4 Pro/Flash · Kimi K2.6 · MiniMax M2.7" "${items[@]}")"
    if [ "${choice:-0}" -eq 0 ]; then
        echo -e "${YELLOW}Отменено.${RESET}"
        exit 0
    fi

    local freebuff_exe
    freebuff_exe="$(resolve_freebuff_exe)" || true
    if [ -z "$freebuff_exe" ]; then
        echo -e "${RED}Freebuff CLI не найден. Установите: npm install -g freebuff${RESET}"
        exit 1
    fi

    if [ -r /proc/cpuinfo ] && ! grep -qi 'avx2' /proc/cpuinfo; then
        echo -e "${RED}Freebuff binary несовместим с этим CPU/VM: нет AVX2.${RESET}"
        echo -e "${YELLOW}Это означает SIGILL: бинарник выполняет инструкцию, которую процессор не поддерживает.${RESET}"
        echo -e "${GRAY}Нужен хост/тариф с AVX2 или сборка Freebuff без AVX2 от авторов.${RESET}"
        exit 1
    fi

    case "$choice" in
        1) export FREEBUFF_MODEL="deepseek-v4-pro" ;;
        2) export FREEBUFF_MODEL="deepseek-v4-flash" ;;
        3) export FREEBUFF_MODEL="kimi-k2.6" ;;
        4) export FREEBUFF_MODEL="minimax-m2.7" ;;
        *) unset FREEBUFF_MODEL ;;
    esac

    clear >&3
    echo -e "${CYAN}Запуск Freebuff…${RESET}" >&3
    if [ -n "${FREEBUFF_MODEL:-}" ]; then
        echo -e "${GRAY}Предпочтительная модель: ${FREEBUFF_MODEL}${RESET}" >&3
        echo -e "${GRAY}Если текущая версия Freebuff игнорирует env, выберите эту модель во встроенном меню.${RESET}" >&3
    fi
    echo "" >&3
    exec "$freebuff_exe"
}

main "$@"
