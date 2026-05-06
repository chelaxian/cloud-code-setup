#!/bin/bash
# Меню OpenCode (облако) - Linux версия

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/opencode-launcher-state.json"
CONFIG_DIR="$SCRIPT_DIR/opencode-sessions"

# Загрузка модулей
. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"

PROFILES=(
    "last|Запустить с последними настройками (быстрый старт)"
    "zai-glm|Z.AI — GLM-4.7 (free, tool calling)"
    "zai-glm51|Z.AI — GLM-5.1 (free, tool calling)"
    "nim-glm|NVIDIA NIM — GLM-4.7 (free, tool calling)"
    "nim-qwen|NVIDIA NIM — Qwen3.5-122B-A10B (free, tool calling)"
    "groq-llama|Groq — Llama 3.3 70B (free, chat only)"
    "groq-qwen|Groq — Qwen3 32B (free, chat only)"
    "openrouter-qwen-coder|OpenRouter — Qwen3 Coder (free, tool calling)"
    "custom-model|Другая модель… → выбор провайдера и модели"
    "native-login|Нативный логин (OpenCode Providers)"
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
        "zai-glm"|"zai-glm51"|"nim-glm"|"nim-qwen"|"groq-llama"|"groq-qwen"|"openrouter-qwen-coder"|"custom-opencode-zai"|"custom-opencode-nim"|"custom-opencode-groq"|"custom-opencode-openrouter")
            echo "$profile_id"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

resolve_opencode_exe() {
    # Проверяем глобальную установку npm
    if command -v opencode &> /dev/null; then
        which opencode
        return 0
    fi
    
    # Проверяем npm global bin
    local npm_prefix
    npm_prefix=$(npm config get prefix 2>/dev/null || true)
    if [ -n "$npm_prefix" ] && [ -x "$npm_prefix/bin/opencode" ]; then
        echo "$npm_prefix/bin/opencode"
        return 0
    fi
    
    # Проверяем ~/.npm-global
    if [ -x "$HOME/.npm-global/bin/opencode" ]; then
        echo "$HOME/.npm-global/bin/opencode"
        return 0
    fi
    
    echo ""
    return 1
}

write_opencode_config() {
    local provider="$1"
    local model="$2"
    local base_url="$3"
    local api_key="$4"
    local max_tokens="${5:-8192}"
    local context_length="${6:-131072}"
    
    mkdir -p "$CONFIG_DIR"
    
    local config_path="$CONFIG_DIR/opencode.json"
    
    cat > "$config_path" << EOFJSON
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "$provider": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "$provider",
      "options": {
        "baseURL": "$base_url",
        "apiKey": "$api_key"
      },
      "models": {
        "$model": {
          "name": "$model",
          "maxTokens": $max_tokens,
          "contextLength": $context_length
        }
      }
    }
  },
  "model": "$provider/$model"
}
EOFJSON
    
    echo "$config_path"
}

get_zai_api_key() {
    local key="${ZAI_API_KEY:-}"
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        key="${OPENAI_API_KEY:-}"
    fi
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        echo -e "${YELLOW}Z.AI API ключ не задан. Задайте ZAI_API_KEY или выберите «Сменить ключ API провайдера».${RESET}" >&2
        return 1
    fi
    echo "$key"
}

get_nim_api_key() {
    local key="${NVIDIA_NIM_API_KEY:-}"
    if [ -z "$key" ]; then
        echo -e "${YELLOW}NVIDIA NIM API ключ не задан. Задайте NVIDIA_NIM_API_KEY или выберите «Сменить ключ API провайдера».${RESET}" >&2
        return 1
    fi
    echo "$key"
}

get_groq_api_key() {
    local key="${GROQ_API_KEY:-}"
    if [ -z "$key" ]; then
        echo -e "${YELLOW}Groq API ключ не задан. Задайте GROQ_API_KEY или выберите «Сменить ключ API провайдера».${RESET}" >&2
        return 1
    fi
    echo "$key"
}

get_openrouter_api_key() {
    local key="${OPENROUTER_API_KEY:-}"
    if [ -z "$key" ]; then
        echo -e "${YELLOW}OpenRouter API ключ не задан. Задайте OPENROUTER_API_KEY или выберите «Сменить ключ API провайдера».${RESET}" >&2
        return 1
    fi
    echo "$key"
}

