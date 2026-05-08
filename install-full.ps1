# cloud-code-setup - Windows bootstrap (PowerShell)
# 1-click: irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | iex
# Or: git clone https://github.com/chelaxian/cloud-code-setup.git && cd cloud-code-setup && .\install.ps1

# TLS 1.2 for PowerShell 5.1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch {}

$ErrorActionPreference = "Stop"

if (-not $RepoUrl) { $RepoUrl = "https://github.com/chelaxian/cloud-code-setup.git" }
if (-not $InstallDir) { $InstallDir = "" }

Write-Host "cloud-code-setup :: starting..." -ForegroundColor Cyan

function Write-Status($Text, $Color = "White") {
    Write-Host $Text -ForegroundColor $Color
}

if (-not $InstallDir) {
    $InstallDir = Join-Path $env:USERPROFILE "cloud-code-setup"
}

try { Clear-Host } catch { }
Write-Status "======================================================================" "Cyan"
Write-Status "" "Cyan"
Write-Status "   ██████╗██╗     ██╗        ██████╗ ██████╗ ██████╗ ███████╗" "Cyan"
Write-Status "  ██╔════╝██║     ██║        ██╔════╝██╔═══██╗██╔══██╗██╔════╝" "Cyan"
Write-Status "  ██║     ██║     ██║ █████╗ ██║     ██║   ██║██║  ██║█████╗  " "Cyan"
Write-Status "  ██║     ██║     ██║ ╚════╝ ██║     ██║   ██║██║  ██║██╔══╝  " "Cyan"
Write-Status "  ╚██████╗███████╗██║        ╚██████╗╚██████╔╝██████╔╝███████╗" "Cyan"
Write-Status "   ╚═════╝╚══════╝╚═╝         ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝" "Cyan"
Write-Status "" "Cyan"
Write-Status "              C L O U D   C O D E  -  1-click install" "Yellow"
Write-Status "" "Cyan"
Write-Status "  Qwen Code + Claude Code + OpenCode" "Yellow"
Write-Status "" "Cyan"
Write-Status "======================================================================" "Cyan"
Write-Host ""

Write-Status "Проверка зависимостей..." "Cyan"

$hasWinget = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
$needRefresh = $false

# --- git ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Status "  git не найден, устанавливаем..." "Yellow"
    if ($hasWinget) {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements 2>&1 | ForEach-Object { Write-Host "    $_" }
        $ErrorActionPreference = $prevEAP
        $needRefresh = $true
    } else {
        Write-Status "  [WARN] winget не найден. Скачайте git вручную: https://git-scm.com/download/win" "Red"
        Read-Host "Нажмите Enter для выхода"
        return
    }
}

# --- node ---
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Status "  Node.js не найден, устанавливаем..." "Yellow"
    if ($hasWinget) {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements 2>&1 | ForEach-Object { Write-Host "    $_" }
        $ErrorActionPreference = $prevEAP
        $needRefresh = $true
    } else {
        Write-Status "  [WARN] winget не найден. Скачайте Node.js вручную: https://nodejs.org/" "Red"
        Read-Host "Нажмите Enter для выхода"
        return
    }
}

# --- npm (if node is present but npm missing) ---
if ((Get-Command node -ErrorAction SilentlyContinue) -and -not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Status "  npm не найден, обновляем..." "Yellow"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & node -e "require('child_process').exec('npm install -g npm@latest', {stdio:'inherit'})" 2>$null
    $ErrorActionPreference = $prevEAP
    $needRefresh = $true
}

# Refresh PATH if we installed something
if ($needRefresh) {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

# Final check
$allOk = $true
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Status "  [OK] git" "Green"
} else {
    Write-Status "  [WARN] git не найден после установки" "Red"
    $allOk = $false
}
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Status "  [OK] node" "Green"
} else {
    Write-Status "  [WARN] node не найден после установки" "Red"
    $allOk = $false
}
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Status "  [OK] npm" "Green"
} else {
    Write-Status "  [WARN] npm не найден после установки" "Red"
    $allOk = $false
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "Не все зависимости удалось установить. Перезапустите терминал и попробуйте снова." -ForegroundColor Red
    Read-Host "Нажмите Enter для выхода"
    return
}
Write-Host ""

