# cloud-code-setup - Windows bootstrap (PowerShell)
# 1-click запуск (скопируйте целиком, вставьте в PowerShell и нажмите Enter):
#   Set-ExecutionPolicy Bypass -Scope Process -Force; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; & powershell -File $(New-Item -Path "$env:TEMP\ccs-inst.ps1" -Value (irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1) -Force).FullName
#
# Короткий вариант (может зависнуть на корпоративных прокси):
#   irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | iex
#
# Или: git clone https://github.com/chelaxian/cloud-code-setup.git && cd cloud-code-setup && .\install.ps1

# TLS 1.2 для PowerShell 5.1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch {}

$ErrorActionPreference = "Stop"

if (-not $RepoUrl) { $RepoUrl = "https://github.com/chelaxian/cloud-code-setup.git" }
if (-not $InstallDir) { $InstallDir = "" }

Write-Host "cloud-code-setup :: starting..." -ForegroundColor Cyan

function Write-Status($Text, $Color = "White") {
    Write-Host $Text -ForegroundColor $Color
}

# ─── Определение путей ───────────────────────────────────────────────────────

if (-not $InstallDir) {
    $InstallDir = Join-Path $env:USERPROFILE "cloud-code-setup"
}

# ─── Заголовок ───────────────────────────────────────────────────────────────
try { Clear-Host } catch { }
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "" "Cyan"
Write-Status "   ██████╗██╗     ██╗        ██████╗ ██████╗ ██████╗ ███████╗" "Cyan"
Write-Status "  ██╔════╝██║     ██║        ██╔════╝██╔═══██╗██╔══██╗██╔════╝" "Cyan"
Write-Status "  ██║     ██║     ██║ █████╗ ██║     ██║   ██║██║  ██║█████╗  " "Cyan"
Write-Status "  ██║     ██║     ██║ ╚════╝ ██║     ██║   ██║██║  ██║██╔══╝  " "Cyan"
Write-Status "  ╚██████╗███████╗██║        ╚██████╗╚██████╔╝██████╔╝███████╗" "Cyan"
Write-Status "   ╚═════╝╚══════╝╚═╝         ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝" "Cyan"
Write-Status "" "Cyan"
Write-Status "              C L O U D   S E T U P  -  1-click install" "Yellow"
Write-Status "" "Cyan"
Write-Status "  Qwen Code + Claude Code + OpenCode" "Yellow"
Write-Status "" "Cyan"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""

# ─── Проверка зависимостей ───────────────────────────────────────────────────

Write-Status "Проверка зависимостей…" "Cyan"

$missing = @()

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $missing += "git (https://git-scm.com/download/win)"
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    $missing += "Node.js LTS (https://nodejs.org/)"
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    $missing += "npm (ставится вместе с Node.js)"
}