invoke_opencode_profile() {
    local profile_id="$1"
    
    local opencode_exe
    opencode_exe=$(resolve_opencode_exe) || true
    if [ -z "$opencode_exe" ]; then
        echo -e "${RED}OpenCode CLI не найден. Установите: npm install -g opencode-ai@latest${RESET}"
        return 1
    fi
    
    case "$profile_id" in
        "zai-glm")
            local api_key
            api_key=$(get_zai_api_key) || return 1
            local config_path
            config_path=$(write_opencode_config "zai" "glm-4.7" "https://api.z.ai/api/openai/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI GLM-4.7)…${RESET}"
            "$opencode_exe"
            ;;
        "zai-glm51")
            local api_key
            api_key=$(get_zai_api_key) || return 1
            local config_path
            config_path=$(write_opencode_config "zai" "glm-5.1" "https://api.z.ai/api/openai/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI GLM-5.1)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-glm")
            local api_key
            api_key=$(get_nim_api_key) || return 1
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "z-ai/glm4.7" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM GLM-4.7)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-qwen")
            local api_key
            api_key=$(get_nim_api_key) || return 1
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "qwen/qwen3.5-122b-a10b" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Qwen3.5-122B-A10B)…${RESET}"
            "$opencode_exe"
            ;;
        "groq-llama")
            local api_key="${GROQ_API_KEY:-}"
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}Groq API ключ не задан. Задайте GROQ_API_KEY.${RESET}" >&2
                return 1
            fi
            local config_path
            config_path=$(write_opencode_config "groq" "llama-3.3-70b-versatile" "https://api.groq.com/openai/v1" "$api_key" 2048 4096)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Groq Llama 3.3 70B)…${RESET}"
            "$opencode_exe"
            ;;
        "groq-qwen")
            local api_key="${GROQ_API_KEY:-}"
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}Groq API ключ не задан. Задайте GROQ_API_KEY.${RESET}" >&2
                return 1
            fi
            local config_path
            config_path=$(write_opencode_config "groq" "qwen/qwen3-32b" "https://api.groq.com/openai/v1" "$api_key" 2048 4096)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Groq Qwen3 32B)…${RESET}"
            "$opencode_exe"
            ;;
        "openrouter-qwen-coder")
            local api_key="${OPENROUTER_API_KEY:-}"
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}OpenRouter API ключ не задан. Задайте OPENROUTER_API_KEY.${RESET}" >&2
                return 1
            fi
            local config_path
            config_path=$(write_opencode_config "openrouter" "qwen/qwen3-coder:free" "https://openrouter.ai/api/v1" "$api_key" 8192 16384)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (OpenRouter Qwen3 Coder)…${RESET}"
            "$opencode_exe"
            ;;
        "custom-opencode-zai")
            local state
            state=$(get_launcher_state) || true
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId. Выберите модель в пункте «Другая модель».${RESET}"
                return 1
            fi
            
            local api_key
            api_key=$(get_zai_api_key) || return 1
            local config_path
            config_path=$(write_opencode_config "zai" "$model_id" "https://api.z.ai/api/openai/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI custom: $model_id)…${RESET}"
            "$opencode_exe"
            ;;
        "custom-opencode-nim")
            local state
            state=$(get_launcher_state) || true
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId. Выберите модель в пункте «Другая модель».${RESET}"
                return 1
            fi
            
            local api_key
            api_key=$(get_nim_api_key) || return 1
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "$model_id" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM custom: $model_id)…${RESET}"
            "$opencode_exe"
            ;;
        "custom-opencode-groq")
            local state
            state=$(get_launcher_state) || true
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для Groq. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            local api_key="${GROQ_API_KEY:-}"
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}Groq API ключ не задан. Задайте GROQ_API_KEY.${RESET}" >&2
                return 1
            fi
            local config_path
            config_path=$(write_opencode_config "groq" "$model_id" "https://api.groq.com/openai/v1" "$api_key" 4096 8192)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Groq custom: $model_id)…${RESET}"
            "$opencode_exe"
            ;;
        "custom-opencode-openrouter")
            local state
            state=$(get_launcher_state) || true
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для OpenRouter. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            local api_key="${OPENROUTER_API_KEY:-}"
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}OpenRouter API ключ не задан. Задайте OPENROUTER_API_KEY.${RESET}" >&2
                return 1
            fi
            local config_path
            config_path=$(write_opencode_config "openrouter" "$model_id" "https://openrouter.ai/api/v1" "$api_key" 8192 16384)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (OpenRouter custom: $model_id)…${RESET}"
            "$opencode_exe"
            ;;
        *)
            echo -e "${RED}Неизвестный профиль: $profile_id${RESET}"
            return 1
            ;;
    esac
}

# ── Мастер выбора модели (упрощённый для Linux) ────────────────────────────────