if (Test-Path -LiteralPath (Join-Path $InstallDir ".git")) {
    Write-Status "Репозиторий уже клонирован: $InstallDir" "Yellow"
    Write-Status "Обновление…" "Cyan"
    Push-Location $InstallDir
    try {
        $prevPrompt = $env:GIT_TERMINAL_PROMPT
        $prevGcm = $env:GCM_INTERACTIVE
        $env:GIT_TERMINAL_PROMPT = "0"
        $env:GCM_INTERACTIVE = "Never"

        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        $out = git pull origin main 2>&1
        $code = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP

        if ($code -eq 0) {
            Write-Status "  [OK] Репозиторий обновлён" "Green"
        } else {
            Write-Status "  [WARN] git pull failed (code $code). Using local files." "Yellow"
            if ($out) { Write-Host $out }
        }
    } catch {
        Write-Status "  [WARN] Could not update" "Yellow"
    } finally {
        $env:GIT_TERMINAL_PROMPT = $prevPrompt
        $env:GCM_INTERACTIVE = $prevGcm
        Pop-Location
    }
} else {
    Write-Status "Клонирование репозитория…" "Cyan"
    $prevPrompt = $env:GIT_TERMINAL_PROMPT
    $prevGcm = $env:GCM_INTERACTIVE
    $env:GIT_TERMINAL_PROMPT = "0"
    $env:GCM_INTERACTIVE = "Never"

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = git clone $RepoUrl $InstallDir 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    $env:GIT_TERMINAL_PROMPT = $prevPrompt
    $env:GCM_INTERACTIVE = $prevGcm
    if ($code -ne 0) {
        Write-Host "Clone error (code $code). Check access to $RepoUrl" -ForegroundColor Red
        if ($out) { Write-Host $out }
        return
    }
    Write-Status "  [OK] Репозиторий клонирован: $InstallDir" "Green"
}

Write-Host ""

Write-Status "======================================================================" "Cyan"
Write-Status "ЧТО УСТАНАВЛИВАЕМ?" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""
Write-Status "  [1] Qwen Code (cloud)" "Green"
Write-Status "  [2] Claude Code (cloud)" "Green"
Write-Status "  [3] OpenCode (cloud)" "Green"
Write-Status "  [4] Все три" "Green"
Write-Status "  [5] Обновление всех компонентов" "Green"
Write-Status "  [6] Полное удаление (удалить всё)" "Red"
Write-Status "  [0] Выход" "Gray"
Write-Host ""

$installChoice = Read-Host "Ваш выбор [4]"

if ([string]::IsNullOrWhiteSpace($installChoice)) { $installChoice = "4" }

# --- Update all components ---
if ($installChoice -eq "5") {
    Write-Host ""
    Write-Status "======================================================================" "Cyan"
    Write-Status "ОБНОВЛЕНИЕ ВСЕХ КОМПОНЕНТОВ" "Magenta"
    Write-Status "======================================================================" "Cyan"
    Write-Host ""

    # git pull
    if (Test-Path -LiteralPath (Join-Path $InstallDir ".git")) {
        Write-Status "Обновление репозитория..." "Cyan"
        Push-Location $InstallDir
        try {
            $prevPrompt = $env:GIT_TERMINAL_PROMPT
            $prevGcm = $env:GCM_INTERACTIVE
            $env:GIT_TERMINAL_PROMPT = "0"
            $env:GCM_INTERACTIVE = "Never"
            $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
            $out = git pull origin main 2>&1
            $code = $LASTEXITCODE
            $ErrorActionPreference = $prevEAP
            if ($code -eq 0) {
                Write-Status "  [OK] Репозиторий обновлён" "Green"
            } else {
                Write-Status "  [WARN] git pull failed (code $code)" "Yellow"
                if ($out) { Write-Host $out }
            }
        } catch {
            Write-Status "  [WARN] Не удалось обновить" "Yellow"
        } finally {
            $env:GIT_TERMINAL_PROMPT = $prevPrompt
            $env:GCM_INTERACTIVE = $prevGcm
            Pop-Location
        }
    } else {
        Write-Status "  [SKIP] Репозиторий не найден, пропуск git pull" "Yellow"
    }

    Write-Host ""
    Write-Status "Обновление npm пакетов..." "Cyan"

    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"

    # Helper to get version before update
    function Get-PkgVersion($cmd) {
        $c = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($c) {
            try {
                $v = & $cmd --version 2>$null
                return $v.Trim()
            } catch { return "?" }
        }
        return $null
    }

    $pkgs = @(
        @{ Name = "qwen-code";  NpmPkg = "@qwen-code/qwen-code";      Fallback = "@anthropic-ai/qwen-code"; Cmd = "qwen" },
        @{ Name = "claude-code"; NpmPkg = "@anthropic-ai/claude-code"; Fallback = $null;                     Cmd = "claude" },
        @{ Name = "opencode-ai"; NpmPkg = "opencode-ai";               Fallback = $null;                     Cmd = "opencode" },
        @{ Name = "claude-mem";  NpmPkg = "claude-mem";                Fallback = $null;                     Cmd = "claude-mem" }
    )

    foreach ($pkg in $pkgs) {
        $before = Get-PkgVersion $pkg.Cmd
        & npm.cmd install -g "$($pkg.NpmPkg)@latest" 2>$null
        if ($LASTEXITCODE -ne 0 -and $pkg.Fallback) {
            & npm.cmd install -g "$($pkg.Fallback)@latest" 2>$null
        }
        $after = Get-PkgVersion $pkg.Cmd
        if ($after) {
            $verInfo = if ($before) { "($before → $after)" } else { "($after)" }
            Write-Status "  [OK] $($pkg.Name) $verInfo" "Green"
        } else {
            Write-Status "  [SKIP] $($pkg.Name) не установлен" "Yellow"
        }
    }

    # free-claude-code proxy update
    $fccDir = Join-Path $env:USERPROFILE ".free-claude-code"
    if (Test-Path -LiteralPath (Join-Path $fccDir ".git")) {
        Write-Status "Обновление free-claude-code proxy..." "Cyan"
        Push-Location $fccDir
        try {
            $prevEAP2 = $ErrorActionPreference; $ErrorActionPreference = "Continue"
            & git pull origin main 2>$null
            $uvExePath = Join-Path $env:USERPROFILE ".local\bin\uv.exe"
            if (Test-Path -LiteralPath $uvExePath) { & $uvExePath sync 2>$null }
            $ErrorActionPreference = $prevEAP2
            Write-Status "  [OK] free-claude-code обновлён" "Green"
        } catch {
            Write-Status "  [WARN] Не удалось обновить free-claude-code" "Yellow"
        } finally {
            Pop-Location
        }
    }

    $ErrorActionPreference = $prevEAP

    Write-Host ""
    Write-Status "======================================================================" "Green"
    Write-Status "ОБНОВЛЕНИЕ ЗАВЕРШЕНО!" "Green"
    Write-Status "======================================================================" "Green"
    Write-Host ""
    Read-Host "Нажмите Enter для выхода"
    return
}

