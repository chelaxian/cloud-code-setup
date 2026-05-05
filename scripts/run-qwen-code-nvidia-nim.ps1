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
  return Join-Path (Split-Path -Parent $PSScriptRoot) "qwen-sessions\_shared"
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