if ($missing.Count -gt 0) {
    Write-Status "Отсутствуют необходимые инструменты:" "Red"
    foreach ($m in $missing) {
        Write-Status "  - $m" "Yellow"
    }
    Write-Host ""
    Write-Status "Установите их и запустите инсталлятор заново." "Yellow"
    Write-Host ""
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

Write-Status "  [OK] git" "Green"
Write-Status "  [OK] node" "Green"
Write-Status "  [OK] npm" "Green"
Write-Host ""

# ─── Клонирование репозитория ────────────────────────────────────────────────

if (Test-Path -LiteralPath (Join-Path $InstallDir ".git")) {
    Write-Status "Репозиторий уже клонирован: $InstallDir" "Yellow"
    Write-Status "Обновление (git pull)…" "Cyan"
    Push-Location $InstallDir
    try {
        # Важно: не допускаем интерактивных prompt'ов git (иначе irm|iex выглядит как "висит")
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
            Write-Status "  [WARN] git pull не выполнен (код $code). Продолжаю с текущими файлами." "Yellow"
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
    Write-Status "Клонирование репозитория…" "Cyan"
    # Аналогично: git clone без интерактива
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
        Write-Status "Ошибка клонирования (код $code). Проверьте доступ к $RepoUrl" "Red"
        if ($out) { Write-Host $out }
        exit 1
    }
    Write-Status "  [OK] Репозиторий клонирован: $InstallDir" "Green"
}

Write-Host ""

# ─── Выбор инструментов ──────────────────────────────────────────────────────

Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "ЧТО УСТАНОВИТЬ?" "Magenta"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""
Write-Status "  [1] Qwen Code (cloud)" "Green"
Write-Status "  [2] Claude Code (cloud)" "Green"
Write-Status "  [3] OpenCode (cloud)" "Green"
Write-Status "  [4] Все три" "Green"
Write-Status "  [0] Выход" "Gray"
Write-Host ""

$installChoice = Read-Host "Ваш выбор [4]"

if ([string]::IsNullOrWhiteSpace($installChoice)) { $installChoice = "4" }

$installQwen = $false
$installClaude = $false
$installOpenCode = $false

switch ($installChoice) {
    "1" { $installQwen = $true }
    "2" { $installClaude = $true }
    "3" { $installOpenCode = $true }
    "4" { $installQwen = $true; $installClaude = $true; $installOpenCode = $true }
    "0" { Write-Status "Выход." "Yellow"; exit 0 }
    default { Write-Status "Неверный выбор. Устанавливаем все три." "Yellow"; $installQwen = $true; $installClaude = $true; $installOpenCode = $true }
}

# ─── Установка CLI ───────────────────────────────────────────────────────────

Write-Host ""
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "УСТАНОВКА CLI" "Magenta"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""

if ($installQwen) {
    Write-Status "Установка/обновление Qwen Code CLI..." "Cyan"
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
        Write-Status "  [WARN] Qwen Code CLI не установлен. Установите вручную:" "Yellow"
        Write-Status "         npm i -g @qwen-code/qwen-code" "Yellow"
    }
}

if ($installClaude) {
    Write-Status "Установка/обновление Claude Code CLI..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & npm.cmd install -g @anthropic-ai/claude-code@latest 2>$null
    $ErrorActionPreference = $prevEAP
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        Write-Status "  [OK] Claude Code CLI: $($claudeCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] Claude Code CLI не установлен. Установите вручную:" "Yellow"
        Write-Status "         npm i -g @anthropic-ai/claude-code" "Yellow"
    }
}

if ($installOpenCode) {
    Write-Status "Установка/обновление OpenCode CLI..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & npm.cmd install -g opencode-ai@latest 2>$null
    $ErrorActionPreference = $prevEAP
    $ocCmd = Get-Command opencode -ErrorAction SilentlyContinue
    if ($ocCmd) {
        Write-Status "  [OK] OpenCode CLI: $($ocCmd.Source)" "Green"
    } else {
        Write-Status "  [WARN] OpenCode CLI не установлен. Установите вручную:" "Yellow"
        Write-Status "         npm i -g opencode-ai@latest" "Yellow"
    }
}

Write-Host ""

# ─── API ключи ───────────────────────────────────────────────────────────────

Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "НАСТРОЙКА API КЛЮЧЕЙ" "Magenta"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""
Write-Status "Оставьте пустым, чтобы пропустить. Ключи можно изменить позже через меню лаунчера." "Yellow"
Write-Host ""

