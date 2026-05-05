# cloud-code-setup

**1-click развёртывание Qwen Code, Claude Code и OpenCode с облачными моделями (NVIDIA NIM, Z.AI)**

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
5. **Создаёт ярлыки** на рабочем столе
6. **Настраивает профили сессий** для Qwen Code

---

## Документация

| Документ | Описание |
|----------|----------|
| [docs/MANUAL-SETUP.md](docs/MANUAL-SETUP.md) | Полное пошаговое руководство по ручной установке (Windows + Linux) |

Включает: архитектуру, требования, настройку LiteLLM, free-claude-code, claude-mem, устранение проблем.

---

## Провайдеры

| Провайдер | Модели | Для кого |
|-----------|--------|----------|
| **NVIDIA NIM** | GLM-4.7, Qwen3.5-122B-A10B | Qwen Code, Claude Code, OpenCode |
| **Z.AI** | GLM-4.7, GLM-5.1 | Qwen Code, Claude Code, OpenCode |

### Где взять API ключи

- **NVIDIA NIM**: [https://build.nvidia.com/](https://build.nvidia.com/) — бесплатный ключ после регистрации
- **Z.AI**: [https://open.bigmodel.cn/](https://open.bigmodel.cn/) — GLM API

---

## После установки

### Запуск

Просто дважды кликните на ярлык на рабочем столе:

- **Qwen Code (cloud)** — меню выбора модели/провайдера
- **Claude Code (cloud)** — меню выбора провайдера
- **OpenCode (cloud)** — меню выбора провайдера

### Смена API ключей

В меню лаунчера выберите пункт **«Сменить ключ API провайдера»**:

1. Выберите провайдера (NVIDIA NIM или Z.AI)
2. Введите новый ключ
3. Ключ сохраняется в переменных окружения

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
