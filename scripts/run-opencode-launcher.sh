#!/bin/bash
# Меню OpenCode (облако) - Linux версия

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/opencode-launcher-state.json"
# Единое пространство (как у Qwen /resume): общий рабочий каталог + единый config
CONFIG_DIR="$SCRIPT_DIR/../opencode-sessions/_shared"

# Загрузка модулей
. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"

PROFILES=(
    "last|Запустить с последними настройками (быстрый старт)"
    "zai-glm|Z.AI - GLM-4.7 (paid, tool calling)"
    "zai-glm51|Z.AI - GLM-5.1 (paid, tool calling)"
    "zai-flash47|Z.AI - GLM-4.7-Flash (free, tool calling)"
    "zai-flash45|Z.AI - GLM-4.5-Flash (free, tool calling)"
    "nim-glm|NVIDIA NIM - GLM-4.7 (free, tool calling)"
    "nim-qwen|NVIDIA NIM - Qwen3.5-122B-A10B (free, tool calling)"
    "openrouter-hy3|OpenRouter - Tencent Hy3 (free, tool calling)"
    "openrouter-nemotron|OpenRouter - Nemotron 3 Super 120B (free, tool calling)"
    "openrouter-laguna|OpenRouter - Poolside Laguna M.1 (free, tool calling, coding)"
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

resolve_api_key_or_prompt() {
    local current_key="$1"
    local provider_name="$2"
    local help_url="$3"

    if [ -z "$current_key" ]; then
        echo -e "${YELLOW}$provider_name API ключ не задан.${RESET}"
        echo -e "${CYAN}Получить ключ: $help_url${RESET}"
    fi

    if [ -z "$current_key" ]; then
        read_secret_text "$provider_name API key: "
    else
        echo "$current_key"
    fi
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
        "zai-glm"|"zai-glm51"|"zai-flash47"|"zai-flash45"|"nim-glm"|"nim-qwen"|"openrouter-hy3"|"openrouter-nemotron"|"openrouter-laguna"|"custom-opencode-zai"|"custom-opencode-nim"|"custom-opencode-groq"|"custom-opencode-openrouter")
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
        key=$(get_current_api_key "ZAI")
    fi
    if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then
        printf "${YELLOW}Z.AI API ключ не задан.${RESET}\n" >&3
        printf "${CYAN}Получить ключ: https://console.z.ai/${RESET}\n" >&3
        local input
        input=$(read_secret_text "Z.AI API key: ")
        if [ -n "$input" ]; then
            set_provider_api_key "ZAI" "$input"
            echo "$input"
        fi
    else
        echo "$key"
    fi
}

get_nim_api_key() {
    local key="${NVIDIA_NIM_API_KEY:-}"
    if [ -z "$key" ]; then
        key=$(get_current_api_key "NVIDIA_NIM")
    fi
    if [ -z "$key" ]; then
        printf "${YELLOW}NVIDIA NIM API ключ не задан.${RESET}\n" >&3
        printf "${CYAN}Получить ключ: https://build.nvidia.com/api-key${RESET}\n" >&3
        local input
        input=$(read_secret_text "NVIDIA NIM API key: ")
        if [ -n "$input" ]; then
            set_provider_api_key "NVIDIA_NIM" "$input"
            echo "$input"
        fi
    else
        echo "$key"
    fi
}

get_groq_api_key() {
    local key="${GROQ_API_KEY:-}"
    if [ -z "$key" ]; then
        key=$(get_current_api_key "GROQ")
    fi
    if [ -z "$key" ]; then
        printf "${YELLOW}Groq API ключ не задан.${RESET}\n" >&3
        printf "${CYAN}Получить ключ: https://console.groq.com/keys${RESET}\n" >&3
        local input
        input=$(read_secret_text "Groq API key: ")
        if [ -n "$input" ]; then
            set_provider_api_key "GROQ" "$input"
            echo "$input"
        fi
    else
        echo "$key"
    fi
}

get_openrouter_api_key() {
    local key="${OPENROUTER_API_KEY:-}"
    if [ -z "$key" ]; then
        key=$(get_current_api_key "OPENROUTER")
    fi
    if [ -z "$key" ]; then
        printf "${YELLOW}OpenRouter API ключ не задан.${RESET}\n" >&3
        printf "${CYAN}Получить ключ: https://openrouter.ai/settings/keys${RESET}\n" >&3
        local input
        input=$(read_secret_text "OpenRouter API key: ")
        if [ -n "$input" ]; then
            set_provider_api_key "OPENROUTER" "$input"
            echo "$input"
        fi
    else
        echo "$key"
    fi
}