# --- Uninstall ---
if ($installChoice -eq "6") {
    Write-Host ""
    Write-Status "======================================================================" "Red"
    Write-Status "ПОЛНОЕ УДАЛЕНИЕ" "Red"
    Write-Status "======================================================================" "Red"
    Write-Host ""
    Write-Host "ВНИМАНИЕ: будет удалено:" -ForegroundColor Red
    Write-Host "  - Repository: $InstallDir" -ForegroundColor Red
    Write-Host "  - Session directories (qwen/claude/opencode-sessions)" -ForegroundColor Red
    Write-Host "  - CLI configs (~/.claude, ~/.qwen)" -ForegroundColor Red
    Write-Host "  - claude-mem (данные и npm пакет)" -ForegroundColor Red
    Write-Host "  - free-claude-code proxy (~/.free-claude-code)" -ForegroundColor Red
    Write-Host "  - uv (Python package manager, ~/.local/bin/uv)" -ForegroundColor Red
    Write-Host "  - Obsidian (если установлен через winget)" -ForegroundColor Red
    Write-Host "  - API keys (user environment variables)" -ForegroundColor Red
    Write-Host "  - Desktop shortcuts (.cmd, .lnk)" -ForegroundColor Red
    Write-Host "  - Global npm packages (qwen-code, claude-code, opencode-ai)" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Введите 'yes' для подтверждения удаления"
    if ($confirm -ne "yes") {
        Write-Status "Удаление отменено." "Yellow"
        Read-Host "Нажмите Enter для выхода"
        return
    }

    Write-Host ""
    Write-Status "Удаляю репозиторий..." "Cyan"
    if (Test-Path -LiteralPath $InstallDir) {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "  [OK] Removed: $InstallDir" "Green"
    } else {
        Write-Status "  [SKIP] $InstallDir not found" "Yellow"
    }

    Write-Status "Удаляю конфиги CLI..." "Cyan"
    foreach ($cfg in @("$env:USERPROFILE\.claude", "$env:USERPROFILE\.qwen", "$env:USERPROFILE\.opencode")) {
        if (Test-Path -LiteralPath $cfg) {
            Remove-Item -LiteralPath $cfg -Recurse -Force -ErrorAction SilentlyContinue
            Write-Status "  [OK] Removed: $cfg" "Green"
        }
    }

    Write-Status "Удаляю API ключи из переменных окружения пользователя..." "Cyan"
    foreach ($var in @("NVIDIA_NIM_API_KEY", "ZAI_API_KEY", "OPENAI_API_KEY", "GROQ_API_KEY", "OPENROUTER_API_KEY")) {
        $existing = [Environment]::GetEnvironmentVariable($var, "User")
        if ($existing) {
            [Environment]::SetEnvironmentVariable($var, $null, "User")
            Write-Status "  [OK] Removed: $var" "Green"
        }
    }

    Write-Status "Удаляю ярлыки на рабочем столе..." "Cyan"
    $desktop = [Environment]::GetFolderPath("Desktop")
    if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE "Desktop" }
    foreach ($name in @("Qwen Code (cloud)", "Claude Code (cloud)", "OpenCode (cloud)", "Claude Mem Start", "Claude Mem Viewer", "Claude Mem Clear", "Obsidian")) {
        foreach ($ext in @(".cmd", ".lnk")) {
            $f = Join-Path $desktop "$name$ext"
            if (Test-Path -LiteralPath $f) {
                Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
                Write-Status "  [OK] Removed: $f" "Green"
            }
        }
    }

    Write-Status "Удаление данных claude-mem..." "Cyan"
    $claudeMemDir = Join-Path $env:USERPROFILE ".claude-mem"
    if (Test-Path -LiteralPath $claudeMemDir) {
        Remove-Item -LiteralPath $claudeMemDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "  [OK] Removed: $claudeMemDir" "Green"
    } else {
        Write-Status "  [SKIP] $claudeMemDir not found" "Yellow"
    }

    Write-Status "Удаление глобальных npm пакетов..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    foreach ($pkg in @("@qwen-code/qwen-code", "@anthropic-ai/qwen-code", "@anthropic-ai/claude-code", "opencode-ai", "claude-mem")) {
        & npm.cmd uninstall -g $pkg 2>$null
        Write-Status "  [OK] Uninstalled: $pkg" "Green"
    }
    $ErrorActionPreference = $prevEAP

    Write-Status "Удаление Obsidian..." "Cyan"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & winget uninstall -e --id Obsidian.Obsidian 2>$null
        $ErrorActionPreference = $prevEAP
        Write-Status "  [OK] Obsidian uninstall requested" "Green"
    } else {
        Write-Status "  [SKIP] winget не найден, Obsidian не удалён" "Yellow"
    }

    Write-Status "Удаление free-claude-code proxy..." "Cyan"
    $fccDir = Join-Path $env:USERPROFILE ".free-claude-code"
    if (Test-Path -LiteralPath $fccDir) {
        Remove-Item -LiteralPath $fccDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "  [OK] Removed: $fccDir" "Green"
    } else {
        Write-Status "  [SKIP] $fccDir not found" "Yellow"
    }

    Write-Status "Удаление uv (Python package manager)..." "Cyan"
    $uvDir = Join-Path $env:USERPROFILE ".local"
    if (Test-Path -LiteralPath $uvDir) {
        Remove-Item -LiteralPath $uvDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "  [OK] Removed: $uvDir" "Green"
    } else {
        Write-Status "  [SKIP] $uvDir not found" "Yellow"
    }

    Write-Host ""
    Write-Status "======================================================================" "Green"
    Write-Status "УДАЛЕНИЕ ЗАВЕРШЕНО!" "Green"
    Write-Status "======================================================================" "Green"
    Write-Host ""
    Write-Status "Перезапустите терминал, чтобы переменные окружения применились." "Yellow"
    Write-Host ""
    Read-Host "Нажмите Enter для выхода"
    return
}

