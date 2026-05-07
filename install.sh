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
echo -e "${CYAN}   ██████╗██╗     ██╗        ██████╗ ██████╗ ██████╗ ███████╗${RESET}"
echo -e "${CYAN}  ██╔════╝██║     ██║        ██╔════╝██╔═══██╗██╔══██╗██╔════╝${RESET}"
echo -e "${CYAN}  ██║     ██║     ██║ █████╗ ██║     ██║   ██║██║  ██║█████╗  ${RESET}"
echo -e "${CYAN}  ██║     ██║     ██║ ╚════╝ ██║     ██║   ██║██║  ██║██╔══╝  ${RESET}"
echo -e "${CYAN}  ╚██████╗███████╗██║        ╚██████╗╚██████╔╝██████╔╝███████╗${RESET}"
echo -e "${CYAN}   ╚═════╝╚══════╝╚═╝         ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝${RESET}"
echo -e "${CYAN}${RESET}"
echo -e "${YELLOW}              C L O U D   S E T U P  -  1-click install${RESET}"
echo -e "${YELLOW}  Qwen Code + Claude Code + OpenCode${RESET}"
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
    echo -e "${CYAN}Обновление…${RESET}"
    (cd "$INSTALL_DIR" && git fetch origin main 2>/dev/null && git reset --hard origin/main 2>/dev/null) || warn "Не удалось обновить"
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
echo -e "  ${RED}[5]${RESET} Полное удаление (uninstall)"
echo -e "  ${GRAY}[0]${RESET} Выход"
echo ""

read -p "Ваш выбор [4]: " install_choice
install_choice="${install_choice:-4}"

INSTALL_QWEN=false
INSTALL_CLAUDE=false
INSTALL_OPENCODE=false
DO_UNINSTALL=false

case "$install_choice" in
    1) INSTALL_QWEN=true ;;
    2) INSTALL_CLAUDE=true ;;
    3) INSTALL_OPENCODE=true ;;
    4) INSTALL_QWEN=true; INSTALL_CLAUDE=true; INSTALL_OPENCODE=true ;;
    5) DO_UNINSTALL=true ;;
    0) echo -e "${YELLOW}Выход.${RESET}"; exit 0 ;;
    *) warn "Неверный выбор. Устанавливаем все три."; INSTALL_QWEN=true; INSTALL_CLAUDE=true; INSTALL_OPENCODE=true ;;
esac

