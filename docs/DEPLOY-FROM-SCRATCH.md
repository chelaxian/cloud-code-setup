# Развёртывание с нуля: Qwen Code, Claude Code, OpenCode, LiteLLM, free-claude-code, claude-mem, Obsidian + NVIDIA NIM и Z.AI GLM

Пошаговая инструкция для воспроизведения рабочей связки на **новой установке Windows**. Секреты (API-ключи, токены) **не** приводятся — только имена переменных окружения и шаблоны.

## Оглавление

1. [Цель и архитектура](#1-цель-и-архитектура)
2. [Требования и установка базовых инструментов](#2-требования-и-установка-базовых-инструментов)
3. [Переменные окружения (без значений)](#3-переменные-окружения-без-значений)
4. [Каталог проекта и сессии Qwen](#4-каталог-проекта-и-сессии-qwen)
5. [LiteLLM для пресетов NIM (порт 4000)](#5-litellm-для-пресетов-nim-порт-4000)
6. [free-claude-code для Claude Code → NIM](#6-free-claude-code-для-claude-code--nim)
7. [claude-mem](#7-claude-mem)
8. [Obsidian](#8-obsidian)
9. [Логика совместимости NIM (whitelist, прокси, обрезка контекста)](#9-логика-совместимости-nim-whitelist-прокси-обрезка-контекста)
10. [Ярлыки на рабочем столе: эквивалент `.lnk` в PowerShell](#10-ярлыки-на-рабочем-столе-эквивалент-lnk-в-powershell)
11. [Полные тексты ключевых скриптов](#11-полные-тексты-ключевых-скриптов) — лаунчеры Claude/Qwen/OpenCode, TUI, мастер модели, `update-cloud-shortcuts`, `providers/nvidia_nim/request.py`

---

## 1. Цель и архитектура

- **Qwen Code** работает с **Z.AI Coding API** (OpenAI-совместимый) и с **NVIDIA NIM** (integrate OpenAI).
- **Пресеты NIM** (GLM-4.7 tools, Qwen3.5-122B-A10B tools) идут через **LiteLLM** на `http://127.0.0.1:4000/v1`.
- **Произвольная модель NIM** вне белого списка: локальный **Node-прокси** `nim-integrate-string-content-proxy.mjs` (строковый `content`, усечение истории по tier).
- **Claude Code** для Z.AI — напрямую на `api.z.ai` (Anthropic-совместимый эндпоинт).
- **Claude Code** для NIM — через локальный **free-claude-code** (uvicorn), который проксирует в NIM; для моделей вне whitelist — `minimal` tools и те же ограничения в Python.
- **claude-mem** — воркер на `127.0.0.1:37777`; **Obsidian** — хранилище для сессий Claude (рабочая директория при запуске).
- **Управление API ключами** — через TUI-меню лаунчеров (пункт "Сменить ключ API провайдера") можно интерактивно обновить ключи для **NVIDIA_NIM_API_KEY**, **ZAI_API_KEY**, **GROQ_API_KEY** и **OPENROUTER_API_KEY** в переменных пользователя без редактирования файлов.

---

## 2. Требования и установка базовых инструментов

### 2.1. Node.js LTS

Установите [Node.js](https://nodejs.org/) (LTS). Убедитесь, что в PATH есть:

- `node`, `npm`
- после глобальных установок — `%APPDATA%\npm`

### 2.2. Qwen Code (CLI)

```powershell
npm install -g @qwen-code/qwen-code@latest
```

Проверка: `qwen --help` (или полный путь `%APPDATA%\npm\qwen.cmd`).

### 2.3. Claude Code (CLI)

Установка по официальной документации Anthropic (глобальный npm-пакет). Типично:

```powershell
npm install -g @anthropic-ai/claude-code
```

Проверка: `claude --help`, ожидается `claude.cmd` в `%APPDATA%\npm`.

### 2.3b. OpenCode (CLI)

Установка OpenCode AI (глобальный npm-пакет):

```powershell
npm install -g opencode-ai@latest
```

Проверка: `opencode --help`, ожидается `opencode.cmd` в `%APPDATA%\npm`.

OpenCode использует конфигурацию `opencode.json` (переменная `OPENCODE_CONFIG`) для подключения к OpenAI-compatible провайдерам (Z.AI, NVIDIA NIM). Лаунчер `run-opencode-launcher.ps1` автоматически создаёт конфиг при выборе провайдера/модели.

### 2.4. uv (Astral)

Установите [uv](https://docs.astral.sh/uv/). В скриптах сессии Claude путь к `uv.exe` может быть задан явно — на новой машине **исправьте** путь в `run-claude-cloud-session.ps1` (функция `Ensure-FreeClaudeCodeProxy`) на ваш, например:

`%USERPROFILE%\.local\bin\uv.exe`

В `run-claude-cloud-session.ps1` функция `Ensure-FreeClaudeCodeProxy` сейчас может ссылаться на **фиксированный** путь к `uv.exe`. Для переносимости замените блок выбора `uv` на поиск в PATH, например:

```powershell
$uv = $null
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if ($uvCmd) { $uv = $uvCmd.Source }
if (-not $uv) {
  $cand = Join-Path $env:USERPROFILE ".local\bin\uv.exe"
  if (Test-Path -LiteralPath $cand) { $uv = $cand }
}
if (-not $uv -or -not (Test-Path -LiteralPath $uv)) { throw "uv.exe не найден. Установите uv и/или добавьте в PATH." }
```

### 2.5. Bun (опционально, для fallback claude-mem)

Рекомендуется для fallback-запуска воркера claude-mem: [Bun](https://bun.sh/).

### 2.6. Копирование репозитория `qwen-local-setup`

Скопируйте дерево проекта (скрипты, `qwen-sessions`, `free-claude-code`) в выбранный корень, например:

- `D:\qwen-local-setup`

Далее в инструкции: `**$RepoRoot**` — этот каталог.

**Обязательно** замените во всех скриптах жёстко прошитые пути:

- `I:\qwen-local-setup` → ваш `$RepoRoot`
- `C:\Users\chelaxian\...` → ваши `Desktop`, `Documents`, `uv.exe`, иконка `.ico`

---

## 3. Переменные окружения (без значений)

Задайте на уровне **пользователя** (Windows: «Переменные среды») или через `setx` (новая сессия):


| Переменная           | Назначение                                                                |
| -------------------- | ------------------------------------------------------------------------- |
| `ZAI_API_KEY`        | Z.AI Coding / Anthropic-совместимые вызовы для Claude и OpenAI-режим Qwen |
| `NVIDIA_NIM_API_KEY` | Доступ к NVIDIA integrate API для NIM                                     |
| `GROQ_API_KEY`       | Groq API (бесплатно, 14400 запросов/день, ultra-fast)                     |
| `OPENROUTER_API_KEY` | OpenRouter API (бесплатные и платные модели, 20 RPM/50 RPD)              |


Не коммитьте значения. В репозитории используйте только `*.example` при необходимости.

---

## 4. Каталог проекта и сессии Qwen

В репозитории должны существовать:

- `qwen-sessions\nim-glm-47\.qwen\settings.json` — NIM GLM-4.7 через LiteLLM `:4000`
- `qwen-sessions\nim-qwen35-122b\.qwen\settings.json` — NIM Qwen3.5-122B-A10B через `:4000`
- `qwen-sessions\zai-glm47\.qwen\settings.json` — Z.AI GLM-4.7

Динамические сессии создаются в `qwen-sessions\_dynamic\...` скриптом `run-qwen-code-dynamic.ps1`.

### 4.1. Примеры содержимого `settings.json` (копируйте в репозиторий как эталон)

Имена моделей для LiteLLM должны **совпадать** с `model.name` и `modelProviders.openai[].id` ниже. База для NIM-пресетов: `http://127.0.0.1:4000/v1`.

`**qwen-sessions/nim-glm-47/.qwen/settings.json`**

```json
{
  "modelProviders": {
    "openai": [
      {
        "id": "nim-glm-4.7-tools",
        "name": "NVIDIA NIM — GLM-4.7 (tool calling + thinking)",
        "description": "LiteLLM :4000 → NIM z-ai/glm4.7; модель …-tools; chat_template_kwargs (thinking)",
        "envKey": "OPENAI_API_KEY",
        "baseUrl": "http://127.0.0.1:4000/v1",
        "generationConfig": {
          "timeout": 600000,
          "maxRetries": 4,
          "contextWindowSize": 202752,
          "extra_body": {
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
  "security": {
    "auth": {
      "selectedType": "openai"
    }
  },
  "model": {
    "name": "nim-glm-4.7-tools"
  },
  "$version": 3
}
```

`**qwen-sessions/nim-deepseek-v31/.qwen/settings.json**`

```json
{
  "modelProviders": {
    "openai": [
      {
        "id": "nim-deepseek-v3.1-terminus-tools",
        "name": "NVIDIA NIM — DeepSeek V3.1 Terminus (tool calling + thinking)",
        "description": "LiteLLM :4000 → NIM deepseek-v3.1-terminus; модель …-tools; chat_template_kwargs (thinking)",
        "envKey": "OPENAI_API_KEY",
        "baseUrl": "http://127.0.0.1:4000/v1",
        "generationConfig": {
          "timeout": 600000,
          "maxRetries": 4,
          "contextWindowSize": 131072,
          "extra_body": {
            "chat_template_kwargs": {
              "thinking": true
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
  "security": {
    "auth": {
      "selectedType": "openai"
    }
  },
  "model": {
    "name": "nim-deepseek-v3.1-terminus-tools"
  },
  "$version": 3
}
```

`**qwen-sessions/zai-glm47/.qwen/settings.json**`

```json
{
  "modelProviders": {
    "openai": [
      {
        "id": "glm-4.7",
        "name": "Z.AI GLM-4.7 (tool calling + thinking)",
        "description": "api.z.ai Coding (OpenAI); function/tool вызовы включены на стороне клиента Qwen Code; thinking через extra_body / chat_template_kwargs",
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
  "security": {
    "auth": {
      "selectedType": "openai"
    }
  },
  "model": {
    "name": "glm-4.7"
  },
  "$version": 3
}
```

---

## 5. LiteLLM для пресетов NIM (порт 4000)

`run-qwen-code-nvidia-nim.ps1` ожидает:

1. Слушающий порт **4000** на `127.0.0.1`, либо
2. Скрипт запуска: `**%USERPROFILE%\.qwen\litellm\start-nvidia-nim-proxy.ps1`**

Создайте каталог `%USERPROFILE%\.qwen\litellm\` и разместите там свой прокси-лаунчер. Пример **шаблона** (адаптируйте под ваш `config.yaml` и способ вызова `litellm`):

```powershell
# %USERPROFILE%\.qwen\litellm\start-nvidia-nim-proxy.ps1  (ШАБЛОН)
$ErrorActionPreference = "Stop"
$env:NVIDIA_NIM_API_KEY = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
if ([string]::IsNullOrWhiteSpace($env:NVIDIA_NIM_API_KEY)) {
  throw "Задайте пользовательскую переменную NVIDIA_NIM_API_KEY"
}
$here = $PSScriptRoot
$config = Join-Path $here "litellm-nim-config.yaml"
if (-not (Test-Path -LiteralPath $config)) {
  throw "Создайте $config — см. документацию LiteLLM и маппинг model_list на integrate.api.nvidia.com"
}
# Пример: litellm в PATH после pipx/pip install
litellm --config $config --port 4000 --host 127.0.0.1
```

В `config.yaml` должны быть объявлены имена моделей в точности как в `settings.json` сессий (`nim-glm-4.7-tools`, `nim-deepseek-v3.1-terminus-tools` и т.д.) с `api_base: https://integrate.api.nvidia.com/v1` и ключом из окружения. Конкретное содержимое YAML зависит от вашей подписки и имён моделей в каталоге NIM — **не** включайте ключи в файл, используйте `os.environ/NVIDIA_NIM_API_KEY` в стиле LiteLLM.

### 5.1. Пример `litellm-nim-config.yaml` (шаблон)

Подставьте **реальные** `model:` строки из каталога NIM (как ожидает LiteLLM для OpenAI-совместимого вызова). Имена в `model_name` — те, что видит Qwen Code (`nim-glm-4.7-tools` и т.д.).

```yaml
# Шаблон: положите рядом со start-nvidia-nim-proxy.ps1
# Ключ: только через env NVIDIA_NIM_API_KEY (не пишите ключ в файл)

model_list:
  - model_name: nim-glm-4.7-tools
    litellm_params:
      model: openai/z-ai/glm4.7
      api_base: https://integrate.api.nvidia.com/v1
      api_key: os.environ/NVIDIA_NIM_API_KEY
  - model_name: nim-deepseek-v3.1-terminus-tools
    litellm_params:
      model: openai/deepseek-ai/deepseek-v3.1-terminus
      api_base: https://integrate.api.nvidia.com/v1
      api_key: os.environ/NVIDIA_NIM_API_KEY

general_settings:
  master_key: optional-local-master-key
```

Если LiteLLM ругается на формат `model:` для вашей версии, сверьтесь с [документацией LiteLLM](https://docs.litellm.ai/docs/proxy/configs) — логика та же: два алиаса на один `api_base` integrate.

---

## 6. free-claude-code для Claude Code → NIM

1. Откройте терминал в `$RepoRoot\free-claude-code`.
2. Установите зависимости через uv (как принято в проекте): например `uv sync`.
3. Прокси поднимается скриптом `run-claude-cloud-session.ps1` через `uv run uvicorn server:app --host 127.0.0.1 --port <порт>`.

Порты по умолчанию в логике лаунчера:

- GLM NIM: **8082** (если не переопределён)
- DeepSeek Terminus: **8083**

Переменные для процесса прокси (без вывода значений в лог пользователя): `NVIDIA_NIM_API_KEY`, `MODEL`, `ANTHROPIC_AUTH_TOKEN` (локальный токен доверия к прокси, не путать с облачным секретом провайдера).

---

## 7. claude-mem

1. Установите плагин по инструкции проекта [claude-mem](https://github.com/thedotmack/claude-mem) (marketplace / `npx claude-mem`).
2. Запуск воркера: см. скрипт `start-claude-mem.ps1` в репозитории (порт **37777**).

Проверка: `http://127.0.0.1:37777/` открывается после `npx claude-mem start`.

---

## 8. Obsidian

1. Установите [Obsidian](https://obsidian.md/).
2. Создайте хранилище (vault) для проектов агента.
3. В `run-claude-cloud-launcher.ps1` и `run-claude-cloud-session.ps1` задайте **свои** `-VaultPath` и `-ObsidianExe` (или отредактируйте значения по умолчанию в файлах).

---

## 9. Логика совместимости NIM (whitelist, прокси, обрезка контекста)

**Белый список каталоговых id** (нативный tool calling, без `tool_choice=none` для совместимости с vLLM):

- `z-ai/glm4.7`
- `qwen/qwen3.5-122b-a10b`
- `deepseek-ai/deepseek-v3.1-terminus`

Для **остальных** NIM-моделей:


| Компонент                                            | Поведение                                                                                                                      |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Qwen Code (`run-qwen-code-dynamic.ps1`)              | Локальный прокси `nim-integrate-string-content-proxy.mjs`, `tool_choice=none`, `skipStartupContext`, tier micro/standard/large |
| Claude (`run-claude-cloud-launcher.ps1`)             | `--tools minimal` если модель не в whitelist                                                                                   |
| free-claude-code (`providers/nvidia_nim/request.py`) | flatten `content`, `tool_choice=none`, cap `max_tokens`, обрезка сообщений по бюджету                                          |


**Типичные ошибки API:**

- `400` из-за массива в `content` → flatten в строку.
- `400` из-за `tool_choice=auto` на бэкендах без auto tool choice → `none`.
- `400` при маленьком контексте (например 4096) и длинной истории → tier **micro** + trim в прокси и в Python.

---

## 10. Ярлыки на рабочем столе: эквивалент `.lnk` в PowerShell

Файлы `.lnk` бинарные; их свойства воспроизводятся скриптом. Ниже **один скрипт**, который создаёт:

- `Claude Code (cloud).lnk`
- `Qwen Code (cloud).lnk`
- `Claude Mem Start.lnk`
- `Claude Mem Viewer.lnk`

**Полный текст** скрипта генерации этих четырёх ярлыков — в репозитории `scripts/create-desktop-shortcuts.ps1` и дублируется в **§11.15** этого документа (один в один).

Запуск с корня репозитория:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-desktop-shortcuts.ps1 -RepoRoot "D:\qwen-local-setup"
```

Параметры `-DesktopPath` и `-IconLocation` опциональны (по умолчанию — рабочий стол текущего пользователя и `%USERPROFILE%\Pictures\claudecode.ico,0`).

Скрипт `scripts/update-cloud-shortcuts.ps1` создаёт ярлыки с **длинными именами** (`Claude Code (Cloud — выбор провайдера).lnk`, `Qwen Code (Cloud — выбор профиля).lnk`); переносимая версия — **§11.12**.

---

## 11. Полные тексты ключевых скриптов

Ниже — копии файлов из `scripts/` и (с **§11.14**) из `free-claude-code/providers/nvidia_nim/` на момент последней сборки этого документа. При расхождении с репозиторием **приоритет у файлов в git**.

Структура: **§11.1–11.4** — терминал, claude-mem, Node-прокси NIM, динамический Qwen; **§11.5–11.6** — пресеты NIM и Z.AI; **§11.7–11.8** — лаунчер и сессия Claude; **§11.9–11.11** — списки моделей, TUI, мастер «Другая модель»; **§11.12** — `update-cloud-shortcuts.ps1` (длинные имена ярлыков, переносимый `RepoRoot`); **§11.13** — меню Qwen; **§11.14** — `request.py` (free-claude-code); **§11.15** — `create-desktop-shortcuts.ps1` (четыре ярлыка cloud + mem); **§11.16** — `set-cloud-api-keys.ps1` (интерактивная запись User env без вывода ключей в консоль).

Лаунчеры **§11.7** и **§11.13** подключают через dot-source `launcher-tui.ps1`, `launcher-provider-models.ps1`, `launcher-custom-model-wizard.ps1` — эти три файла должны лежать рядом в `scripts/`.

### 11.1. `ensure-streaming-friendly-terminal.ps1`

```powershell
# Dot-source перед интерактивным Qwen Code / Claude Code:
#   . (Join-Path $PSScriptRoot 'ensure-streaming-friendly-terminal.ps1')
#
# Qwen Code (Ink + is-in-ci): любые CI_* / CI / CONTINUOUS_INTEGRATION дают «не CI-терминал» —
# страдает интерактив и по ощущениям стриминг (пакетная отрисовка).
# Claude Code в обычном cmd /k тоже не должен видеть фальш-CI.

foreach ($name in @(
    'CI',
    'CONTINUOUS_INTEGRATION',
    'GITHUB_ACTIONS',
    'GITLAB_CI',
    'BUILDKITE',
    'TEAMCITY_VERSION',
    'JENKINS_URL',
    'TRAVIS',
    'CIRCLECI'
  )) {
  if (Test-Path -LiteralPath "Env:$name") {
    Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
  }
}

foreach ($var in @(Get-ChildItem Env: -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'CI_*' })) {
  Remove-Item -LiteralPath ("Env:{0}" -f $var.Name) -ErrorAction SilentlyContinue
}

if (-not $env:PYTHONUNBUFFERED) {
  $env:PYTHONUNBUFFERED = "1"
}
```

### 11.2. `start-claude-mem.ps1`

```powershell
[CmdletBinding()]
param(
  [int]$OpenBrowser = 0,
  [switch]$SkipStatus,
  [switch]$RepairInstall
)

$ErrorActionPreference = "Stop"

$npmBin = Join-Path $env:APPDATA "npm"
if (Test-Path -LiteralPath $npmBin) {
  $env:PATH = $npmBin + ";" + $env:PATH
}
$bunBin = Join-Path $HOME ".bun\bin"
if (Test-Path -LiteralPath $bunBin) {
  $env:PATH = $bunBin + ";" + $env:PATH
}

function Test-ClaudeMemPortOpen {
  $c = $null
  try {
    $c = New-Object System.Net.Sockets.TcpClient
    $ar = $c.BeginConnect("127.0.0.1", 37777, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne(600)) { return $false }
    $c.EndConnect($ar)
    return $c.Connected
  } catch {
    return $false
  } finally {
    if ($null -ne $c) { try { $c.Close() } catch {} }
  }
}

function Wait-ClaudeMemReady {
  param([int]$TimeoutSec = 20)
  $deadline = (Get-Date).AddSeconds([Math]::Max(1, $TimeoutSec))
  while ((Get-Date) -lt $deadline) {
    if (Test-ClaudeMemPortOpen) { return $true }
    Start-Sleep -Milliseconds 400
  }
  return $false
}

function Start-ClaudeMemFallbackDirect {
  $pluginDir = Join-Path $HOME ".claude\plugins\marketplaces\thedotmack\plugin"
  $workerScript = Join-Path $pluginDir "scripts\worker-service.cjs"
  if (-not (Test-Path -LiteralPath $workerScript)) {
    Write-Host "claude-mem: fallback недоступен (не найден worker-service.cjs)." -ForegroundColor DarkYellow
    return $false
  }

  $logDir = Join-Path $HOME ".qwen-local-setup"
  if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $outLog = Join-Path $logDir "claude-mem.fallback.$stamp.out.log"
  $errLog = Join-Path $logDir "claude-mem.fallback.$stamp.err.log"

  $bunExe = $null
  try {
    $bunCmd = Get-Command bun -ErrorAction SilentlyContinue
    if ($bunCmd) { $bunExe = $bunCmd.Source }
  } catch {}
  if (-not $bunExe) {
    $bunExe = Join-Path $HOME ".bun\bin\bun.exe"
  }
  if (-not (Test-Path -LiteralPath $bunExe)) {
    Write-Host "claude-mem: fallback недоступен (bun.exe не найден)." -ForegroundColor Red
    return $false
  }
  try {
    Start-Process -FilePath $bunExe -WorkingDirectory $pluginDir -ArgumentList @("scripts/worker-service.cjs") -WindowStyle Hidden -RedirectStandardOutput $outLog -RedirectStandardError $errLog | Out-Null
  } catch {
    Write-Host "claude-mem: fallback запуск не удался: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }

  if (Wait-ClaudeMemReady -TimeoutSec 25) {
    Write-Host "claude-mem: fallback успешно поднял worker (127.0.0.1:37777)." -ForegroundColor Green
    return $true
  }

  Write-Host "claude-mem: fallback не поднял порт 37777. Логи: $outLog ; $errLog" -ForegroundColor Red
  return $false
}

function Repair-ClaudeMemInstall {
  Write-Host "claude-mem: выполняю self-repair (npx claude-mem update)…" -ForegroundColor DarkYellow
  try {
    npx --yes claude-mem update | Out-Null
    return $true
  } catch {
    Write-Host "claude-mem: self-repair не удался: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

$pidFile = Join-Path $HOME ".claude-mem\worker.pid"

if (Test-ClaudeMemPortOpen) {
  Write-Host "claude-mem уже слушает 127.0.0.1:37777 — повторный старт не нужен." -ForegroundColor DarkGreen
  if ($OpenBrowser -ne 0) {
    try { Start-Process "http://127.0.0.1:37777/" | Out-Null } catch {}
  }
  if (-not $SkipStatus) {
    npx --yes claude-mem status
  }
  exit 0
}

if ($RepairInstall) {
  Write-Host "claude-mem: update (repair)…" -ForegroundColor Cyan
  npx --yes claude-mem update
}

Write-Host "claude-mem: остановка и очистка stale PID…" -ForegroundColor DarkCyan
try { npx --yes claude-mem stop 2>$null } catch {}
Start-Sleep -Milliseconds 500
if (Test-Path -LiteralPath $pidFile) {
  try { Remove-Item -LiteralPath $pidFile -Force -ErrorAction Stop } catch {}
}

Write-Host "claude-mem: start…" -ForegroundColor Cyan
npx --yes claude-mem start

if (-not (Wait-ClaudeMemReady -TimeoutSec 10)) {
  Write-Host "claude-mem: npx start не поднял worker, включаю fallback через bun…" -ForegroundColor DarkYellow
  if (Repair-ClaudeMemInstall) {
    Write-Host "claude-mem: повторный старт после self-repair…" -ForegroundColor DarkYellow
    npx --yes claude-mem start
  }
  if (-not (Wait-ClaudeMemReady -TimeoutSec 12)) {
    [void](Start-ClaudeMemFallbackDirect)
  }
}

if (-not $SkipStatus) {
  Start-Sleep -Seconds 2
  npx --yes claude-mem status
  if (Test-ClaudeMemPortOpen) {
    Write-Host "claude-mem: worker доступен на http://127.0.0.1:37777/" -ForegroundColor Green
  } else {
    Write-Host "claude-mem: worker всё ещё не запущен." -ForegroundColor Red
  }
}

if ($OpenBrowser -ne 0) {
  try { Start-Process "http://127.0.0.1:37777/" | Out-Null } catch {}
}
```

### 11.3. `nim-integrate-string-content-proxy.mjs`

```javascript
/**
 * Локальный OpenAI-совместимый прокси для NVIDIA integrate NIM (динамические модели вне whitelist):
 * 1) content: string (flatten массива частей)
 * 2) усечение messages по бюджету context − max_tokens − margin (Qwen Code иначе шлёт 8k+ токенов при ctx=4096)
 * Tier и лимиты совпадают с run-qwen-code-dynamic.ps1 / free-claude-code request.py.
 */
import http from "node:http";
import { Readable } from "node:stream";

const UPSTREAM_ORIGIN = (process.env.NIM_UPSTREAM_ORIGIN || "https://integrate.api.nvidia.com").replace(/\/$/, "");
const argvPort = process.argv[2] ? parseInt(process.argv[2], 10) : 0;
const PORT = Number.isFinite(argvPort) && argvPort > 0 ? argvPort : parseInt(process.env.NIM_FLATTEN_PROXY_PORT || "0", 10);

const MICRO_RE =
  /nemotron-mini|nemotron-3-content-safety|content-safety-reasoning|\/gliner|\/pii|\b300m\b|nemoretriever|nv-embed|embedcode|cosmos-transfer|cosmos-predict|magpie-tts|voicechat|safety-guard|zeroshot|llama-3\.1-nemotron-safety|transfer2\.5-2b|transfer1-7b|riva-translate|synthetic-video|active-speaker|video-detector|parakeet|whisper|\/tts|text-to-speech/i;
const LARGE_RE =
  /480b|235b|405b|70b|8x7b|8x22b|106b-a47b|\b128k\b|\b1m\b|qwen3-coder|minimax-m2|step-3\.5|solar-10\.7/i;

function tierFromModel(model) {
  const m = String(model || "").toLowerCase();
  if (MICRO_RE.test(m)) return "micro";
  if (LARGE_RE.test(m)) return "large";
  return "standard";
}

function ctxLimitFromTier(tier) {
  if (tier === "micro") return 4096;
  if (tier === "large") return 131072;
  return 16384;
}

function defaultMaxOut(tier) {
  if (tier === "micro") return 512;
  if (tier === "large") return 8192;
  return 2048;
}

function flattenContent(content) {
  if (content == null) return content;
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return content;
  const parts = [];
  for (const part of content) {
    if (typeof part === "string") {
      parts.push(part);
      continue;
    }
    if (part && typeof part === "object" && part.type === "text" && part.text != null) {
      parts.push(String(part.text));
    }
  }
  return parts.filter((p) => p.length > 0).join("\n\n");
}

function flattenBody(body) {
  if (!body || typeof body !== "object" || !Array.isArray(body.messages)) return body;
  return {
    ...body,
    messages: body.messages.map((m) => {
      if (!m || typeof m !== "object") return m;
      const content = flattenContent(m.content);
      return { ...m, content };
    }),
  };
}

function estMessagesTokens(messages) {
  if (!Array.isArray(messages)) return 0;
  let s = 0;
  for (const m of messages) {
    try {
      s += Math.max(4, Math.ceil(JSON.stringify(m ?? {}).length / 4));
    } catch {
      s += 64;
    }
  }
  return s;
}

function trimMessagesForBudget(messages, maxInputTokens) {
  if (!Array.isArray(messages)) return messages;
  const out = messages.map((m) => (m && typeof m === "object" ? { ...m } : m));
  let guard = 0;
  while (estMessagesTokens(out) > maxInputTokens && guard++ < 2000) {
    if (out.length <= 1) {
      const m0 = out[0];
      if (m0 && typeof m0 === "object" && typeof m0.content === "string") {
        const c = m0.content;
        const targetChars = Math.max(800, (maxInputTokens - 24) * 3);
        if (c.length > targetChars) {
          m0.content = "[truncated]\n" + c.slice(-targetChars);
        }
      }
      break;
    }
    if (out[0]?.role === "system" && out.length > 1) {
      out.splice(1, 1);
    } else {
      out.splice(0, 1);
    }
  }
  return out;
}

function applyNimCompat(body) {
  const b = flattenBody(typeof body === "object" && body ? { ...body } : body);
  const tier = tierFromModel(b.model);
  const ctx = ctxLimitFromTier(tier);
  const defOut = defaultMaxOut(tier);
  let maxOut = Number(b.max_tokens);
  if (!Number.isFinite(maxOut) || maxOut <= 0) maxOut = defOut;
  maxOut = Math.min(maxOut, defOut);
  b.max_tokens = maxOut;
  const margin = tier === "micro" ? 384 : 640;
  const maxInput = Math.max(200, ctx - maxOut - margin);
  b.messages = trimMessagesForBudget(b.messages || [], maxInput);
  return b;
}

function hopByHop(name) {
  const n = name.toLowerCase();
  return (
    n === "connection" ||
    n === "keep-alive" ||
    n === "proxy-authenticate" ||
    n === "proxy-authorization" ||
    n === "te" ||
    n === "trailers" ||
    n === "transfer-encoding" ||
    n === "upgrade"
  );
}

async function readJsonBody(req) {
  const chunks = [];
  for await (const ch of req) chunks.push(ch);
  const raw = Buffer.concat(chunks).toString("utf8");
  if (!raw.trim()) return {};
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

if (!Number.isFinite(PORT) || PORT <= 0) {
  console.error("nim-integrate-string-content-proxy: pass port as argv (node …mjs 39081) or set NIM_FLATTEN_PROXY_PORT.");
  process.exit(1);
}

const server = http.createServer(async (req, res) => {
  try {
    const host = req.headers.host || `127.0.0.1:${PORT}`;
    const url = new URL(req.url || "/", `http://${host}`);

    if (req.method === "GET" && url.pathname === "/v1/models") {
      const r = await fetch(`${UPSTREAM_ORIGIN}/v1/models`, {
        headers: { authorization: req.headers.authorization || "" },
      });
      res.writeHead(r.status);
      if (r.body) Readable.fromWeb(r.body).pipe(res);
      else res.end();
      return;
    }

    if (req.method === "POST" && url.pathname === "/v1/chat/completions") {
      const body = await readJsonBody(req);
      if (body === null) {
        res.writeHead(400, { "content-type": "application/json" });
        res.end(JSON.stringify({ error: { message: "invalid json" } }));
        return;
      }
      const flat = applyNimCompat(body);
      const r = await fetch(`${UPSTREAM_ORIGIN}/v1/chat/completions`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: req.headers.authorization || "",
        },
        body: JSON.stringify(flat),
      });
      const outHeaders = {};
      r.headers.forEach((v, k) => {
        if (!hopByHop(k)) outHeaders[k] = v;
      });
      res.writeHead(r.status, outHeaders);
      if (r.body) Readable.fromWeb(r.body).pipe(res);
      else res.end();
      return;
    }

    res.writeHead(404, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: { message: "not found" } }));
  } catch (e) {
    res.writeHead(502, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: { message: String(e && e.message ? e.message : e) } }));
  }
});

server.listen(PORT, "127.0.0.1", () => {
  console.error(`nim-integrate-string-content-proxy: http://127.0.0.1:${PORT}/v1 → ${UPSTREAM_ORIGIN}/v1`);
});
```

### 11.4. `run-qwen-code-dynamic.ps1`

```powershell
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("zai", "nim")]
  [string]$Provider,

  [Parameter(Mandatory = $true)]
  [string]$ModelId
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")
. (Join-Path $PSScriptRoot "launcher-provider-models.ps1")

function Read-SecretText([string]$Prompt) {
  $sec = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Ensure-NpmBinInPath {
  $npmBin = Join-Path $env:APPDATA "npm"
  if (Test-Path -LiteralPath $npmBin) {
    $env:PATH = $npmBin + ";" + $env:PATH
  }
}

function Resolve-QwenExe {
  $cmd = Get-Command qwen -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @(
      (Join-Path $env:APPDATA "npm\qwen.cmd"),
      (Join-Path $env:APPDATA "npm\qwen.ps1")
    )) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

function Get-SafeDirName([string]$s) {
  $x = ($s -replace '[^a-zA-Z0-9._-]', '_')
  if ($x.Length -gt 48) { $x = $x.Substring(0, 48) }
  if ([string]::IsNullOrWhiteSpace($x)) { $x = "model" }
  return $x
}

function Build-QwenSettingsZai([string]$Mid) {
  return @{
    modelProviders = @{
      openai = @(
        @{
          id           = $Mid
          name         = ("Z.AI — {0} (dynamic)" -f $Mid)
          description  = "Coding API; extra_body как у GLM-4.7"
          envKey       = "OPENAI_API_KEY"
          baseUrl      = "https://api.z.ai/api/coding/paas/v4"
          generationConfig = @{
            timeout            = 600000
            maxRetries         = 4
            contextWindowSize  = 202752
            extra_body         = @{
              enable_thinking       = $true
              chat_template_kwargs  = @{
                enable_thinking = $true
                clear_thinking  = $false
              }
            }
            samplingParams = @{
              temperature = 0.6
              top_p         = 0.95
              max_tokens    = 81920
            }
          }
        }
      )
    }
    security = @{
      auth = @{ selectedType = "openai" }
    }
    model = @{ name = $Mid }
  }
}

function Get-FreeListenPort {
  param([int]$Min = 39080, [int]$Max = 39179)
  for ($p = $Min; $p -le $Max; $p++) {
    $c = $null
    try {
      $c = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $p)
      $c.Start()
      $c.Stop()
      return $p
    } catch {
      if ($c) { try { $c.Stop() } catch {} }
    }
  }
  throw "Не найден свободный TCP-порт в диапазоне $Min-$Max для NIM-прокси."
}

function Wait-TcpListen {
  param([int]$Port, [int]$TimeoutSec = 15)
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
  while ([DateTime]::UtcNow -lt $deadline) {
    $c = $null
    try {
      $c = New-Object System.Net.Sockets.TcpClient
      $c.ReceiveTimeout = 800
      $c.SendTimeout = 800
      $ar = $c.BeginConnect("127.0.0.1", $Port, $null, $null)
      if (-not $ar.AsyncWaitHandle.WaitOne(900)) { continue }
      $c.EndConnect($ar)
      return
    } catch {
    } finally {
      if ($c) { try { $c.Close() } catch {} }
    }
    Start-Sleep -Milliseconds 200
  }
  throw "Прокси NIM не поднялся на 127.0.0.1:$Port за $TimeoutSec с."
}

function Start-NimStringContentProxy {
  param([int]$Port)
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) { throw "node не в PATH — нужен для nim-integrate-string-content-proxy.mjs" }
  $scriptPath = Join-Path $PSScriptRoot "nim-integrate-string-content-proxy.mjs"
  if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Не найден $scriptPath" }
  Start-Process -FilePath $node.Source -ArgumentList @("`"$scriptPath`"", "$Port") -WorkingDirectory $PSScriptRoot -WindowStyle Hidden | Out-Null
}

function Get-NimDynamicCompatLimits {
  param([Parameter(Mandatory = $true)][string]$ModelId)
  $l = $ModelId.Trim().ToLowerInvariant()
  while ($l.StartsWith("nvidia_nim/")) {
    $l = $l.Substring("nvidia_nim/".Length)
  }
  if ($l -match 'nemotron-mini|nemotron-3-content-safety|content-safety-reasoning|/gliner|/pii|\b300m\b|nemoretriever|nv-embed|embedcode|cosmos-transfer|cosmos-predict|magpie-tts|voicechat|safety-guard|zeroshot|llama-3\.1-nemotron-safety|transfer2\.5-2b|transfer1-7b|riva-translate|synthetic-video|active-speaker|video-detector|parakeet|whisper|/tts|text-to-speech') {
    return @{
      ContextWindowSize = 4096
      MaxTokens         = 512
      EnvMaxOutput      = 512
      Tier              = "micro"
    }
  }
  if ($l -match '480b|235b|405b|70b|8x7b|8x22b|106b-a47b|\b128k\b|\b1m\b|qwen3-coder|minimax-m2|step-3\.5|solar-10\.7') {
    return @{
      ContextWindowSize = 131072
      MaxTokens         = 8192
      EnvMaxOutput      = 8192
      Tier              = "large"
    }
  }
  return @{
    ContextWindowSize = 16384
    MaxTokens         = 2048
    EnvMaxOutput      = 2048
    Tier              = "standard"
  }
}

function Build-QwenSettingsNim {
  param(
    [string]$Mid,
    [string]$BaseUrl = "https://integrate.api.nvidia.com/v1",
    [switch]$MinimalCompat,
    [hashtable]$CompatLimits = $null
  )

  $nativeTools = Test-NvidiaNimOpenAiNativeToolCalling $Mid

  $extra = [ordered]@{}
  if (-not $MinimalCompat) {
    $lower = $Mid.ToLowerInvariant()
    if ($lower -match "deepseek|terminus") {
      $extra["chat_template_kwargs"] = @{ thinking = $true }
    } elseif ($lower -match "glm|z-ai") {
      $extra["chat_template_kwargs"] = @{ enable_thinking = $true; clear_thinking = $false }
    }
  }
  if (-not $nativeTools) {
    $extra["tool_choice"] = "none"
  }
  $extraHt = @{}
  foreach ($k in $extra.Keys) { $extraHt[$k] = $extra[$k] }

  if ($MinimalCompat) {
    if (-not $CompatLimits) {
      $CompatLimits = Get-NimDynamicCompatLimits $Mid
    }
    $ctxWin = [int]$CompatLimits.ContextWindowSize
    $maxTok = [int]$CompatLimits.MaxTokens
    $tier = [string]$CompatLimits.Tier
    $desc = ("127.0.0.1 прокси → integrate; tier={0} ctx={1} max_out={2}; content string; skipStartupContext; tool_choice=none" -f $tier, $ctxWin, $maxTok)
  } elseif ($nativeTools) {
    $desc = "Прямой integrate.api.nvidia.com/v1; NIM + нативный tool calling (каталог)"
  } else {
    $desc = "Прямой integrate.api.nvidia.com/v1; NIM без tool_choice=auto (extra_body.tool_choice=none)"
  }

  if (-not $MinimalCompat) {
    $maxTok = 81920
    $ctxWin = 131072
  }

  $modelBlock = @{ name = $Mid }
  if ($MinimalCompat) {
    $modelBlock["skipStartupContext"] = $true
  }

  return @{
    modelProviders = @{
      openai = @(
        @{
          id           = $Mid
          name         = ("NVIDIA NIM — {0} (dynamic)" -f $Mid)
          description  = $desc
          envKey       = "OPENAI_API_KEY"
          baseUrl      = $BaseUrl
          generationConfig = @{
            timeout            = 600000
            maxRetries         = 4
            contextWindowSize  = $ctxWin
            extra_body         = $extraHt
            samplingParams     = @{
              temperature = 0.6
              top_p         = 0.95
              max_tokens    = $maxTok
            }
          }
        }
      )
    }
    security = @{
      auth = @{ selectedType = "openai" }
    }
    model    = $modelBlock
  }
}

Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_OPUS_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_SONNET_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:OPENAI_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:OPENAI_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:DASHSCOPE_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:QWEN_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:ALIYUN_API_KEY -ErrorAction SilentlyContinue

$rootBase = Join-Path (Split-Path -Parent $PSScriptRoot) "qwen-sessions\_dynamic"
$slug = "{0}-{1}" -f $Provider, (Get-SafeDirName $ModelId)
$sessionRoot = Join-Path $rootBase $slug
$qwenDir = Join-Path $sessionRoot ".qwen"
if (-not (Test-Path -LiteralPath $qwenDir)) {
  New-Item -ItemType Directory -Path $qwenDir -Force | Out-Null
}

if ($Provider -eq "zai") {
  $key = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = $env:ZAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = $env:OPENAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = Read-SecretText "Z.AI API key" }
  $env:OPENAI_API_KEY = $key.Trim()
  $cfg = Build-QwenSettingsZai -Mid $ModelId.Trim()
} else {
  $key = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($key)) { $key = $env:NVIDIA_NIM_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key)) { $key = Read-SecretText "NVIDIA NIM API key" }
  $env:OPENAI_API_KEY = $key.Trim()
  $midTrim = $ModelId.Trim()
  $script:NimDynamicCompat = $false
  $script:NimCompatLimits = $null
  if (Test-NvidiaNimOpenAiNativeToolCalling $midTrim) {
    $cfg = Build-QwenSettingsNim -Mid $midTrim -BaseUrl "https://integrate.api.nvidia.com/v1"
  } else {
    $script:NimDynamicCompat = $true
    $script:NimCompatLimits = Get-NimDynamicCompatLimits $midTrim
    $px = Get-FreeListenPort
    Start-NimStringContentProxy -Port $px
    Wait-TcpListen -Port $px
    $cfg = Build-QwenSettingsNim -Mid $midTrim -BaseUrl ("http://127.0.0.1:{0}/v1" -f $px) -MinimalCompat -CompatLimits $script:NimCompatLimits
  }
}

$json = ($cfg | ConvertTo-Json -Depth 20)
$settingsPath = Join-Path $qwenDir "settings.json"
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))

$env:API_TIMEOUT_MS = "600000"
if ($Provider -eq "nim" -and $script:NimDynamicCompat -and $script:NimCompatLimits) {
  $env:QWEN_CODE_MAX_OUTPUT_TOKENS = [string]$script:NimCompatLimits.EnvMaxOutput
  $env:QWEN_CODE_EMIT_TOOL_USE_SUMMARIES = "0"
} else {
  $env:QWEN_CODE_MAX_OUTPUT_TOKENS = "81920"
  $env:QWEN_CODE_EMIT_TOOL_USE_SUMMARIES = "1"
}

Ensure-NpmBinInPath
$qwenExe = Resolve-QwenExe
if (-not $qwenExe) {
  throw "Qwen Code CLI не найден. npm install -g @qwen-code/qwen-code@latest"
}

Write-Host ("Qwen Code: {0} / модель {1} → {2}" -f $Provider, $ModelId, $sessionRoot) -ForegroundColor Cyan
if ($Provider -eq "nim" -and $script:NimDynamicCompat -and $script:NimCompatLimits) {
  Write-Host ("NIM (динамика): прокси string-content, skipStartupContext, tier={0} ctx={1} max_out={2} (см. settings.json)." -f $script:NimCompatLimits.Tier, $script:NimCompatLimits.ContextWindowSize, $script:NimCompatLimits.MaxTokens) -ForegroundColor DarkCyan
}

Push-Location $sessionRoot
try {
  & $qwenExe
} finally {
  Pop-Location
}
```

### 11.5. `run-qwen-code-nvidia-nim.ps1` (NIM пресет через LiteLLM)

```powershell
[CmdletBinding()]
param(
  [string]$Model = "nim-glm-4.7-tools"
)
$ErrorActionPreference = "Stop"

$ProgressPreference = "SilentlyContinue"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")

function Ensure-NpmBinInPath {
  $npmBin = "C:\Users\chelaxian\AppData\Roaming\npm"
  if (Test-Path -LiteralPath $npmBin) {
    $env:PATH = $npmBin + ";" + $env:PATH
  }
}

function Resolve-QwenExe {
  $cmd = Get-Command qwen -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @(
      "C:\Users\chelaxian\AppData\Roaming\npm\qwen.cmd",
      "C:\Users\chelaxian\AppData\Roaming\npm\qwen.ps1"
    )) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

function Resolve-QwenNimSessionRoot([string]$ModelId) {
  switch ($ModelId) {
    "nim-glm-4.7-tools" { return Join-Path (Split-Path -Parent $PSScriptRoot) "qwen-sessions\nim-glm-47" }
    "nim-deepseek-v3.1-terminus-tools" { return Join-Path (Split-Path -Parent $PSScriptRoot) "qwen-sessions\nim-deepseek-v31" }
    default { throw "Unsupported NIM model for session profile: $ModelId (expected nim-glm-4.7-tools or nim-deepseek-v3.1-terminus-tools)" }
  }
}

function Resolve-NimLiteLlmApiKey {
  $k = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k)) { $k = $env:NVIDIA_NIM_API_KEY }
  if (-not [string]::IsNullOrWhiteSpace($k)) { return $k.Trim() }

  $path = Join-Path $env:USERPROFILE ".qwen\settings.json"
  if (-not (Test-Path -LiteralPath $path)) { return "" }
  try {
    $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $mps = $cfg.modelProviders.openai
    if (-not $mps) { return "" }
    foreach ($entry in @($mps)) {
      $bu = [string]$entry.baseUrl
      $mid = [string]$entry.id
      if ($bu -match "127\.0\.0\.1:4000" -or $mid -match "^nim-") {
        $ek = [string]$entry.envKey
        if ([string]::IsNullOrWhiteSpace($ek)) { continue }
        $val = $cfg.env.$ek
        if ([string]::IsNullOrWhiteSpace($val)) { $val = [Environment]::GetEnvironmentVariable($ek, "User") }
        if ([string]::IsNullOrWhiteSpace($val)) { $val = [Environment]::GetEnvironmentVariable($ek, "Process") }
        if (-not [string]::IsNullOrWhiteSpace($val)) { return $val.Trim() }
      }
    }
  } catch {
    return ""
  }
  return ""
}

function Test-HttpOk([string]$Url, [int]$TimeoutSec = 3) {
  try {
    $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
    if ($iwr.Parameters.ContainsKey("UseBasicParsing")) {
      $r = Invoke-WebRequest -UseBasicParsing -Uri $Url -Method Get -TimeoutSec $TimeoutSec
    } else {
      $r = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSec
    }
    return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400)
  } catch {
    return $false
  }
}

Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue

$proxyPort = 4000
$isUp = $false
try {
  $conn = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $proxyPort -State Listen -ErrorAction Stop
  if ($conn) { $isUp = $true }
} catch { }

if (-not $isUp) {
  $proxyLauncher = Join-Path $env:USERPROFILE ".qwen\litellm\start-nvidia-nim-proxy.ps1"
  if (!(Test-Path -LiteralPath $proxyLauncher)) {
    throw "LiteLLM proxy launcher not found: $proxyLauncher"
  }

  $shell = (Get-Command pwsh -ErrorAction SilentlyContinue)
  $shellExe = if ($shell) { $shell.Source } else { (Get-Command powershell.exe -ErrorAction Stop).Source }

  $logDir = Join-Path $env:USERPROFILE ".qwen\litellm\logs"
  if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $outLog = Join-Path $logDir "litellm-proxy-$stamp.out.log"
  $errLog = Join-Path $logDir "litellm-proxy-$stamp.err.log"

  $p = Start-Process -FilePath $shellExe -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $proxyLauncher
  ) -WindowStyle Hidden -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog

  $readyUrl = "http://127.0.0.1:$proxyPort/v1/models"
  $deadline = (Get-Date).AddSeconds(60)
  while ((Get-Date) -lt $deadline) {
    if (Test-HttpOk -Url $readyUrl -TimeoutSec 3) { $isUp = $true; break }
    if ($p -and $p.HasExited) { break }
    Start-Sleep -Milliseconds 300
  }

  if (-not $isUp) {
    $hint = @()
    if ($p -and $p.HasExited) { $hint += "proxy exited early (exit=$($p.ExitCode))" }
    if (Test-Path -LiteralPath $errLog) { $hint += "stderr: $errLog" }
    if (Test-Path -LiteralPath $outLog) { $hint += "stdout: $outLog" }
    $suffix = if ($hint.Count -gt 0) { " (" + ($hint -join ", ") + ")" } else { "" }
    throw "LiteLLM proxy did not start on 127.0.0.1:$proxyPort$suffix"
  }
}

Remove-Item Env:OPENAI_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:OPENAI_MODEL -ErrorAction SilentlyContinue

$apiKey = Resolve-NimLiteLlmApiKey
if ([string]::IsNullOrWhiteSpace($apiKey)) {
  throw "NVIDIA NIM API key: задайте переменную пользователя NVIDIA_NIM_API_KEY или ключ в %USERPROFILE%\.qwen\settings.json для моделей на :4000."
}
$env:OPENAI_API_KEY = $apiKey

$sessionRoot = Resolve-QwenNimSessionRoot $Model
$projSettings = Join-Path $sessionRoot ".qwen\settings.json"
if (-not (Test-Path -LiteralPath $projSettings)) {
  throw "Не найден профиль сессии: $projSettings"
}

$env:QWEN_CODE_MAX_OUTPUT_TOKENS = "81920"
$env:QWEN_CODE_EMIT_TOOL_USE_SUMMARIES = "1"
$env:API_TIMEOUT_MS = "600000"

Ensure-NpmBinInPath
$qwenExe = Resolve-QwenExe
if (-not $qwenExe) {
  throw "Qwen Code CLI not found. Reinstall with: npm install -g @qwen-code/qwen-code@latest"
}

Write-Host "Launching Qwen Code (NVIDIA NIM, $Model — tools + thinking via modelProviders) ..." -ForegroundColor Cyan

Push-Location $sessionRoot
try {
  & $qwenExe
} finally {
  Pop-Location
}
```

### 11.6. `run-qwen-code-cloud-zai-glm47.ps1` (Z.AI GLM-4.7 сессия)

```powershell
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")

function Read-SecretText([string]$Prompt) {
  $sec = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Ensure-NpmBinInPath {
  $npmBin = "C:\Users\chelaxian\AppData\Roaming\npm"
  if (Test-Path -LiteralPath $npmBin) {
    $env:PATH = $npmBin + ";" + $env:PATH
  }
}

function Resolve-QwenExe {
  $cmd = Get-Command qwen -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @(
    "C:\Users\chelaxian\AppData\Roaming\npm\qwen.cmd",
    "C:\Users\chelaxian\AppData\Roaming\npm\qwen.ps1"
  )
  foreach ($p in $candidates) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

Write-Host "Launching Qwen Code (Z.AI GLM-4.7: thinking + agent tools) ..." -ForegroundColor Cyan

$sessionRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "qwen-sessions\zai-glm47"
if (-not (Test-Path -LiteralPath (Join-Path $sessionRoot ".qwen\settings.json"))) {
  throw "Missing project settings: $(Join-Path $sessionRoot '.qwen\settings.json')"
}

# Do not leak Claude / proxy Anthropic vars into Qwen Code (OpenAI protocol).
Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_OPUS_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_SONNET_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue

$zaiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY","User")
if ([string]::IsNullOrWhiteSpace($zaiKey) -or $zaiKey -eq "__SET_ME__") {
  $zaiKey = $env:ZAI_API_KEY
}
if ([string]::IsNullOrWhiteSpace($zaiKey) -or $zaiKey -eq "__SET_ME__") {
  $zaiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY","User")
}
if ([string]::IsNullOrWhiteSpace($zaiKey) -or $zaiKey -eq "__SET_ME__") {
  $zaiKey = $env:OPENAI_API_KEY
}
if ([string]::IsNullOrWhiteSpace($zaiKey) -or $zaiKey -eq "__SET_ME__") {
  $zaiKey = Read-SecretText "Enter Z.AI API key (will not be saved)"
}

Ensure-NpmBinInPath

# Ключ в OPENAI_API_KEY; endpoint и extra_body (thinking) — в qwen-sessions/zai-glm47/.qwen/settings.json.
$env:OPENAI_API_KEY = $zaiKey
# baseUrl задаётся в qwen-sessions/zai-glm47/.qwen/settings.json (modelProviders), чтобы применить extra_body (thinking).
Remove-Item Env:OPENAI_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:OPENAI_MODEL -ErrorAction SilentlyContinue
$env:API_TIMEOUT_MS = "600000"
$env:QWEN_CODE_MAX_OUTPUT_TOKENS = "81920"
$env:QWEN_CODE_EMIT_TOOL_USE_SUMMARIES = "1"

$qwenExe = Resolve-QwenExe
if (-not $qwenExe) {
  throw "Qwen Code CLI not found. Reinstall with: npm install -g @qwen-code/qwen-code@latest"
}

Push-Location $sessionRoot
try {
  & $qwenExe
} finally {
  Pop-Location
}
```

### 11.7. `run-claude-cloud-launcher.ps1` (меню Claude (облако))

```powershell
[CmdletBinding()]
param(
  [switch]$Quick
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")
. (Join-Path $PSScriptRoot "launcher-tui.ps1")
. (Join-Path $PSScriptRoot "launcher-provider-models.ps1")
. (Join-Path $PSScriptRoot "launcher-custom-model-wizard.ps1")
. (Join-Path $PSScriptRoot "launcher-api-keys.ps1")

$VaultPath = "C:\Users\chelaxian\Documents\Obsidian Vault"
$ObsidianExe = "C:\Users\chelaxian\AppData\Local\Programs\Obsidian\Obsidian.exe"

$StatePath = Join-Path $PSScriptRoot "claude-cloud-launcher-state.json"
$SessionScript = Join-Path $PSScriptRoot "run-claude-cloud-session.ps1"

if (-not (Test-Path -LiteralPath $SessionScript)) {
  throw "Не найден скрипт: $SessionScript"
}

Write-Host "Claude (облако): общая подготовка (claude-mem, Obsidian, настройки)…" -ForegroundColor DarkCyan
& $SessionScript -PrepareOnly `
  -VaultPath $VaultPath `
  -ObsidianExe $ObsidianExe `
  -OpenClaudeMemObserver 1 `
  -ClaudeMemMaxWaitSec 35

$script:Profiles = @(
  @{
    Id    = "last"
    Label = "Запустить с последними настройками (быстрый старт)"
  }
  @{
    Id    = "claude-zai"
    Label = "Z.AI — GLM-4.7 (Anthropic api.z.ai; Claude Code — tool calling)"
  }
  @{
    Id    = "claude-nim"
    Label = "NVIDIA NIM — GLM-4.7 (free-claude-code → NIM; tool calling)"
  }
  @{
    Id    = "claude-nim-qwen"
    Label = "NVIDIA NIM — Qwen3.5-122B-A10B (free-claude-code → NIM; tool calling)"
  }
  @{
    Id    = "custom-model"
    Label = "Другая модель… → Z.AI или NIM, список с API (прокрутка)"
  }
  @{
    Id    = "change-api-key"
    Label = "Сменить ключ API провайдера"
  }
)

function Get-LauncherState {
  if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
  try {
    return (Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Save-LauncherState {
  param(
    [Parameter(Mandatory = $true)][string]$ProfileId,
    [hashtable]$Extra = @{}
  )
  $obj = [ordered]@{
    profileId = $ProfileId
    updatedAt = (Get-Date).ToString("o")
  }
  foreach ($k in $Extra.Keys) {
    $obj[$k] = $Extra[$k]
  }
  ($obj | ConvertTo-Json -Compress) | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Resolve-ProfileFromState($state) {
  if (-not $state -or [string]::IsNullOrWhiteSpace($state.profileId)) { return $null }
  $id = [string]$state.profileId
  if ($id -in @(
      "claude-zai", "claude-nim", "claude-nim-qwen",
      "custom-claude-zai", "custom-claude-nim"
    )) { return $id }
  return $null
}

function Invoke-ClaudeCloudProfile {
  param(
    [Parameter(Mandatory = $true)][string]$ProfileId,
    # Быстрый старт без PrepareOnly: открыть observer один раз здесь (после меню Prepare уже открыл вкладку).
    [int]$OpenClaudeMemObserver = 0
  )

  Clear-Host
  Write-Host "Запуск сессии Claude Code (облако)…" -ForegroundColor Cyan
  Write-Host "Профиль: $ProfileId   Vault: $VaultPath" -ForegroundColor DarkGray
  [Console]::Out.Flush()

  switch ($ProfileId) {
    "claude-zai" {
      & $SessionScript -Provider zai -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-nim" {
      & $SessionScript -Provider nim -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-nim-qwen" {
      & $SessionScript -Provider nim-qwen -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "custom-claude-zai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId в claude-cloud-launcher-state.json. Выберите модель в «Другая модель»."
      }
      & $SessionScript -Provider zai -ZaiAnthropicModelId $mid.Trim() -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "custom-claude-nim" {
      $st = Get-LauncherState
      $full = [string]$st.customNimModel
      if ([string]::IsNullOrWhiteSpace($full)) {
        throw "Нет customNimModel в claude-cloud-launcher-state.json."
      }
      $catalog = $full.Trim().ToLowerInvariant()
      while ($catalog.StartsWith("nvidia_nim/")) {
        $catalog = $catalog.Substring("nvidia_nim/".Length)
      }
      $claudeTools = if (Test-NvidiaNimOpenAiNativeToolCalling $catalog) { "default" } else { "minimal" }
      $port = Get-LauncherFreeTcpPort
      & $SessionScript -Provider nim -NimModel $full.Trim() -ProxyPort $port -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools $claudeTools `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    default {
      throw "Неизвестный профиль: $ProfileId"
    }
  }
}

if ($Quick -or $env:CLAUDE_CLOUD_LAUNCHER_QUICK -eq "1") {
  $st = Get-LauncherState
  $resolvedId = Resolve-ProfileFromState $st
  if (-not $resolvedId) {
    Write-Host "Нет сохранённого профиля Claude (облако). Один раз выберите провайдер в меню." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit 2
  }
  Invoke-ClaudeCloudProfile -ProfileId $resolvedId -OpenClaudeMemObserver 1
  exit $LASTEXITCODE
}

$state = Get-LauncherState
$lastId = Resolve-ProfileFromState $state
$items = $script:Profiles
$startIdx = 0
if ($lastId) {
  for ($i = 0; $i -lt $items.Count; $i++) {
    if ($items[$i].Id -eq $lastId) { $startIdx = $i; break }
  }
} else {
  $startIdx = 1
}

while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "Claude" -Title "Claude Code (облако) — провайдер" -Subtitle "Z.AI Anthropic · NVIDIA NIM через free-claude-code" -Items $items -InitialIndex $startIdx -MaxVisible 14
  if (-not $choice) {
    Write-Host "Отменено." -ForegroundColor Yellow
    exit 0
  }

  $profileId = [string]$choice.Id

  if ($profileId -eq "custom-model") {
    $w = Invoke-LauncherCustomModelWizard -App "Claude"
    if ($null -eq $w) {
      Write-Host "Отменено." -ForegroundColor Yellow
      exit 0
    }
    if ($true -eq $w.__menuBack) { continue }
    if ($w.Provider -eq "zai") {
      Save-LauncherState -ProfileId "custom-claude-zai" -Extra @{ customModelId = [string]$w.ModelId }
      Invoke-ClaudeCloudProfile -ProfileId "custom-claude-zai"
    } else {
      Save-LauncherState -ProfileId "custom-claude-nim" -Extra @{ customNimModel = [string]$w.ClaudeNimModel }
      Invoke-ClaudeCloudProfile -ProfileId "custom-claude-nim"
    }
    exit $LASTEXITCODE
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "Claude"
    continue
  }

  if ($profileId -eq "last") {
    $st = Get-LauncherState
    $profileId = Resolve-ProfileFromState $st
    if (-not $profileId) {
      Write-Host "Сохранённый профиль не найден. Выберите пункт меню один раз." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      exit 2
    }
  } else {
    Save-LauncherState -ProfileId $profileId
  }

  Invoke-ClaudeCloudProfile -ProfileId $profileId
  exit $LASTEXITCODE
}
```

### 11.8. `run-claude-cloud-session.ps1` (сессия Claude + free-claude-code)

```powershell
[CmdletBinding(DefaultParameterSetName = "Full")]
param(
  [Parameter(ParameterSetName = "Full", Mandatory = $true)]
  [ValidateSet("zai", "nim", "nim-qwen")]
  [string]$Provider,

  [Parameter(ParameterSetName = "Prepare")]
  [switch]$PrepareOnly,

  [Parameter(ParameterSetName = "Full")]
  [switch]$SkipCommonPreamble,

  [string]$VaultPath = "C:\Users\chelaxian\Documents\Obsidian Vault",
  [string]$ObsidianExe = "C:\Users\chelaxian\AppData\Local\Programs\Obsidian\Obsidian.exe",
  # 0 = don't open browser tab, 1 = open viewer
  [int]$OpenClaudeMemObserver = 0,
  [int]$DryRun = 0,

  # Z.AI (Anthropic-compatible)
  [string]$ZaiApiKey = "",
  # Если задано (лаунчер «другая модель»), подставляется в ANTHROPIC_DEFAULT_* вместо glm-4.7.
  [string]$ZaiAnthropicModelId = "",

  # NVIDIA NIM via free-claude-code proxy
  [string]$NvidiaNimApiKey = "",
  [string]$FreeClaudeCodeDir = "I:\qwen-local-setup\free-claude-code",
  [int]$ProxyPort = 8082,
  [string]$ProxyAuthToken = "freecc",
  # Для -Provider nim-qwen значение ниже не используется (жёстко nvidia_nim/qwen/qwen3.5-122b-a10b); порт по умолчанию 8083.
  [string]$NimModel = "nvidia_nim/z-ai/glm4.7",

  # Claude Code knobs
  [string]$ClaudeTools = "default",

  # Не блокировать запуск Claude Code ожиданием claude-mem (37777)
  [switch]$SkipClaudeMem,
  # Макс. секунд ожидания claude-mem после npx start (холодный кэш npx может занять 30–60 с).
  [int]$ClaudeMemMaxWaitSec = 45
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")

function Ensure-NpmBinInPath {
  # Claude Code / npx: в ярлыках cmd /k и -NoProfile часто нет Roaming\npm и Node.
  $npmBin = Join-Path $env:APPDATA "npm"
  if ($npmBin -and (Test-Path -LiteralPath $npmBin)) {
    $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $npmBin.TrimEnd('\') })) {
      $env:PATH = $npmBin + ";" + $env:PATH
    }
  }
}

function Ensure-ClaudeSidecarPath {
  Ensure-NpmBinInPath
  foreach ($nodeDir in @(
      (Join-Path ${env:ProgramFiles} "nodejs"),
      (Join-Path ${env:ProgramFiles(x86)} "nodejs")
    )) {
    if ($nodeDir -and (Test-Path -LiteralPath $nodeDir)) {
      $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
      $nd = $nodeDir.TrimEnd('\')
      if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $nd })) {
        $env:PATH = $nodeDir + ";" + $env:PATH
      }
    }
  }
  $bunBin = Join-Path $HOME ".bun\bin"
  if (Test-Path -LiteralPath $bunBin) {
    $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    $bb = $bunBin.TrimEnd('\')
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $bb })) {
      $env:PATH = $bunBin + ";" + $env:PATH
    }
  }
}

function Test-HttpOk([string]$Url,[int]$TimeoutSec = 3) {
  try {
    # Avoid the "Script Execution Risk" prompt in Windows PowerShell (5.1).
    $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
    if ($iwr.Parameters.ContainsKey("UseBasicParsing")) {
      $r = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec $TimeoutSec -UseBasicParsing
    } else {
      $r = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec $TimeoutSec
    }
    return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400)
  } catch {
    return $false
  }
}

function Test-HttpResponding([string]$Url,[int]$TimeoutSec = 3) {
  # "Responding" means the server returned any HTTP response (including 401/403/404).
  # This is used for readiness checks where auth may be required for 2xx.
  try {
    $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
    $useBasic = $iwr.Parameters.ContainsKey("UseBasicParsing")

    # Prefer GET for readiness. Some servers log noisy 405 for HEAD (e.g. /v1/models).
    if ($useBasic) {
      $null = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSec -UseBasicParsing
    } else {
      $null = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSec
    }
    return $true
  } catch {
    try {
      if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { return $true }
    } catch {}
    return $false
  }
}

function Ensure-ClaudeSettingsNoBom {
  $dir = Join-Path $HOME ".claude"
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $path = Join-Path $dir "settings.json"
  $obj = @{}
  if (Test-Path -LiteralPath $path) {
    try { $obj = (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json) } catch { $obj = @{} }
  }
  if (-not $obj.env) { $obj | Add-Member -NotePropertyName env -NotePropertyValue @{} -Force }
  $obj.env.CLAUDE_CODE_ATTRIBUTION_HEADER = "0"
  $obj.env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
  $json = ($obj | ConvertTo-Json -Depth 10)
  [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Test-ClaudeMemTcp37777 {
  $c = $null
  try {
    $c = New-Object System.Net.Sockets.TcpClient
    $ar = $c.BeginConnect("127.0.0.1", 37777, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne(800)) { return $false }
    $c.EndConnect($ar)
    return $c.Connected
  } catch {
    return $false
  } finally {
    if ($c) { try { $c.Close() } catch {} }
  }
}

function Test-ClaudeMemWorkerUp {
  if (Test-ClaudeMemTcp37777) { return $true }
  try {
    $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
    $useBasic = $iwr.Parameters.ContainsKey("UseBasicParsing")
    if ($useBasic) {
      $r = Invoke-WebRequest -Uri "http://127.0.0.1:37777/" -Method Get -TimeoutSec 2 -UseBasicParsing
    } else {
      $r = Invoke-WebRequest -Uri "http://127.0.0.1:37777/" -Method Get -TimeoutSec 2
    }
    return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500)
  } catch {
    return $false
  }
}

function Ensure-ClaudeMemWorker {
  if ($SkipClaudeMem) { return }
  if (Test-ClaudeMemWorkerUp) { return }
  Ensure-ClaudeSidecarPath

  $logDir = Join-Path $HOME ".qwen-local-setup"
  if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $outLog = Join-Path $logDir "claude-mem.cloud.$stamp.out.log"
  $errLog = Join-Path $logDir "claude-mem.cloud.$stamp.err.log"

  $memStarter = Join-Path $PSScriptRoot "start-claude-mem.ps1"
  $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
  if (-not $psExe) { $psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" }

  try {
    # 1) Тот же сценарий, что у вас вручную: bun в PATH + npx (не обрезать stdout у .cmd — иначе пустые логи и сбой джоба).
    if (Test-Path -LiteralPath $memStarter) {
      # Без перенаправления stdout/stderr: у npx.cmd + .cmd цепочек редирект в фоне часто даёт пустые логи и нестарт.
      Start-Process `
        -FilePath $psExe `
        -WorkingDirectory $HOME `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $memStarter, "-OpenBrowser", "0", "-SkipStatus") `
        -WindowStyle Hidden `
        | Out-Null
    } else {
      $npmCmd = Join-Path (Join-Path $env:APPDATA "npm") "npm.cmd"
      if (Test-Path -LiteralPath $npmCmd) {
        Start-Process `
          -FilePath $npmCmd `
          -WorkingDirectory $HOME `
          -ArgumentList @("exec", "--yes", "--", "claude-mem", "start") `
          -WindowStyle Hidden `
          -RedirectStandardOutput $outLog `
          -RedirectStandardError $errLog `
          | Out-Null
      } else {
        $npxCmd = Join-Path (Join-Path $env:APPDATA "npm") "npx.cmd"
        if (Test-Path -LiteralPath $npxCmd) {
          Start-Process `
            -FilePath $npxCmd `
            -WorkingDirectory $HOME `
            -ArgumentList @("--yes", "claude-mem", "start") `
            -WindowStyle Hidden `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            | Out-Null
        } else {
          throw "Не найдены npm/npx (ожидалось в $env:APPDATA\npm)."
        }
      }
    }
  } catch {
    Write-Host ("Предупреждение: не удалось стартовать claude-mem: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow
  }

  $waitSec = [Math]::Max(5, $ClaudeMemMaxWaitSec)
  $deadline = (Get-Date).AddSeconds($waitSec)
  while ((Get-Date) -lt $deadline) {
    if (Test-ClaudeMemWorkerUp) { return }
    Start-Sleep -Milliseconds 400
  }
  Write-Host ("Предупреждение: claude-mem (127.0.0.1:37777) не готов за {0} с. Смотрите логи: {1} и {2}" -f $waitSec, $outLog, $errLog) -ForegroundColor DarkYellow
}

function Read-SecretText([string]$Prompt) {
  $s = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Start-Obsidian([string]$Exe,[string]$Vault) {
  try {
    if (Get-Process -Name "Obsidian" -ErrorAction SilentlyContinue) {
      Write-Host "Obsidian уже запущен — пропуск повторного старта." -ForegroundColor DarkGray
      return
    }
  } catch {}
  if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Host "Предупреждение: Obsidian.exe не найден: $Exe" -ForegroundColor DarkYellow
    return
  }
  if (-not (Test-Path -LiteralPath $Vault)) {
    Write-Host "Предупреждение: папка хранилища Obsidian не найдена: $Vault" -ForegroundColor DarkYellow
  }
  try {
    $cmdLine = "start """" ""$Exe"" --vault ""$Vault"""
    Start-Process -FilePath "cmd.exe" -ArgumentList @("/d", "/c", $cmdLine) -WindowStyle Hidden | Out-Null
    Write-Host "Obsidian: запуск с хранилищем «$Vault»" -ForegroundColor DarkCyan
  } catch {
    try {
      Start-Process -FilePath $Exe -ArgumentList @("--vault", $Vault) -WindowStyle Hidden | Out-Null
      Write-Host "Obsidian: запуск (fallback)." -ForegroundColor DarkCyan
    } catch {
      Write-Host ("Предупреждение: не удалось запустить Obsidian: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow
    }
  }
}

function Ensure-FreeClaudeCodeProxy {
  param(
    [string]$Dir,
    [int]$Port,
    [string]$NimKey,
    [string]$Model,
    [string]$AuthToken
  )

  # Be strict: require a listening socket (HTTP checks can false-positive on some failures).
  try {
    $conn = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $Port -State Listen -ErrorAction Stop
    if ($conn) { return }
  } catch {}
  if (-not (Test-Path -LiteralPath $Dir)) { throw "free-claude-code dir not found: $Dir" }

  $uv = "C:\Users\chelaxian\.local\bin\uv.exe"
  if (-not (Test-Path -LiteralPath $uv)) { throw "uv.exe not found at $uv" }

  Push-Location $Dir
  try {
    # Ensure Python 3.14 exists (no-op if already installed)
    & $uv python install 3.14 | Out-Null

    # Prepare env vars for the proxy process (avoid writing secrets to disk).
    $env:NVIDIA_NIM_API_KEY = $NimKey
    $env:MODEL = $Model
    $env:ANTHROPIC_AUTH_TOKEN = $AuthToken

    # Start proxy in background with logs.
    $logDir = Join-Path $HOME ".qwen-local-setup"
    if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outLog = Join-Path $logDir "free-claude-code-$stamp.out.log"
    $errLog = Join-Path $logDir "free-claude-code-$stamp.err.log"

    $cmd = "& `"$uv`" run uvicorn server:app --host 127.0.0.1 --port $Port"
    $p = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-Command",$cmd) -WindowStyle Hidden -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog
  } finally {
    Pop-Location
  }

  for ($i = 0; $i -lt 60; $i++) {
    try {
      $conn = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $Port -State Listen -ErrorAction Stop
      if ($conn) { return }
    } catch {}
    if ($p -and $p.HasExited) {
      throw "free-claude-code proxy exited early (exit=$($p.ExitCode)). Logs: $errLog ; $outLog"
    }
    Start-Sleep -Seconds 1
  }
  throw "free-claude-code proxy did not become ready on port $Port. Logs: $errLog ; $outLog"
}

# PATH до npx/node — до любых sidecar и до claude.cmd.
Ensure-ClaudeSidecarPath

if (-not $SkipCommonPreamble) {
  Ensure-ClaudeSettingsNoBom
}

# claude-mem и Obsidian нужны при каждом входе в сессию: при -SkipCommonPreamble раньше они не вызывались,
# и если PrepareOnly не успел за 8 с — воркер так и не поднимался.
Ensure-ClaudeMemWorker
if ($OpenClaudeMemObserver -ne 0) {
  try {
    if (Test-ClaudeMemWorkerUp) {
      Start-Process -FilePath "http://127.0.0.1:37777/" | Out-Null
      Write-Host "Открыт claude-mem observer: http://127.0.0.1:37777/" -ForegroundColor DarkCyan
    } else {
      Start-Process -FilePath "http://127.0.0.1:37777/" | Out-Null
      Write-Host "Открыт браузер на 37777 (воркер ещё может подниматься)." -ForegroundColor DarkYellow
    }
  } catch {}
}
Start-Obsidian -Exe $ObsidianExe -Vault $VaultPath

if ($PrepareOnly) {
  Write-Host "Claude (облако): общая подготовка выполнена (settings, claude-mem, Obsidian, PATH npm)." -ForegroundColor Green
  exit 0
}

if ($Provider -eq "zai") {
  if (-not $ZaiApiKey -or $ZaiApiKey.Trim().Length -eq 0 -or $ZaiApiKey -eq "__SET_ME__") {
    $ZaiApiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY","User")
  }
  if (-not $ZaiApiKey -or $ZaiApiKey.Trim().Length -eq 0 -or $ZaiApiKey -eq "__SET_ME__") {
    $ZaiApiKey = $env:ZAI_API_KEY
  }
  if (-not $ZaiApiKey -or $ZaiApiKey.Trim().Length -eq 0 -or $ZaiApiKey -eq "__SET_ME__") {
    $ZaiApiKey = Read-SecretText "Enter Z.AI API key (will not be saved)"
  }
  $env:ANTHROPIC_AUTH_TOKEN = $ZaiApiKey
  $env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"
  $env:API_TIMEOUT_MS = "3000000"
  $zModel = "glm-4.7"
  if (-not [string]::IsNullOrWhiteSpace($ZaiAnthropicModelId)) {
    $zModel = $ZaiAnthropicModelId.Trim()
  }
  $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $zModel
  $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $zModel
  $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $zModel

  if ($DryRun -ne 0) {
    if (-not (Test-HttpOk -Url "https://api.z.ai/api/anthropic" -TimeoutSec 5)) {
      throw "Z.AI endpoint not reachable: https://api.z.ai/api/anthropic"
    }
    # Also verify Claude Code is discoverable in this environment (common failure under -NoProfile).
    $cc = Get-Command claude.cmd -ErrorAction SilentlyContinue
    if (-not $cc) { $cc = Get-Command claude -ErrorAction SilentlyContinue }
    if (-not $cc) { throw "Claude Code not found on PATH. Expected: $($env:APPDATA)\\npm\\claude.cmd" }
    Write-Host "dry-run:ZAI:OK" -ForegroundColor Green
    return
  }
}

if ($Provider -in @("nim", "nim-qwen")) {
  # Отдельный порт для Qwen3.5: если прокси уже слушает 8082 с MODEL=GLM, повторный запуск с другой моделью не сменит MODEL.
  $nimModelResolved = $NimModel
  $proxyPortResolved = $ProxyPort
  if ($Provider -eq "nim-qwen") {
    $nimModelResolved = "nvidia_nim/qwen/qwen3.5-122b-a10b"
    if ($PSBoundParameters.ContainsKey("ProxyPort")) {
      $proxyPortResolved = $ProxyPort
    } else {
      $proxyPortResolved = 8083
    }
  }

  if (-not $NvidiaNimApiKey -or $NvidiaNimApiKey.Trim().Length -eq 0 -or $NvidiaNimApiKey -eq "__SET_ME__") {
    $NvidiaNimApiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY","User")
  }
  if (-not $NvidiaNimApiKey -or $NvidiaNimApiKey.Trim().Length -eq 0 -or $NvidiaNimApiKey -eq "__SET_ME__") {
    $NvidiaNimApiKey = $env:NVIDIA_NIM_API_KEY
  }
  if (-not $NvidiaNimApiKey -or $NvidiaNimApiKey.Trim().Length -eq 0 -or $NvidiaNimApiKey -eq "__SET_ME__") {
    $NvidiaNimApiKey = Read-SecretText "Enter NVIDIA NIM API key (will not be saved)"
  }
  Ensure-FreeClaudeCodeProxy -Dir $FreeClaudeCodeDir -Port $proxyPortResolved -NimKey $NvidiaNimApiKey -Model $nimModelResolved -AuthToken $ProxyAuthToken
  $env:ANTHROPIC_AUTH_TOKEN = $ProxyAuthToken
  $env:ANTHROPIC_BASE_URL = ("http://127.0.0.1:{0}" -f $proxyPortResolved)
  $env:API_TIMEOUT_MS = "3000000"

  if ($DryRun -ne 0) {
    if (-not (Test-HttpResponding -Url ("http://127.0.0.1:{0}/v1/models" -f $proxyPortResolved) -TimeoutSec 3)) {
      throw "free-claude-code not responding on http://127.0.0.1:$proxyPortResolved"
    }
    $cc = Get-Command claude.cmd -ErrorAction SilentlyContinue
    if (-not $cc) { $cc = Get-Command claude -ErrorAction SilentlyContinue }
    if (-not $cc) { throw "Claude Code not found on PATH. Expected: $($env:APPDATA)\\npm\\claude.cmd" }
    Write-Host "dry-run:NIM:OK" -ForegroundColor Green
    return
  }
}

Push-Location $VaultPath
try {
  # IMPORTANT: call the Claude Code launcher, not any other "claude" shim.
  $claudeCmd = Get-Command claude.cmd -ErrorAction SilentlyContinue
  if (-not $claudeCmd) {
    $expected = Join-Path (Join-Path $env:APPDATA "npm") "claude.cmd"
    if (Test-Path -LiteralPath $expected) {
      $claudeExe = $expected
    } else {
      $claudeExe = "claude"
    }
  } else {
    $claudeExe = $claudeCmd.Source
  }

  if ($ClaudeTools -eq "default") {
    & $claudeExe
  } else {
    & $claudeExe --tools $ClaudeTools
  }
} finally {
  Pop-Location
}
```

### 11.9. `launcher-provider-models.ps1` (модели API / whitelist NIM)

```powershell
# Dot-source из лаунчеров: списки моделей по API-ключу (Z.AI Coding, NVIDIA NIM).

function Test-TcpPortListening([int]$Port) {
  try {
    $c = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalAddress -eq "127.0.0.1" -and $_.LocalPort -eq $Port })
    return ($c.Count -gt 0)
  } catch {
    return $false
  }
}

function Get-LauncherFreeTcpPort {
  param(
    [int]$Min = 8090,
    [int]$Max = 8140
  )
  for ($p = $Min; $p -le $Max; $p++) {
    if (-not (Test-TcpPortListening -Port $p)) { return $p }
  }
  throw "Не найден свободный TCP-порт на 127.0.0.1 в диапазоне $Min..$Max"
}

function Invoke-LauncherJsonGet {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [hashtable]$Headers = @{},
    [int]$TimeoutSec = 25
  )
  $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
  $useBasic = $iwr.Parameters.ContainsKey("UseBasicParsing")
  $params = @{
    Uri             = $Uri
    Method          = "Get"
    TimeoutSec      = $TimeoutSec
    ErrorAction     = "Stop"
  }
  if ($Headers.Count -gt 0) { $params.Headers = $Headers }
  if ($useBasic) { $params.UseBasicParsing = $true }
  $resp = Invoke-WebRequest @params
  return ($resp.Content | ConvertFrom-Json)
}

# У NVIDIA NIM (integrate OpenAI) нативный tool calling в Qwen Code имеет смысл только для моделей,
# явно помеченных в каталоге как Tool Calling / strict function calling (по списку пользователя).
# Для всех остальных NIM-моделей: в run-qwen-code-dynamic.ps1 — tool_choice=none, локальный прокси
# nim-integrate-string-content-proxy.mjs (content → string, trim messages по ctx tier), model.skipStartupContext; эвристика tier
# micro/standard/large (contextWindowSize + max_tokens) в run-qwen-code-dynamic.ps1; в free-claude-code
# providers/nvidia_nim/request.py — tool_choice=none, flatten content, cap max_tokens по тем же tier; custom Claude NIM —
# в run-claude-cloud-launcher.ps1 --tools minimal. Префикс nvidia_nim/ учитывается в Test-NvidiaNimOpenAiNativeToolCalling.
# чтобы не слать tool_choice=auto (ошибка vLLM 400 про --enable-auto-tool-choice).
function Test-NvidiaNimOpenAiNativeToolCalling {
  param([Parameter(Mandatory = $true)][string]$ModelId)
  $norm = $ModelId.Trim().ToLowerInvariant()
  while ($norm.StartsWith("nvidia_nim/")) {
    $norm = $norm.Substring("nvidia_nim/".Length)
  }
  foreach ($id in @(
      "z-ai/glm4.7"
      "qwen/qwen3.5-122b-a10b"
      "deepseek-ai/deepseek-v3.1-terminus"
    )) {
    if ($norm -eq $id) { return $true }
  }
  return $false
}

# Список free / preview NIM (вручную по каталогу build.nvidia.com, nim_type_preview).
# Обновляйте при необходимости: https://build.nvidia.com/models?filters=nimType%3Anim_type_preview
function Get-NvidiaNimBundledFreeModelIds {
  $raw = @(
    "z-ai/glm4.7"
    "z-ai/glm5"
    "z-ai/glm-5.1"
    "nvidia/nemotron-3-content-safety"
    "nvidia/synthetic-video-detector"
    "nvidia/active-speaker-detection"
    "minimaxai/minimax-m2.7"
    "nvidia/nemotron-voicechat"
    "nvidia/gliner-pii"
    "nvidia/cosmos-transfer2.5-2b"
    "stepfun-ai/step-3.5-flash"
    "nvidia/nemotron-content-safety-reasoning-4b"
    "deepseek-ai/deepseek-v3.2"
    "nvidia/riva-translate-4b-instruct-v1.1"
    "mistralai/devstral-2-123b-instruct-2512"
    "moonshotai/kimi-k2-thinking"
    "mistralai/mistral-large-3-675b-instruct-2512"
    "nvidia/streampetr"
    "nvidia/llama-3.1-nemotron-safety-guard-8b-v3"
    "deepseek-ai/deepseek-v3.1-terminus"
    "moonshotai/kimi-k2-instruct-0905"
    "bytedance/seed-oss-36b-instruct"
    "qwen/qwen3-coder-480b-a35b-instruct"
    "nvidia/llama-3_2-nemoretriever-300m-embed-v1"
    "moonshotai/kimi-k2-instruct"
    "mistralai/magistral-small-2506"
    "meta/llama-guard-4-12b"
    "google/gemma-3n-e4b-it"
    "google/gemma-3n-e2b-it"
    "nvidia/cosmos-transfer1-7b"
    "mistralai/mistral-nemotron"
    "nvidia/magpie-tts-zeroshot"
    "mistralai/mistral-medium-3-instruct"
    "meta/llama-4-maverick-17b-128e-instruct"
    "nvidia/cosmos-predict1-5b"
    "nvidia/sparsedrive"
    "nvidia/bevformer"
    "nvidia/nv-embedcode-7b-v1"
    "google/gemma-3-27b-it"
    "microsoft/phi-4-multimodal-instruct"
    "nvidia/usdcode"
    "nvidia/studiovoice"
    "abacusai/dracarys-llama-3.1-70b-instruct"
    "meta/esm2-650m"
    "nvidia/nemotron-mini-4b-instruct"
    "google/gemma-2-2b-it"
    "nvidia/usdvalidate"
    "nvidia/nv-embed-v1"
    "upstage/solar-10.7b-instruct"
    "google/paligemma"
    "nvidia/rerank-qa-mistral-4b"
    "meta/esmfold"
  )
  return ($raw | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-NvidiaNimModelIdsFromApi {
  param(
    [Parameter(Mandatory = $true)][string]$ApiKey,
    # Оставить только те ID, что есть и в ответе API, и во встроенном каталоге free/preview.
    [switch]$FilterToBundledFreeCatalog
  )
  $h = @{ Authorization = "Bearer $($ApiKey.Trim())" }
  $j = Invoke-LauncherJsonGet -Uri "https://integrate.api.nvidia.com/v1/models" -Headers $h
  if (-not $j.data) { return @() }
  $ids = [System.Collections.Generic.List[string]]::new()
  foreach ($row in @($j.data)) {
    $id = [string]$row.id
    if (-not [string]::IsNullOrWhiteSpace($id)) { $ids.Add($id.Trim()) | Out-Null }
  }
  $out = $ids | Sort-Object -Unique
  if ($FilterToBundledFreeCatalog) {
    $allow = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($x in @(Get-NvidiaNimBundledFreeModelIds)) { [void]$allow.Add($x) }
    $out = $out | Where-Object { $allow.Contains($_) }
  }
  return $out
}

function Get-ZaiCodingModelIdsFromApi {
  param([Parameter(Mandatory = $true)][string]$ApiKey)
  $h = @{ Authorization = "Bearer $($ApiKey.Trim())" }
  $uris = @(
    "https://api.z.ai/api/coding/paas/v4/models",
    "https://api.z.ai/api/paas/v4/models"
  )
  foreach ($u in $uris) {
    try {
      $j = Invoke-LauncherJsonGet -Uri $u -Headers $h -TimeoutSec 20
      if ($j.data) {
        $ids = [System.Collections.Generic.List[string]]::new()
        foreach ($row in @($j.data)) {
          $id = [string]$row.id
          if (-not [string]::IsNullOrWhiteSpace($id)) { $ids.Add($id.Trim()) | Out-Null }
        }
        if ($ids.Count -gt 0) { return ($ids | Sort-Object -Unique) }
      }
    } catch {
      continue
    }
  }
  return @(
    "glm-4.7", "glm-4.7-flash", "glm-4.7-flashx",
    "glm-4.6", "glm-4.6v", "glm-4.5", "glm-4.5-air", "glm-4.5-flash", "glm-4.5v",
    "glm-5", "glm-5-turbo", "glm-5.1", "glm-5v-turbo"
  )
}

function Resolve-NvidiaNimFreeClaudeModel {
  param([Parameter(Mandatory = $true)][string]$OpenAiModelId)
  $m = $OpenAiModelId.Trim().Trim("/")
  if ($m.StartsWith("nvidia_nim/", [StringComparison]::OrdinalIgnoreCase)) { return $m }
  return ("nvidia_nim/{0}" -f $m)
}
```

### 11.10. `launcher-tui.ps1` (TUI меню)

```powershell
# TUI-меню для лаунчеров Qwen / Claude (рамки, прокрутка, баннер).

function Set-LauncherTuiConsole {
  try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
  } catch {}
}

function Get-LauncherTuiBox {
  return @{
    TL = [char]0x2554; TR = [char]0x2557; BL = [char]0x255A; BR = [char]0x255D
    H  = [char]0x2550; V  = [char]0x2551
    LJ = [char]0x2560; RJ = [char]0x2563
  }
}

# В PowerShell нельзя писать [char] * N — только ([string][char]) * N
function Repeat-TuiChar {
  param(
    [char]$Ch,
    [int]$Count
  )
  if ($Count -lt 1) { return "" }
  return ([string]$Ch) * $Count
}

function Write-TuiRow {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text,
    [Parameter(Mandatory = $true)][int]$InnerWidth,
    [System.ConsoleColor]$Fg = "Gray"
  )
  $b = Get-LauncherTuiBox
  if ($Text.Length -gt $InnerWidth) {
    $Text = $Text.Substring(0, [Math]::Max(0, $InnerWidth - 1)) + [char]0x2026
  } else {
    $Text = $Text.PadRight($InnerWidth)
  }
  Write-Host ($b.V + $Text + $b.V) -ForegroundColor $Fg
}

function Write-TuiBannerQwen {
  param([int]$InnerWidth)
  # Тот же визуальный язык, что и у Claude (FIGlet «ANSI Shadow»), по центру как CLAUDE (ширина 59).
  $raw = @(
    " ██████╗ ██╗    ██╗███████╗███╗   ██╗"
    "██╔═══██╗██║    ██║██╔════╝████╗  ██║"
    "██║   ██║██║ █╗ ██║█████╗  ██╔██╗ ██║"
    "██║▄▄ ██║██║███╗██║██╔══╝  ██║╚██╗██║"
    "╚██████╔╝╚███╔███╔╝███████╗██║ ╚████║"
    " ╚══▀▀═╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═══╝"
  )
  $bannerW = 59
  foreach ($ln in $raw) {
    $len = $ln.Length
    if ($len -ge $bannerW) {
      $row = $ln.Substring(0, $bannerW)
    } else {
      $padL = [int][Math]::Floor(($bannerW - $len) / 2)
      $padR = $bannerW - $len - $padL
      $row = ((" " * $padL) + $ln + (" " * $padR))
    }
    Write-TuiRow -Text $row -InnerWidth $InnerWidth -Fg DarkCyan
  }
}

function Write-TuiBannerClaude {
  param([int]$InnerWidth)
  $lines = @(
    "   ██████╗██╗     ██╗      █████╗ ██╗   ██╗██████╗ ███████╗",
    "  ██╔════╝██║     ██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝",
    "  ██║     ██║     ██║     ███████║██║   ██║██║  ██║█████╗  ",
    "  ██║     ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  ",
    "  ╚██████╗███████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗",
    "   ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝"
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg DarkMagenta
  }
}

function Show-TuiFramedMenu {
  param(
    [ValidateSet("Qwen", "Claude")]
    [string]$AppBrand,
    [Parameter(Mandatory = $true)][string]$Title,
    [string]$Subtitle = "",
    [Parameter(Mandatory = $true)][object[]]$Items,
    [int]$InitialIndex = 0,
    [int]$MaxVisible = 12,
    # Exit = Esc полностью отменяет (как главное меню). Back = Esc вернуться к предыдущему шагу (мастер «другая модель»).
    [ValidateSet("Exit", "Back")]
    [string]$EscapeAction = "Exit"
  )

  Set-LauncherTuiConsole
  $b = Get-LauncherTuiBox
  $win = $Host.UI.RawUI.WindowSize
  $frameW = [Math]::Min(90, [Math]::Max(54, $win.Width - 2))
  $inner = $frameW - 2
  $n = $Items.Count
  if ($n -lt 1) {
    throw "Show-TuiFramedMenu: список Items пуст."
  }
  $idx = [Math]::Max(0, [Math]::Min($InitialIndex, $n - 1))
  $heightCap = [Math]::Max(6, $win.Height - 20)
  $visible = [Math]::Max(4, [Math]::Min($MaxVisible, [Math]::Min($n, $heightCap)))
  # При dot-source $script: — область вызывающего файла; скролл ломался. Hashtable — общий изменяемый объект.
  $scroll = @{ Top = 0 }

  function Sync-TuiScroll {
    if ($idx -lt $scroll.Top) { $scroll.Top = $idx }
    $maxTop = [Math]::Max(0, $n - $visible)
    if ($idx -ge $scroll.Top + $visible) { $scroll.Top = $idx - $visible + 1 }
    if ($scroll.Top -gt $maxTop) { $scroll.Top = $maxTop }
    if ($scroll.Top -lt 0) { $scroll.Top = 0 }
  }

  function Redraw-TuiMenu {
    Sync-TuiScroll
    Clear-Host
    Write-Host ($b.TL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.TR) -ForegroundColor Cyan
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    if ($AppBrand -eq "Qwen") { Write-TuiBannerQwen -InnerWidth $inner } else { Write-TuiBannerClaude -InnerWidth $inner }
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    Write-Host ($b.LJ + (Repeat-TuiChar $b.H $inner) + $b.RJ) -ForegroundColor DarkCyan
    Write-TuiRow -Text (" " + $Title.Trim()) -InnerWidth $inner -Fg White
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
      Write-TuiRow -Text (" " + $Subtitle.Trim()) -InnerWidth $inner -Fg DarkGray
    }
    Write-Host ($b.LJ + (Repeat-TuiChar $b.H $inner) + $b.RJ) -ForegroundColor DarkCyan
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    for ($r = 0; $r -lt $visible; $r++) {
      $i = $scroll.Top + $r
      if ($i -ge $n) {
        Write-TuiRow -Text "" -InnerWidth $inner
        continue
      }
      $lbl = [string]$Items[$i].Label
      $mark = if ($i -eq $idx) { ("  {0} " -f [char]0x25B6) } else { "     " }
      $row = $mark + $lbl
      $fg = if ($i -eq $idx) { "Yellow" } else { "Gray" }
      Write-TuiRow -Text $row -InnerWidth $inner -Fg $fg
    }
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    $escHint = if ($EscapeAction -eq "Back") { "Esc — назад" } else { "Esc — выход" }
    $hint = ("  {0}{1}  выбор   Enter — OK   {2}   Home/End   PgUp/PgDn" -f [char]0x2191, [char]0x2193, $escHint)
    Write-TuiRow -Text $hint -InnerWidth $inner -Fg DarkGray
    if ($n -gt $visible) {
      $pg = ("  строки {0}-{1} из {2}" -f ($scroll.Top + 1), ([Math]::Min($scroll.Top + $visible, $n)), $n)
      Write-TuiRow -Text $pg -InnerWidth $inner -Fg DarkCyan
    }
    Write-Host ($b.BL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.BR) -ForegroundColor Cyan
  }

  $scroll.Top = 0
  Sync-TuiScroll
  [Console]::CursorVisible = $false
  try {
    Redraw-TuiMenu
    while ($true) {
      $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      switch ($key.VirtualKeyCode) {
        38 {
          if ($idx -gt 0) { $idx-- }
          Redraw-TuiMenu
        }
        40 {
          if ($idx -lt $n - 1) { $idx++ }
          Redraw-TuiMenu
        }
        33 {
          $idx = [Math]::Max(0, $idx - $visible)
          Redraw-TuiMenu
        }
        34 {
          $idx = [Math]::Min($n - 1, $idx + $visible)
          Redraw-TuiMenu
        }
        36 {
          $idx = 0
          Redraw-TuiMenu
        }
        35 {
          $idx = $n - 1
          Redraw-TuiMenu
        }
        13 { return $Items[$idx] }
        27 {
          if ($EscapeAction -eq "Back") {
            return [pscustomobject]@{ __menuBack = $true }
          }
          return $null
        }
      }
    }
  } finally {
    [Console]::CursorVisible = $true
  }
}

function Show-TuiWaitFrame {
  param(
    [ValidateSet("Qwen", "Claude")]
    [string]$AppBrand,
    [Parameter(Mandatory = $true)][string]$Message
  )
  Set-LauncherTuiConsole
  $b = Get-LauncherTuiBox
  $win = $Host.UI.RawUI.WindowSize
  $frameW = [Math]::Min(82, [Math]::Max(50, $win.Width - 4))
  $inner = $frameW - 2
  Clear-Host
  Write-Host ($b.TL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.TR) -ForegroundColor Cyan
  Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
  if ($AppBrand -eq "Qwen") { Write-TuiBannerQwen -InnerWidth $inner } else { Write-TuiBannerClaude -InnerWidth $inner }
  Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
  Write-TuiRow -Text ("  " + $Message) -InnerWidth $inner -Fg Yellow
  Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
  Write-Host ($b.BL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.BR) -ForegroundColor Cyan
}
```

### 11.11. `launcher-custom-model-wizard.ps1` (мастер «Другая модель»)

```powershell
# Dot-source после launcher-tui.ps1 и launcher-provider-models.ps1
# Возврат: [pscustomobject]@{ Provider = 'zai'|'nim'; ModelId = '...'; ClaudeNimModel = 'nvidia_nim/...' }
# NIM в мастере: полный API, пересечение с каталогом free/preview, или только встроенный статический список.

function Read-SecretTextWizard([string]$Prompt) {
  $sec = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Resolve-ZaiKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") { $k = $env:ZAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") { $k = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") { $k = $env:OPENAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") {
    $k = Read-SecretTextWizard "Z.AI API key (не сохраняется)"
  }
  return $k.Trim()
}

function Resolve-NimKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k)) { $k = $env:NVIDIA_NIM_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k)) {
    $k = Read-SecretTextWizard "NVIDIA NIM API key (не сохраняется)"
  }
  return $k.Trim()
}

function Invoke-LauncherCustomModelWizard {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Qwen", "Claude")]
    [string]$App
  )

  $brand = $App
  $provItems = @(
    [pscustomobject]@{ Id = "zai"; Label = "Z.AI — Coding / Anthropic (список моделей по вашему ключу)" }
    [pscustomobject]@{ Id = "nim"; Label = "NVIDIA NIM — полный каталог (GET /v1/models, все ID)" }
    [pscustomobject]@{ Id = "nim-bundled"; Label = "NVIDIA NIM — только free/preview (API ∩ встроенный список ~50)" }
    [pscustomobject]@{ Id = "nim-free"; Label = "NVIDIA NIM — free/preview (только статический список, без API)" }
  )

  while ($true) {
    $p1 = Show-TuiFramedMenu -AppBrand $brand -Title "Другая модель" -Subtitle "Шаг 1 из 2 — выберите провайдера" -Items $provItems -InitialIndex 0 -EscapeAction Back
    if ($null -eq $p1) { return $null }
    if ($true -eq $p1.__menuBack) { return [pscustomobject]@{ __menuBack = $true } }
    $provSource = [string]$p1.Id

    $ids = @()
    try {
      if ($provSource -eq "zai") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога моделей с API…"
        $key = Resolve-ZaiKeyForWizard
        $ids = @(Get-ZaiCodingModelIdsFromApi -ApiKey $key)
      }
      elseif ($provSource -eq "nim") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога NVIDIA NIM (полный список)…"
        $key = Resolve-NimKeyForWizard
        $ids = @(Get-NvidiaNimModelIdsFromApi -ApiKey $key)
      }
      elseif ($provSource -eq "nim-bundled") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка NIM и фильтр по каталогу free/preview…"
        $key = Resolve-NimKeyForWizard
        $ids = @(Get-NvidiaNimModelIdsFromApi -ApiKey $key -FilterToBundledFreeCatalog)
      }
      elseif ($provSource -eq "nim-free") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Встроенный каталог free/preview NIM (без GET /v1/models)…"
        $null = Resolve-NimKeyForWizard
        $ids = @(Get-NvidiaNimBundledFreeModelIds)
      }
      else {
        throw ("Неизвестный провайдер: {0}" -f $provSource)
      }
    } catch {
      Write-Host ("Ошибка API: {0}" -f $_.Exception.Message) -ForegroundColor Red
      Write-Host "Нажмите любую клавишу…" -ForegroundColor DarkYellow
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      return $null
    }

    if ($ids.Count -eq 0) {
      if ($provSource -eq "nim-bundled") {
        Write-Host "После фильтра free/preview список пуст. Проверьте NVIDIA_NIM_API_KEY или обновите Get-NvidiaNimBundledFreeModelIds в launcher-provider-models.ps1." -ForegroundColor Red
      } else {
        Write-Host "Провайдер вернул пустой список моделей." -ForegroundColor Red
      }
      Write-Host "Нажмите любую клавишу…" -ForegroundColor DarkYellow
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      return $null
    }

    $prov = if ($provSource -in @("nim", "nim-free", "nim-bundled")) { "nim" } else { $provSource }
    $provLabel = switch ($provSource) {
      "zai" { "Z.AI" }
      "nim" { "NIM (полный API)" }
      "nim-free" { "NIM free/preview (стат.)" }
      "nim-bundled" { "NIM (API ∩ free)" }
      default { $provSource.ToUpper() }
    }

    $modelItems = foreach ($id in $ids) {
      [pscustomobject]@{ Id = $id; Label = $id }
    }

    $pick = Show-TuiFramedMenu -AppBrand $brand -Title "Другая модель" -Subtitle ("Шаг 2 из 2 — {0}, моделей: {1}" -f $provLabel, $ids.Count) -Items $modelItems -InitialIndex 0 -MaxVisible 14 -EscapeAction Back
    if ($null -eq $pick) { return $null }
    if ($pick.__menuBack) { continue }

    $mid = [string]$pick.Id
    $claudeNim = $null
    if ($App -eq "Claude" -and $prov -eq "nim") {
      $claudeNim = Resolve-NvidiaNimFreeClaudeModel -OpenAiModelId $mid
    }

    return [pscustomobject]@{
      Provider        = $prov
      ModelId         = $mid
      ClaudeNimModel  = $claudeNim
    }
  }
}
```

### 11.12. `launcher-api-keys.ps1` (модуль управления API ключами)

Модуль для чтения и смены API ключей провайдеров (NVIDIA NIM, Z.AI) через TUI-меню лаунчеров.

```powershell
# Модуль для управления API ключами в лаунчерах Qwen/Claude