$installQwen = $false
$installClaude = $false
$installOpenCode = $false
$installClaudeMem = $false
$installObsidian = $false

switch ($installChoice) {
    "1" { $installQwen = $true }
    "2" { $installClaude = $true }
    "3" { $installOpenCode = $true }
    "4" { $installQwen = $true; $installClaude = $true; $installOpenCode = $true }
    "0" { Write-Status "Выход." "Yellow"; return }
    default { Write-Status "Неверный выбор. Устанавливаем все три." "Yellow"; $installQwen = $true; $installClaude = $true; $installOpenCode = $true }
}

if ($installClaude) {
    Write-Host ""
    Write-Status "Дополнительные компоненты для Claude Code:" "Cyan"
    $cmAnswer = Read-Host "Установить claude-mem (memory plugin для Claude Code)? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($cmAnswer) -or $cmAnswer.Trim().ToLower() -eq "y" -or $cmAnswer.Trim().ToLower() -eq "д") {
        $installClaudeMem = $true
    }
    $obAnswer = Read-Host "Установить Obsidian (note-taking app для хранения сессий)? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($obAnswer) -or $obAnswer.Trim().ToLower() -eq "y" -or $obAnswer.Trim().ToLower() -eq "д") {
        $installObsidian = $true
    }
}

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "УСТАНОВКА CLI" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""

