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
$launcherOpenCode = Join-Path $RepoRoot "scripts\run-opencode-launcher.ps1"
$memScript      = Join-Path $RepoRoot "scripts\start-claude-mem.ps1"

foreach ($p in @($launcherClaude, $launcherQwen, $launcherOpenCode, $memScript)) {
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
  -Description "Claude Code: Z.AI или NIM через free-claude-code - меню. Пресеты NIM без изменений. Другая модель (NIM вне GLM-4.7/Qwen3.5-122B/DeepSeek Terminus): tool_choice=none + content как строка + в лаунчере --tools minimal. Qwen: для таких NIM отдельно локальный прокси string-content."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "Qwen Code (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherQwen + '"') `
  -WorkingDirectory $RepoRoot `
  -Icon $IconLocation `
  -Description "Qwen Code: Z.AI Coding / NVIDIA NIM - меню. Пресеты NIM без изменений. Другая модель NIM: локальный прокси string-content + минимальный режим. У Claude для таких NIM - free-claude-code и --tools minimal. Z.AI без ограничений."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "OpenCode (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherOpenCode + '"') `
  -WorkingDirectory $RepoRoot `
  -Icon $IconLocation `
  -Description "OpenCode: Z.AI / NIM / OpenRouter - меню выбора модели."

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

Write-Host "Shortcuts created on desktop: Claude Code (cloud), Qwen Code (cloud), OpenCode (cloud), Claude Mem Start, Claude Mem Viewer." -ForegroundColor Green
Write-Host "RepoRoot=$RepoRoot  Desktop=$DesktopPath" -ForegroundColor DarkGray
