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
Write-Status "   ____ _     _             ____ _             __  __ " "Cyan"
Write-Status "  / ___| |__ (_)_ __   __ _|  _ \ |_   _      |  \/  | ___  ___" "Cyan"
Write-Status " | |   | '_ \| | '_ \ / _` | |_) | | | |_____| |\/| |/ _ \/ _ \" "Cyan"
Write-Status " | |___| | | | | | | | (_| |  __/| | |_|     | |  | |  __/ (_) |" "Cyan"
Write-Status "  \____|_| |_|_|_| |_|\__, |_|   |_|         |_|  |_|\___|\___/" "Cyan"
Write-Status "                      |___/                   " "Cyan"
Write-Status "" "Cyan"
Write-Status "              C L O U D   S E T U P  -  1-click install" "Yellow"
Write-Status "" "Cyan"
Write-Status "  Qwen Code + Claude Code + OpenCode" "Yellow"
Write-Status "" "Cyan"
Write-Status "======================================================================" "Cyan"
Write-Host ""

Write-Status "Checking dependencies..." "Cyan"

$missing = @()

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $missing += "git (https://git-scm.com/download/win)"
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    $missing += "Node.js LTS (https://nodejs.org/)"
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    $missing += "npm (installs with Node.js)"
}

if ($missing.Count -gt 0) {
    Write-Status "Missing required tools:" "Red"
    foreach ($m in $missing) {
        Write-Status "  - $m" "Yellow"
    }
    Write-Host ""
    Write-Host "Install them and re-run this script." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    return
}

Write-Status "  [OK] git" "Green"
Write-Status "  [OK] node" "Green"
Write-Status "  [OK] npm" "Green"
Write-Host ""

if (Test-Path -LiteralPath (Join-Path $InstallDir ".git")) {
    Write-Status "Repo already cloned: $InstallDir" "Yellow"
    Write-Status "Updating (git pull)..." "Cyan"
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
            Write-Status "  [OK] Repository updated" "Green"
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
    Write-Status "Cloning repository..." "Cyan"
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
    Write-Status "  [OK] Repository cloned: $InstallDir" "Green"
}

Write-Host ""

Write-Status "======================================================================" "Cyan"
Write-Status "WHAT TO INSTALL?" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""
Write-Status "  [1] Qwen Code (cloud)" "Green"
Write-Status "  [2] Claude Code (cloud)" "Green"
Write-Status "  [3] OpenCode (cloud)" "Green"
Write-Status "  [4] All three" "Green"
Write-Status "  [5] Full uninstall (remove everything)" "Red"
Write-Status "  [0] Exit" "Gray"
Write-Host ""

$installChoice = Read-Host "Your choice [4]"

if ([string]::IsNullOrWhiteSpace($installChoice)) { $installChoice = "4" }

# --- Uninstall ---
if ($installChoice -eq "5") {
    Write-Host ""
    Write-Status "======================================================================" "Red"
    Write-Status "FULL UNINSTALL" "Red"
    Write-Status "======================================================================" "Red"
    Write-Host ""
    Write-Host "WARNING: This will remove:" -ForegroundColor Red
    Write-Host "  - Repository: $InstallDir" -ForegroundColor Red
    Write-Host "  - Session directories (qwen/claude/opencode-sessions)" -ForegroundColor Red
    Write-Host "  - CLI configs (~/.claude, ~/.qwen)" -ForegroundColor Red
    Write-Host "  - API keys (user environment variables)" -ForegroundColor Red
    Write-Host "  - Desktop shortcuts (.cmd, .lnk)" -ForegroundColor Red
    Write-Host "  - Global npm packages (qwen-code, claude-code, opencode-ai)" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Type 'yes' to confirm uninstall"
    if ($confirm -ne "yes") {
        Write-Status "Uninstall cancelled." "Yellow"
        Read-Host "Press Enter to exit"
        return
    }

    Write-Host ""
    Write-Status "Removing repository..." "Cyan"
    if (Test-Path -LiteralPath $InstallDir) {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "  [OK] Removed: $InstallDir" "Green"
    } else {
        Write-Status "  [SKIP] $InstallDir not found" "Yellow"
    }

    Write-Status "Removing CLI configs..." "Cyan"
    foreach ($cfg in @("$env:USERPROFILE\.claude", "$env:USERPROFILE\.qwen", "$env:USERPROFILE\.opencode")) {
        if (Test-Path -LiteralPath $cfg) {
            Remove-Item -LiteralPath $cfg -Recurse -Force -ErrorAction SilentlyContinue
            Write-Status "  [OK] Removed: $cfg" "Green"
        }
    }

    Write-Status "Removing API keys from user environment..." "Cyan"
    foreach ($var in @("NVIDIA_NIM_API_KEY", "ZAI_API_KEY", "OPENAI_API_KEY", "GROQ_API_KEY", "OPENROUTER_API_KEY")) {
        $existing = [Environment]::GetEnvironmentVariable($var, "User")
        if ($existing) {
            [Environment]::SetEnvironmentVariable($var, $null, "User")
            Write-Status "  [OK] Removed: $var" "Green"
        }
    }

    Write-Status "Removing desktop shortcuts..." "Cyan"
    $desktop = [Environment]::GetFolderPath("Desktop")
    if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE "Desktop" }
    foreach ($name in @("Qwen Code (cloud)", "Claude Code (cloud)", "OpenCode (cloud)")) {
        foreach ($ext in @(".cmd", ".lnk")) {
            $f = Join-Path $desktop "$name$ext"
            if (Test-Path -LiteralPath $f) {
                Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
                Write-Status "  [OK] Removed: $f" "Green"
            }
        }
    }

    Write-Status "Uninstalling global npm packages..." "Cyan"
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    foreach ($pkg in @("@qwen-code/qwen-code", "@anthropic-ai/qwen-code", "@anthropic-ai/claude-code", "opencode-ai")) {
        & npm.cmd uninstall -g $pkg 2>$null
        Write-Status "  [OK] Uninstalled: $pkg" "Green"
    }
    $ErrorActionPreference = $prevEAP

    Write-Host ""
    Write-Status "======================================================================" "Green"
    Write-Status "UNINSTALL COMPLETE!" "Green"
    Write-Status "======================================================================" "Green"
    Write-Host ""
    Write-Status "Restart your terminal to clear environment variables." "Yellow"
    Write-Host ""
    Read-Host "Press Enter to exit"
    return
}