function Read-Secret($Prompt) {
    $sec = Read-Host -Prompt $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# NVIDIA NIM
$nimKey = Read-Secret "NVIDIA NIM API ключ (Enter = пропуск): "
if (-not [string]::IsNullOrWhiteSpace($nimKey)) {
    [Environment]::SetEnvironmentVariable("NVIDIA_NIM_API_KEY", $nimKey.Trim(), "User")
    Write-Status "  [OK] NVIDIA_NIM_API_KEY сохранён" "Green"
} else {
    Write-Status "  [SKIP] NVIDIA_NIM_API_KEY пропущен" "Yellow"
}

Write-Host ""

# Z.AI
$zaiKey = Read-Secret "Z.AI API ключ (Enter = пропуск): "
if (-not [string]::IsNullOrWhiteSpace($zaiKey)) {
    [Environment]::SetEnvironmentVariable("ZAI_API_KEY", $zaiKey.Trim(), "User")
    Write-Status "  [OK] ZAI_API_KEY сохранён" "Green"
} else {
    Write-Status "  [SKIP] ZAI_API_KEY пропущен" "Yellow"
}

Write-Host ""

# Groq
$groqKey = Read-Secret "Groq API ключ (Enter = пропуск): "
if (-not [string]::IsNullOrWhiteSpace($groqKey)) {
    [Environment]::SetEnvironmentVariable("GROQ_API_KEY", $groqKey.Trim(), "User")
    Write-Status "  [OK] GROQ_API_KEY сохранён" "Green"
} else {
    Write-Status "  [SKIP] GROQ_API_KEY пропущен" "Yellow"
}

Write-Host ""

# OpenRouter
$orKey = Read-Secret "OpenRouter API ключ (Enter = пропуск): "
if (-not [string]::IsNullOrWhiteSpace($orKey)) {
    [Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", $orKey.Trim(), "User")
    Write-Status "  [OK] OPENROUTER_API_KEY сохранён" "Green"
} else {
    Write-Status "  [SKIP] OPENROUTER_API_KEY пропущен" "Yellow"
}

Write-Host ""

# ─── Единое пространство /resume ──────────────────────────────────────────────

Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "НАСТРОЙКА СЕССИЙ (/resume)" "Magenta"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
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

# ─── Создание ярлыков ────────────────────────────────────────────────────────

Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "СОЗДАНИЕ ЯРЛЫКОВ НА РАБОЧЕМ СТОЛЕ" "Magenta"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
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

    # Всегда создаём .cmd файл для надёжности (кодировка UTF-8 + chcp 65001)
    $cmdPath = Join-Path $desktop "$Name.cmd"
    $cmdContent = "@echo off`r`nchcp 65001 >nul 2>`&1`r`npowershell -NoProfile -ExecutionPolicy Bypass -Command `"& '$launcher'`"`r`nif ($LASTEXITCODE -ne 0) pause"
    [System.IO.File]::WriteAllText($cmdPath, $cmdContent, (New-Object System.Text.UTF8Encoding($false)))
    Write-Status "  [OK] $Name.cmd → $cmdPath" "Green"

    # Также пробуем создать .lnk ярлык
    $lnkPath = Join-Path $desktop "$Name.lnk"
    try {
        $shell = New-Object -ComObject WScript.Shell -ErrorAction Stop
        $lnk = $shell.CreateShortcut($lnkPath)
        $lnk.TargetPath = $psExe
        $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"chcp 65001 | Out-Null; & '$launcher'`""
        $lnk.WorkingDirectory = $InstallDir
        $lnk.WindowStyle = 1
        $lnk.Save()
        Write-Status "  [OK] $Name.lnk → $lnkPath" "Green"
    } catch {
        # .lnk не создался, но .cmd уже есть
    }
}

if ($installQwen)     { New-LauncherShortcut -Name "Qwen Code (cloud)"     -ScriptFile "run-qwen-code-launcher.ps1" }
if ($installClaude)   { New-LauncherShortcut -Name "Claude Code (cloud)"   -ScriptFile "run-claude-cloud-launcher.ps1" }
if ($installOpenCode) { New-LauncherShortcut -Name "OpenCode (cloud)"      -ScriptFile "run-opencode-launcher.ps1" }

Write-Host ""

# ─── Итоги ───────────────────────────────────────────────────────────────────

Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Status "УСТАНОВКА ЗАВЕРШЕНА!" "Green"
Write-Status "════════════════════════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""
Write-Status "Репозиторий: $InstallDir" "Gray"
Write-Host ""
Write-Status "Ярлыки на рабочем столе:" "Cyan"
if ($installQwen)  { Write-Status "  * Qwen Code (cloud)" "Green" }
if ($installClaude) { Write-Status "  * Claude Code (cloud)" "Green" }
if ($installOpenCode) { Write-Status "  * OpenCode (cloud)" "Green" }
Write-Host ""
Write-Status "Перезапустите терминал для применения API ключей. Запускайте через ярлыки!" "Yellow"
Write-Host ""
Read-Host "Нажмите Enter для выхода"
