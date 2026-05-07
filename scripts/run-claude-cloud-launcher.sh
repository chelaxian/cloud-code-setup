#!/bin/bash
# Меню Claude Code (облако) - Linux версия

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/claude-cloud-launcher-state.json"
SESSION_DIR="$SCRIPT_DIR/../claude-sessions/_shared"

# Единое пространство для /resume (как у Qwen): общий каталог для запуска claude
CLAUDE_SESSION_ROOT="${CLAUDE_SESSION_ROOT:-$SCRIPT_DIR/../claude-sessions/_shared}"

# Настройки (можно изменить под свои пути)
VAULT_PATH="${CLAUDE_VAULT_PATH:-$HOME/Documents/Obsidian\ Vault}"
OBSIDIAN_EXE="${OBSIDIAN_EXE:-/usr/bin/obsidian}"

# Загрузка модулей
. "$SCRIPT_DIR/launcher-tui.sh"
. "$SCRIPT_DIR/launcher-api-keys.sh"

enter_claude_shared_dir() {
    mkdir -p "$CLAUDE_SESSION_ROOT"
    cd "$CLAUDE_SESSION_ROOT"
}

PROFILES=(
    "last|Запустить с последними настройками (быстрый старт)"
    "claude-zai|Z.AI - GLM-4.7 (paid, tool calling)"
    "claude-zai-glm51|Z.AI - GLM-5.1 (paid, tool calling)"
    "claude-zai-flash47|Z.AI - GLM-4.7-Flash (free, tool calling)"
    "claude-zai-flash45|Z.AI - GLM-4.5-Flash (free, tool calling)"
    "claude-nim|NVIDIA NIM - GLM-4.7 (free, tool calling)"
    "claude-nim-qwen|NVIDIA NIM - Qwen3.5-122B-A10B (free, tool calling)"
    "claude-openrouter-hy3|OpenRouter - Tencent Hy3 (free, tool calling)"
    "claude-openrouter-nemotron|OpenRouter - Nemotron 3 Super 120B (free, tool calling)"
    "claude-openrouter-laguna|OpenRouter - Poolside Laguna M.1 (free, tool calling, coding)"
    "custom-model|Другая модель… → выбор провайдера и модели"
    "native-login|Нативный логин (Anthropic OAuth / Console)"
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
        "claude-zai"|"claude-zai-glm51"|"claude-zai-flash47"|"claude-zai-flash45"|"claude-nim"|"claude-nim-qwen"|"claude-openrouter-hy3"|"claude-openrouter-nemotron"|"claude-openrouter-laguna"|"custom-claude-zai"|"custom-claude-zai-general"|"custom-claude-nim"|"custom-claude-openrouter")
            echo "$profile_id"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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

# ── free-claude-code proxy for NIM/OpenRouter ──────────────────────────────────
FCC_DIR="$HOME/.free-claude-code"

ensure_fcc_proxy() {
    local provider="$1"
    local model="$2"
    local port="${3:-8082}"

    # Check if proxy already running on this port AND responding to HTTP
    if (ss -tlnp 2>/dev/null | grep -q ":${port} " || nc -z 127.0.0.1 "$port" 2>/dev/null); then
        local existing_code
        existing_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${port}/v1/models" 2>/dev/null) || true
        if [ -n "$existing_code" ] && [ "$existing_code" != "000" ]; then
            printf "${GREEN}  [OK] Proxy уже работает на порту ${port} (HTTP ${existing_code})${RESET}\n" >&3
            echo "$port"
            return 0
        fi
        # Port is open but not HTTP — kill whatever is on it and restart
        printf "${YELLOW}Порт ${port} занят, но не отвечает на HTTP. Перезапуск...${RESET}\n" >&3
        fuser -k "${port}/tcp" 2>/dev/null || true
        sleep 1
    fi

    # Install uv if missing
    if ! command -v uv &>/dev/null; then
        printf "${CYAN}Установка uv (Python package manager)...${RESET}\n" >&3
        curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || {
            printf "${RED}Не удалось установить uv.${RESET}\n" >&3
            return 1
        }
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # Clone free-claude-code if missing
    if [ ! -d "$FCC_DIR" ]; then
        printf "${CYAN}Клонирование free-claude-code...${RESET}\n" >&3
        git clone https://github.com/Alishahryar1/free-claude-code.git "$FCC_DIR" 2>/dev/null || {
            printf "${RED}Не удалось клонировать free-claude-code.${RESET}\n" >&3
            return 1
        }
    fi

    # Update repo
    (cd "$FCC_DIR" && git pull origin main 2>/dev/null) || true

    # Write .env
    local nim_key="${NVIDIA_NIM_API_KEY:-}"
    local or_key="${OPENROUTER_API_KEY:-}"
    local env_file="$FCC_DIR/.env"
    cat > "$env_file" << ENVEOF