invoke_custom_model_wizard() {
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
            show_tui_wait_frame "$app_brand" "Загрузка каталога моделей Z.AI с API…"
            key=$(get_zai_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }
            
            # Получаем список моделей через API
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
            key=$(get_nim_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }
            
            local response
            response=$(curl -s -H "Authorization: Bearer $key" "https://integrate.api.nvidia.com/v1/models" 2>/dev/null) || true
            
            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "groq" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога Groq…"
            key=$(get_groq_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }
            
            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://api.groq.com/openai/v1/models" 2>/dev/null) || true
            
            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "groq-free" ]; then
            ids=( "llama-3.1-8b-instant" "llama-3.3-70b-versatile" "meta-llama/llama-4-scout-17b-16e-instruct" "openai/gpt-oss-120b" "openai/gpt-oss-20b" "qwen/qwen3-32b" "allam-2-7b" "deepseek-r1-distill-llama-70b" "deepseek-r1-distill-qwen-32b" "gemma2-9b-it" )
            key=$(get_groq_api_key) || true
        elif [ "$prov_source" = "openrouter" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога OpenRouter…"
            key=$(get_openrouter_api_key) || { echo -e "${RED}Не удалось получить API ключ${RESET}"; read -p "Нажмите Enter..."; return 1; }
            
            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://openrouter.ai/api/v1/models" 2>/dev/null) || true
            
            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "openrouter-free" ]; then
            ids=( "openrouter/free" "tencent/hy3-preview:free" "nvidia/nemotron-3-super:free" "inclusionai/ling-2.6-1t:free" "openai/gpt-oss-120b:free" "poolside/laguna-m.1:free" "openrouter/owl-alpha:free" "z-ai/glm-4.5-air:free" "minimax/minimax-m2.5:free" "nvidia/nemotron-3-nano-30b-a3b:free" "openai/gpt-oss-20b:free" "meta-llama/llama-4-scout:free" "qwen/qwen3-235b-a22b:free" "qwen/qwen3-coder:free" "deepseek/deepseek-r1:free" "google/gemma-4-31b:free" "meta-llama/llama-3.3-70b-instruct:free" "mistralai/mistral-small-3.1-24b-instruct:free" )
            key=$(get_openrouter_api_key) || true
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

# ── Быстрый старт ────────────────────────────────────────────────────────────

if [ "${OPENCODE_LAUNCHER_QUICK:-0}" = "1" ]; then
    if state=$(get_launcher_state); then
        if resolved_id=$(resolve_profile_from_state "$state"); then
            invoke_opencode_profile "$resolved_id"
            exit $?
        fi
    fi
    
    echo -e "${YELLOW}Нет сохранённого профиля. Один раз выберите модель в меню.${RESET}"
    sleep 3
    exit 2
fi

# ── Главное меню ─────────────────────────────────────────────────────────────

while true; do
    local state=$(get_launcher_state 2>/dev/null || true)
    local last_id=$(resolve_profile_from_state "$state" 2>/dev/null || true)
    
    # Подготовка списка пунктов меню
    local menu_items=()
    for profile in "${PROFILES[@]}"; do
        local label="${profile##*|}"
        menu_items+=("$label")
    done
    
    show_tui_framed_menu "OpenCode" "OpenCode — выбор провайдера" "Z.AI · NVIDIA NIM (OpenAI-compatible)" "${menu_items[@]}"
    local choice=$?
    
    if [ $choice -eq 0 ]; then
        echo -e "${YELLOW}Отменено.${RESET}"
        exit 0
    fi
    
    local profile_id=$(echo "${PROFILES[$((choice-1))]}" | cut -d'|' -f1)
    
    case "$profile_id" in
        "native-login")
            echo ""
            echo -e "${CYAN}OpenCode: авторизация через провайдеров${RESET}"
            echo ""
            echo -e "${YELLOW}Для нативного логина выполните в отдельном терминале:${RESET}"
            echo -e "  ${WHITE}opencode providers login${RESET}"
            echo ""
            echo -e "${YELLOW}Либо задайте API-ключи через переменные окружения:${RESET}"
            echo -e "  ${WHITE}OPENROUTER_API_KEY, GROQ_API_KEY, ZAI_API_KEY${RESET}"
            echo ""
            echo -e "${YELLOW}Для просмотра текущих подключений:${RESET}"
            echo -e "  ${WHITE}opencode providers list${RESET}"
            echo ""
            echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
            read
            continue
            ;;
        "change-api-key")
            show_api_key_change_menu "OpenCode"
            continue
            ;;
        "custom-model")
            local wizard_result
            wizard_result=$(invoke_custom_model_wizard "OpenCode") || {
                echo -e "${YELLOW}Отменено.${RESET}"
                exit 0
            }
            
            local wiz_provider=$(echo "$wizard_result" | cut -d'|' -f1)
            local wiz_model=$(echo "$wizard_result" | cut -d'|' -f2)
            
            local new_id="custom-opencode-nim"
            if [ "$wiz_provider" = "zai" ]; then
                new_id="custom-opencode-zai"
            elif [ "$wiz_provider" = "groq" ]; then
                new_id="custom-opencode-groq"
            elif [ "$wiz_provider" = "openrouter" ]; then
                new_id="custom-opencode-openrouter"
            fi
            
            save_launcher_state "$new_id" "\"customModelId\":\"$wiz_model\""
            invoke_opencode_profile "$new_id"
            exit $?
            ;;
        "last")
            if state=$(get_launcher_state); then
                if resolved_id=$(resolve_profile_from_state "$state"); then
                    profile_id="$resolved_id"
                else
                    echo -e "${RED}Сохранённый профиль не найден. Выберите провайдер один раз.${RESET}"
                    read -p "Нажмите Enter..."
                    exit 2
                fi
            else
                echo -e "${RED}Сохранённый профиль не найден. Выберите провайдер один раз.${RESET}"
                read -p "Нажмите Enter..."
                exit 2
            fi
            ;;
        *)
            save_launcher_state "$profile_id"
            ;;
    esac
    
    invoke_opencode_profile "$profile_id"
    exit $?
done