if ($installQwen) {
    Write-Status "Установка Qwen Code CLI..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & npm.cmd install -g @qwen-code/qwen-code@latest 2>$null
    if ($LASTEXITCODE -ne 0) {
        & npm.cmd install -g @anthropic-ai/qwen-code@latest 2>$null
    }
    $ErrorActionPreference = $prevEAP
    $qwenCmd = Get-Command qwen -ErrorAction SilentlyContinue
    if ($qwenCmd) {
        Write-Status "  [OK] Qwen Code CLI: $($qwenCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] Qwen Code CLI not found. Install manually:" "Yellow"
        Write-Status "         npm i -g @qwen-code/qwen-code" "Yellow"
    }
}

if ($installClaude) {
    Write-Status "Установка Claude Code CLI..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & npm.cmd install -g @anthropic-ai/claude-code@latest 2>$null
    $ErrorActionPreference = $prevEAP
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        Write-Status "  [OK] Claude Code CLI: $($claudeCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] Claude Code CLI not found. Install manually:" "Yellow"
        Write-Status "         npm i -g @anthropic-ai/claude-code" "Yellow"
    }

    Write-Status "" "Cyan"
    if ($installClaudeMem -or $installObsidian) {
        Write-Status "Claude: установка доп. компонентов..." "Magenta"
    }

    if ($installClaudeMem) {
    # claude-mem - полная неинтерактивная установка
    # Pre-create settings.json so the installer picks up defaults without prompting
    $claudeMemDataDir = Join-Path $env:USERPROFILE ".claude-mem"
    if (-not (Test-Path -LiteralPath $claudeMemDataDir)) {
        New-Item -ItemType Directory -Path $claudeMemDataDir -Force | Out-Null
    }
    $claudeMemSettingsFile = Join-Path $claudeMemDataDir "settings.json"

    $claudeMemSettings = @{
        CLAUDE_MEM_PROVIDER       = "claude"
        CLAUDE_MEM_CLAUDE_AUTH_METHOD = "api"
        CLAUDE_MEM_MODEL          = "claude-sonnet-4-6"
        CLAUDE_MEM_TIER_ROUTING_ENABLED = "true"
        CLAUDE_MEM_TIER_SIMPLE_MODEL = "haiku"
        CLAUDE_MEM_WORKER_PORT    = "37777"
        CLAUDE_MEM_WORKER_HOST    = "127.0.0.1"
        CLAUDE_MEM_MODE           = "code"
    } | ConvertTo-Json -Depth 3

    # Only write settings file if it doesn't already exist (preserve user's custom config)
    if (-not (Test-Path -LiteralPath $claudeMemSettingsFile)) {
        [System.IO.File]::WriteAllText($claudeMemSettingsFile, $claudeMemSettings, (New-Object System.Text.UTF8Encoding($false)))
        Write-Status "  [OK] claude-mem settings pre-configured (claude provider, api auth)" "Green"
    } else {
        Write-Status "  [OK] claude-mem settings already exist, keeping user config" "Green"
    }

    Write-Status "  Установка claude-mem через npm..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $npmOut = & npm.cmd install -g claude-mem@latest 2>&1
    $npmExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    
    $claudeMemInstalled = $false
    $claudeMemCmd = Get-Command claude-mem -ErrorAction SilentlyContinue
    
    if (-not $claudeMemCmd -and $npmExit -ne 0) {
        Write-Status "  npm install не удался (код: $npmExit). Пробуем npx..." "Yellow"
    }
    
    # Run 'claude-mem install --non-interactive' to initialise plugin dirs without prompts
    if ($claudeMemCmd) {
        Write-Status "  Инициализация claude-mem (non-interactive)..." "Cyan"
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & claude-mem install --non-interactive --provider claude 2>$null
        if ($LASTEXITCODE -ne 0) {
            & npx.cmd --yes claude-mem install --non-interactive --provider claude 2>$null
        }
        $ErrorActionPreference = $prevEAP
        Write-Status "  [OK] claude-mem установлен и инициализирован" "Green"
        $claudeMemInstalled = $true
    } else {
        # npm didn't create a binary — try npx to install and init
        Write-Status "  Установка claude-mem через npx (non-interactive)..." "Cyan"
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & npx.cmd --yes claude-mem install --non-interactive --provider claude 2>$null
        $ErrorActionPreference = $prevEAP
        $claudeMemCmd = Get-Command claude-mem -ErrorAction SilentlyContinue
        if ($claudeMemCmd) {
            Write-Status "  [OK] claude-mem установлен через npx" "Green"
            $claudeMemInstalled = $true
        } else {
            Write-Status "  [WARN] claude-mem не установлен глобально. Будет запускаться через npx (медленнее)." "Yellow"
        }
    }
    
    # Verify plugin directory exists (claude-mem needs this to run)
    $pluginDir = Join-Path $env:USERPROFILE ".claude\plugins\marketplaces\thedotmack\plugin"
    if (-not (Test-Path -LiteralPath $pluginDir)) {
        Write-Status "  Создание директории плагина claude-mem..." "Cyan"
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & npx.cmd --yes claude-mem install --non-interactive --provider claude 2>$null
        $ErrorActionPreference = $prevEAP
    }

    # Remind user to set OpenRouter API key for free model access
    if ([string]::IsNullOrWhiteSpace($existingOrKey)) {
        Write-Status "  [INFO] claude-mem использует OpenRouter free модель (xiaomi/mimo-v2-flash:free)." "Cyan"
        Write-Status "         Для работы наблюдений необходим API ключ OpenRouter (бесплатно):" "Cyan"
        Write-Status "         1. Зарегистрируйтесь: https://openrouter.ai/" "Cyan"
        Write-Status "         2. Создайте ключ:    https://openrouter.ai/keys" "Cyan"
        Write-Status "         3. Добавьте в settings: $claudeMemSettingsFile" "Cyan"
        Write-Status "            или установите переменную OPENROUTER_API_KEY" "Cyan"
    }
    } # end if ($installClaudeMem)

    # uv (Python package manager for free-claude-code)
    Write-Status "  Установка uv (Python package manager)..." "Cyan"
    $uvExe = Join-Path $env:USERPROFILE ".local\bin\uv.exe"
    if (-not (Test-Path -LiteralPath $uvExe)) {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        try {
            $uvInstallScript = Join-Path $env:TEMP "uv-install.ps1"
            Invoke-WebRequest -Uri "https://astral.sh/uv/install.ps1" -OutFile $uvInstallScript -UseBasicParsing
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $uvInstallScript 2>$null
            Remove-Item -LiteralPath $uvInstallScript -Force -ErrorAction SilentlyContinue
        } catch {
            # Fallback: try with curl
            & curl.exe -LsSf https://astral.sh/uv/install.sh -o "$env:TEMP\uv-install.sh" 2>$null
        }
        $ErrorActionPreference = $prevEAP
    }
    if (Test-Path -LiteralPath $uvExe) {
        Write-Status "  [OK] uv установлен: $uvExe" "Green"
    } else {
        # Check if it was installed to a different location
        $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
        if ($uvCmd) {
            Write-Status "  [OK] uv установлен: $($uvCmd.Source)" "Green"
        } else {
            Write-Status "  [WARN] uv не найден. NIM/OpenRouter для Claude будут недоступны." "Yellow"
        }
    }

    # free-claude-code proxy (for NIM/OpenRouter with Claude Code)
    $fccDir = Join-Path $env:USERPROFILE ".free-claude-code"
    if (-not (Test-Path -LiteralPath $fccDir)) {
        Write-Status "  Клонирование free-claude-code proxy..." "Cyan"
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & git clone https://github.com/Alishahryar1/free-claude-code.git $fccDir 2>$null
        $ErrorActionPreference = $prevEAP
        if (Test-Path -LiteralPath $fccDir) {
            # Pre-install deps
            if (Test-Path -LiteralPath $uvExe) {
                $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
                Push-Location $fccDir
                try { & $uvExe sync 2>$null } catch {}
                Pop-Location
                $ErrorActionPreference = $prevEAP
            }
            Write-Status "  [OK] free-claude-code установлен: $fccDir" "Green"
        } else {
            Write-Status "  [WARN] Не удалось клонировать free-claude-code. NIM/OpenRouter для Claude будут недоступны." "Yellow"
        }
    } else {
        Write-Status "  [OK] free-claude-code уже установлен" "Green"
    }

    # Obsidian (best-effort via winget)
    if ($installObsidian) {
    if (-not (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA "Programs\\Obsidian\\Obsidian.exe"))) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Status "  Установка Obsidian через winget..." "Cyan"
            $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
            $wingetResult = & winget install -e --id Obsidian.Obsidian --accept-source-agreements --accept-package-agreements 2>&1
            $wingetExitCode = $LASTEXITCODE
            $ErrorActionPreference = $prevEAP
            
            if ($wingetExitCode -ne 0) {
                Write-Status "  [WARN] Установка через winget не удалась (код: $wingetExitCode). Попробуйте вручную или проверьте соединение." "Yellow"
                Write-Status "         Ссылка для ручной установки: https://obsidian.md/download" "Cyan"
            }
        } else {
            Write-Status "  [WARN] winget не найден — Obsidian не установлен автоматически." "Yellow"
        }
    }
    if (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA "Programs\\Obsidian\\Obsidian.exe")) {
        Write-Status "  [OK] Obsidian найден" "Green"
    } else {
        Write-Status "  [WARN] Obsidian.exe не найден" "Yellow"
        Write-Status "         Установите вручную: https://obsidian.md/download" "Cyan"
        Write-Status "         Или через PowerShell: Invoke-WebRequest -Uri 'https://github.com/obsidianmd/obsidian-releases/releases/download/v1.12.7/Obsidian-1.12.7.exe' -OutFile 'Obsidian.exe'; .\Obsidian.exe" "Cyan"
    }
    } # end if ($installObsidian)
}