# --- Uninstall ---
if $DO_UNINSTALL; then
    step "ПОЛНОЕ УДАЛЕНИЕ"

    echo -e "${RED}ВНИМАНИЕ: Это действие удалит:${RESET}"
    echo -e "${RED}  - Репозиторий $INSTALL_DIR${RESET}"
    echo -e "${RED}  - Все сессии (qwen/claude/opencode-sessions)${RESET}"
    echo -e "${RED}  - Конфиги CLI (~/.claude, ~/.qwen)${RESET}"
    echo -e "${RED}  - API ключи из ~/.bashrc и ~/.zshrc${RESET}"
    echo -e "${RED}  - Лаунчеры ~/qwen-code-cloud.sh, ~/claude-code-cloud.sh, ~/opencode-cloud.sh${RESET}"
    echo -e "${RED}  - Desktop ярлыки (.desktop)${RESET}"
    echo -e "${RED}  - Глобальные npm пакеты (qwen-code, claude-code, opencode-ai)${RESET}"
    echo ""
    echo -e "${YELLOW}Введите 'yes' для подтверждения удаления: ${RESET}"
    read -r confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Отмена удаления.${RESET}"
        read -p "Нажмите Enter для выхода..."
        exit 0
    fi

    echo ""
    echo -e "${CYAN}Удаление репозитория...${RESET}"
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        ok "Удалён: $INSTALL_DIR"
    else
        skip "$INSTALL_DIR не найден"
    fi

    echo -e "${CYAN}Удаление сессий...${RESET}"
    for sdir in "$HOME/qwen-sessions" "$HOME/claude-sessions" "$HOME/opencode-sessions"; do
        if [ -d "$sdir" ]; then
            rm -rf "$sdir"
            ok "Удалён: $sdir"
        fi
    done

    echo -e "${CYAN}Удаление конфигов CLI...${RESET}"
    for cfg in "$HOME/.claude" "$HOME/.qwen" "$HOME/.opencode"; do
        if [ -d "$cfg" ]; then
            rm -rf "$cfg"
            ok "Удалён: $cfg"
        fi
    done

    echo -e "${CYAN}Удаление API ключей из ~/.bashrc и ~/.zshrc...${RESET}"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            for var in NVIDIA_NIM_API_KEY ZAI_API_KEY OPENAI_API_KEY GROQ_API_KEY OPENROUTER_API_KEY; do
                sed -i "/^export ${var}=/d" "$rc"
            done
            ok "Очищен: $rc"
        fi
    done

    echo -e "${CYAN}Удаление лаунчеров...${RESET}"
    for launcher in "$HOME/qwen-code-cloud.sh" "$HOME/claude-code-cloud.sh" "$HOME/opencode-cloud.sh"; do
        if [ -f "$launcher" ]; then
            rm -f "$launcher"
            ok "Удалён: $launcher"
        fi
    done

    echo -e "${CYAN}Удаление desktop ярлыков...${RESET}"
    for d in "$HOME/Desktop" "$HOME/Рабочий стол"; do
        if [ -d "$d" ]; then
            for f in "$d/Qwen Code (cloud).desktop" "$d/Claude Code (cloud).desktop" "$d/OpenCode (cloud).desktop"; do
                if [ -f "$f" ]; then
                    rm -f "$f"
                    ok "Удалён: $f"
                fi
            done
        fi
    done

    echo -e "${CYAN}Удаление глобальных npm пакетов...${RESET}"
    for pkg in @qwen-code/qwen-code @anthropic-ai/qwen-code @anthropic-ai/claude-code opencode-ai; do
        if npm ls -g "$pkg" &>/dev/null; then
            npm uninstall -g "$pkg" 2>/dev/null && ok "Удалён npm: $pkg" || warn "Не удалось удалить: $pkg"
        else
            skip "npm $pkg не установлен"
        fi
    done

    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}  ПОЛНОЕ УДАЛЕНИЕ ЗАВЕРШЕНО!${RESET}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo -e "${YELLOW}Перезапустите терминал для очистки переменных окружения.${RESET}"
    echo ""
    read -p "Нажмите Enter для выхода..."
    exit 0
fi

# ─── Установка CLI ───────────────────────────────────────────────────────────

step "УСТАНОВКА CLI"

if $INSTALL_QWEN; then
    echo -e "${CYAN}Установка/обновление Qwen Code CLI…${RESET}"
    if npm install -g @qwen-code/qwen-code@latest 2>/dev/null; then
        ok "Qwen Code CLI: $(which qwen 2>/dev/null)"
    else
        warn "Не удалось установить Qwen Code CLI. Установите вручную: npm i -g @qwen-code/qwen-code"
    fi
fi

if $INSTALL_CLAUDE; then
    echo -e "${CYAN}Установка/обновление Claude Code CLI…${RESET}"
    if npm install -g @anthropic-ai/claude-code@latest 2>/dev/null; then
        ok "Claude Code CLI: $(which claude 2>/dev/null)"
    else
        warn "Не удалось установить Claude Code CLI. Установите вручную: npm i -g @anthropic-ai/claude-code"
    fi

    # free-claude-code proxy for NIM/OpenRouter
    FCC_DIR="$HOME/.free-claude-code"
    echo -e "${CYAN}Установка free-claude-code proxy (для NIM/OpenRouter)…${RESET}"
    if ! command -v uv &>/dev/null; then
        echo -e "${CYAN}  Установка uv…${RESET}"
        curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null
        export PATH="$HOME/.local/bin:$PATH"
    fi
    if [ ! -d "$FCC_DIR" ]; then
        git clone https://github.com/Alishahryar1/free-claude-code.git "$FCC_DIR" 2>/dev/null
        if [ -d "$FCC_DIR" ]; then
            ok "free-claude-code: $FCC_DIR"
        else
            warn "Не удалось клонировать free-claude-code. NIM/OpenRouter будут недоступны."
        fi
    else
        (cd "$FCC_DIR" && git pull origin main 2>/dev/null) || true
        ok "free-claude-code: обновлён"
    fi
fi

if $INSTALL_OPENCODE; then
    echo -e "${CYAN}Установка/обновление OpenCode CLI…${RESET}"
    if npm install -g opencode-ai@latest 2>/dev/null; then
        ok "OpenCode CLI: $(which opencode 2>/dev/null)"
    else
        warn "Не удалось установить OpenCode CLI. Установите вручную: npm i -g opencode-ai@latest"
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

