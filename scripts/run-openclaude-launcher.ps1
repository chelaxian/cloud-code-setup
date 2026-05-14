[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "launcher-tui.ps1")
. (Join-Path $PSScriptRoot "launcher-api-keys.ps1")

function Resolve-OpenClaudeExe {
  $cmd = Get-Command openclaude.cmd -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command openclaude -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @((Join-Path $env:APPDATA "npm\openclaude.cmd"), (Join-Path $env:APPDATA "npm\openclaude.ps1"))) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

$items = @(
  [pscustomobject]@{ Id = "nim-qwen"; Label = "NVIDIA NIM - Qwen3.5-122B-A10B" },
  [pscustomobject]@{ Id = "provider"; Label = "OpenClaude providers setup (/provider)" },
  [pscustomobject]@{ Id = "vanilla"; Label = "Запустить OpenClaude без пресета" }
)

$choice = Show-TuiFramedMenu -AppBrand "OpenClaude" -Title "OpenClaude - выбор профиля" -Subtitle "OpenAI-compatible providers · NIM Qwen preset" -Items $items
if (-not $choice) { return }

$openClaudeExe = Resolve-OpenClaudeExe
if (-not $openClaudeExe) { throw "OpenClaude CLI не найден. Установите: npm install -g @gitlawb/openclaude" }

if ([string]$choice.Id -eq "nim-qwen") {
  $key = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($key)) { $key = $env:NVIDIA_NIM_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Host "NVIDIA NIM API ключ не задан." -ForegroundColor Yellow
    Write-Host "Получить ключ: https://build.nvidia.com/api-key" -ForegroundColor DarkCyan
    $key = Read-SecretText "Введите NVIDIA NIM API key"
    if (-not [string]::IsNullOrWhiteSpace($key)) {
      Set-ProviderApiKey -Provider "NVIDIA_NIM" -NewKey $key
    }
  }
  $env:CLAUDE_CODE_USE_OPENAI = "1"
  $env:OPENAI_API_KEY = $key
  $env:NVIDIA_API_KEY = $key
  $env:OPENAI_BASE_URL = "https://integrate.api.nvidia.com/v1"
  $env:OPENAI_MODEL = "qwen/qwen3.5-122b-a10b"
} elseif ([string]$choice.Id -eq "provider") {
  Write-Host "После запуска выполните /provider для настройки профиля." -ForegroundColor Cyan
  Start-Sleep -Seconds 1
}

Clear-Host
Write-Host "Запуск OpenClaude..." -ForegroundColor Cyan
& $openClaudeExe