if ($installOpenCode) {
    Write-Status "Установка OpenCode CLI..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & npm.cmd install -g opencode-ai@latest 2>$null
    $ErrorActionPreference = $prevEAP
    $ocCmd = Get-Command opencode -ErrorAction SilentlyContinue
    if ($ocCmd) {
        Write-Status "  [OK] OpenCode CLI: $($ocCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] OpenCode CLI not found. Install manually:" "Yellow"
        Write-Status "         npm i -g opencode-ai@latest" "Yellow"
    }
}

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "НАСТРОЙКА API КЛЮЧЕЙ" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""
Write-Status "Оставьте пустым чтобы пропустить. Ключи можно поменять позже через меню лаунчера." "Yellow"
Write-Host ""

function Read-Secret($Prompt) {
    Write-Host -NoNewline $Prompt
    $key = ""
    while ($true) {
        $cki = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp")
        if ($cki.Key -eq "Enter") {
            Write-Host ""
            break
        } elseif ($cki.Key -eq "Backspace") {
            if ($key.Length -gt 0) {
                $key = $key.Substring(0, $key.Length - 1)
                Write-Host -NoNewline "`b `b"
            }
        } elseif ($cki.Key -eq "Escape") {
            Write-Host ""
            return ""
        } elseif (-not [string]::IsNullOrEmpty($cki.Character)) {
            $key += $cki.Character
            Write-Host -NoNewline "*"
        }
    }
    return $key
}

