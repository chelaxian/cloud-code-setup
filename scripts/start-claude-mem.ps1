[CmdletBinding()]
param(
  [int]$OpenBrowser = 0,
  [switch]$SkipStatus,
  # Обновление плагина до последней версии (npx claude-mem update), затем stop/clean/start.
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
  Write-Host "claude-mem уже слушает 127.0.0.1:37777 - повторный старт не нужен." -ForegroundColor DarkGreen
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

# Сброс «зависшего» worker.pid: внутренний worker-service сразу exit(0), если считает дубликат - тогда HTTP не поднимается.
Write-Host "claude-mem: остановка и очистка stale PID…" -ForegroundColor DarkCyan

# Auto-install claude-mem if missing (non-interactive)
if (-not (Get-Command claude-mem -ErrorAction SilentlyContinue)) {
  $pluginDir = Join-Path $HOME ".claude\plugins\marketplaces\thedotmack\plugin"
  $workerScript = Join-Path $pluginDir "scripts\worker-service.cjs"
  if (-not (Test-Path -LiteralPath $workerScript)) {
    Write-Host "claude-mem не установлен. Выполняю неинтерактивную установку..." -ForegroundColor Cyan

    # Pre-create settings.json for non-interactive install (free OpenRouter model)
    $cmDataDir = Join-Path $HOME ".claude-mem"
    if (-not (Test-Path -LiteralPath $cmDataDir)) {
      New-Item -ItemType Directory -Path $cmDataDir -Force | Out-Null
    }
    $cmSettingsFile = Join-Path $cmDataDir "settings.json"
    if (-not (Test-Path -LiteralPath $cmSettingsFile)) {
      $existingOrKey = $env:OPENROUTER_API_KEY
      if ([string]::IsNullOrWhiteSpace($existingOrKey)) {
        $existingOrKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
      }
      $cmSettings = @{
        CLAUDE_MEM_PROVIDER       = "openrouter"
        CLAUDE_MEM_OPENROUTER_MODEL = "xiaomi/mimo-v2-flash:free"
        CLAUDE_MEM_OPENROUTER_API_KEY = if ($existingOrKey) { $existingOrKey } else { "" }
        CLAUDE_MEM_MODEL          = "claude-haiku-4-5-20251001"
        CLAUDE_MEM_CLAUDE_AUTH_METHOD = "subscription"
        CLAUDE_MEM_WORKER_PORT    = "37777"
      } | ConvertTo-Json -Depth 3
      [System.IO.File]::WriteAllText($cmSettingsFile, $cmSettings, (New-Object System.Text.UTF8Encoding($false)))
    }

    & npx.cmd --yes claude-mem install --non-interactive --provider openrouter 2>$null
    if ($LASTEXITCODE -ne 0) {
      & npm.cmd install -g claude-mem@latest 2>$null
      & npx.cmd --yes claude-mem install --non-interactive --provider openrouter 2>$null
    }
    if (-not (Test-Path -LiteralPath $workerScript)) {
      Write-Host "claude-mem: не удалось установить. Пропуск." -ForegroundColor Red
      exit 1
    }
    Write-Host "claude-mem: установлен." -ForegroundColor Green
  }
}

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
