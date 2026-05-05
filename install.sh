#!/bin/bash
# cloud-code-setup — Linux/macOS инсталлятор
# Запуск: curl -fsSL https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.sh | bash
# Или: git clone + ./install.sh

set -e

REPO_URL="${REPO_URL:-https://github.com/chelaxian/cloud-code-setup.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/cloud-code-setup}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
RESET='\033[0m'

step()   { echo -e "\n${CYAN}══════════════════════════════════════════════════════════════════${RESET}"; echo -e "${MAGENTA}$1${RESET}"; echo -e "${CYAN}══════════════════════════════════════════════════════════════════${RESET}\n"; }
ok()     { echo -e "${GREEN}  [OK]   $1${RESET}"; }
skip()   { echo -e "${YELLOW}  [SKIP] $1${RESET}"; }
warn()   { echo -e "${YELLOW}  [WARN] $1${RESET}"; }
err()    { echo -e "${RED}  [ERR]  $1${RESET}" >&2; }

# ─── Заголовок ───────────────────────────────────────────────────────────────

clear
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  ██████╗ ██╗    ██╗███████╗███╗   ██╗           +   CLAUDE CODE             ${RESET}"
echo -e "${CYAN} ██╔═══██╗██║    ██║██╔════╝████╗  ██║                                     ${RESET}"
echo -e "${CYAN} ██║   ██║██║ █╗ ██║█████╗  ██╔██╗ ██║            CLOUD SETUP              ${RESET}"
echo -e "${CYAN} ██║▄▄ ██║██║███╗██║██╔══╝  ██║╚██╗██║                                     ${RESET}"
echo -e "${CYAN} ╚██████╔╝╚███╔███╔╝███████╗██║ ╚████║           1-click install           ${RESET}"
echo -e "${CYAN}  ╚══▀▀═╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═══╝                                     ${RESET}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
echo ""

# ─── Проверка зависимостей ───────────────────────────────────────────────────

step "ПРОВЕРКА ЗАВИСИМОСТЕЙ"

missing=()

if ! command -v git >/dev/null 2>&1; then
    missing+=("git")
fi
if ! command -v node >/dev/null 2>&1; then
    missing+=("node (Node.js LTS — https://nodejs.org/)")
fi
if ! command -v npm >/dev/null 2>&1; then
    missing+=("npm (ставится вместе с Node.js)")
fi

if [ ${#missing[@]} -gt 0 ]; then
    err "Отсутствуют необходимые инструменты:"
    for m in "${missing[@]}"; do
        echo -e "${YELLOW}  - $m${RESET}"
    done
    echo ""
    echo -e "${YELLOW}Установите их и запустите инсталлятор заново.${RESET}"
    echo ""
    echo "  Ubuntu/Debian: sudo apt install git nodejs npm"
    echo "  Fedora:        sudo dnf install git nodejs npm"
    echo "  Arch:          sudo pacman -S git nodejs npm"
    echo ""
    read -p "Нажмите Enter для выхода…"
    exit 1
fi

ok "git: $(git --version 2>&1 | head -1)"
ok "node: $(node --version 2>&1)"
ok "npm: $(npm --version 2>&1)"

# ─── Клонирование ────────────────────────────────────────────────────────────

step "КЛОНИРОВАНИЕ РЕПОЗИТОРИЯ"

if [ -d "$INSTALL_DIR/.git" ]; then
    warn "Репозиторий уже клонирован: $INSTALL_DIR"
    echo -e "${CYAN}Обновление (git pull)…${RESET}"
    (cd "$INSTALL_DIR" && git pull origin main 2>/dev/null) || warn "Не удалось обновить"
    ok "Репозиторий обновлён"
else
    echo -e "${CYAN}Клонирование $REPO_URL → $INSTALL_DIR…${RESET}"
    git clone "$REPO_URL" "$INSTALL_DIR" 2>&1 || {
        err "Ошибка клонирования. Проверьте доступ к $REPO_URL"
        exit 1
    }
    ok "Репозиторий клонирован: $INSTALL_DIR"
fi

# ─── Выбор инструментов ──────────────────────────────────────────────────────

step "ЧТО УСТАНОВИТЬ?"

echo -e "  ${GREEN}[1]${RESET} Qwen Code (cloud)"
echo -e "  ${GREEN}[2]${RESET} Claude Code (cloud)"
echo -e "  ${GREEN}[3]${RESET} OpenCode (cloud)"
echo -e "  ${GREEN}[4]${RESET} Все три"
echo -e "  ${GRAY}[0]${RESET} Выход"
echo ""

read -p "Ваш выбор [4]: " install_choice
install_choice="${install_choice:-4}"

INSTALL_QWEN=false
INSTALL_CLAUDE=false
INSTALL_OPENCODE=false

case "$install_choice" in
    1) INSTALL_QWEN=true ;;
    2) INSTALL_CLAUDE=true ;;
    3) INSTALL_OPENCODE=true ;;
    4) INSTALL_QWEN=true; INSTALL_CLAUDE=true; INSTALL_OPENCODE=true ;;
    0) echo -e "${YELLOW}Выход.${RESET}"; exit 0 ;;
    *) warn "Неверный выбор. Устанавливаем все три."; INSTALL_QWEN=true; INSTALL_CLAUDE=true; INSTALL_OPENCODE=true ;;