echo ""

read -s -p "Groq API ключ (Enter = пропуск): " groq_key
echo ""
if [ -n "$groq_key" ]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            sed -i '/^export GROQ_API_KEY=/d' "$rc"
            echo "export GROQ_API_KEY=\"$groq_key\"" >> "$rc"
        fi
    done
    export GROQ_API_KEY="$groq_key"
    ok "GROQ_API_KEY сохранён"
else
    skip "GROQ_API_KEY пропущен"
fi

echo ""

read -s -p "OpenRouter API ключ (Enter = пропуск): " or_key
echo ""
if [ -n "$or_key" ]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            sed -i '/^export OPENROUTER_API_KEY=/d' "$rc"
            echo "export OPENROUTER_API_KEY=\"$or_key\"" >> "$rc"
        fi
    done
    export OPENROUTER_API_KEY="$or_key"
    ok "OPENROUTER_API_KEY сохранён"
else
    skip "OPENROUTER_API_KEY пропущен"
fi

# ─── Единое пространство /resume ──────────────────────────────────────────────

step "НАСТРОЙКА СЕССИЙ (/resume)"

if $INSTALL_QWEN; then
    SHARED_DIR="$INSTALL_DIR/qwen-sessions/_shared/.qwen"
    mkdir -p "$SHARED_DIR"
    ok "qwen-sessions/_shared/"
fi
if $INSTALL_CLAUDE; then
    mkdir -p "$REPO_DIR/claude-sessions/_shared"
    ok "claude-sessions/_shared/"
fi
if $INSTALL_OPENCODE; then
    mkdir -p "$REPO_DIR/opencode-sessions/_shared"
    ok "opencode-sessions/_shared/"
fi

# ─── Создание ярлыков ────────────────────────────────────────────────────────

step "СОЗДАНИЕ ЯРЛЫКОВ"

SCRIPTS_DIR="$INSTALL_DIR/scripts"
chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true

# Определяем каталог рабочего стола
DESKTOP=""
for d in "$HOME/Desktop" "$HOME/Рабочий стол"; do
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

# Создаём .sh скрипты-лаунчеры в ~/ (для серверов без GUI)
make_sh_launcher() {
    local name="$1"
    local exec_path="$2"
    local safe_name=$(echo "$name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    local sh_path="$HOME/${safe_name}.sh"

    cat > "$sh_path" << EOF
#!/bin/bash
# Запуск лаунчера $name
exec bash "$exec_path" "\$@"
EOF
    chmod +x "$sh_path"
    ok "${safe_name}.sh → $sh_path"
}

if $INSTALL_QWEN; then
    LAUNCHER="$SCRIPTS_DIR/run-qwen-code-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        if [ -n "$DESKTOP" ]; then
            make_desktop_entry "Qwen Code (cloud)" "$LAUNCHER"
        fi
        make_sh_launcher "qwen-code-cloud" "$LAUNCHER"
    fi
fi

if $INSTALL_CLAUDE; then
    LAUNCHER="$SCRIPTS_DIR/run-claude-cloud-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        if [ -n "$DESKTOP" ]; then
            make_desktop_entry "Claude Code (cloud)" "$LAUNCHER"
        fi
        make_sh_launcher "claude-code-cloud" "$LAUNCHER"
    fi
fi

if $INSTALL_OPENCODE; then
    LAUNCHER="$SCRIPTS_DIR/run-opencode-launcher.sh"
    if [ -f "$LAUNCHER" ]; then
        if [ -n "$DESKTOP" ]; then
            make_desktop_entry "OpenCode (cloud)" "$LAUNCHER"
        fi
        make_sh_launcher "opencode-cloud" "$LAUNCHER"
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
echo -e "${CYAN}Команды для запуска:${RESET}"
if $INSTALL_QWEN;     then echo -e "${GREEN}  ~/qwen-code-cloud.sh${RESET}"; fi
if $INSTALL_CLAUDE;   then echo -e "${GREEN}  ~/claude-code-cloud.sh${RESET}"; fi
if $INSTALL_OPENCODE; then echo -e "${GREEN}  ~/opencode-cloud.sh${RESET}"; fi
echo ""
echo -e "${YELLOW}Перезапустите терминал для применения API ключей. Запускайте через команды выше!${RESET}"
echo ""
echo -e "${CYAN}Приятного использования!${RESET}"
echo ""
read -p "Нажмите Enter для выхода…"