$installQwen = $false
$installClaude = $false
$installOpenCode = $false

switch ($installChoice) {
    "1" { $installQwen = $true }
    "2" { $installClaude = $true }
    "3" { $installOpenCode = $true }
    "4" { $installQwen = $true; $installClaude = $true; $installOpenCode = $true }
    "0" { Write-Status "Exit." "Yellow"; return }
    default { Write-Status "Invalid choice. Installing all three." "Yellow"; $installQwen = $true; $installClaude = $true; $installOpenCode = $true }
}

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "INSTALLING CLI" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""

if ($installQwen) {
    Write-Status "Installing Qwen Code CLI..." "Cyan"
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
    Write-Status "Installing Claude Code CLI..." "Cyan"
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
}

if ($installOpenCode) {
    Write-Status "Installing OpenCode CLI..." "Cyan"
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
Write-Status "API KEY SETUP" "Magenta"
Write-Status "======================================================================" "Cyan"
Write-Host ""
Write-Status "Leave empty to skip. Keys can be changed later via launcher menu." "Yellow"
Write-Host ""

function Read-Secret($Prompt) {
    $sec = Read-Host -Prompt $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$nimKey = Read-Secret "NVIDIA NIM API key (Enter = skip): "
if (-not [string]::IsNullOrWhiteSpace($nimKey)) {
    [Environment]::SetEnvironmentVariable("NVIDIA_NIM_API_KEY", $nimKey.Trim(), "User")
    Write-Status "  [OK] NVIDIA_NIM_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] NVIDIA_NIM_API_KEY" "Yellow"
}

Write-Host ""

$zaiKey = Read-Secret "Z.AI API key (Enter = skip): "
if (-not [string]::IsNullOrWhiteSpace($zaiKey)) {
    [Environment]::SetEnvironmentVariable("ZAI_API_KEY", $zaiKey.Trim(), "User")
    Write-Status "  [OK] ZAI_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] ZAI_API_KEY" "Yellow"
}

Write-Host ""

$groqKey = Read-Secret "Groq API key (Enter = skip): "
if (-not [string]::IsNullOrWhiteSpace($groqKey)) {
    [Environment]::SetEnvironmentVariable("GROQ_API_KEY", $groqKey.Trim(), "User")
    Write-Status "  [OK] GROQ_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] GROQ_API_KEY" "Yellow"
}

Write-Host ""

$orKey = Read-Secret "OpenRouter API key (Enter = skip): "
if (-not [string]::IsNullOrWhiteSpace($orKey)) {
    [Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", $orKey.Trim(), "User")
    Write-Status "  [OK] OPENROUTER_API_KEY saved" "Green"
} else {
    Write-Status "  [SKIP] OPENROUTER_API_KEY" "Yellow"
}

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "SESSION SETUP (/resume)" "Magenta"
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
Write-Status "CREATING DESKTOP SHORTCUTS" "Magenta"
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
        $shell = New-Object -ComObject WScript.Shell -ErrorAction Stop
        $lnk = $shell.CreateShortcut($lnkPath)
        $lnk.TargetPath = $psExe
        $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"chcp 65001 | Out-Null; & '$launcher'`""
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

Write-Host ""
Write-Status "======================================================================" "Cyan"
Write-Status "INSTALL COMPLETE!" "Green"
Write-Status "======================================================================" "Cyan"
Write-Host ""
Write-Status "Repository: $InstallDir" "Gray"
Write-Host ""
Write-Status "Desktop shortcuts:" "Cyan"
if ($installQwen)  { Write-Status "  * Qwen Code (cloud)" "Green" }
if ($installClaude) { Write-Status "  * Claude Code (cloud)" "Green" }
if ($installOpenCode) { Write-Status "  * OpenCode (cloud)" "Green" }
Write-Host ""
Write-Status "Restart your terminal for API keys to take effect. Use the desktop shortcuts!" "Yellow"
Write-Host ""
Read-Host "Press Enter to exit"