invoke_opencode_profile() {
    local profile_id="$1"
    
    # Проверка API ключа
    local env_var=""
    local provider_name=""
    local provider_url=""
    case "$profile_id" in
        zai-*|custom-opencode-zai*) env_var="ZAI"; provider_name="Z.AI"; provider_url="https://console.z.ai/" ;;
        nim-*|custom-opencode-nim*) env_var="NVIDIA_NIM"; provider_name="NVIDIA NIM"; provider_url="https://build.nvidia.com/api-key" ;;
        openrouter-*|custom-opencode-openrouter*) env_var="OPENROUTER"; provider_name="OpenRouter"; provider_url="https://openrouter.ai/settings/keys" ;;
    esac
    if [ -n "$env_var" ]; then
        if ! ensure_api_key_or_prompt "$env_var" "$provider_name" "$provider_url"; then
            return 1
        fi
    fi
    
    local opencode_exe
    opencode_exe=$(resolve_opencode_exe) || true
    if [ -z "$opencode_exe" ]; then
        echo -e "${RED}OpenCode CLI не найден. Установите: npm install -g opencode-ai@latest${RESET}"
        return 1
    fi
    
    case "$profile_id" in
        "zai-glm")
            local api_key
            api_key=$(get_zai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "zai" "glm-4.7" "https://api.z.ai/api/coding/paas/v4" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI GLM-4.7)…${RESET}"
            "$opencode_exe"
            ;;
        "zai-glm51")
            local api_key
            api_key=$(get_zai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "zai" "glm-5.1" "https://api.z.ai/api/coding/paas/v4" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI GLM-5.1)…${RESET}"
            "$opencode_exe"
            ;;
        "zai-flash47")
            local api_key
            api_key=$(get_zai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "zai" "glm-4.7-flash" "https://api.z.ai/api/coding/paas/v4" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI GLM-4.7-Flash)…${RESET}"
            "$opencode_exe"
            ;;
        "zai-flash45")
            local api_key
            api_key=$(get_zai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "zai" "glm-4.5-flash" "https://api.z.ai/api/coding/paas/v4" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (Z.AI GLM-4.5-Flash)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-glm")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "z-ai/glm4.7" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM GLM-4.7)…${RESET}"
            "$opencode_exe"
            ;;
        "nim-qwen")
            local api_key
            api_key=$(get_nim_api_key) || true
            local config_path
            config_path=$(write_opencode_config "nvidia-nim" "qwen/qwen3.5-122b-a10b" "https://integrate.api.nvidia.com/v1" "$api_key")
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (NVIDIA NIM Qwen3.5-122B-A10B)…${RESET}"
            "$opencode_exe"
            ;;
        "openrouter-hy3")
            local api_key
            api_key=$(get_openrouter_api_key)
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}OpenRouter API ключ не задан.${RESET}"
                read -p "Нажмите Enter для продолжения..."
                return 0
            fi
            local config_path
            config_path=$(write_opencode_config "openrouter" "tencent/hy3-preview:free" "https://openrouter.ai/api/v1" "$api_key" 8192 262144)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (OpenRouter Tencent Hy3)…${RESET}"
            "$opencode_exe"
            ;;
        "openrouter-nemotron")
            local api_key
            api_key=$(get_openrouter_api_key)
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}OpenRouter API ключ не задан.${RESET}"
                read -p "Нажмите Enter для продолжения..."
                return 0
            fi
            local config_path
            config_path=$(write_opencode_config "openrouter" "nvidia/nemotron-3-super-120b-a12b:free" "https://openrouter.ai/api/v1" "$api_key" 8192 262144)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (OpenRouter Nemotron 3 Super)…${RESET}"
            "$opencode_exe"
            ;;
        "openrouter-laguna")
            local api_key
            api_key=$(get_openrouter_api_key)
            if [ -z "$api_key" ]; then
                echo -e "${YELLOW}OpenRouter API ключ не задан.${RESET}"
                read -p "Нажмите Enter для продолжения..."
                return 0
            fi
            local config_path
            config_path=$(write_opencode_config "openrouter" "poolside/laguna-m.1:free" "https://openrouter.ai/api/v1" "$api_key" 8192 131072)
            export OPENCODE_CONFIG="$config_path"
            echo -e "${CYAN}Запуск OpenCode (OpenRouter Poolside Laguna M.1)…${RESET}"
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
            api_key=$(get_zai_api_key) || true
            local config_path
            config_path=$(write_opencode_config "zai" "$model_id" "https://api.z.ai/api/coding/paas/v4" "$api_key")
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
            api_key=$(get_nim_api_key) || true
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
            config_path=$(write_opencode_config "groq" "$model_id" "https://api.groq.com/openai/v1" "$api_key" 8192 131072)
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
        "zai|Z.AI - Coding endpoint (список моделей по вашему ключу)"
        "zai-general|Z.AI - General endpoint (все модели, статический список)"
        "nim|NVIDIA NIM - полный каталог (GET /v1/models)"
        "groq|Groq - полный каталог моделей (paid, GET /v1/models)"
        "groq-free|Groq - статический список популярных моделей (paid)"
        "openrouter|OpenRouter - полный каталог моделей (GET /v1/models)"
        "openrouter-free|OpenRouter - только бесплатные модели (статический список)"
    )
    
    while true; do
        local prov_menu=()
        for item in "${prov_items[@]}"; do
            local label="${item##*|}"
            prov_menu+=("$label")
        done
        
        local prov_choice
        prov_choice="$(show_tui_framed_menu "$app_brand" "Другая модель" "Шаг 1 из 2 - выберите провайдера" "${prov_menu[@]}")"
        
        if [ "${prov_choice:-0}" -eq 0 ]; then
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
        elif [ "$prov_source" = "zai-general" ]; then
            show_tui_wait_frame "$app_brand" "Z.AI General (статический список)…"
            key=$(get_zai_api_key) || true
            ids=(
                "glm-4.7" "glm-4.7-flash" "glm-4.7-flashx"
                "glm-4.6" "glm-4.6v" "glm-4.6v-flashx" "glm-4.6v-flash"
                "glm-4.5" "glm-4.5-x" "glm-4.5-air" "glm-4.5-airx" "glm-4.5-flash" "glm-4.5v"
                "glm-4-32b-0414-128k"
                "glm-5" "glm-5-turbo" "glm-5.1" "glm-5v-turbo"
                "glm-ocr"
            )
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
            show_tui_wait_frame "$app_brand" "Groq (статический список, pay-per-token)…"
            ids=( "llama-3.3-70b-versatile" "llama-3.1-8b-instant" "meta-llama/llama-4-scout-17b-16e-instruct" "qwen/qwen3-32b" "openai/gpt-oss-120b" "deepseek-r1-distill-llama-70b" "deepseek-r1-distill-qwen-32b" )
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
        
        local model_choice
        model_choice="$(show_tui_framed_menu "$app_brand" "Другая модель" "Шаг 2 из 2 - моделей: ${#ids[@]}" "${model_menu[@]}")"
        
        if [ "${model_choice:-0}" -eq 0 ]; then
            continue
        fi
        
        local model_id="${ids[$((model_choice-1))]}"
        local prov="nim"
        if [ "$prov_source" = "zai" ] || [ "$prov_source" = "zai-general" ]; then
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

main() {
while true; do
    local state=$(get_launcher_state 2>/dev/null || true)
    local last_id=$(resolve_profile_from_state "$state" 2>/dev/null || true)
    
    # Подготовка списка пунктов меню
    local menu_items=()
    for profile in "${PROFILES[@]}"; do
        local label="${profile##*|}"
        menu_items+=("$label")
    done
    
    local choice
    choice="$(show_tui_framed_menu "OpenCode" "OpenCode - выбор провайдера" "Z.AI · NVIDIA NIM (OpenAI-compatible)" "${menu_items[@]}")"
    
    if [ "${choice:-0}" -eq 0 ]; then
        echo -e "${YELLOW}Отменено.${RESET}"
        exit 0
    fi
    
    local profile_id=$(echo "${PROFILES[$((choice-1))]}" | cut -d'|' -f1)
    
    case "$profile_id" in
        "native-login")
            local opencode_exe
            opencode_exe=$(resolve_opencode_exe) || true
            if [ -z "$opencode_exe" ]; then
                echo -e "${RED}OpenCode CLI не найден. Установите: npm install -g opencode-ai@latest${RESET}"
                echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                read
                continue
            fi
            local login_items=("providers-login|Вход через провайдера (opencode providers login)" "providers-list|Показать подключённых провайдеров" "vanilla|Запуск OpenCode (ванильный запуск)")
            local login_menu=()
            for item in "${login_items[@]}"; do
                login_menu+=("${item##*|}")
            done

            local login_choice
            login_choice="$(show_tui_framed_menu "OpenCode" "Нативный логин OpenCode" "Выберите действие" "${login_menu[@]}")"

            if [ "${login_choice:-0}" -eq 0 ]; then
                continue
            fi

            local login_id=$(echo "${login_items[$((login_choice-1))]}" | cut -d'|' -f1)

            case "$login_id" in
                "providers-login")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  OpenCode - вход через провайдера${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Выберите провайдера и следуйте инструкциям.${RESET}"
                    echo ""
                    echo -e "${CYAN}  Запуск...${RESET}"
                    "$opencode_exe" providers login
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "providers-list")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  OpenCode - подключённые провайдеры${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    "$opencode_exe" providers list
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "vanilla")
                    unset OPENCODE_CONFIG
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Запуск OpenCode (ванильный запуск)${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Команда: opencode${RESET}"
                    echo ""
                    "$opencode_exe"
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
            esac
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
}
main "$@"
