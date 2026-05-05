#!/bin/bash
# Меню Claude Code (облако) - Linux версия

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/claude-cloud-launcher-state.json"
SESSION_SCRIPT="$SCRIPT_DIR/run-claude-cloud-session.sh"

# Настройки (можно изменить под свои пути)
VAULT_PATH="${CLAUDE_VAULT_PATH:-$HOME/Documents/Obsidian\ Vault}"
OBSIDIAN_EXE="${OBSIDIAN_EXE:-/usr/bin/obsidian}"

# Загрузка модулей
. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"

PROFILES=(
    "last|Запустить с последними настройками (быстрый старт)"
    "claude-zai|Z.AI — GLM-4.7 (free, tool calling)"
    "claude-zai-glm51|Z.AI — GLM-5.1 (free, tool calling)"
    "claude-nim|NVIDIA NIM — GLM-4.7 (free, tool calling)"
    "claude-nim-qwen|NVIDIA NIM — Qwen3.5-122B-A10B (free, tool calling)"
    "claude-openrouter-sonnet|OpenRouter — Claude Sonnet 4 (paid, tool calling)"
    "custom-model|Другая модель… → выбор провайдера и модели"
    "change-api-key|Сменить ключ API провайдера"
)

get_launcher_state() {
    if [ ! -f "$STATE_FILE" ]; then
        return 1
    fi
    cat "$STATE_FILE"
}

save_launcher_state() {
    local profile_id="$1"
    local extra="$2"
    
    local timestamp=$(date -Iseconds)
    local json="{\"profileId\":\"$profile_id\",\"updatedAt\":\"$timestamp\""
    
    if [ -n "$extra" ]; then
        json="$json,$extra"
    fi
    
    json="$json}"
    
    echo "$json" > "$STATE_FILE"
}

resolve_profile_from_state() {
    local state="$1"
    local profile_id=$(echo "$state" | grep -o '"profileId":"[^"]*"' | cut -d'"' -f4)
    
    case "$profile_id" in
        "claude-zai"|"claude-zai-glm51"|"claude-nim"|"claude-nim-qwen"|"claude-openrouter-sonnet"|"custom-claude-zai"|"custom-claude-nim")
            echo "$profile_id"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

invoke_claude_cloud_profile() {
    local profile_id="$1"
    
    clear
    echo -e "${CYAN}Запуск сессии Claude Code (облако)…${RESET}"
    echo -e "${GRAY}Профиль: $profile_id   Vault: $VAULT_PATH${RESET}"
    
    case "$profile_id" in
        "claude-zai")
            bash "$SESSION_SCRIPT" -Provider zai \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        "claude-zai-glm51")
            bash "$SESSION_SCRIPT" -Provider zai \
                -ZaiAnthropicModelId "glm-5.1" \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        "claude-nim")
            bash "$SESSION_SCRIPT" -Provider nim \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        "claude-nim-qwen")
            bash "$SESSION_SCRIPT" -Provider nim-qwen \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        "claude-openrouter-sonnet")
            bash "$SESSION_SCRIPT" -Provider openrouter \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        "custom-claude-zai")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId в claude-cloud-launcher-state.json.${RESET}"
                echo -e "${RED}Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            
            bash "$SESSION_SCRIPT" -Provider zai \
                -ZaiAnthropicModelId "$model_id" \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        "custom-claude-nim")
            local state=$(get_launcher_state)
            local model=$(echo "$state" | grep -o '"customNimModel":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model" ]; then
                echo -e "${RED}Нет customNimModel в claude-cloud-launcher-state.json.${RESET}"
                return 1
            fi
            
            bash "$SESSION_SCRIPT" -Provider nim \
                -NimModel "$model" \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools minimal \
                -SkipCommonPreamble
            ;;
        *)
            echo -e "${RED}Неизвестный профиль: $profile_id${RESET}"
            return 1
            ;;
    esac
}

# Быстрый старт
if [ "${CLAUDE_CLOUD_LAUNCHER_QUICK:-0}" = "1" ]; then
    if state=$(get_launcher_state); then
        if resolved_id=$(resolve_profile_from_state "$state"); then
            invoke_claude_cloud_profile "$resolved_id"
            exit $?
        fi
    fi
    
    echo -e "${YELLOW}Нет сохранённого профиля Claude (облако). Один раз выберите провайдер в меню.${RESET}"
    sleep 3
    exit 2
fi

# Главное меню
while true; do
    local state=$(get_launcher_state 2>/dev/null || true)
    local last_id=$(resolve_profile_from_state "$state" 2>/dev/null || true)
    
    # Подготовка списка пунктов меню
    local menu_items=()
    for profile in "${PROFILES[@]}"; do
        local id="${profile%%|*}"
        local label="${profile##*|}"
        menu_items+=("$label")
    done
    
    show_tui_framed_menu "Claude" "Claude Code (облако) — провайдер" "Z.AI Anthropic · NVIDIA NIM через free-claude-code" "${menu_items[@]}"
    local choice=$?
    
    if [ $choice -eq 0 ]; then
        echo -e "${YELLOW}Отменено.${RESET}"
        exit 0
    fi
    
    local profile_id=$(echo "${PROFILES[$((choice-1))]}" | cut -d'|' -f1)
    
    case "$profile_id" in
        "change-api-key")
            show_api_key_change_menu "Claude"
            continue
            ;;
        "custom-model")
            # TODO: Вызов мастера выбора модели
            echo -e "${YELLOW}Функция «Другая модель» в разработке${RESET}"
            sleep 2
            continue
            ;;
        "last")
            if state=$(get_launcher_state); then
                if resolved_id=$(resolve_profile_from_state "$state"); then
                    profile_id="$resolved_id"
                else
                    echo -e "${RED}Сохранённый профиль не найден. Выберите пункт меню один раз.${RESET}"
                    read -p "Нажмите Enter..."
                    exit 2
                fi
            else
                echo -e "${RED}Сохранённый профиль не найден. Выберите пункт меню один раз.${RESET}"
                read -p "Нажмите Enter..."
                exit 2
            fi
            ;;
        *)
            save_launcher_state "$profile_id"
            ;;
    esac
    
    invoke_claude_cloud_profile "$profile_id"
    exit $?
done
