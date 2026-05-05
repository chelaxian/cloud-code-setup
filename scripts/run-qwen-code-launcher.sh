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
    "nim-glm|NVIDIA NIM — GLM-4.7 (free, tool calling)"
    "nim-qwen|NVIDIA NIM — Qwen3.5-122B-A10B (free, tool calling)"
    "zai-glm|Z.AI — GLM-4.7 (free, tool calling)"
    "zai-glm51|Z.AI — GLM-5.1 (free, tool calling)"
    "groq-llama|Groq — Llama 3.3 70B (free, tool calling)"
    "groq-qwen|Groq — Qwen3 32B (free, tool calling)"
    "openrouter-qwen-coder|OpenRouter — Qwen3 Coder (free, tool calling)"
    "custom-model|Другая модель… → выбор провайдера и модели"
    "native-login|Нативный логин (Qwen OAuth / Coding Plan)"
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
        "nim-glm"|"nim-qwen"|"zai-glm"|"zai-glm51"|"groq-llama"|"groq-qwen"|"openrouter-qwen-coder"|"custom-qwen-zai"|"custom-qwen-nim"|"custom-qwen-groq"|"custom-qwen-openrouter")
            echo "$profile_id"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ── API key helpers ──────────────────────────────────────────────────────────
get_qwen_zai_api_key() {
    local key="${ZAI_API_KEY:-}"
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        key="${OPENAI_API_KEY:-}"
    fi
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        echo -e "${YELLOW}Z.AI API ключ не задан. Задайте ZAI_API_KEY.${RESET}" >&2
        return 1
    fi
    echo "$key"
}

get_qwen_nim_api_key() {
    local key="${NVIDIA_NIM_API_KEY:-}"
    if [ -z "$key" ]; then
        echo -e "${YELLOW}NVIDIA NIM API ключ не задан. Задайте NVIDIA_NIM_API_KEY.${RESET}" >&2
        return 1
    fi
    echo "$key"
}

get_qwen_groq_api_key() {
    local key="${GROQ_API_KEY:-}"
    if [ -z "$key" ]; then
        echo -e "${YELLOW}Groq API ключ не задан. Задайте GROQ_API_KEY.${RESET}" >&2
        return 1
    fi
    echo "$key"
}

get_qwen_openrouter_api_key() {
    local key="${OPENROUTER_API_KEY:-}"
    if [ -z "$key" ]; then
        echo -e "${YELLOW}OpenRouter API ключ не задан. Задайте OPENROUTER_API_KEY.${RESET}" >&2
        return 1
    fi
    echo "$key"
}