NVIDIA_NIM_API_KEY="${nim_key}"
OPENROUTER_API_KEY="${or_key}"
MODEL="${model}"
ANTHROPIC_AUTH_TOKEN="freecc"
ENABLE_MODEL_THINKING=true
PROVIDER_RATE_LIMIT=1
PROVIDER_RATE_WINDOW=3
PROVIDER_MAX_CONCURRENCY=5
HTTP_READ_TIMEOUT=300
MESSAGING_PLATFORM="none"
ENABLE_WEB_SERVER_TOOLS=false
ENVEOF

    # Warm deps once (prevents long first-run hang) — timeout-safe
    timeout 30 sh -c 'cd "$1" && uv sync &>/dev/null' _ "$FCC_DIR" 2>/dev/null || true

    # Start proxy in background (log to file for debugging)
    local log_file="$FCC_DIR/fcc-${port}.log"
    printf "${CYAN}Запуск free-claude-code proxy на порту ${port}...${RESET}\n" >&3
    printf "${GRAY}Логи: ${log_file}${RESET}\n" >&3

    # Use nohup + disown so the process survives shell exits
    # </dev/null: fully detach stdin so parent shell never blocks on pipe
    nohup sh -c "cd '$FCC_DIR' && uv run uvicorn server:app --host 127.0.0.1 --port '$port' --log-level warning" </dev/null >>"$log_file" 2>&1 &
    local proxy_pid=$!
    disown "$proxy_pid" 2>/dev/null || true

    # Brief pause for process to begin initializing
    sleep 0.5

    # Wait for proxy TCP port to become available (show progress)
    local tries=0
    printf "${GRAY}  Ожидание TCP" >&3
    while [ $tries -lt 30 ]; do
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            printf " ✓${RESET}\n" >&3
            break
        fi
        printf "." >&3
        sleep 1
        tries=$((tries + 1))
    done

    if [ $tries -ge 30 ]; then
        printf "${RED}Proxy не запустился за 30 сек (TCP порт не открыт).${RESET}\n" >&3
        printf "${YELLOW}Последние строки лога:${RESET}\n" >&3
        tail -20 "$log_file" >&3 2>/dev/null || true
        return 1
    fi

    # Verify HTTP is actually responding (not just port open)
    local http_tries=0
    while [ $http_tries -lt 15 ]; do
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${port}/v1/models" 2>/dev/null) || true
        if [ -n "$http_code" ] && [ "$http_code" != "000" ]; then
            printf "${GREEN}  [OK] Proxy запущен на порту ${port} (HTTP ${http_code})${RESET}\n" >&3
            echo "$port"
            return 0
        fi
        sleep 1
        http_tries=$((http_tries + 1))
    done

    printf "${RED}Proxy TCP порт открыт, но HTTP не отвечает за 15 сек.${RESET}\n" >&3
    printf "${YELLOW}Последние строки лога:${RESET}\n" >&3
    tail -20 "$log_file" >&3 2>/dev/null || true
    return 1
}