function Get-CurrentApiKey {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("NVIDIA_NIM", "ZAI")]
    [string]$Provider
  )

  switch ($Provider) {
    "NVIDIA_NIM" {
      $key = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($key)) {
        $key = $env:NVIDIA_NIM_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        return ""
      } else {
        return $key.Trim()
      }
    }
    "ZAI" {
      $key = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        $key = $env:ZAI_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        $key = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User")
      }
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        $key = $env:OPENAI_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        return ""
      } else {
        return $key.Trim()
      }
    }
    default { return "" }
  }
}

function Read-SecretText {
  param([string]$Prompt)
  $sec = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Set-ProviderApiKey {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("NVIDIA_NIM", "ZAI")]
    [string]$Provider,
    [Parameter(Mandatory = $true)]
    [string]$NewKey
  )

  if ([string]::IsNullOrWhiteSpace($NewKey)) {
    throw "API ключ не может быть пустым"
  }

  switch ($Provider) {
    "NVIDIA_NIM" {
      [Environment]::SetEnvironmentVariable("NVIDIA_NIM_API_KEY", $NewKey.Trim(), "User")
      Write-Host "NVIDIA NIM API ключ обновлён в переменных пользователя." -ForegroundColor Green
    }
    "ZAI" {
      [Environment]::SetEnvironmentVariable("ZAI_API_KEY", $NewKey.Trim(), "User")
      Write-Host "Z.AI API ключ обновлён в переменных пользователя." -ForegroundColor Green
    }
  }
}