# ── Мастер выбора модели ─────────────────────────────────────────────────────
invoke_qwen_custom_model_wizard() {
    local app_brand="$1"

    local prov_items=(
        "zai|Z.AI — Coding / Anthropic (список моделей по вашему ключу)"
        "nim|NVIDIA NIM — полный каталог (GET /v1/models)"
        "groq|Groq — полный каталог моделей (GET /v1/models)"
        "groq-free|Groq — только бесплатные модели (статический список)"
        "openrouter|OpenRouter — полный каталог моделей (GET /v1/models)"
        "openrouter-free|OpenRouter — только бесплатные модели (статический список)"
    )

    while true; do
        local prov_menu=()
        for item in "${prov_items[@]}"; do
            local label="${item##*|}"
            prov_menu+=("$label")
        done

        show_tui_framed_menu "$app_brand" "Другая модель" "Шаг 1 из 2 — выберите провайдера" "${prov_menu[@]}"
        local prov_choice=$?

        if [ $prov_choice -eq 0 ]; then
            return 1
        fi

        local prov_source=$(echo "${prov_items[$((prov_choice-1))]}" | cut -d'|' -f1)

        local ids=()
        local key=""

        if [ "$prov_source" = "zai" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога моделей Z.AI…"
            key=$(get_qwen_zai_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }

            local response
            response=$(curl -s -H "Authorization: Bearer $key" "https://api.z.ai/api/coding/paas/v4/models" 2>/dev/null) || true
            if [ -z "$response" ]; then
                response=$(curl -s -H "Authorization: Bearer $key" "https://api.z.ai/api/paas/v4/models" 2>/dev/null) || true
            fi

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi

            if [ ${#ids[@]} -eq 0 ]; then
                ids=("glm-4.7" "glm-4.7-flash" "glm-4.7-flashx" "glm-4.6" "glm-4.5" "glm-5" "glm-5-turbo" "glm-5.1")
            fi
        elif [ "$prov_source" = "nim" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога NVIDIA NIM…"
            key=$(get_qwen_nim_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }

            local response
            response=$(curl -s -H "Authorization: Bearer $key" "https://integrate.api.nvidia.com/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "groq" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога Groq…"
            key=$(get_qwen_groq_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }

            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://api.groq.com/openai/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "groq-free" ]; then
            ids=( "llama-3.1-8b-instant" "llama-3.3-70b-versatile" "meta-llama/llama-4-scout-17b-16e-instruct" "openai/gpt-oss-120b" "openai/gpt-oss-20b" "qwen/qwen3-32b" "allam-2-7b" "deepseek-r1-distill-llama-70b" "deepseek-r1-distill-qwen-32b" "gemma2-9b-it" )
            key=$(get_qwen_groq_api_key) || true
        elif [ "$prov_source" = "openrouter" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога OpenRouter…"
            key=$(get_qwen_openrouter_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }

            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://openrouter.ai/api/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "openrouter-free" ]; then
            ids=( "openrouter/free" "tencent/hy3-preview:free" "nvidia/nemotron-3-super:free" "inclusionai/ling-2.6-1t:free" "openai/gpt-oss-120b:free" "poolside/laguna-m.1:free" "openrouter/owl-alpha:free" "z-ai/glm-4.5-air:free" "minimax/minimax-m2.5:free" "nvidia/nemotron-3-nano-30b-a3b:free" "openai/gpt-oss-20b:free" "meta-llama/llama-4-scout:free" "qwen/qwen3-235b-a22b:free" "qwen/qwen3-coder:free" "deepseek/deepseek-r1:free" "google/gemma-4-31b:free" "meta-llama/llama-3.3-70b-instruct:free" "mistralai/mistral-small-3.1-24b-instruct:free" )
            key=$(get_qwen_openrouter_api_key) || true
        fi

        if [ ${#ids[@]} -eq 0 ]; then
            echo -e "${RED}Провайдер вернул пустой список моделей.${RESET}"
            read -p "Нажмите Enter…"
            return 1
        fi

        local model_menu=()
        for id in "${ids[@]}"; do
            model_menu+=("$id")
        done

        show_tui_framed_menu "$app_brand" "Другая модель" "Шаг 2 из 2 — моделей: ${#ids[@]}" "${model_menu[@]}"
        local model_choice=$?

        if [ $model_choice -eq 0 ]; then
            continue
        fi

        local model_id="${ids[$((model_choice-1))]}"
        local prov="nim"
        if [ "$prov_source" = "zai" ]; then
            prov="zai"
        elif [ "$prov_source" = "groq" ] || [ "$prov_source" = "groq-free" ]; then
            prov="groq"
        elif [ "$prov_source" = "openrouter" ] || [ "$prov_source" = "openrouter-free" ]; then
            prov="openrouter"
        fi

        echo "$prov|$model_id"
        return 0
    done
}

# ── Профили ──────────────────────────────────────────────────────────────────
invoke_qwen_profile() {
    local profile_id="$1"
    
    case "$profile_id" in
        "nim-glm")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "nim-glm-4.7-tools"
            ;;
        "nim-qwen")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider nim -ModelId "nim-qwen3.5-122b-a10b-tools"
            ;;
        "zai-glm")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider zai -ModelId "glm-4.7"
            ;;
        "zai-glm51")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider zai -ModelId "glm-5.1"
            ;;
        "groq-llama")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider groq -ModelId "llama-3.3-70b-versatile"
            ;;
        "groq-qwen")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider groq -ModelId "qwen/qwen3-32b"
            ;;
        "openrouter-qwen-coder")
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider openrouter -ModelId "qwen/qwen3-coder:free"
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
        "custom-qwen-groq")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для custom-qwen-groq. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider groq -ModelId "$model_id"
            ;;
        "custom-qwen-openrouter")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для custom-qwen-openrouter. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            bash "$SCRIPT_DIR/run-qwen-code-dynamic.sh" -Provider openrouter -ModelId "$model_id"
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
        "native-login")
            local login_items=("qwen-oauth|Qwen OAuth (браузер, подписка Qwen)" "coding-plan|Alibaba Cloud Coding Plan (API-ключ)")
            local login_menu=()
            for item in "${login_items[@]}"; do
                login_menu+=("${item##*|}")
            done

            show_tui_framed_menu "Qwen" "Нативный логин Qwen Code" "Выберите способ авторизации" "${login_menu[@]}"
            local login_choice=$?

            if [ $login_choice -eq 0 ]; then
                continue
            fi

            local login_id=$(echo "${login_items[$((login_choice-1))]}" | cut -d'|' -f1)

            case "$login_id" in
                "qwen-oauth")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Qwen OAuth — авторизация через браузер${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Откроется браузер. Завершите авторизацию в нём.${RESET}"
                    echo -e "${YELLOW}  Для этого нужна подписка Qwen (qwen.ai).${RESET}"
                    echo ""
                    qwen auth qwen-oauth
                    echo ""
                    echo -e "${GREEN}  Текущий статус:${RESET}"
                    qwen auth status
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "coding-plan")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Alibaba Cloud Coding Plan${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Регион: china или global${RESET}"
                    echo -e "${YELLOW}  Потребуется API-ключ от Alibaba Cloud.${RESET}"
                    echo ""
                    qwen auth coding-plan
                    echo ""
                    echo -e "${GREEN}  Текущий статус:${RESET}"
                    qwen auth status
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
            esac
            continue
            ;;
        "change-api-key")
            show_api_key_change_menu "Qwen"
            continue
            ;;
        "custom-model")
            wizard_result=$(invoke_qwen_custom_model_wizard "Qwen") || {
                echo -e "${YELLOW}Отменено.${RESET}"
                continue
            }
            local wiz_provider=$(echo "$wizard_result" | cut -d'|' -f1)
            local wiz_model=$(echo "$wizard_result" | cut -d'|' -f2)
            
            local new_id="custom-qwen-nim"
            if [ "$wiz_provider" = "zai" ]; then
                new_id="custom-qwen-zai"
            elif [ "$wiz_provider" = "groq" ]; then
                new_id="custom-qwen-groq"
            elif [ "$wiz_provider" = "openrouter" ]; then
                new_id="custom-qwen-openrouter"
            fi
            
            save_launcher_state "$new_id" "\"customModelId\":\"$wiz_model\""
            invoke_qwen_profile "$new_id"
            exit $?
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