invoke_claude_cloud_profile() {
    local profile_id="$1"
    
    # Проверка API ключа
    local env_var=""
    local provider_name=""
    local provider_url=""
    case "$profile_id" in
        claude-zai*|custom-claude-zai*) env_var="ZAI"; provider_name="Z.AI"; provider_url="https://console.z.ai/" ;;
        "custom-claude-zai-general") env_var="ZAI"; provider_name="Z.AI General"; provider_url="https://console.z.ai/" ;;
        claude-nim*|custom-claude-nim*) env_var="NVIDIA_NIM"; provider_name="NVIDIA NIM"; provider_url="https://build.nvidia.com/api-key" ;;
        claude-openrouter*|custom-claude-openrouter*) env_var="OPENROUTER"; provider_name="OpenRouter"; provider_url="https://openrouter.ai/settings/keys" ;;
    esac
    if [ -n "$env_var" ]; then
        if ! ensure_api_key_or_prompt "$env_var" "$provider_name" "$provider_url"; then
            return 1
        fi
    fi
    
    # Находим claude CLI
    local claude_exe=""
    if command -v claude &>/dev/null; then
        claude_exe="$(command -v claude)"
    fi
    if [ -z "$claude_exe" ]; then
        printf "${RED}Claude Code CLI не найден. Установите: npm install -g @anthropic-ai/claude-code@latest${RESET}\n" >&3
        return 1
    fi
    
    # Определяем модель для Z.AI (NIM/OpenRouter используют proxy — модель задаётся ниже)
    local model=""
    case "$profile_id" in
        "claude-zai") model="glm-4.7" ;;
        "claude-zai-glm51") model="glm-5.1" ;;
        "claude-zai-flash47") model="glm-4.7-flash" ;;
        "claude-zai-flash45") model="glm-4.5-flash" ;;
        custom-claude-zai|"custom-claude-zai-general")
            local state=$(get_launcher_state)
            model=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            if [ -z "$model" ]; then
                printf "${RED}Нет customModelId. Выберите модель в «Другая модель».${RESET}\n" >&3
                return 1
            fi
            ;;
        claude-nim*|claude-openrouter*|custom-claude-nim|custom-claude-openrouter)
            # Model determined in env-vars block below (via proxy)
            ;;
        *) model="" ;;
    esac
    
    # Устанавливаем env vars для Claude Code
    case "$profile_id" in
        claude-zai*|custom-claude-zai*|custom-claude-zai-general)
            local key="${ZAI_API_KEY:-}"
            if [ -z "$key" ] || [ "$key" = "__SET_ME__" ]; then key="${OPENAI_API_KEY:-}"; fi
            export ANTHROPIC_AUTH_TOKEN="$key"
            export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="$model"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="$model"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model"
            export API_TIMEOUT_MS="3000000"
            ;;
        claude-nim*|custom-claude-nim*)
            local fcc_model="nvidia_nim/z-ai/glm4.7"
            case "$profile_id" in
                "claude-nim-qwen") fcc_model="nvidia_nim/qwen/qwen3.5-122b-a10b" ;;
                "custom-claude-nim")
                    local st=$(get_launcher_state)
                    local cm=$(echo "$st" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
                    if [ -n "$cm" ]; then fcc_model="nvidia_nim/$cm"; fi
                    ;;
            esac
            local proxy_port
            proxy_port=$(ensure_fcc_proxy "nvidia_nim" "$fcc_model" "8082") || {
                printf "${RED}Не удалось запустить free-claude-code proxy.${RESET}\n" >&3
                return 1
            }
            # Final HTTP sanity check before launching Claude Code
            local precheck_code
            precheck_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${proxy_port}/v1/models" 2>/dev/null) || true
            if [ -z "$precheck_code" ] || [ "$precheck_code" = "000" ]; then
                printf "${RED}Proxy на порту ${proxy_port} не отвечает на HTTP-запросы.${RESET}\n" >&3
                printf "${YELLOW}Логи: $FCC_DIR/fcc-${proxy_port}.log${RESET}\n" >&3
                return 1
            fi
            export ANTHROPIC_AUTH_TOKEN="freecc"
            export ANTHROPIC_BASE_URL="http://127.0.0.1:${proxy_port}"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="$fcc_model"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="$fcc_model"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="$fcc_model"
            export API_TIMEOUT_MS="3000000"
            ;;
        claude-openrouter*|custom-claude-openrouter*)
            # Keep main menu to 3 working free models; custom still supported.
            local fcc_model="open_router/tencent/hy3-preview:free"
            case "$profile_id" in
                "claude-openrouter-hy3") fcc_model="open_router/tencent/hy3-preview:free" ;;
                "claude-openrouter-nemotron") fcc_model="open_router/nvidia/nemotron-3-super-120b-a12b:free" ;;
                "claude-openrouter-laguna") fcc_model="open_router/poolside/laguna-m.1:free" ;;
                "custom-claude-openrouter")
                    local st=$(get_launcher_state)
                    local cm=$(echo "$st" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
                    if [ -n "$cm" ]; then fcc_model="open_router/$cm"; fi
                    ;;
            esac
            local proxy_port
            proxy_port=$(ensure_fcc_proxy "open_router" "$fcc_model" "8084") || {
                printf "${RED}Не удалось запустить free-claude-code proxy.${RESET}\n" >&3
                return 1
            }
            # Final HTTP sanity check before launching Claude Code
            local precheck_code
            precheck_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${proxy_port}/v1/models" 2>/dev/null) || true
            if [ -z "$precheck_code" ] || [ "$precheck_code" = "000" ]; then
                printf "${RED}Proxy на порту ${proxy_port} не отвечает на HTTP-запросы.${RESET}\n" >&3
                printf "${YELLOW}Логи: $FCC_DIR/fcc-${proxy_port}.log${RESET}\n" >&3
                return 1
            fi
            export ANTHROPIC_AUTH_TOKEN="freecc"
            export ANTHROPIC_BASE_URL="http://127.0.0.1:${proxy_port}"
            export ANTHROPIC_DEFAULT_OPUS_MODEL="$fcc_model"
            export ANTHROPIC_DEFAULT_SONNET_MODEL="$fcc_model"
            export ANTHROPIC_DEFAULT_HAIKU_MODEL="$fcc_model"
            export API_TIMEOUT_MS="3000000"
            ;;
    esac
    
    # Отключаем лишний трафик Claude Code
    mkdir -p "$HOME/.claude"
    local settings_file="$HOME/.claude/settings.json"
    if [ -f "$settings_file" ]; then
        # Обновляем существующий settings
        if command -v python3 &>/dev/null; then
            python3 -c "
import json, sys
try:
    with open('$settings_file','r') as f: d=json.load(f)
except: d={}
if 'env' not in d: d['env']={}
d['env']['CLAUDE_CODE_ATTRIBUTION_HEADER']='0'
d['env']['CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC']='1'
with open('$settings_file','w') as f: json.dump(d,f,indent=2)
" 2>/dev/null || true
        fi
    else
        echo '{"env":{"CLAUDE_CODE_ATTRIBUTION_HEADER":"0","CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC":"1"}}' > "$settings_file"
    fi
    
    # Входим в shared session dir и запускаем claude
    enter_claude_shared_dir
    
    clear >&3
    printf "${CYAN}Запуск Claude Code…${RESET}\n" >&3
    printf "${GRAY}Провайдер: $profile_id   Модель: ${model:-default}${RESET}\n" >&3
    printf "${GRAY}Директория сессий: $(pwd)${RESET}\n" >&3
    printf "\n" >&3
    
    # exec: replace shell with claude so no parent waits / hangs
    exec "$claude_exe"
}