esac

# ─── Установка CLI ───────────────────────────────────────────────────────────

step "УСТАНОВКА CLI"

if $INSTALL_QWEN; then
    if command -v qwen >/dev/null 2>&1; then
        ok "Qwen Code CLI: $(which qwen)"
    else
        echo -e "${CYAN}Установка Qwen Code CLI…${RESET}"
        if npm install -g @qwen-code/qwen-code@latest 2>/dev/null; then
            ok "Qwen Code CLI установлен: $(which qwen 2>/dev/null)"
        else
            warn "Не удалось установить Qwen Code CLI. Установите вручную: npm i -g @qwen-code/qwen-code"
        fi
    fi
fi

if $INSTALL_CLAUDE; then
    if command -v claude >/dev/null 2>&1; then
        ok "Claude Code CLI: $(which claude)"
    else
        echo -e "${CYAN}Установка Claude Code CLI…${RESET}"
        if npm install -g @anthropic-ai/claude-code@latest 2>/dev/null; then
            ok "Claude Code CLI установлен: $(which claude 2>/dev/null)"
        else
            warn "Не удалось установить Claude Code CLI. Установите вручную: npm i -g @anthropic-ai/claude-code"
        fi
    fi
fi

if $INSTALL_OPENCODE; then
    if command -v opencode >/dev/null 2>&1; then
        ok "OpenCode CLI: $(which opencode)"
    else
        echo -e "${CYAN}Установка OpenCode CLI…${RESET}"
        if npm install -g opencode-ai@latest 2>/dev/null; then
            ok "OpenCode CLI установлен: $(which opencode 2>/dev/null)"
        else
            warn "Не удалось установить OpenCode CLI. Установите вручную: npm i -g opencode-ai@latest"
        fi
    fi
fi

# ─── API ключи ───────────────────────────────────────────────────────────────

step "НАСТРОЙКА API КЛЮЧЕЙ"

echo -e "${YELLOW}Оставьте пустым, чтобы пропустить. Ключи можно изменить позже через меню лаунчера.${RESET}"
echo ""

read -s -p "NVIDIA NIM API ключ (Enter = пропуск): " nim_key
echo ""
if [ -n "$nim_key" ]; then
    # Записываем в ~/.bashrc и ~/.zshrc
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            sed -i '/^export NVIDIA_NIM_API_KEY=/d' "$rc"
            echo "export NVIDIA_NIM_API_KEY=\"$nim_key\"" >> "$rc"
        fi
    done
    export NVIDIA_NIM_API_KEY="$nim_key"
    ok "NVIDIA_NIM_API_KEY сохранён"
else
    skip "NVIDIA_NIM_API_KEY пропущен"
fi

echo ""

read -s -p "Z.AI API ключ (Enter = пропуск): " zai_key
echo ""
if [ -n "$zai_key" ]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            sed -i '/^export ZAI_API_KEY=/d' "$rc"
            echo "export ZAI_API_KEY=\"$zai_key\"" >> "$rc"
        fi
    done
    export ZAI_API_KEY="$zai_key"
    ok "ZAI_API_KEY сохранён"
else
    skip "ZAI_API_KEY пропущен"
fi

# ─── Настройка сессий Qwen ──────────────────────────────────────────────────

