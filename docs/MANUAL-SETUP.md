# Ручная установка: пошаговое руководство

Полная инструкция для ручного развёртывания **Qwen Code**, **Claude Code** и **OpenCode** с облачными провайдерами **NVIDIA NIM**, **Z.AI**, **Groq** и **OpenRouter** на **Windows** и **Linux**.

---

## Оглавление

1. [Архитектура](#1-архитектура)
2. [Требования](#2-требования)
3. [Клонирование репозитория](#3-клонирование-репозитория)
4. [Установка CLI](#4-установка-cli)
5. [Настройка API ключей](#5-настройка-api-ключей)
6. [Профили сессий Qwen Code](#6-профили-сессий-qwen-code)
7. [LiteLLM для пресетов NIM (порт 4000)](#7-litellm-для-пресетов-nim-порт-4000)
8. [free-claude-code для Claude Code → NIM](#8-free-claude-code-для-claude-code--nim)
9. [claude-mem (опционально)](#9-claude-mem-опционально)
10. [Создание ярлыков](#10-создание-ярлыков)
11. [Управление API ключами через TUI](#11-управление-api-ключами-через-tui)
12. [Нативный логин](#12-нативный-логин)
13. [Проверка установки](#13-проверка-установки)
14. [Устранение проблем](#14-устранение-проблем)

---

## 1. Архитектура

```
┌──────────────────────────────────────────────────────────────┐
│                       Рабочая станция                         │
│                                                              │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │  Qwen Code  │    │  Claude Code │    │   OpenCode   │     │
│  │  (OpenAI)   │    │  (Anthropic) │    │   (OpenAI)   │     │
│  └──────┬──────┘    └──────┬───────┘    └──────┬───────┘     │
│         │                  │                   │             │
│  ┌──────┴──────┐    ┌──────┴───────┐           │             │
│  │  LiteLLM    │    │ free-claude- │           │             │
│  │  :4000      │    │ code :8082   │           │             │
│  └──────┬──────┘    └──────┬───────┘           │             │
└─────────┼──────────────────┼───────────────────┼─────────────┘
          │                  │                   │
          ▼                  ▼                   ▼
   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
   │  NVIDIA NIM  │   │    Z.AI      │   │  NVIDIA NIM  │
   │  (integrate) │   │  (api.z.ai)  │   │  (integrate) │
   └──────────────┘   └──────────────┘   └──────────────┘
```

**Потоки данных:**

| CLI | Провайдер | Маршрут |
|-----|-----------|---------|
| Qwen Code | Z.AI | Прямой HTTPS → `api.z.ai/api/openai/v1` |
| Qwen Code | NVIDIA NIM | LiteLLM `127.0.0.1:4000` → `integrate.api.nvidia.com` |
| Qwen Code | Groq | Прямой HTTPS → `api.groq.com/openai/v1` |
| Qwen Code | OpenRouter | Прямой HTTPS → `openrouter.ai/api/v1` |
| Claude Code | Z.AI | Прямой HTTPS → `api.z.ai/api/anthropic` |
| Claude Code | NVIDIA NIM | free-claude-code `127.0.0.1:8082` → `integrate.api.nvidia.com` |
| Claude Code | OpenRouter | free-claude-code `127.0.0.1:8082` → `openrouter.ai` |
| OpenCode | Z.AI | Прямой HTTPS → `api.z.ai/api/openai/v1` (opencode.json) |
| OpenCode | NVIDIA NIM | Прямой HTTPS → `integrate.api.nvidia.com/v1` (opencode.json) |
| OpenCode | Groq | Прямой HTTPS → `api.groq.com/openai/v1` (opencode.json) |
| OpenCode | OpenRouter | Прямой HTTPS → `openrouter.ai/api/v1` (opencode.json) |

---

## 2. Требования

### Обязательные

| Инструмент | Windows | Linux |
|-----------|---------|-------|
| **Git** | [git-scm.com](https://git-scm.com/download/win) | `sudo apt install git` |
| **Node.js** LTS (18+) | [nodejs.org](https://nodejs.org/) | `sudo apt install nodejs npm` или [nvm](https://github.com/nvm-sh/nvm) |
| **npm** | Ставится с Node.js | Ставится с Node.js |

### Для NIM пресетов (Qwen Code)

| Инструмент | Назначение |
|-----------|-----------|
| **LiteLLM** (`pip install litellm[proxy]`) | Прокси `:4000` для NIM-моделей |
| **Python 3.10+** | Для LiteLLM |

### Для Claude Code + NIM

| Инструмент | Назначение |
|-----------|-----------|
| **uv** ([docs.astral.sh/uv](https://docs.astral.sh/uv/)) | Запуск free-claude-code |
| **free-claude-code** | Прокси Claude→NIM |

### Опционально

| Инструмент | Назначение |
|-----------|-----------|
| **claude-mem** | Память для Claude Code (порт 37777) |
| **Obsidian** | Хранилище сессий Claude |
| **Bun** | Fallback для claude-mem |

---

## 3. Клонирование репозитория

### Windows (PowerShell)

```powershell
git clone https://github.com/chelaxian/cloud-code-setup.git
cd cloud-code-setup
```

### Linux

```bash
git clone https://github.com/chelaxian/cloud-code-setup.git
cd cloud-code-setup
chmod +x scripts/*.sh
```

Далее в инструкции: **`$REPO_ROOT`** — корень клонированного репозитория.

---

## 4. Установка CLI

### Qwen Code

```bash
# Windows / Linux
npm install -g @qwen-code/qwen-code@latest
```

Проверка:
```bash
qwen --help
```

### Claude Code

```bash
# Windows / Linux
npm install -g @anthropic-ai/claude-code@latest
```

Проверка:
```bash
claude --help
```

### OpenCode

```bash
# Windows / Linux
npm install -g opencode-ai@latest
```

Проверка:
```bash
opencode --help
```

OpenCode использует `opencode.json` конфигурацию (переменная `OPENCODE_CONFIG`) для подключения к OpenAI-compatible API. Лаунчер `run-opencode-launcher.ps1` (или `.sh`) автоматически генерирует конфиг при выборе провайдера.

---

## 5. Настройка API ключей

### Где взять ключи

| Провайдер | Регистрация | Бесплатно |
|-----------|-------------|-----------|
| **NVIDIA NIM** | [build.nvidia.com](https://build.nvidia.com/) | Да, с лимитами |
| **Z.AI** | [open.bigmodel.cn](https://open.bigmodel.cn/) | Да, с лимитами |
| **Groq** | [console.groq.com](https://console.groq.com/) | Да, 14400 запросов/день |
| **OpenRouter** | [openrouter.ai](https://openrouter.ai/) | Да, бесплатные модели |

### Windows: переменные пользователя

**Способ 1 — через лаунчер:**

Запустите ярлык и выберите "Сменить ключ API провайдера".

**Способ 2 — через PowerShell:**

```powershell
# Сохранить ключ (перезапустите терминал после)
[Environment]::SetEnvironmentVariable("NVIDIA_NIM_API_KEY", "ваш_ключ", "User")
[Environment]::SetEnvironmentVariable("ZAI_API_KEY", "ваш_ключ", "User")
[Environment]::SetEnvironmentVariable("GROQ_API_KEY", "ваш_ключ", "User")
[Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", "ваш_ключ", "User")
```

**Способ 3 — через GUI:**

1. Win+R → `sysdm.cpl` → Дополнительно → Переменные среды
2. Добавьте пользовательские переменные `NVIDIA_NIM_API_KEY`, `ZAI_API_KEY`, `GROQ_API_KEY`, `OPENROUTER_API_KEY`

### Linux: ~/.bashrc / ~/.zshrc

```bash
# Добавьте в конец ~/.bashrc (или ~/.zshrc)
export NVIDIA_NIM_API_KEY="ваш_ключ"
export ZAI_API_KEY="ваш_ключ"
export GROQ_API_KEY="ваш_ключ"
export OPENROUTER_API_KEY="ваш_ключ"

# Применить в текущей сессии
source ~/.bashrc
```

### Нативный логин (без API-ключей)

Каждый лаунчер поддерживает авторизацию через нативный OAuth/браузер:

| Лаунчер | Пункт меню | Команда |
|---------|-----------|---------|
| **Qwen Code** | Нативный логин → Qwen OAuth | `qwen auth qwen-oauth` (браузер) |
| **Qwen Code** | Нативный логин → Coding Plan | `qwen auth coding-plan` (API-ключ Alibaba Cloud) |
| **Claude Code** | Нативный логин → Claude подписка | `claude auth login --claudeai` (OAuth, браузер) |
| **Claude Code** | Нативный логин → Anthropic Console | `claude auth login --console` (API-биллинг, браузер) |
| **OpenCode** | Нативный логин → Providers | `opencode providers login` (интерактивный выбор) |

Для использования нативного логина需要有 платная подписка на соответствующий сервис (Claude Pro/Max, Qwen Coding Plan и т.д.).

### Переменные окружения (справка)

| Переменная | Назначение |
|-----------|-----------|
| `NVIDIA_NIM_API_KEY` | Доступ к NVIDIA integrate API |
| `ZAI_API_KEY` | Z.AI Coding / Anthropic-совместимые вызовы |
| `GROQ_API_KEY` | Groq API (бесплатно, 14400 запросов/день) |
| `OPENROUTER_API_KEY` | OpenRouter API (бесплатные и платные модели) |

**Не коммитьте значения ключей в git.**

---

## 6. Профили сессий Qwen Code

Шаблоны уже включены в репозиторий в `qwen-sessions/`. При необходимости пересоздайте:

### Z.AI GLM-4.7 — `qwen-sessions/zai-glm47/.qwen/settings.json`

```json
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
```

### NIM GLM-4.7 — `qwen-sessions/nim-glm-47/.qwen/settings.json`

```json
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
```

### NIM Qwen3.5-122B — `qwen-sessions/nim-qwen35-122b/.qwen/settings.json`

```json
{
  "modelProviders": {
    "openai": [
      {
        "id": "nim-qwen3.5-122b-a10b-tools",
        "name": "NVIDIA NIM Qwen3.5-122B-A10B (LiteLLM)",
        "baseUrl": "http://127.0.0.1:4000/v1",
        "envKey": "NVIDIA_NIM_API_KEY"
      }
    ]
  }
}
```

---

## 7. LiteLLM для пресетов NIM (порт 4000)

**Только для Qwen Code + NIM.** Если вы используете только Z.AI — пропустите этот шаг.

### Установка

```bash
pip install 'litellm[proxy]'
```

### Конфигурация

Создайте директорию и файл конфигурации:

**Windows:**
```powershell
mkdir "$env:USERPROFILE\.qwen\litellm" -Force
```

**Linux:**
```bash
mkdir -p ~/.qwen/litellm
```

Создайте файл `~/.qwen/litellm/litellm-nim-config.yaml`:

```yaml
# Ключ только через env NVIDIA_NIM_API_KEY (не пишите ключ в файл)
model_list:
  - model_name: nim-glm-4.7-tools
    litellm_params:
      model: openai/z-ai/glm4.7
      api_base: https://integrate.api.nvidia.com/v1
      api_key: os.environ/NVIDIA_NIM_API_KEY
  - model_name: nim-qwen3.5-122b-a10b-tools
    litellm_params:
      model: openai/qwen/qwen3.5-122b-a10b
      api_base: https://integrate.api.nvidia.com/v1
      api_key: os.environ/NVIDIA_NIM_API_KEY

general_settings:
  master_key: optional-local-master-key
```

### Запуск прокси

**Windows** — создайте `~/.qwen/litellm/start-nvidia-nim-proxy.ps1`:

```powershell
$env:NVIDIA_NIM_API_KEY = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
if ([string]::IsNullOrWhiteSpace($env:NVIDIA_NIM_API_KEY)) {
  throw "Задайте NVIDIA_NIM_API_KEY"
}
$config = Join-Path $PSScriptRoot "litellm-nim-config.yaml"
litellm --config $config --port 4000 --host 127.0.0.1
```

**Linux** — создайте `~/.qwen/litellm/start-nvidia-nim-proxy.sh`:

```bash
#!/bin/bash
export NVIDIA_NIM_API_KEY="${NVIDIA_NIM_API_KEY:?$NVIDIA_NIM_API_KEY not set}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
litellm --config "$SCRIPT_DIR/litellm-nim-config.yaml" --port 4000 --host 127.0.0.1
```

Запуск:
```bash
chmod +x ~/.qwen/litellm/start-nvidia-nim-proxy.sh
~/.qwen/litellm/start-nvidia-nim-proxy.sh
```

Проверка: `curl http://127.0.0.1:4000/v1/models` должен вернуть список моделей.

---

## 8. free-claude-code для Claude Code → NIM

**Только для Claude Code + NIM.** Если вы используете только Z.AI — пропустите этот шаг.

### Установка

```bash
# Установите uv (если нет)
# Windows: irm https://astral.sh/uv/install.ps1 | iex
# Linux:   curl -LsSf https://astral.sh/uv/install.sh | sh

# Клонируйте free-claude-code в отдельную директорию
git clone <url-free-claude-code> $REPO_ROOT/free-claude-code
cd $REPO_ROOT/free-claude-code

# Установите зависимости
uv sync
```

### Порты по умолчанию

| Модель | Порт |
|--------|------|
| GLM-4.7 NIM | 8082 |
| Qwen3.5-122B-A10B | 8083 |

### Запуск прокси

Скрипт `run-claude-cloud-session.ps1` автоматически запускает free-claude-code при выборе профиля NIM в лаунчере.

Ручной запуск (для отладки):

```bash
cd $REPO_ROOT/free-claude-code
NVIDIA_NIM_API_KEY="ваш_ключ" MODEL="nvidia_nim/z-ai/glm4.7" ANTHROPIC_AUTH_TOKEN="freecc" \
  uv run uvicorn server:app --host 127.0.0.1 --port 8082
```

---

## 9. claude-mem (опционально)

Память для Claude Code — воркер на `127.0.0.1:37777`.

### Установка

```bash
npx claude-mem start
```

### Проверка

Откройте в браузере: `http://127.0.0.1:37777/`

---

## 10. Создание ярлыков

### Автоматически (рекомендуется)

**Windows:**
```powershell
cd $REPO_ROOT
.\install.ps1
```

**Linux:**
```bash
cd $REPO_ROOT
./install.sh
```

Инсталлятор создаст ярлыки на рабочем столе автоматически.

### Вручную — Windows

```powershell
$shell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")
$repoRoot = "ПУТЬ_К_РЕПО"

# Qwen Code
$lnk = $shell.CreateShortcut("$desktop\Qwen Code (cloud).lnk")
$lnk.TargetPath = "powershell.exe"
$lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$repoRoot\scripts\run-qwen-code-launcher.ps1`""
$lnk.WorkingDirectory = $repoRoot
$lnk.Save()

# Claude Code
$lnk = $shell.CreateShortcut("$desktop\Claude Code (cloud).lnk")
$lnk.TargetPath = "cmd.exe"
$lnk.Arguments = "/k chcp 65001 >nul & powershell -NoProfile -ExecutionPolicy Bypass -File `"$repoRoot\scripts\run-claude-cloud-launcher.ps1`""
$lnk.WorkingDirectory = $repoRoot
$lnk.Save()

# OpenCode
$lnk = $shell.CreateShortcut("$desktop\OpenCode (cloud).lnk")
$lnk.TargetPath = "cmd.exe"
$lnk.Arguments = "/k chcp 65001 >nul & powershell -NoProfile -ExecutionPolicy Bypass -File `"$repoRoot\scripts\run-opencode-launcher.ps1`""
$lnk.WorkingDirectory = $repoRoot
$lnk.Save()
```

### Вручную — Linux

```bash
REPO_ROOT="$HOME/cloud-code-setup"
DESKTOP="$HOME/Desktop"
[ -d "$DESKTOP" ] || DESKTOP="$HOME"

# Qwen Code
cat > "$DESKTOP/Qwen Code (cloud).desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Qwen Code (cloud)
Exec=bash "$REPO_ROOT/scripts/run-qwen-code-launcher.sh"
Path=$REPO_ROOT
Terminal=true
Categories=Development;
EOF
chmod +x "$DESKTOP/Qwen Code (cloud).desktop"

# Claude Code
cat > "$DESKTOP/Claude Code (cloud).desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Claude Code (cloud)
Exec=bash "$REPO_ROOT/scripts/run-claude-cloud-launcher.sh"
Path=$REPO_ROOT
Terminal=true
Categories=Development;
EOF
chmod +x "$DESKTOP/Claude Code (cloud).desktop"

# OpenCode
cat > "$DESKTOP/OpenCode (cloud).desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=OpenCode (cloud)
Exec=bash "$REPO_ROOT/scripts/run-opencode-launcher.sh"
Path=$REPO_ROOT
Terminal=true
Categories=Development;
EOF
chmod +x "$DESKTOP/OpenCode (cloud).desktop"
```

---

## 11. Управление API ключами через TUI

Во всех лаунчерах (Qwen Code, Claude Code, OpenCode) есть встроенное меню для смены API ключей:

1. Запустите ярлык
2. Выберите **«Сменить ключ API провайдера»**
3. Выберите провайдера: **NVIDIA NIM**, **Z.AI**, **Groq** или **OpenRouter**
4. Текущий ключ показан замаскированным (например `nv1234...5678ab`)
5. Введите новый ключ (скрытый ввод)
6. **ESC** — вернуться в предыдущее меню

Ключи сохраняются:
- **Windows**: в переменных пользователя (`[Environment]::SetEnvironmentVariable`)
- **Linux**: в `~/.bashrc` и `~/.zshrc`

---

## 12. Нативный логин

Каждый лаунчер поддерживает нативную авторизацию (OAuth через браузер), если у вас есть платная подписка:

### Qwen Code

| Способ | Описание |
|--------|----------|
| **Qwen OAuth** | Авторизация через браузер (подписка Qwen) |
| **Coding Plan** | Alibaba Cloud Coding Plan (API-ключ, регионы china/global) |

Выберите в меню **«Нативный логин (Qwen OAuth / Coding Plan)»** → нужный способ.

### Claude Code

| Способ | Описание |
|--------|----------|
| **Claude подписка** | OAuth через браузер (Claude Pro / Max) |
| **Anthropic Console** | API-биллинг через Anthropic Console |

Выберите в меню **«Нативный логин (Anthropic OAuth / Console)»** → нужный способ.

### OpenCode

Интерактивное меню `opencode providers login` с выбором провайдера и метода входа.

Выберите в меню **«Нативный логин (OpenCode Providers)»**.

---

## 13. Проверка установки

### Проверка зависимостей

```bash
# Должны быть доступны:
git --version
node --version
npm --version
qwen --help      # если установлен Qwen Code
claude --help    # если установлен Claude Code
opencode --help  # если установлен OpenCode
```

### Проверка API ключей

**Windows:**
```powershell
[Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
[Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
[Environment]::GetEnvironmentVariable("GROQ_API_KEY", "User")
[Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
```

**Linux:**
```bash
echo $NVIDIA_NIM_API_KEY
echo $ZAI_API_KEY
echo $GROQ_API_KEY
echo $OPENROUTER_API_KEY
```

### Проверка LiteLLM (если установлен)

```bash
curl http://127.0.0.1:4000/v1/models
```

Должен вернуть JSON со списком моделей.

### Проверка free-claude-code (если установлен)

```bash
curl http://127.0.0.1:8082/v1/models
```

### Быстрый тест — Qwen Code + Z.AI

```bash
cd $REPO_ROOT/qwen-sessions/zai-glm47
qwen
```

---

## 14. Устранение проблем

### Windows: «Политика выполнения скриптов»

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Linux: «Permission denied»

```bash
chmod +x ~/cloud-code-setup/scripts/*.sh
```

### Ключи не подхватываются

**Windows**: Перезапустите терминал (новое окно PowerShell).

**Linux**: Выполните `source ~/.bashrc` или откройте новый терминал.

### LiteLLM не стартует

1. Проверьте что `litellm` установлен: `pip show litellm`
2. Проверьте что `NVIDIA_NIM_API_KEY` задан
3. Проверьте что конфиг YAML валидный
4. Смотрите логи: `$env:USERPROFILE\.qwen\litellm\logs\` (Windows) или `~/.qwen/litellm/logs/` (Linux)

### free-claude-code не стартует

1. Проверьте что `uv` установлен: `uv --version`
2. Проверьте что зависимости установлены: `cd free-claude-code && uv sync`
3. Проверьте что порт не занят: `ss -ltnp | grep 8082` (Linux) или `netstat -an | findstr 8082` (Windows)

### Qwen Code: «API key not found»

Скрипт `run-qwen-code-cloud-zai-glm47.ps1` ищет ключ в следующем порядке:
1. `ZAI_API_KEY` (переменная пользователя)
2. `ZAI_API_KEY` (env процесса)
3. `OPENAI_API_KEY` (переменная пользователя)
4. `OPENAI_API_KEY` (env процесса)
5. Интерактивный ввод (скрытый)

### Claude Code: модели NIM не работают

Для моделей **вне белого списка** Claude Code запускается с `--tools minimal`. Белый список:
- `z-ai/glm4.7`
- `qwen/qwen3.5-122b-a10b`

### Ошибка 400 от NIM API

- **Массив в `content`** → скрипты автоматически делают flatten
- **`tool_choice=auto`** на бэкенде без поддержки → автоматически `none`
- **Длинная история** при маленьком контексте → автоматическая обрезка

### Groq: «Request too large» / TPM limit exceeded

Groq бесплатный тариф имеет жёсткие лимиты TPM (6000-12000 токенов в минуту). Системный промпт агента (tool definitions + инструкции) занимает ~20-30K токенов, что **превышает лимит**. 

Решение в лаунчерах:
- **Qwen Code**: запуск в режиме чата (`--bare`, без инструментов) — только текстовый диалог, без агента
- **OpenCode**: урезанный контекст `maxTokens=2048`, `contextLength=4096`

Для полноценной работы агента используйте **Z.AI**, **NVIDIA NIM** или **OpenRouter**.

### OpenRouter: «403 Provider returned error» / «429 Too Many Requests»

OpenRouter имеет лимиты: ~20 RPM, ~50 RPD для бесплатных моделей. Лаунчеры автоматически урезают контекст:
- **Qwen Code**: `contextWindowSize=16384`, `max_tokens=8192`, `skipStartupContext=true`
- **OpenCode**: `maxTokens=8192`, `contextLength=16384`

Если ошибка повторяется — подождите или используйте платный API-ключ.

### Очистка памяти claude-mem

Если во время тестов память `claude-mem` забилась:
```powershell
# Windows
.\scripts\clear-claude-mem.ps1
```

---

## Быстрый чеклист

### Минимальная установка (только Z.AI)

- [ ] Git установлен
- [ ] Node.js + npm установлены
- [ ] Qwen Code CLI: `npm i -g @qwen-code/qwen-code`
- [ ] Claude Code CLI: `npm i -g @anthropic-ai/claude-code`
- [ ] Репозиторий клонирован
- [ ] `ZAI_API_KEY` задан
- [ ] Ярлыки созданы (через `install.ps1` / `install.sh`)

### Полная установка (Z.AI + NIM + Groq + OpenRouter)

- [ ] Всё из минимальной установки
- [ ] `NVIDIA_NIM_API_KEY` задан
- [ ] `GROQ_API_KEY` задан
- [ ] `OPENROUTER_API_KEY` задан
- [ ] LiteLLM установлен и настроен (`:4000`)
- [ ] free-claude-code клонирован и зависимости установлены
- [ ] (Опционально) claude-mem запущен (`:37777`)
- [ ] (Опционально) Obsidian установлен