# ── API key helpers ──────────────────────────────────────────────────────────
get_claude_zai_api_key() {
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
        else
            return 1
        fi
    else
        echo "$key"
    fi
}

get_claude_nim_api_key() {
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
        else
            return 1
        fi
    else
        echo "$key"
    fi
}

get_claude_openrouter_api_key() {
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
        else
            return 1
        fi
    else
        echo "$key"
    fi
}

# ── Мастер выбора модели ─────────────────────────────────────────────────────
invoke_claude_custom_model_wizard() {
    local app_brand="$1"

    local prov_items=(
        "zai|Z.AI - Coding endpoint (список моделей по вашему ключу)"
        "zai-general|Z.AI - General endpoint (все модели, статический список)"
        "nim|NVIDIA NIM - полный каталог (GET /v1/models)"
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
            show_tui_wait_frame "$app_brand" "Загрузка каталога моделей Z.AI…"
            key=$(get_claude_zai_api_key) || true

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
            key=$(get_claude_zai_api_key) || true
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
            key=$(get_claude_nim_api_key) || true

            local response
            response=$(curl -s -H "Authorization: Bearer $key" "https://integrate.api.nvidia.com/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "openrouter" ]; then
            show_tui_wait_frame "$app_brand" "Загрузка каталога OpenRouter…"
            key=$(get_claude_openrouter_api_key) || true

            local response
            response=$(curl -s -H "Authorization: Bearer $key" -H "Content-Type: application/json" "https://openrouter.ai/api/v1/models" 2>/dev/null) || true

            if [ -n "$response" ]; then
                ids=($(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort -u))
            fi
        elif [ "$prov_source" = "openrouter-free" ]; then
            ids=( "openrouter/free" "tencent/hy3-preview:free" "nvidia/nemotron-3-super:free" "inclusionai/ling-2.6-1t:free" "openai/gpt-oss-120b:free" "poolside/laguna-m.1:free" "openrouter/owl-alpha:free" "z-ai/glm-4.5-air:free" "minimax/minimax-m2.5:free" "openai/gpt-oss-20b:free" "meta-llama/llama-4-scout:free" "qwen/qwen3-235b-a22b:free" "google/gemma-4-31b:free" "meta-llama/llama-3.3-70b-instruct:free" "mistralai/mistral-small-3.1-24b-instruct:free" )
            key=$(get_claude_openrouter_api_key) || true
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
        elif [ "$prov_source" = "openrouter" ] || [ "$prov_source" = "openrouter-free" ]; then
            prov="openrouter"
        fi

        echo "$prov|$model_id"
        return 0
    done
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
# Главное меню
main() {
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
    
    local choice
    choice="$(show_tui_framed_menu "Claude" "Claude Code (облако) - провайдер" "Z.AI Anthropic · NVIDIA NIM через free-claude-code" "${menu_items[@]}")"
    
    if [ "${choice:-0}" -eq 0 ]; then
        echo -e "${YELLOW}Отменено.${RESET}"
        exit 0
    fi
    
    local profile_id=$(echo "${PROFILES[$((choice-1))]}" | cut -d'|' -f1)
    
    case "$profile_id" in
        "native-login")
            if ! command -v claude &>/dev/null; then
                echo -e "${RED}Claude Code CLI не найден (claude). Установите: npm install -g @anthropic-ai/claude-code@latest${RESET}"
                echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                read
                continue
            fi
            local login_items=("claude-sub|Claude подписка (OAuth, браузер)" "anthropic-console|Anthropic Console (API-биллинг, браузер)" "vanilla|Запуск Claude Code (ванильный запуск)")
            local login_menu=()
            for item in "${login_items[@]}"; do
                login_menu+=("${item##*|}")
            done

            local login_choice
            login_choice="$(show_tui_framed_menu "Claude" "Нативный логин Claude Code" "Anthropic авторизация" "${login_menu[@]}")"

            if [ "${login_choice:-0}" -eq 0 ]; then
                continue
            fi

            local login_id=$(echo "${login_items[$((login_choice-1))]}" | cut -d'|' -f1)

            case "$login_id" in
                "claude-sub")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Claude OAuth - авторизация через браузер${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Откроется браузер. Завершите авторизацию в нём.${RESET}"
                    echo -e "${YELLOW}  Нужна подписка Claude Pro / Max (claude.ai).${RESET}"
                    echo ""
                    echo -e "${CYAN}  Запуск...${RESET}"
                    enter_claude_shared_dir
                    claude auth login --claudeai
                    echo ""
                    echo -e "${GREEN}  Текущий статус:${RESET}"
                    claude auth status
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "anthropic-console")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Anthropic Console - авторизация через браузер${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Откроется браузер. Завершите авторизацию.${RESET}"
                    echo -e "${YELLOW}  Нужен аккаунт на console.anthropic.com.${RESET}"
                    echo ""
                    echo -e "${CYAN}  Запуск...${RESET}"
                    enter_claude_shared_dir
                    claude auth login --console
                    echo ""
                    echo -e "${GREEN}  Текущий статус:${RESET}"
                    claude auth status
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
                "vanilla")
                    clear
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo -e "${CYAN}  Запуск Claude Code (ванильный запуск)${RESET}"
                    echo -e "${CYAN}═══════════════════════════════════════════════════${RESET}"
                    echo ""
                    echo -e "${YELLOW}  Команда: claude${RESET}"
                    echo ""
                    enter_claude_shared_dir
                    claude
                    echo ""
                    echo -e "${GREEN}Нажмите Enter для возврата в меню…${RESET}"
                    read
                    ;;
            esac
            continue
            ;;
        "change-api-key")
            show_api_key_change_menu "Claude"
            continue
            ;;
        "custom-model")
            wizard_result=$(invoke_claude_custom_model_wizard "Claude") || {
                echo -e "${YELLOW}Отменено.${RESET}"
                continue
            }
            local wiz_provider=$(echo "$wizard_result" | cut -d'|' -f1)
            local wiz_model=$(echo "$wizard_result" | cut -d'|' -f2)
            
            local new_id="custom-claude-nim"
            local extra="\"customNimModel\":\"$wiz_model\""
            if [ "$wiz_provider" = "zai" ] || [ "$wiz_provider" = "zai-general" ]; then
                new_id="custom-claude-zai"
                extra="\"customModelId\":\"$wiz_model\""
            elif [ "$wiz_provider" = "openrouter" ]; then
                new_id="custom-claude-openrouter"
                extra="\"customModelId\":\"$wiz_model\""
            fi
            
            save_launcher_state "$new_id" "$extra"
            invoke_claude_cloud_profile "$new_id"
            exit $?
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
}
main "$@"