$nimKey = Read-Secret "NVIDIA NIM API key (Enter = пропустить): "
if (-not [string]::IsNullOrWhiteSpace($nimKey)) {
    [Environment]::SetEnvironmentVariable("NVIDIA_NIM_API_KEY", $nimKey.Trim(), "User")
    Write-Status "  [OK] NVIDIA_NIM_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] NVIDIA_NIM_API_KEY" "Yellow"
}

Write-Host ""

$zaiKey = Read-Secret "Z.AI API key (Enter = пропустить): "
if (-not [string]::IsNullOrWhiteSpace($zaiKey)) {
    [Environment]::SetEnvironmentVariable("ZAI_API_KEY", $zaiKey.Trim(), "User")
    Write-Status "  [OK] ZAI_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] ZAI_API_KEY" "Yellow"
}

Write-Host ""

$groqKey = Read-Secret "Groq API key (Enter = пропустить): "
if (-not [string]::IsNullOrWhiteSpace($groqKey)) {
    [Environment]::SetEnvironmentVariable("GROQ_API_KEY", $groqKey.Trim(), "User")
    Write-Status "  [OK] GROQ_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] GROQ_API_KEY" "Yellow"
}

Write-Host ""

$orKey = Read-Secret "OpenRouter API key (Enter = пропустить): "
if (-not [string]::IsNullOrWhiteSpace($orKey)) {
    [Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", $orKey.Trim(), "User")
    Write-Status "  [OK] OPENROUTER_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] OPENROUTER_API_KEY" "Yellow"
}

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "НАСТРОЙКА СЕССИЙ (/resume)" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""

if ($installQwen) {
    $sharedDir = Join-Path $InstallDir "qwen-sessions\_shared\.qwen"
    if (-not (Test-Path -LiteralPath $sharedDir)) { New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null }
    Write-Status "  [OK] qwen-sessions/_shared/" "Green"
}
if ($installClaude) {
    $claudeShared = Join-Path $InstallDir "claude-sessions\_shared"
    if (-not (Test-Path -LiteralPath $claudeShared)) { New-Item -ItemType Directory -Path $claudeShared -Force | Out-Null }
    Write-Status "  [OK] claude-sessions/_shared/" "Green"
}
if ($installOpenCode) {
    $ocShared = Join-Path $InstallDir "opencode-sessions\_shared"
    if (-not (Test-Path -LiteralPath $ocShared)) { New-Item -ItemType Directory -Path $ocShared -Force | Out-Null }
    Write-Status "  [OK] opencode-sessions/_shared/" "Green"
}

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "СОЗДАНИЕ ЯРЛЫКОВ НА РАБОЧЕМ СТОЛЕ" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""

$desktop = [Environment]::GetFolderPath("Desktop")
if (-not $desktop -or -not (Test-Path -LiteralPath $desktop)) {
    $desktop = Join-Path $env:USERPROFILE "Desktop"
    if (-not (Test-Path -LiteralPath $desktop)) {
        $desktop = $env:USERPROFILE
    }
}

$psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
if (-not $psExe) { $psExe = "powershell.exe" }
$scriptsDir = Join-Path $InstallDir "scripts"

function New-LauncherShortcut {
    param([string]$Name, [string]$ScriptFile)
    $launcher = Join-Path $scriptsDir $ScriptFile
    if (-not (Test-Path -LiteralPath $launcher)) { return }

    $cmdPath = Join-Path $desktop "$Name.cmd"
    $cmdContent = "@echo off`r`nchcp 65001 >nul 2>`&1`r`npowershell -NoProfile -ExecutionPolicy Bypass -Command `"& '$launcher'`"`r`nif ($LASTEXITCODE -ne 0) pause"
    [System.IO.File]::WriteAllText($cmdPath, $cmdContent, (New-Object System.Text.UTF8Encoding($false)))
    Write-Status "  [OK] $Name.cmd" "Green"

    $lnkPath = Join-Path $desktop "$Name.lnk"
    try {
        $cmdExe = (Get-Command cmd.exe -ErrorAction SilentlyContinue).Source
        if (-not $cmdExe) { $cmdExe = "$env:SystemRoot\System32\cmd.exe" }
        $shell = New-Object -ComObject WScript.Shell -ErrorAction Stop
        $lnk = $shell.CreateShortcut($lnkPath)
        $lnk.TargetPath = $cmdExe
        $lnk.Arguments = "/k chcp 65001 >nul & `"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
        $lnk.WorkingDirectory = $InstallDir
        $lnk.WindowStyle = 1
        $lnk.Save()
        Write-Status "  [OK] $Name.lnk" "Green"
    } catch {
        # .lnk failed, but .cmd is available
    }
}