function Show-ApiKeyChangeMenu {
  param(
    [ValidateSet("Qwen", "Claude")]
    [string]$AppBrand = "Qwen"
  )

  . (Join-Path $PSScriptRoot "launcher-tui.ps1")

  $providers = @(
    @{
      Id    = "nim"
      Label = "NVIDIA NIM API ключ"
    }
    @{
      Id    = "zai"
      Label = "Z.AI API ключ"
    }
  )

  while ($true) {
    $choice = Show-TuiFramedMenu -AppBrand $AppBrand -Title "Сменить ключ API провайдера" -Subtitle "Выберите провайдер" -Items $providers -EscapeAction "Back"
    
    if ($null -eq $choice) {
      return $null
    }

    if ($choice.__menuBack) {
      return $null
    }

    $providerId = [string]$choice.Id
    $envVarName = if ($providerId -eq "nim") { "NVIDIA_NIM" } else { "ZAI" }
    $currentKey = Get-CurrentApiKey -Provider $envVarName

    Clear-Host
    Write-Host ("Провайдер: {0}" -f $choice.Label) -ForegroundColor Cyan
    if ([string]::IsNullOrWhiteSpace($currentKey)) {
      Write-Host "Текущий ключ: (не задан)" -ForegroundColor Yellow
    } else {
      $masked = if ($currentKey.Length -gt 12) {
        $currentKey.Substring(0, 6) + "..." + $currentKey.Substring($currentKey.Length - 6)
      } else {
        "***"
      }
      Write-Host ("Текущий ключ: {0}" -f $masked) -ForegroundColor Green
    }
    Write-Host ""
    
    $newKey = Read-SecretText "Введите новый API ключ (или оставьте пустым для отмены): "
    
    if ([string]::IsNullOrWhiteSpace($newKey)) {
      Write-Host "Отмена — ключ не изменён." -ForegroundColor Yellow
      Write-Host "Нажмите любую клавишу для продолжения..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }

    try {
      Set-ProviderApiKey -Provider $envVarName -NewKey $newKey
      Write-Host ""
      Write-Host "Нажмите любую клавишу для продолжения..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
      Write-Host ("Ошибка: {0}" -f $_.Exception.Message) -ForegroundColor Red
      Write-Host "Нажмите любую клавишу для продолжения..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
  }
}
```

### 11.13. `update-cloud-shortcuts.ps1` (длинные имена ярлыков; переносимый `RepoRoot`)

```powershell
# Ярлыки с длинными именами (как в оригинальном сетапе): «Cloud — выбор провайдера/профиля».
# Запуск из корня репозитория или любой папки: путь к репо берётся из расположения scripts\.

[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$DesktopPath = "",
  [string]$IconLocation = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
  $DesktopPath = [Environment]::GetFolderPath("Desktop")
}
if ([string]::IsNullOrWhiteSpace($IconLocation)) {
  $IconLocation = (Join-Path $env:USERPROFILE "Pictures\claudecode.ico") + ",0"
}

$psExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$cmdExe = (Get-Command cmd.exe -ErrorAction Stop).Source
$ws = New-Object -ComObject WScript.Shell
$launcherClaude = Join-Path $RepoRoot "scripts\run-claude-cloud-launcher.ps1"
$launcherQwen = Join-Path $RepoRoot "scripts\run-qwen-code-launcher.ps1"

if (-not (Test-Path -LiteralPath $launcherClaude)) { throw "Не найден: $launcherClaude" }
if (-not (Test-Path -LiteralPath $launcherQwen)) { throw "Не найден: $launcherQwen" }

function Ensure-ClaudeCloudUnifiedShortcut {
  $lnkName = "Claude Code (Cloud — выбор провайдера).lnk"
  $lnk = Join-Path $DesktopPath $lnkName
  $sc = $ws.CreateShortcut($lnk)
  $sc.TargetPath = $cmdExe
  $sc.WorkingDirectory = $RepoRoot
  $sc.WindowStyle = 1
  $sc.IconLocation = $IconLocation
  $sc.Description = "Claude Code: Z.AI или NIM через free-claude-code — меню. Пресеты NIM без изменений. Другая модель (NIM вне GLM-4.7/Qwen3.5-122B/DeepSeek Terminus): tool_choice=none + content как строка + в лаунчере --tools minimal. Qwen-ярлык: для таких NIM отдельно локальный прокси string-content."
  $sc.Arguments = (
    '/k chcp 65001 >nul & ' + $psExe +
    " -NoProfile -ExecutionPolicy Bypass" +
    " -File " + '"' + $launcherClaude + '"'
  )
  $sc.Save()
}

function Ensure-QwenCodeCloudUnifiedShortcut {
  $lnkName = "Qwen Code (Cloud — выбор профиля).lnk"
  $lnk = Join-Path $DesktopPath $lnkName
  $sc = $ws.CreateShortcut($lnk)
  $sc.TargetPath = $cmdExe
  $sc.WorkingDirectory = $RepoRoot
  $sc.WindowStyle = 1
  $sc.IconLocation = $IconLocation
  $sc.Description = "Qwen Code: Z.AI Coding / NVIDIA NIM — меню. Пресеты NIM без изменений. Другая модель (NIM вне GLM-4.7/Qwen3.5-122B/DeepSeek Terminus): локальный прокси string-content + минимальный режим. У Claude-ярлыка для таких NIM — free-claude-code (content→строка) и --tools minimal. Z.AI без ограничений."
  $sc.Arguments = (
    '/k chcp 65001 >nul & ' + $psExe +
    " -NoProfile -ExecutionPolicy Bypass" +
    " -File " + '"' + $launcherQwen + '"'
  )
  $sc.Save()
}

Ensure-ClaudeCloudUnifiedShortcut
Ensure-QwenCodeCloudUnifiedShortcut
Write-Output "ok"
```

### 11.14. `run-qwen-code-launcher.ps1` (меню Qwen (облако))

```powershell
[CmdletBinding()]
param(
  [switch]$Quick
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")
. (Join-Path $PSScriptRoot "launcher-tui.ps1")
. (Join-Path $PSScriptRoot "launcher-provider-models.ps1")
. (Join-Path $PSScriptRoot "launcher-custom-model-wizard.ps1")
. (Join-Path $PSScriptRoot "launcher-api-keys.ps1")

$StatePath = Join-Path $PSScriptRoot "qwen-code-launcher-state.json"

$script:Profiles = @(
  @{
    Id          = "last"
    Label       = "Запустить с последними настройками (быстрый старт)"
    Description = "Пропуск меню: последний выбранный профиль"
  }
  @{
    Id          = "nim-glm"
    Label       = "NVIDIA NIM — GLM-4.7 (tool calling + thinking, модель …-tools)"
    NimModel    = "nim-glm-4.7-tools"
  }
  @{
    Id          = "nim-qwen"
    Label       = "NVIDIA NIM — Qwen3.5-122B-A10B (tool calling + thinking, …-tools)"
    NimModel    = "nim-qwen3.5-122b-a10b-tools"
  }
  @{
    Id          = "zai-glm"
    Label       = "Z.AI — GLM-4.7 (OpenAI Coding API: tool calling + thinking + агент)"
  }
  @{
    Id          = "custom-model"
    Label       = "Другая модель… → Z.AI или NIM, список с API (прокрутка)"
  }
  @{
    Id          = "change-api-key"
    Label       = "Сменить ключ API провайдера"
  }
)

function Get-LauncherState {
  if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
  try {
    $raw = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Save-LauncherState {
  param(
    [Parameter(Mandatory = $true)][string]$ProfileId,
    [hashtable]$Extra = @{}
  )
  $obj = [ordered]@{
    profileId = $ProfileId
    updatedAt = (Get-Date).ToString("o")
  }
  foreach ($k in $Extra.Keys) {
    $obj[$k] = $Extra[$k]
  }
  ($obj | ConvertTo-Json -Compress) | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Resolve-ProfileFromState($state) {
  if (-not $state -or [string]::IsNullOrWhiteSpace($state.profileId)) { return $null }
  $id = [string]$state.profileId
  if ($id -in @("nim-glm", "nim-qwen", "zai-glm", "custom-qwen-zai", "custom-qwen-nim")) { return $id }
  return $null
}

function Invoke-QwenProfile {
  param([string]$ProfileId)

  switch ($ProfileId) {
    "nim-glm" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "nim-glm-4.7-tools"
      return
    }
    "nim-qwen" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "nim-qwen3.5-122b-a10b-tools"
      return
    }
    "zai-glm" {
      & (Join-Path $PSScriptRoot "run-qwen-code-cloud-zai-glm47.ps1")
      return
    }
    "custom-qwen-zai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "В qwen-code-launcher-state.json нет customModelId для custom-qwen-zai. Выберите модель в пункте «Другая модель»."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider zai -ModelId $mid.Trim()
      return
    }
    "custom-qwen-nim" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "В qwen-code-launcher-state.json нет customModelId для custom-qwen-nim."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider nim -ModelId $mid.Trim()
      return
    }
    default {
      throw "Неизвестный профиль: $ProfileId"
    }
  }
}

if ($Quick -or $env:QWEN_CODE_LAUNCHER_QUICK -eq "1") {
  $st = Get-LauncherState
  $resolvedId = Resolve-ProfileFromState $st
  if (-not $resolvedId) {
    Write-Host "Нет сохранённого профиля. Один раз выберите модель в меню или уберите -Quick." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit 2
  }
  Invoke-QwenProfile -ProfileId $resolvedId
  exit $LASTEXITCODE
}

$state = Get-LauncherState
$lastId = Resolve-ProfileFromState $state
$items = $script:Profiles
$startIdx = 0
if ($lastId) {
  for ($i = 0; $i -lt $items.Count; $i++) {
    if ($items[$i].Id -eq $lastId) { $startIdx = $i; break }
  }
} else {
  $startIdx = 1
}

while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "Qwen" -Title "Qwen Code — выбор профиля" -Subtitle "OpenAI Coding (Z.AI / NIM) + пресеты" -Items $items -InitialIndex $startIdx -MaxVisible 14
  if (-not $choice) {
    Write-Host "Отменено." -ForegroundColor Yellow
    exit 0
  }

  $profileId = [string]$choice.Id

  if ($profileId -eq "custom-model") {
    $w = Invoke-LauncherCustomModelWizard -App "Qwen"
    if ($null -eq $w) {
      Write-Host "Отменено." -ForegroundColor Yellow
      exit 0
    }
    if ($true -eq $w.__menuBack) { continue }
    $newId = if ($w.Provider -eq "zai") { "custom-qwen-zai" } else { "custom-qwen-nim" }
    Save-LauncherState -ProfileId $newId -Extra @{ customModelId = [string]$w.ModelId }
    Invoke-QwenProfile -ProfileId $newId
    exit $LASTEXITCODE
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "Qwen"
    continue
  }

  if ($profileId -eq "last") {
    $st = Get-LauncherState
    $profileId = Resolve-ProfileFromState $st
    if (-not $profileId) {
      Write-Host "Сохранённый профиль не найден. Выберите пресет или «Другая модель» один раз." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      exit 2
    }
  } else {
    Save-LauncherState -ProfileId $profileId
  }

  Invoke-QwenProfile -ProfileId $profileId
  exit $LASTEXITCODE
}
```

### 11.15. `request.py` (NIM request builder (free-claude-code))

```python
"""Request builder for NVIDIA NIM provider."""

import json
import re
from collections.abc import Callable
from copy import deepcopy
from typing import Any

from loguru import logger

from config.nim import NimSettings
from core.anthropic import (
    ReasoningReplayMode,
    build_base_request_body,
    set_if_not_none,
)
from core.anthropic.conversion import OpenAIConversionError
from providers.exceptions import InvalidRequestError

_SCHEMA_VALUE_KEYS = frozenset(
    {
        "additionalProperties",
        "additionalItems",
        "unevaluatedProperties",
        "unevaluatedItems",
        "items",
        "contains",
        "propertyNames",
        "if",
        "then",
        "else",
        "not",
    }
)
_SCHEMA_LIST_KEYS = frozenset({"allOf", "anyOf", "oneOf", "prefixItems"})
_SCHEMA_MAP_KEYS = frozenset(
    {"properties", "patternProperties", "$defs", "definitions", "dependentSchemas"}
)

# Каталог integrate NIM: нативный OpenAI tool_choice=auto поддерживается не у всех моделей.
# Остальные дают 400 (vLLM: --enable-auto-tool-choice / --tool-call-parser). Z.AI не затрагивается.
_NIM_NATIVE_TOOL_CATALOG_IDS = frozenset(
    {
        "z-ai/glm4.7",
        "qwen/qwen3.5-122b-a10b",
        "deepseek-ai/deepseek-v3.1-terminus",
    }
)


def _nim_integrate_catalog_model_id(model: str) -> str:
    """Нормализовать к id каталога (z-ai/glm4.7), убрав префикс nvidia_nim/ если есть."""
    m = (model or "").strip().lower()
    while m.startswith("nvidia_nim/"):
        m = m[len("nvidia_nim/") :]
    return m


def _nim_model_supports_native_tool_choice(model: str) -> bool:
    return _nim_integrate_catalog_model_id(model) in _NIM_NATIVE_TOOL_CATALOG_IDS


_MICRO_CTX_RE = re.compile(
    r"nemotron-mini|nemotron-3-content-safety|content-safety-reasoning|/gliner|/pii|\b300m\b|"
    r"nemoretriever|nv-embed|embedcode|cosmos-transfer|cosmos-predict|magpie-tts|voicechat|safety-guard|zeroshot|"
    r"llama-3\.1-nemotron-safety|transfer2\.5-2b|transfer1-7b|riva-translate|synthetic-video|"
    r"active-speaker|video-detector|parakeet|whisper|/tts|text-to-speech",
    re.IGNORECASE,
)
_LARGE_CTX_RE = re.compile(
    r"480b|235b|405b|70b|8x7b|8x22b|106b-a47b|\b128k\b|\b1m\b|qwen3-coder|minimax-m2|step-3\.5|solar-10\.7",
    re.IGNORECASE,
)


def _nim_strict_context_limit_tokens(catalog_id: str) -> int | None:
    """Суммарный лимит контекста (вход+выход) для strict NIM вне whitelist."""
    if _nim_model_supports_native_tool_choice(catalog_id):
        return None
    if not catalog_id or "/" not in catalog_id:
        return None
    if _MICRO_CTX_RE.search(catalog_id):
        return 4096
    if _LARGE_CTX_RE.search(catalog_id):
        return 131_072
    return 16_384


def _estimate_messages_tokenish(messages: list[Any]) -> int:
    n = 0
    for m in messages:
        if isinstance(m, dict):
            n += max(4, len(json.dumps(m, ensure_ascii=False)) // 4)
    return n


def _trim_strict_nim_messages_for_budget(
    body: dict[str, Any], *, catalog_id: str, max_out: int
) -> None:
    ctx = _nim_strict_context_limit_tokens(catalog_id)
    if ctx is None:
        return
    messages = body.get("messages")
    if not isinstance(messages, list) or not messages:
        return
    margin = 384 if ctx <= 4096 else 640
    max_input = max(200, ctx - int(max_out) - margin)
    out: list[Any] = [dict(m) if isinstance(m, dict) else m for m in messages]
    guard = 0
    while _estimate_messages_tokenish(out) > max_input and guard < 2000:
        guard += 1
        if len(out) <= 1:
            m0 = out[0]
            if isinstance(m0, dict) and isinstance(m0.get("content"), str):
                c = m0["content"]
                target_chars = max(800, (max_input - 24) * 3)
                if len(c) > target_chars:
                    m0["content"] = "[truncated]\n" + c[-target_chars:]
            break
        if isinstance(out[0], dict) and out[0].get("role") == "system" and len(out) > 1:
            out.pop(1)
        else:
            out.pop(0)
    body["messages"] = out


def _nim_strict_dynamic_max_tokens_cap(catalog_id: str) -> int | None:
    """Сжать max_tokens для «жёстких» NIM вне whitelist (согласовано с run-qwen-code-dynamic.ps1)."""
    if _nim_model_supports_native_tool_choice(catalog_id):
        return None
    if not catalog_id or "/" not in catalog_id:
        return None
    if _MICRO_CTX_RE.search(catalog_id):
        return 512
    if _LARGE_CTX_RE.search(catalog_id):
        return 8192
    return 2048


def _flatten_message_content_to_string(content: Any) -> Any:
    """Строгие NIM (vLLM) часто требуют ``content: str``, а не массив частей OpenAI."""
    if content is None or isinstance(content, str):
        return content
    if not isinstance(content, list):
        return content
    chunks: list[str] = []
    for part in content:
        if isinstance(part, str):
            chunks.append(part)
            continue
        if not isinstance(part, dict):
            continue
        ptype = part.get("type")
        if ptype == "text" and part.get("text") is not None:
            chunks.append(str(part["text"]))
        elif ptype in ("image_url", "input_audio", "video_url", "file"):
            chunks.append(f"[{ptype}]")
    out = "\n\n".join(c for c in chunks if c)
    return out


def _flatten_strict_nim_messages(body: dict[str, Any]) -> None:
    messages = body.get("messages")
    if not isinstance(messages, list):
        return
    for msg in messages:
        if not isinstance(msg, dict):
            continue
        role = msg.get("role")
        if role == "assistant" and msg.get("tool_calls") and (
            msg.get("content") is None or msg.get("content") == ""
        ):
            continue
        flat = _flatten_message_content_to_string(msg.get("content"))
        if flat is not None and flat != msg.get("content"):
            msg["content"] = flat


def _clone_strip_extra_body(
    body: dict[str, Any],
    strip: Callable[[dict[str, Any]], bool],
) -> dict[str, Any] | None:
    """Deep-clone ``body`` and remove fields via ``strip`` on ``extra_body`` only.

    Returns ``None`` when there is no ``extra_body`` dict or ``strip`` reports no change.
    """
    cloned_body = deepcopy(body)
    extra_body = cloned_body.get("extra_body")
    if not isinstance(extra_body, dict):
        return None
    if not strip(extra_body):
        return None
    if not extra_body:
        cloned_body.pop("extra_body", None)
    return cloned_body


def _strip_reasoning_budget_fields(extra_body: dict[str, Any]) -> bool:
    removed = extra_body.pop("reasoning_budget", None) is not None
    chat_template_kwargs = extra_body.get("chat_template_kwargs")
    if (
        isinstance(chat_template_kwargs, dict)
        and chat_template_kwargs.pop("reasoning_budget", None) is not None
    ):
        removed = True
    return removed


def _strip_chat_template_field(extra_body: dict[str, Any]) -> bool:
    return extra_body.pop("chat_template", None) is not None


def _strip_message_reasoning_content(body: dict[str, Any]) -> bool:
    removed = False
    messages = body.get("messages")
    if not isinstance(messages, list):
        return False
    for message in messages:
        if (
            isinstance(message, dict)
            and message.pop("reasoning_content", None) is not None
        ):
            removed = True
    return removed


def _sanitize_nim_schema_node(value: Any) -> tuple[bool, Any]:
    """Remove boolean JSON Schema subschemas that hosted NIM rejects."""
    if isinstance(value, bool):
        return False, None
    if isinstance(value, dict):
        sanitized: dict[str, Any] = {}
        for key, item in value.items():
            if key in _SCHEMA_VALUE_KEYS:
                keep, sanitized_item = _sanitize_nim_schema_node(item)
                if keep:
                    sanitized[key] = sanitized_item
            elif key in _SCHEMA_LIST_KEYS and isinstance(item, list):
                sanitized_items: list[Any] = []
                for schema_item in item:
                    keep, sanitized_item = _sanitize_nim_schema_node(schema_item)
                    if keep:
                        sanitized_items.append(sanitized_item)
                if sanitized_items:
                    sanitized[key] = sanitized_items
            elif key in _SCHEMA_MAP_KEYS and isinstance(item, dict):
                sanitized_map: dict[str, Any] = {}
                for map_key, schema_item in item.items():
                    keep, sanitized_item = _sanitize_nim_schema_node(schema_item)
                    if keep:
                        sanitized_map[map_key] = sanitized_item
                sanitized[key] = sanitized_map
            else:
                sanitized[key] = item
        return True, sanitized
    if isinstance(value, list):
        sanitized_items = []
        for item in value:
            keep, sanitized_item = _sanitize_nim_schema_node(item)
            if keep:
                sanitized_items.append(sanitized_item)
        return True, sanitized_items
    return True, value


def _sanitize_nim_tool_schemas(body: dict[str, Any]) -> None:
    """Sanitize only tool parameter schemas, preserving tool calls/history."""
    tools = body.get("tools")
    if not isinstance(tools, list):
        return

    sanitized_tools: list[Any] = []
    for tool in tools:
        if not isinstance(tool, dict):
            sanitized_tools.append(tool)
            continue
        sanitized_tool = dict(tool)
        function = tool.get("function")
        if isinstance(function, dict):
            sanitized_function = dict(function)
            parameters = function.get("parameters")
            if isinstance(parameters, dict):
                _, sanitized_parameters = _sanitize_nim_schema_node(parameters)
                sanitized_function["parameters"] = sanitized_parameters
            sanitized_tool["function"] = sanitized_function
        sanitized_tools.append(sanitized_tool)

    body["tools"] = sanitized_tools


def _set_extra(
    extra_body: dict[str, Any], key: str, value: Any, ignore_value: Any = None
) -> None:
    if key in extra_body:
        return
    if value is None:
        return
    if ignore_value is not None and value == ignore_value:
        return
    extra_body[key] = value


def clone_body_without_reasoning_budget(body: dict[str, Any]) -> dict[str, Any] | None:
    """Clone a request body and strip only reasoning_budget fields."""
    return _clone_strip_extra_body(body, _strip_reasoning_budget_fields)


def clone_body_without_chat_template(body: dict[str, Any]) -> dict[str, Any] | None:
    """Clone a request body and strip only chat_template."""
    return _clone_strip_extra_body(body, _strip_chat_template_field)


def clone_body_without_reasoning_content(body: dict[str, Any]) -> dict[str, Any] | None:
    """Clone a request body and strip assistant message ``reasoning_content`` fields."""
    cloned_body = deepcopy(body)
    if not _strip_message_reasoning_content(cloned_body):
        return None
    return cloned_body


def build_request_body(
    request_data: Any, nim: NimSettings, *, thinking_enabled: bool
) -> dict:
    """Build OpenAI-format request body from Anthropic request."""
    logger.debug(
        "NIM_REQUEST: conversion start model={} msgs={}",
        getattr(request_data, "model", "?"),
        len(getattr(request_data, "messages", [])),
    )
    try:
        body = build_base_request_body(
            request_data,
            reasoning_replay=ReasoningReplayMode.REASONING_CONTENT
            if thinking_enabled
            else ReasoningReplayMode.DISABLED,
        )
    except OpenAIConversionError as exc:
        raise InvalidRequestError(str(exc)) from exc

    _sanitize_nim_tool_schemas(body)

    # NIM-specific max_tokens: cap against nim.max_tokens
    max_tokens = body.get("max_tokens") or getattr(request_data, "max_tokens", None)
    if max_tokens is None:
        max_tokens = nim.max_tokens
    elif nim.max_tokens:
        max_tokens = min(max_tokens, nim.max_tokens)
    catalog_id = _nim_integrate_catalog_model_id(str(body.get("model", "")))
    strict_cap = _nim_strict_dynamic_max_tokens_cap(catalog_id)
    if strict_cap is not None and max_tokens is not None:
        max_tokens = min(int(max_tokens), strict_cap)
    elif strict_cap is not None:
        max_tokens = strict_cap
    set_if_not_none(body, "max_tokens", max_tokens)

    # NIM-specific temperature/top_p: fall back to NIM defaults if request didn't set
    if body.get("temperature") is None and nim.temperature is not None:
        body["temperature"] = nim.temperature
    if body.get("top_p") is None and nim.top_p is not None:
        body["top_p"] = nim.top_p

    # NIM-specific stop sequences fallback
    if "stop" not in body and nim.stop:
        body["stop"] = nim.stop

    if nim.presence_penalty != 0.0:
        body["presence_penalty"] = nim.presence_penalty
    if nim.frequency_penalty != 0.0:
        body["frequency_penalty"] = nim.frequency_penalty
    if nim.seed is not None:
        body["seed"] = nim.seed

    body["parallel_tool_calls"] = nim.parallel_tool_calls

    # Handle non-standard parameters via extra_body
    extra_body: dict[str, Any] = {}
    request_extra = getattr(request_data, "extra_body", None)
    if request_extra:
        extra_body.update(request_extra)

    if thinking_enabled:
        chat_template_kwargs = extra_body.setdefault(
            "chat_template_kwargs", {"thinking": True, "enable_thinking": True}
        )
        if isinstance(chat_template_kwargs, dict):
            chat_template_kwargs.setdefault("reasoning_budget", max_tokens)

    req_top_k = getattr(request_data, "top_k", None)
    top_k = req_top_k if req_top_k is not None else nim.top_k
    _set_extra(extra_body, "top_k", top_k, ignore_value=-1)
    _set_extra(extra_body, "min_p", nim.min_p, ignore_value=0.0)
    _set_extra(
        extra_body, "repetition_penalty", nim.repetition_penalty, ignore_value=1.0
    )
    _set_extra(extra_body, "min_tokens", nim.min_tokens, ignore_value=0)
    _set_extra(extra_body, "chat_template", nim.chat_template)
    _set_extra(extra_body, "request_id", nim.request_id)
    _set_extra(extra_body, "ignore_eos", nim.ignore_eos)

    if extra_body:
        body["extra_body"] = extra_body

    model_ref = str(body.get("model", ""))
    if not _nim_model_supports_native_tool_choice(model_ref):
        _flatten_strict_nim_messages(body)
        body["tool_choice"] = "none"
        _trim_strict_nim_messages_for_budget(
            body,
            catalog_id=_nim_integrate_catalog_model_id(model_ref),
            max_out=int(body.get("max_tokens") or 512),
        )

    logger.debug(
        "NIM_REQUEST: conversion done model={} msgs={} tools={}",
        body.get("model"),
        len(body.get("messages", [])),
        len(body.get("tools", [])),
    )
    return body
```

### 11.16. `create-desktop-shortcuts.ps1` (ярлыки: Claude/Qwen `(cloud)` + Claude Mem Start/Viewer)

> Источник правды в репозитории: `scripts/create-desktop-shortcuts.ps1`. Ниже — тот же полный текст.

```powershell
# Создаёт ярлыки на рабочем столе: Claude/Qwen Code (cloud), claude-mem Start/Viewer.
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-desktop-shortcuts.ps1 -RepoRoot "D:\qwen-local-setup"

[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$DesktopPath = "",
  [string]$IconLocation = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
  $DesktopPath = [Environment]::GetFolderPath("Desktop")
}
if ([string]::IsNullOrWhiteSpace($IconLocation)) {
  $IconLocation = (Join-Path $env:USERPROFILE "Pictures\claudecode.ico") + ",0"
}

$cmdExe = (Get-Command cmd.exe -ErrorAction Stop).Source
$psExe  = (Get-Command powershell.exe -ErrorAction Stop).Source
$ws = New-Object -ComObject WScript.Shell

$launcherClaude = Join-Path $RepoRoot "scripts\run-claude-cloud-launcher.ps1"
$launcherQwen   = Join-Path $RepoRoot "scripts\run-qwen-code-launcher.ps1"
$memScript      = Join-Path $RepoRoot "scripts\start-claude-mem.ps1"

foreach ($p in @($launcherClaude, $launcherQwen, $memScript)) {
  if (-not (Test-Path -LiteralPath $p)) { throw "Не найден файл: $p" }
}

function New-Shortcut {
  param(
    [string]$LinkPath,
    [string]$TargetPath,
    [string]$Arguments,
    [string]$WorkingDirectory,
    [string]$Icon,
    [string]$Description
  )
  $s = $ws.CreateShortcut($LinkPath)
  $s.TargetPath = $TargetPath
  $s.Arguments = $Arguments
  $s.WorkingDirectory = $WorkingDirectory
  $s.WindowStyle = 1
  if ($Icon) { $s.IconLocation = $Icon }
  if ($Description) { $s.Description = $Description }
  $s.Save()
}

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "Claude Code (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherClaude + '"') `
  -WorkingDirectory $RepoRoot `
  -Icon $IconLocation `
  -Description "Claude Code: Z.AI или NIM через free-claude-code — меню. Пресеты NIM без изменений. Другая модель (NIM вне GLM-4.7/Qwen3.5-122B/DeepSeek Terminus): tool_choice=none + content как строка + в лаунчере --tools minimal. Qwen: для таких NIM отдельно локальный прокси string-content."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "Qwen Code (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherQwen + '"') `
  -WorkingDirectory $RepoRoot `
  -Icon $IconLocation `
  -Description "Qwen Code: Z.AI Coding / NVIDIA NIM — меню. Пресеты NIM без изменений. Другая модель NIM: локальный прокси string-content + минимальный режим. У Claude для таких NIM — free-claude-code и --tools minimal. Z.AI без ограничений."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "Claude Mem Start.lnk") `
  -TargetPath $psExe `
  -Arguments ('-NoProfile -ExecutionPolicy Bypass -File "' + $memScript + '" -OpenBrowser 0') `
  -WorkingDirectory $env:USERPROFILE `
  -Icon $IconLocation `
  -Description "Старт claude-mem worker (127.0.0.1:37777)."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "Claude Mem Viewer.lnk") `
  -TargetPath $psExe `
  -Arguments ('-NoProfile -ExecutionPolicy Bypass -File "' + $memScript + '" -OpenBrowser 1') `
  -WorkingDirectory $env:USERPROFILE `
  -Icon $IconLocation `
  -Description "claude-mem: старт при необходимости и открыть http://127.0.0.1:37777/"

Write-Host "Shortcuts created on desktop: Claude Code (cloud), Qwen Code (cloud), Claude Mem Start, Claude Mem Viewer." -ForegroundColor Green
Write-Host "RepoRoot=$RepoRoot  Desktop=$DesktopPath" -ForegroundColor DarkGray
```

### 11.17. `set-cloud-api-keys.ps1` (интерактивно записать `ZAI_API_KEY` и `NVIDIA_NIM_API_KEY` в User; значения не логируются)

```powershell
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Read-SecretText([string]$Prompt) {
  $s = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

$zai = Read-SecretText "Enter Z.AI API key (saved to User env var ZAI_API_KEY)"
$nim = Read-SecretText "Enter NVIDIA NIM API key (saved to User env var NVIDIA_NIM_API_KEY)"

if ([string]::IsNullOrWhiteSpace($zai) -or [string]::IsNullOrWhiteSpace($nim)) {
  throw "Both keys are required."
}

[Environment]::SetEnvironmentVariable("ZAI_API_KEY", $zai, "User")
[Environment]::SetEnvironmentVariable("NVIDIA_NIM_API_KEY", $nim, "User")

Write-Output "ok"
```

### 11.18. `run-opencode-launcher.ps1` (меню OpenCode (облако))

TUI-меню для OpenCode с выбором провайдера (Z.AI / NVIDIA NIM), пресетами моделей, мастером «Другая модель» и сменой API ключей. При выборе профиля автоматически генерируется `opencode-sessions/opencode.json` с конфигурацией провайдера.

```powershell
# Полный текст: scripts/run-opencode-launcher.ps1
# Скопируйте из I:\qwen-local-setup\scripts\run-opencode-launcher.ps1
# или из репозитория cloud-code-setup/scripts/run-opencode-launcher.ps1
```

Ключевые особенности:
- Поддержка пресетов: Z.AI GLM-4.7, Z.AI GLM-5.1, NVIDIA NIM GLM-4.7, NVIDIA NIM Qwen3.5-122B-A10B
- Пункт «Другая модель…» для выбора любой модели из каталога Z.AI или NIM через API
- Пункт «Сменить ключ API провайдера» для интерактивной смены ключей
- Быстрый старт (переменная `OPENCODE_LAUNCHER_QUICK=1`) для запуска с последним профилем
- Автоматическое создание `opencode.json` с `@ai-sdk/openai-compatible` провайдером

---

## Быстрый чеклист после миграции

1. Заменить все пути `I:\...` и `C:\Users\chelaxian\...` (в т.ч. в `run-qwen-code-nvidia-nim.ps1`, где исторически прошит `C:\Users\...\Roaming\npm` — лучше выровнять с `$env:APPDATA\npm` как в `run-qwen-code-dynamic.ps1`).
2. Установить Node, Qwen Code, Claude Code, OpenCode, uv, (Bun), Obsidian.
3. Задать `ZAI_API_KEY`, `NVIDIA_NIM_API_KEY`, `GROQ_API_KEY`, `OPENROUTER_API_KEY` (User), например через пункт «Сменить ключ API провайдера» в лаунчере или вручную в «Переменные среды».
4. Создать `%USERPROFILE%\.qwen\litellm\` и рабочий LiteLLM на **4000**.
5. `uv sync` в `free-claude-code`.
6. Запустить `.\scripts\create-desktop-shortcuts.ps1` и при необходимости `.\scripts\update-cloud-shortcuts.ps1` (§10, §11.12, §11.15).
7. Проверить: ярлык Qwen → пресет NIM / Z.AI / Groq / OpenRouter → ответ модели; ярлык Claude → NIM / Z.AI / OpenRouter; ярлык OpenCode → любой провайдер; `claude-mem` на 37777.
8. При наличии платной подписки: использовать пункт «Нативный логин» для OAuth-авторизации (Qwen OAuth, Claude подписка, OpenCode providers).

---

*Документ сгенерирован для публикации на GitHub. Не храните секреты в issue и в коммитах.*