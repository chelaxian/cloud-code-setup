# cloud-code-setup

**1-click развёртывание Qwen Code, Claude Code и OpenCode с облачными моделями (NVIDIA NIM, Z.AI, Groq, OpenRouter)**

Работает на Windows и Linux. Устанавливается одной командой в терминале.

---

## Быстрая установка

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | iex
```

### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/bootstrap.sh | bash
```

Или вручную:

```bash
git clone https://github.com/chelaxian/cloud-code-setup.git
cd cloud-code-setup
./install.sh          # Linux
.\install.ps1         # Windows
```

---

## Что делает инсталлятор

1. **Проверяет зависимости** — git, Node.js, npm
2. **Спрашивает** что установить: Qwen Code, Claude Code, OpenCode или все три
3. **Устанавливает CLI** через npm (если не установлен)
4. **Запрашивает API ключи**:
   - NVIDIA NIM API ключ (можно пропустить)
   - Z.AI API ключ (можно пропустить)
   - Groq API ключ (можно пропустить)
   - OpenRouter API ключ (можно пропустить)
5. **Создаёт ярлыки** на рабочем столе
6. **Настраивает профили сессий** для Qwen Code

---

## Документация

| Документ | Описание |
|----------|----------|
| [docs/MANUAL-SETUP.md](docs/MANUAL-SETUP.md) | Полное пошаговое руководство по ручной установке (Windows + Linux) |

Включает: архитектуру, требования, настройку LiteLLM, free-claude-code, claude-mem, устранение проблем.

---

## Провайдеры и модели

Все модели доступны из главного меню лаунчера (TUI):

### NVIDIA NIM (free, tool calling)
| Модель | Qwen Code | Claude Code | OpenCode |
|--------|-----------|-------------|----------|
| GLM-4.7 | + | + | + |
| Qwen3.5-122B-A10B | + | + | + |

### Z.AI (paid, tool calling)
| Модель | Qwen Code | Claude Code | OpenCode |
|--------|-----------|-------------|----------|
| GLM-4.7 | + | + | + |
| GLM-5.1 | + | + | + |

### Z.AI Flash (free, tool calling)
| Модель | Qwen Code | Claude Code | OpenCode |
|--------|-----------|-------------|----------|
| GLM-4.7-Flash | + | + | + |
| GLM-4.5-Flash | + | + | + |

### OpenRouter (free, tool calling)
| Модель | Qwen Code | Claude Code | OpenCode |
|--------|-----------|-------------|----------|
| Qwen3 Coder | + | + | + |
| Tencent Hy3 preview | + | + | + |
| Nemotron 3 Super 120B | + | + | + |
| Poolside Laguna M.1 (coding) | + | + | + |

### OpenRouter (paid, tool calling)
| Модель | Qwen Code | Claude Code | OpenCode |
|--------|-----------|-------------|----------|
| Claude Sonnet 4 | — | + | — |

### Groq (free, chat only — через «Другая модель»)
| Заметка | Qwen Code | Claude Code | OpenCode |
|---------|-----------|-------------|----------|
| Любая Groq модель, контекст 4K, chat only | + | — | + |

> Пункты **«Другая модель…»** позволяют выбрать любую модель из каталога провайдера (API или статический список).
> Пункт **«Нативный логин»** — OAuth-авторизация через браузер (Qwen, Claude, OpenCode).

### Где взять API ключи

- **NVIDIA NIM**: [build.nvidia.com](https://build.nvidia.com/) — бесплатный ключ после регистрации
- **Z.AI**: [console.z.ai](https://console.z.ai/) — GLM API (paid); [open.bigmodel.cn](https://open.bigmodel.cn/) — альтернативный вход
- **Groq**: [console.groq.com](https://console.groq.com/) — бесплатный ключ, ультрабыстрая инференс
- **OpenRouter**: [openrouter.ai](https://openrouter.ai/) — шлюз к множеству моделей, есть бесплатные

---

## После установки

### Запуск

Просто дважды кликните на ярлык на рабочем столе:

- **Qwen Code (cloud)** — меню выбора модели/провайдера
- **Claude Code (cloud)** — меню выбора провайдера
- **OpenCode (cloud)** — меню выбора провайдера

### Смена API ключей

В меню лаунчера выберите пункт **«Сменить ключ API провайдера»**:

1. Выберите провайдера (NVIDIA NIM, Z.AI, Groq или OpenRouter)
2. Введите новый ключ
3. Ключ сохраняется в переменных окружения

### Нативный логин (OAuth)

Если у вас есть платная подписка, авторизуйтесь через браузер:

1. Выберите в меню лаунчера **«Нативный логин»**
2. **Qwen Code**: Qwen OAuth или Alibaba Cloud Coding Plan
3. **Claude Code**: Claude подписка (OAuth) или Anthropic Console
4. **OpenCode**: интерактивный выбор провайдера через `opencode providers login`

---

## Структура проекта

```
cloud-code-setup/
├── install.ps1                # Windows инсталлятор (1-click)
├── install.sh                 # Linux инсталлятор
├── bootstrap.sh               # curl | bash точка входа
├── README.md                  # Этот файл
├── scripts/
│   ├── launcher-tui.ps1       # TUI-меню (Windows)
│   ├── launcher-tui.sh        # TUI-меню (Linux)
│   ├── launcher-api-keys.ps1  # Управление API ключами (Windows)
│   ├── launcher-api-keys.sh   # Управление API ключами (Linux)
│   ├── launcher-provider-models.ps1
│   ├── launcher-custom-model-wizard.ps1
│   ├── run-qwen-code-launcher.ps1    # Qwen Code лаунчер (Windows)
│   ├── run-qwen-code-launcher.sh     # Qwen Code лаунчер (Linux)
│   ├── run-qwen-code-dynamic.ps1     # Qwen Code dynamic provider (Windows)
│   ├── run-qwen-code-dynamic.sh      # Qwen Code dynamic provider (Linux)
│   ├── run-claude-cloud-launcher.ps1  # Claude Code лаунчер (Windows)
│   ├── run-claude-cloud-launcher.sh   # Claude Code лаунчер (Linux)
│   ├── run-opencode-launcher.ps1      # OpenCode лаунчер (Windows)
│   ├── run-opencode-launcher.sh       # OpenCode лаунчер (Linux)
│   └── ...                             # Вспомогательные скрипты
├── qwen-sessions/             # Профили сессий Qwen Code
│   ├── zai-glm47/
│   ├── nim-glm-47/
│   └── nim-deepseek-v31/
└── docs/
    └── ...
```

---

## Требования

### Обязательные
- **Windows 10/11** или **Linux** (Ubuntu 20+, Fedora, Arch и т.д.)
- **Git**
- **Node.js** LTS (18+)
- **npm**

### Опциональные (для продвинутых функций)
- **LiteLLM** — для пресетов NIM с Qwen Code (порт 4000)
- **free-claude-code** — для Claude Code через NIM
- **claude-mem** — память для Claude Code
- **Obsidian** — хранилище сессий Claude Code

---

## Устранение проблем

### Windows: «Политика выполнения скриптов»

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Linux: «Permission denied»

```bash
chmod +x ~/cloud-code-setup/scripts/*.sh
chmod +x ~/cloud-code-setup/install.sh
```

### Ключи не подхватываются

**Windows**: Перезапустите терминал или компьютер.

**Linux**: Выполните `source ~/.bashrc` или перезапустите терминал.

---

## Лицензия

MIT
