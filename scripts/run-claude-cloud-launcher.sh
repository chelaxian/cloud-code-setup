#!/bin/bash
# Меню Claude Code (облако) - Linux версия

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/claude-cloud-launcher-state.json"
SESSION_SCRIPT="$SCRIPT_DIR/run-claude-cloud-session.sh"

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
    "claude-openrouter-sonnet|OpenRouter - Claude Sonnet 4 (paid, tool calling)"
    "claude-openrouter-qwen-coder|OpenRouter - Qwen3 Coder (free, tool calling)"
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
        "claude-zai"|"claude-zai-glm51"|"claude-zai-flash47"|"claude-zai-flash45"|"claude-nim"|"claude-nim-qwen"|"claude-openrouter-sonnet"|"claude-openrouter-qwen-coder"|"claude-openrouter-hy3"|"claude-openrouter-nemotron"|"claude-openrouter-laguna"|"custom-claude-zai"|"custom-claude-nim"|"custom-claude-openrouter")
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

invoke_claude_cloud_profile() {
    local profile_id="$1"
    
    # Проверка API ключа
    local env_var=""
    local provider_name=""
    local provider_url=""
    case "$profile_id" in
        claude-zai*|custom-claude-zai*) env_var="ZAI"; provider_name="Z.AI"; provider_url="https://console.z.ai/" ;;
        claude-nim*|custom-claude-nim*) env_var="NVIDIA_NIM"; provider_name="NVIDIA NIM"; provider_url="https://build.nvidia.com/api-key" ;;
        claude-openrouter*|custom-claude-openrouter*) env_var="OPENROUTER"; provider_name="OpenRouter"; provider_url="https://openrouter.ai/settings/keys" ;;
    esac
    if [ -n "$env_var" ]; then
        if ! ensure_api_key_or_prompt "$env_var" "$provider_name" "$provider_url"; then
            return 1
        fi
    fi
    
    clear >&3
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
        "claude-zai-flash47")
            bash "$SESSION_SCRIPT" -Provider zai \
                -ZaiAnthropicModelId "glm-4.7-flash" \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        "claude-zai-flash45")
            bash "$SESSION_SCRIPT" -Provider zai \
                -ZaiAnthropicModelId "glm-4.5-flash" \
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
        "claude-openrouter-qwen-coder")
            bash "$SESSION_SCRIPT" -Provider openrouter \
                -ZaiAnthropicModelId "qwen/qwen3-coder:free" \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        "claude-openrouter-hy3")
            bash "$SESSION_SCRIPT" -Provider openrouter \
                -ZaiAnthropicModelId "tencent/hy3-preview:free" \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        "claude-openrouter-nemotron")
            bash "$SESSION_SCRIPT" -Provider openrouter \
                -ZaiAnthropicModelId "nvidia/nemotron-3-super-120b-a12b:free" \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        "claude-openrouter-laguna")
            bash "$SESSION_SCRIPT" -Provider openrouter \
                -ZaiAnthropicModelId "poolside/laguna-m.1:free" \
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
        "custom-claude-openrouter")
            local state=$(get_launcher_state)
            local model_id=$(echo "$state" | grep -o '"customModelId":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$model_id" ]; then
                echo -e "${RED}Нет customModelId для custom-claude-openrouter. Выберите модель в «Другая модель».${RESET}"
                return 1
            fi
            
            bash "$SESSION_SCRIPT" -Provider openrouter \
                -ZaiAnthropicModelId "$model_id" \
                -VaultPath "$VAULT_PATH" \
                -ObsidianExe "$OBSIDIAN_EXE" \
                -ClaudeTools default \
                -SkipCommonPreamble
            ;;
        *)
            echo -e "${RED}Неизвестный профиль: $profile_id${RESET}"
            return 1
            ;;
    esac
}

# ── API key helpers ──────────────────────────────────────────────────────────
get_claude_zai_api_key() {
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

get_claude_nim_api_key() {
    local key="${NVIDIA_NIM_API_KEY:-}"
    if [ -z "$key" ]; then
        echo -e "${YELLOW}NVIDIA NIM API ключ не задан.${RESET}"
        echo -e "${CYAN}Получить ключ: https://build.nvidia.com/api-key${RESET}"
    fi

    if [ -z "$key" ]; then
        read_secret_text "NVIDIA NIM API key: "
    else
        echo "$key"
    fi
}

get_claude_openrouter_api_key() {
    local key="${OPENROUTER_API_KEY:-}"
    if [ -z "$key" ]; then
        echo -e "${YELLOW}OpenRouter API ключ не задан.${RESET}"
        echo -e "${CYAN}Получить ключ: https://openrouter.ai/settings/keys${RESET}"
    fi

    if [ -z "$key" ]; then
        read_secret_text "OpenRouter API key: "
    else
        echo "$key"
    fi
}

# ── Мастер выбора модели ─────────────────────────────────────────────────────
invoke_claude_custom_model_wizard() {
    local app_brand="$1"

    local prov_items=(
        "zai|Z.AI - Coding / Anthropic (список моделей по вашему ключу)"
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
            ids=( "openrouter/free" "tencent/hy3-preview:free" "nvidia/nemotron-3-super:free" "inclusionai/ling-2.6-1t:free" "openai/gpt-oss-120b:free" "poolside/laguna-m.1:free" "openrouter/owl-alpha:free" "z-ai/glm-4.5-air:free" "minimax/minimax-m2.5:free" "openai/gpt-oss-20b:free" "meta-llama/llama-4-scout:free" "qwen/qwen3-coder:free" "deepseek/deepseek-r1:free" "google/gemma-4-31b:free" "meta-llama/llama-3.3-70b-instruct:free" "mistralai/mistral-small-3.1-24b-instruct:free" )
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
        if [ "$prov_source" = "zai" ]; then
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
            if [ "$wiz_provider" = "zai" ]; then
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