if ($installQwen)     { New-LauncherShortcut -Name "Qwen Code (cloud)"     -ScriptFile "run-qwen-code-launcher.ps1" }
if ($installClaude)   { New-LauncherShortcut -Name "Claude Code (cloud)"   -ScriptFile "run-claude-cloud-launcher.ps1" }
if ($installOpenCode) { New-LauncherShortcut -Name "OpenCode (cloud)"      -ScriptFile "run-opencode-launcher.ps1" }

# Also (re)create shortcuts via the dedicated helper script (keeps them in sync)
try {
    $shortcutScript = Join-Path $scriptsDir "create-desktop-shortcuts.ps1"
    if (Test-Path -LiteralPath $shortcutScript) {
        $shortcutArgs = @("-RepoRoot", $InstallDir)
        if ($installClaudeMem) { $shortcutArgs += "-IncludeClaudeMem" }
        if ($installObsidian) { $shortcutArgs += "-IncludeObsidian" }
        & $psExe -NoProfile -ExecutionPolicy Bypass -File $shortcutScript @shortcutArgs 2>$null
    }
} catch { }

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "УСТАНОВКА ЗАВЕРШЕНА!" "Green"
Write-Status "======================================================================" "Cyan"
Write-Host ""
Write-Status "Repository: $InstallDir" "Gray"
Write-Host ""
Write-Status "Ярлыки на рабочем столе:" "Cyan"
if ($installQwen)  { Write-Status "  * Qwen Code (cloud)" "Green" }
if ($installClaude) { Write-Status "  * Claude Code (cloud)" "Green" }
if ($installOpenCode) { Write-Status "  * OpenCode (cloud)" "Green" }
Write-Host ""
Write-Status "Перезапустите терминал, чтобы API ключи применились. Запускайте через ярлыки!" "Yellow"
Write-Host ""
Read-Host "Нажмите Enter для выхода"