if $INSTALL_QWEN; then
    step "НАСТРОЙКА СЕССИЙ QWEN CODE"

    SESSIONS_DIR="$INSTALL_DIR/qwen-sessions"
    mkdir -p "$SESSIONS_DIR"

    # Z.AI GLM-4.7
    mkdir -p "$SESSIONS_DIR/zai-glm47/.qwen"
    ZAI_SETTINGS="$SESSIONS_DIR/zai-glm47/.qwen/settings.json"
    if [ ! -f "$ZAI_SETTINGS" ]; then
        cat > "$ZAI_SETTINGS" << 'SETTINGSJSON'
{
  "modelProviders": {
    "openai": [
      {
        "id": "zai-glm-47",
        "name": "Z.AI GLM-4.7",
        "baseUrl": "https://api.z.ai/api/openai/v1",
        "envKey": "ZAI_API_KEY"
      }
    ]
  }
}
SETTINGSJSON
        ok "zai-glm47/.qwen/settings.json"
    else
        skip "zai-glm47/.qwen/settings.json уже существует"
    fi

    # NIM GLM-4.7
    mkdir -p "$SESSIONS_DIR/nim-glm-47/.qwen"
    NIM_SETTINGS="$SESSIONS_DIR/nim-glm-47/.qwen/settings.json"
    if [ ! -f "$NIM_SETTINGS" ]; then
        cat > "$NIM_SETTINGS" << 'SETTINGSJSON'
{
  "modelProviders": {
    "openai": [
      {
        "id": "nim-glm-47-tools",
        "name": "NVIDIA NIM GLM-4.7 (LiteLLM)",
        "baseUrl": "http://127.0.0.1:4000/v1",
        "envKey": "NVIDIA_NIM_API_KEY"
      }
    ]
  }
}
SETTINGSJSON
        ok "nim-glm-47/.qwen/settings.json"
    else
        skip "nim-glm-47/.qwen/settings.json уже существует"
    fi

    # NIM DeepSeek
    mkdir -p "$SESSIONS_DIR/nim-deepseek-v31/.qwen"
    DS_SETTINGS="$SESSIONS_DIR/nim-deepseek-v31/.qwen/settings.json"
    if [ ! -f "$DS_SETTINGS" ]; then
        cat > "$DS_SETTINGS" << 'SETTINGSJSON'
{
  "modelProviders": {
    "openai": [
      {
        "id": "nim-deepseek-v3.1-terminus-tools",
        "name": "NVIDIA NIM DeepSeek V3.1 Terminus (LiteLLM)",
        "baseUrl": "http://127.0.0.1:4000/v1",
        "envKey": "NVIDIA_NIM_API_KEY"
      }
    ]
  }
}
SETTINGSJSON
        ok "nim-deepseek-v31/.qwen/settings.json"
    else
        skip "nim-deepseek-v31/.qwen/settings.json уже существует"
    fi
fi

# ─── Создание ярлыков ────────────────────────────────────────────────────────

step "СОЗДАНИЕ ЯРЛЫКОВ"

SCRIPTS_DIR="$INSTALL_DIR/scripts"
chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true

# Определяем каталог рабочего стола
DESKTOP=""
for d in "$HOME/Desktop" "$HOME/Рабочий стол" "$HOME"; do
    if [ -d "$d" ]; then
        DESKTOP="$d"
        break
    fi
done

make_desktop_entry() {
    local name="$1"
    local exec_path="$2"
    local entry_path="$DESKTOP/${name}.desktop"

    cat > "$entry_path" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Exec=bash "$exec_path"
Path=$INSTALL_DIR
Terminal=true
StartupNotify=true
Categories=Development;
EOF
    chmod +x "$entry_path"
    ok "${name}.desktop → $entry_path"
}

if $INSTALL_QWEN; then
    LAUNCHER="$SCRIPTS_DIR/run-qwen-code-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        make_desktop_entry "Qwen Code (cloud)" "$LAUNCHER"
    fi
fi

if $INSTALL_CLAUDE; then
    LAUNCHER="$SCRIPTS_DIR/run-claude-cloud-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        make_desktop_entry "Claude Code (cloud)" "$LAUNCHER"
    fi
fi

if $INSTALL_OPENCODE; then
    LAUNCHER="$SCRIPTS_DIR/run-opencode-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        make_desktop_entry "OpenCode (cloud)" "$LAUNCHER"
    fi
fi

# ─── Итоги ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}УСТАНОВКА ЗАВЕРШЕНА!${RESET}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${GRAY}Репозиторий: $INSTALL_DIR${RESET}"
echo ""
echo -e "${CYAN}Ярлыки на рабочем столе:${RESET}"
if $INSTALL_QWEN;     then echo -e "${GREEN}  * Qwen Code (cloud)${RESET}"; fi
if $INSTALL_CLAUDE;   then echo -e "${GREEN}  * Claude Code (cloud)${RESET}"; fi
if $INSTALL_OPENCODE; then echo -e "${GREEN}  * OpenCode (cloud)${RESET}"; fi
echo ""
echo -e "${YELLOW}ПРИМЕЧАНИЯ:${RESET}"
echo -e "${GRAY}  - Выполните: source ~/.bashrc  (или перезапустите терминал)${RESET}"
echo -e "${GRAY}  - В меню лаунчеров есть пункт 'Сменить ключ API провайдера'${RESET}"
echo -e "${GRAY}  - Для NIM пресетов (Qwen) нужен LiteLLM — см. docs/${RESET}"
echo ""
echo -e "${CYAN}Приятного использования!${RESET}"
echo ""
read -p "Нажмите Enter для выхода…"
