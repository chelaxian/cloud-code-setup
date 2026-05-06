#!/bin/bash
# Динамический запуск Qwen Code с произвольным OpenAI-совместимым провайдером
# Usage: bash run-qwen-code-dynamic.sh -Provider <zai|nim|groq|openrouter> -ModelId <model-id>

set -euo pipefail

PROVIDER=""
MODEL_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Provider) PROVIDER="$2"; shift 2 ;;
    -ModelId) MODEL_ID="$2"; shift 2 ;;
    *) echo "Unknown param: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$PROVIDER" ] || [ -z "$MODEL_ID" ]; then
  echo "Usage: $0 -Provider <zai|nim|groq|openrouter> -ModelId <model-id>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Безопасное имя для директории ──
safe_dir_name() {
  echo "$1" | sed 's/[^a-zA-Z0-9._-]/_/g'
}

get_api_key_interactive() {
  local prompt="$1"
  echo -n "$prompt"
  read -s key
  echo
  echo "$key"
}

# ── Определяем API ключ и baseURL ──
API_KEY=""
BASE_URL=""
SESSION_DIR_NAME="$(safe_dir_name "$PROVIDER")-$(safe_dir_name "$MODEL_ID")"

case "$PROVIDER" in
  zai)
    API_KEY="${ZAI_API_KEY:-}"
    if [ -z "$API_KEY" ] || [ "$API_KEY" = "__SET_ME__" ]; then
      API_KEY="${OPENAI_API_KEY:-}"
    fi
    if [ -z "$API_KEY" ] || [ "$API_KEY" = "__SET_ME__" ]; then
      API_KEY=$(get_api_key_interactive "Z.AI API key: ")
    fi
    BASE_URL="https://api.z.ai/api/coding/paas/v4"
    ;;
  nim)
    API_KEY="${NVIDIA_NIM_API_KEY:-}"
    if [ -z "$API_KEY" ]; then
      API_KEY=$(get_api_key_interactive "NVIDIA NIM API key: ")
    fi
    BASE_URL="https://integrate.api.nvidia.com/v1"
    ;;
  groq)
    API_KEY="${GROQ_API_KEY:-}"
    if [ -z "$API_KEY" ]; then
      API_KEY=$(get_api_key_interactive "Groq API key: ")
    fi
    BASE_URL="https://api.groq.com/openai/v1"
    ;;
  openrouter)
    API_KEY="${OPENROUTER_API_KEY:-}"
    if [ -z "$API_KEY" ]; then
      API_KEY=$(get_api_key_interactive "OpenRouter API key: ")
    fi
    BASE_URL="https://openrouter.ai/api/v1"
    ;;
  *)
    echo "Unknown provider: $PROVIDER" >&2
    exit 1
    ;;
esac

if [ -z "$API_KEY" ]; then
  echo "API ключ не задан." >&2
  exit 1
fi

# ── Создаём сессионную директорию ──
SESSION_ROOT="$SCRIPT_DIR/../qwen-sessions/_shared"
QWEN_DIR="$SESSION_ROOT/.qwen"
mkdir -p "$QWEN_DIR"

