#!/bin/bash
# Меню Qwen Code (облако) - Linux версия

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/qwen-code-launcher-state.json"

# Загрузка модулей
. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"

PROFILES=(
    "last|Запустить с последними настройками (быстрый старт)"
    "nim-glm|NVIDIA NIM — GLM-4.7 (tool calling + thinking, модель …-tools)"
    "nim-qwen|NVIDIA NIM — Qwen3.5-122B-A10B (tool calling + thinking, …-tools)"
    "zai-glm|Z.AI — GLM-4.7 (OpenAI Coding API: tool calling + thinking + агент)"
    "zai-glm51|Z.AI — GLM-5.1 (OpenAI Coding API: tool calling + thinking + агент)"
    "custom-model|Другая модель… → Z.AI или NIM, список с API (прокрутка)"
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
        "nim-glm"|"nim-qwen"|"zai-glm"|"zai-glm51"|"custom-qwen-zai"|"custom-qwen-nim")
            echo "$profile_id"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

invoke_qwen_profile() {
    local profile_id="$1"
    
    case "$profile_id" in
        "nim-glm")
            bash "$SCRIPT_DIR/run-qwen-code-nvidia-nim.sh" -Model "nim-glm-4.7-tools"
            ;;
        "nim-qwen")
            bash "$SCRIPT_DIR/run-qwen-code-nvidia-nim.sh" -Model "nim-qwen3.5-122b-a10b-tools"
            ;;
        "zai-glm")
            bash "$SCRIPT_DIR/run-qwen-code-cloud-zai-glm47.sh"
            ;;
        "zai-glm51")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider zai -ModelId "glm-5.1"
            ;;
        "custom-qwen-zai")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}В qwen-code-launcher-state.json нет customModelId для custom-qwen-zai.${RESET}"
                echo -e "${RED}Выберите модель в пункте «Другая модель».${RESET}"
                return 1
            fi
            
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider zai -ModelId "$model_id"
            ;;
        "custom-qwen-nim")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}В qwen-code-launcher-state.json нет customModelId для custom-qwen-nim.${RESET}"
                return 1
            fi
            
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "$model_id"
            ;;
        *)
            echo -e "${RED}Неизвестный профиль: $profile_id${RESET}"
            return 1
            ;;
    esac
}

# Быстрый старт
if [ "${QWEN_CODE_LAUNCHER_QUICK:-0}" = "1" ]; then
    if state=$(get_launcher_state); then
        if resolved_id=$(resolve_profile_from_state "$state"); then
            invoke_qwen_profile "$resolved_id"
            exit $?
        fi
    fi
    
    echo -e "${YELLOW}Нет сохранённого профиля. Один раз выберите модель в меню или уберите -Quick.${RESET}"
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
    
    show_tui_framed_menu "Qwen" "Qwen Code — выбор профиля" "OpenAI Coding (Z.AI / NIM) + пресеты" "${menu_items[@]}"
    local choice=$?
    
    if [ $choice -eq 0 ]; then
        echo -e "${YELLOW}Отменено.${RESET}"
        exit 0
    fi
    
    local profile_id=$(echo "${PROFILES[$((choice-1))]}" | cut -d'|' -f1)
    
    case "$profile_id" in
        "change-api-key")
            show_api_key_change_menu "Qwen"
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
                    echo -e "${RED}Сохранённый профиль не найден. Выберите пресет или «Другая модель» один раз.${RESET}"
                    read -p "Нажмите Enter..."
                    exit 2
                fi
            else
                echo -e "${RED}Сохранённый профиль не найден. Выберите пресет или «Другая модель» один раз.${RESET}"
                read -p "Нажмите Enter..."
                exit 2
            fi
            ;;
        *)
            save_launcher_state "$profile_id"
            ;;
    esac
    
    invoke_qwen_profile "$profile_id"
    exit $?
done
