[CmdletBinding()]
param(
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$dbDir = Join-Path $HOME ".claude-mem"
$dbPath = Join-Path $dbDir "claude-mem.db"
$pidFile = Join-Path $dbDir "worker.pid"

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

$npmBin = Join-Path $env:APPDATA "npm"
if (Test-Path -LiteralPath $npmBin) {
  $env:PATH = $npmBin + ";" + $env:PATH
}

# ── Шаг 1: показать текущую статистику ───────────────────────────────────────
Write-Host ""
Write-Host "  claude-mem — очистка памяти" -ForegroundColor Cyan
Write-Host "  ============================" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path -LiteralPath $dbPath)) {
  Write-Host "  База данных не найдена ($dbPath)." -ForegroundColor DarkYellow
  Write-Host "  Нечего очищать." -ForegroundColor DarkYellow
  Write-Host ""
  Read-Host "  Нажмите Enter для выхода"
  exit 0
}

$dbSize = (Get-Item -LiteralPath $dbPath).Length
$dbSizeMB = [Math]::Round($dbSize / 1MB, 2)

# Попробовать получить статистику через API
$obsCount = "?"
$sessCount = "?"
$summCount = "?"
try {
  $stats = Invoke-RestMethod -Uri "http://127.0.0.1:37777/api/stats" -Method Get -TimeoutSec 3
  $obsCount = $stats.database.observations
  $sessCount = $stats.database.sessions
  $summCount = $stats.database.summaries
} catch {}

Write-Host "  Текущее состояние:" -ForegroundColor White
Write-Host "    БД:          $dbPath" -ForegroundColor DarkGray
Write-Host "    Размер:      $dbSizeMB MB" -ForegroundColor White
Write-Host "    Наблюдений:  $obsCount" -ForegroundColor White
Write-Host "    Сессий:      $sessCount" -ForegroundColor White
Write-Host "    Сводок:      $summCount" -ForegroundColor White
Write-Host ""

if (-not $Force) {
  Write-Host "  Это удалит ВСЮ память claude-mem (наблюдения, сессии, сводки)." -ForegroundColor Yellow
  Write-Host "  БД будет пересоздана при следующем запуске." -ForegroundColor Yellow
  Write-Host ""
  $answer = Read-Host "  Подтвердите: введите 'да' для очистки"
  if ($answer -ne "да") {
    Write-Host ""
    Write-Host "  Отменено." -ForegroundColor DarkYellow
    Start-Sleep -Seconds 2
    exit 0
  }
}

# ── Шаг 2: остановить worker ─────────────────────────────────────────────────
Write-Host ""
Write-Host "  [1/4] Остановка claude-mem worker…" -ForegroundColor DarkCyan

if (Test-ClaudeMemPortOpen) {
  try {
    npx --yes claude-mem stop 2>$null | Out-Null
  } catch {}
  Start-Sleep -Seconds 2
}

if (Test-ClaudeMemPortOpen) {
  Write-Host "  Worker не остановился — принудительное завершение…" -ForegroundColor DarkYellow
  if (Test-Path -LiteralPath $pidFile) {
    $pid = [int](Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue)
    if ($pid -gt 0) {
      try { Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue } catch {}
    }
  }
  Start-Sleep -Seconds 2
}

if (Test-ClaudeMemPortOpen) {
  # Последняя попытка — убить по порту
  $conns = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq 37777 }
  foreach ($conn in $conns) {
    try { Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue } catch {}
  }
  Start-Sleep -Seconds 2
}

if (Test-ClaudeMemPortOpen) {
  Write-Host "  Не удалось остановить worker. Попробуйте вручную." -ForegroundColor Red
  Read-Host "  Нажмите Enter"
  exit 1
}

Write-Host "  Worker остановлен." -ForegroundColor Green

# ── Шаг 3: создать бэкап и удалить БД ────────────────────────────────────────
Write-Host "  [2/4] Создание бэкапа…" -ForegroundColor DarkCyan

$backupDir = Join-Path $dbDir "backups"
if (-not (Test-Path -LiteralPath $backupDir)) {
  New-Item -ItemType Directory -Path $backupDir | Out-Null
}

$stamp = Get-Date -Format "yyyy-MM-ddTHH-mm-ss"
$backupFile = Join-Path $backupDir "claude-mem-pre-clear-$stamp.db"
Copy-Item -LiteralPath $dbPath -Destination $backupFile -Force
Write-Host "  Бэкап: $backupFile" -ForegroundColor DarkGray

Write-Host "  [3/4] Удаление базы данных…" -ForegroundColor DarkCyan

Remove-Item -LiteralPath $dbPath -Force -ErrorAction SilentlyContinue

# Удалить WAL и SHM файлы
$dbWal = $dbPath + "-wal"
$dbShm = $dbPath + "-shm"
Remove-Item -LiteralPath $dbWal -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $dbShm -Force -ErrorAction SilentlyContinue

# Очистить observer-sessions
$obsSessDir = Join-Path $dbDir "observer-sessions"
if (Test-Path -LiteralPath $obsSessDir) {
  Get-ChildItem -LiteralPath $obsSessDir -File | Remove-Item -Force -ErrorAction SilentlyContinue
}

Write-Host "  БД удалена." -ForegroundColor Green

# ── Шаг 4: запустить worker (создаст пустую БД) ─────────────────────────────
Write-Host "  [4/4] Запуск claude-mem (создание чистой БД)…" -ForegroundColor DarkCyan

if (Test-Path -LiteralPath $pidFile) {
  Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}

npx --yes claude-mem start 2>$null | Out-Null

if (Wait-ClaudeMemReady -TimeoutSec 15) {
  Write-Host "  Worker запущен (127.0.0.1:37777)." -ForegroundColor Green
} else {
  Write-Host "  Worker не поднялся автоматически." -ForegroundColor DarkYellow
  Write-Host "  Используйте ярлык 'Claude Mem Start' для запуска." -ForegroundColor DarkYellow
}

# Показать итог
Write-Host ""
$newSize = "?"
if (Test-Path -LiteralPath $dbPath) {
  $newSize = "$([Math]::Round((Get-Item -LiteralPath $dbPath).Length / 1KB, 1)) KB"
}
Write-Host "  Готово! Память claude-mem очищена." -ForegroundColor Green
Write-Host "    Новая БД:  $newSize" -ForegroundColor White
Write-Host "    Бэкап:     $backupFile" -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Нажмите Enter для выхода"