# ── Генерируем settings.json ──
if [ "$PROVIDER" = "zai" ]; then
  cat > "$QWEN_DIR/settings.json" <<SETTINGS_EOF
{
  "modelProviders": {
    "openai": [
      {
        "id": "$MODEL_ID",
        "name": "Z.AI — $MODEL_ID (dynamic)",
        "envKey": "OPENAI_API_KEY",
        "baseUrl": "https://api.z.ai/api/coding/paas/v4",
        "generationConfig": {
          "timeout": 600000,
          "maxRetries": 4,
          "contextWindowSize": 202752,
          "extra_body": {
            "enable_thinking": true,
            "chat_template_kwargs": {
              "enable_thinking": true,
              "clear_thinking": false
            }
          },
          "samplingParams": {
            "temperature": 0.6,
            "top_p": 0.95,
            "max_tokens": 81920
          }
        }
      }
    ]
  },
  "security": { "auth": { "selectedType": "openai" } },
  "model": { "name": "$MODEL_ID" }
}
SETTINGS_EOF
else
  CONTEXT_SIZE=131072
  MAX_TOKENS=81920
  SKIP_STARTUP=""
  # Groq free tier: очень низкий TPM (6-12K). Урезаем контекст.
  if [ "$PROVIDER" = "groq" ]; then
    CONTEXT_SIZE=4096
    MAX_TOKENS=2048
    SKIP_STARTUP=',"skipStartupContext":true'
  elif [ "$PROVIDER" = "openrouter" ]; then
    CONTEXT_SIZE=16384
    MAX_TOKENS=8192
    SKIP_STARTUP=',"skipStartupContext":true'
  fi
  cat > "$QWEN_DIR/settings.json" <<SETTINGS_EOF
{
  "modelProviders": {
    "openai": [
      {
        "id": "$MODEL_ID",
        "name": "$PROVIDER — $MODEL_ID (dynamic)",
        "envKey": "OPENAI_API_KEY",
        "baseUrl": "$BASE_URL",
        "generationConfig": {
          "timeout": 600000,
          "maxRetries": 4,
          "contextWindowSize": $CONTEXT_SIZE,
          "samplingParams": {
            "temperature": 0.6,
            "top_p": 0.95,
            "max_tokens": $MAX_TOKENS
          }
        }
      }
    ]
  },
  "security": { "auth": { "selectedType": "openai" } },
  "model": { "name": "$MODEL_ID"$SKIP_STARTUP }
}
SETTINGS_EOF
fi

# ── Экспортируем ключ и лимиты ──
export OPENAI_API_KEY="$API_KEY"
export API_TIMEOUT_MS="600000"
if [ "$PROVIDER" = "groq" ]; then
  export QWEN_CODE_MAX_OUTPUT_TOKENS="2048"
  export QWEN_CODE_EMIT_TOOL_USE_SUMMARIES="0"
elif [ "$PROVIDER" = "openrouter" ]; then
  export QWEN_CODE_MAX_OUTPUT_TOKENS="8192"
  export QWEN_CODE_EMIT_TOOL_USE_SUMMARIES="0"
else
  export QWEN_CODE_MAX_OUTPUT_TOKENS="81920"
  export QWEN_CODE_EMIT_TOOL_USE_SUMMARIES="1"
fi

# ── Находим qwen-code ──
QWEN_EXE=""
if command -v qwen-code &>/dev/null; then
  QWEN_EXE="$(command -v qwen-code)"
elif command -v qwen &>/dev/null; then
  QWEN_EXE="$(command -v qwen)"
elif [ -f "$HOME/.npm-global/bin/qwen-code" ]; then
  QWEN_EXE="$HOME/.npm-global/bin/qwen-code"
elif [ -f "$HOME/.local/bin/qwen-code" ]; then
  QWEN_EXE="$HOME/.local/bin/qwen-code"
fi

if [ -z "$QWEN_EXE" ]; then
  echo "Qwen Code CLI не найден. Установите: npm install -g @qwen-code/qwen-code@latest" >&2
  exit 1
fi

echo -e "\033[36mQwen Code: $PROVIDER / модель $MODEL_ID → $SESSION_ROOT\033[0m"
cd "$SESSION_ROOT"
if [ "$PROVIDER" = "groq" ]; then
  echo ""
  echo -e "\033[33m╔══════════════════════════════════════════════════════════════════╗\033[0m"
  echo -e "\033[33m║  Groq free tier: TPM лимит 6K-12K слишком мал для agent mode.  ║\033[0m"
  echo -e "\033[33m║  Запуск в режиме чата (без инструментов/agent).                 ║\033[0m"
  echo -e "\033[33m║  Для полного agent mode используйте Z.AI / NIM / OpenRouter.    ║\033[0m"
  echo -e "\033[33m╚══════════════════════════════════════════════════════════════════╝\033[0m"
  echo ""
  exec "$QWEN_EXE" --bare -m "$MODEL_ID" --openai-api-key "$OPENAI_API_KEY" --openai-base-url "https://api.groq.com/openai/v1" --system-prompt "You are a helpful coding assistant. Answer questions about code. No tools available - just chat." --auth-type openai
else
  exec "$QWEN_EXE"
fi
