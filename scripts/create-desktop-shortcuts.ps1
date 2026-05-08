# Создаёт ярлыки на рабочем столе: Claude/Qwen Code (cloud), OpenCode, claude-mem Start/Viewer/Clear.
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-desktop-shortcuts.ps1 -RepoRoot "D:\qwen-local-setup"

[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$DesktopPath = "",
  [switch]$IncludeClaudeMem,
  [switch]$IncludeObsidian
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
  $DesktopPath = [Environment]::GetFolderPath("Desktop")
}

$cmdExe = (Get-Command cmd.exe -ErrorAction Stop).Source
$psExe  = (Get-Command powershell.exe -ErrorAction Stop).Source
$ws = New-Object -ComObject WScript.Shell

$launcherClaude  = Join-Path $RepoRoot "scripts\run-claude-cloud-launcher.ps1"
$launcherQwen    = Join-Path $RepoRoot "scripts\run-qwen-code-launcher.ps1"
$launcherOpenCode = Join-Path $RepoRoot "scripts\run-opencode-launcher.ps1"
$memScript       = Join-Path $RepoRoot "scripts\start-claude-mem.ps1"
$clearMemScript  = Join-Path $RepoRoot "scripts\clear-claude-mem.ps1"

$filesToValidate = @($launcherClaude, $launcherQwen, $launcherOpenCode)
if ($IncludeClaudeMem) { $filesToValidate += @($memScript, $clearMemScript) }
foreach ($p in $filesToValidate) {
  if (-not (Test-Path -LiteralPath $p)) { throw "Не найден файл: $p" }
}

function New-Shortcut {
  param(
    [string]$LinkPath,
    [string]$TargetPath,
    [string]$Arguments,
    [string]$WorkingDirectory,
    [string]$Description
  )
  $s = $ws.CreateShortcut($LinkPath)
  $s.TargetPath = $TargetPath
  $s.Arguments = $Arguments
  $s.WorkingDirectory = $WorkingDirectory
  $s.WindowStyle = 1
  if ($Description) { $s.Description = $Description }
  $s.Save()

  # Make .lnk visible (not hidden) on desktop
  $item = Get-Item -LiteralPath $LinkPath
  $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
}

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "Claude Code (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherClaude + '"') `
  -WorkingDirectory $RepoRoot `
  -Description "Claude Code: Z.AI или NIM через free-claude-code - меню."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "Qwen Code (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherQwen + '"') `
  -WorkingDirectory $RepoRoot `
  -Description "Qwen Code: Z.AI Coding / NVIDIA NIM - меню."

New-Shortcut `
  -LinkPath (Join-Path $DesktopPath "OpenCode (cloud).lnk") `
  -TargetPath $cmdExe `
  -Arguments ('/k chcp 65001 >nul & ' + $psExe + ' -NoProfile -ExecutionPolicy Bypass -File "' + $launcherOpenCode + '"') `
  -WorkingDirectory $RepoRoot `
  -Description "OpenCode: Z.AI / NIM / OpenRouter - меню выбора модели."

if ($IncludeClaudeMem) {
  New-Shortcut `
    -LinkPath (Join-Path $DesktopPath "Claude Mem Start.lnk") `
    -TargetPath $psExe `
    -Arguments ('-NoProfile -ExecutionPolicy Bypass -File "' + $memScript + '" -OpenBrowser 0') `
    -WorkingDirectory $env:USERPROFILE `
    -Description "Старт claude-mem worker (127.0.0.1:37777)."

  New-Shortcut `
    -LinkPath (Join-Path $DesktopPath "Claude Mem Viewer.lnk") `
    -TargetPath $psExe `
    -Arguments ('-NoProfile -ExecutionPolicy Bypass -File "' + $memScript + '" -OpenBrowser 1') `
    -WorkingDirectory $env:USERPROFILE `
    -Description "claude-mem: старт при необходимости и открыть http://127.0.0.1:37777/"

  New-Shortcut `
    -LinkPath (Join-Path $DesktopPath "Claude Mem Clear.lnk") `
    -TargetPath $psExe `
    -Arguments ('-NoProfile -ExecutionPolicy Bypass -File "' + $clearMemScript + '" -Force') `
    -WorkingDirectory $env:USERPROFILE `
    -Description "Очистка памяти claude-mem (без подтверждения)."
}

# Hide the .ps1 script files referenced by shortcuts
$filesToHide = @($launcherClaude, $launcherQwen, $launcherOpenCode)
if ($IncludeClaudeMem) { $filesToHide += @($memScript, $clearMemScript) }
foreach ($p in $filesToHide) {
  $item = Get-Item -LiteralPath $p
  $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
}

# Hide any .cmd wrappers on the desktop
Get-ChildItem -LiteralPath $DesktopPath -Filter "*.cmd" | ForEach-Object {
  $_.Attributes = $_.Attributes -bor [System.IO.FileAttributes]::Hidden
}

$shortcutNames = @("Claude Code (cloud)", "Qwen Code (cloud)", "OpenCode (cloud)")
if ($IncludeClaudeMem) { $shortcutNames += @("Claude Mem Start", "Claude Mem Viewer", "Claude Mem Clear") }
Write-Host ("Shortcuts created on desktop: " + ($shortcutNames -join ", ")) -ForegroundColor Green
Write-Host "RepoRoot=$RepoRoot  Desktop=$DesktopPath" -ForegroundColor DarkGray
