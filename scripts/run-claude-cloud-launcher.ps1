[CmdletBinding()]
param(
  [switch]$Quick
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")
. (Join-Path $PSScriptRoot "launcher-tui.ps1")
. (Join-Path $PSScriptRoot "launcher-provider-models.ps1")
. (Join-Path $PSScriptRoot "launcher-custom-model-wizard.ps1")
. (Join-Path $PSScriptRoot "launcher-api-keys.ps1")

$StatePath = Join-Path $PSScriptRoot "claude-cloud-launcher-state.json"
$SessionScript = Join-Path $PSScriptRoot "run-claude-cloud-session.ps1"

function Ensure-NpmBinInPath {
  $npmBin = Join-Path $env:APPDATA "npm"
  if ($npmBin -and (Test-Path -LiteralPath $npmBin)) {
    $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $npmBin.TrimEnd('\') })) {
      $env:PATH = $npmBin + ";" + $env:PATH
    }
  }
}

function Resolve-ClaudeExe {
  Ensure-NpmBinInPath
  $cmd = Get-Command claude.cmd -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command claude -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @(
      (Join-Path $env:APPDATA "npm\claude.cmd"),
      (Join-Path $env:APPDATA "npm\claude.ps1")
    )) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

function Invoke-CliCommand {
  param(
    [Parameter(Mandatory = $true)][string]$ExePath,
    [string[]]$Arguments = @()
  )
  if ($ExePath -like "*.cmd" -or $ExePath -like "*.bat") {
    $allArgs = @("/c", $ExePath) + $Arguments
    & cmd.exe @allArgs
  } else {
    if ($Arguments.Count -gt 0) {
      & $ExePath @Arguments
    } else {
      & $ExePath
    }
  }
}

if (-not (Test-Path -LiteralPath $SessionScript)) {
  throw "Не найден скрипт: $SessionScript"
}

$script:Profiles = @(
  @{
    Id    = "last"
    Label = "Запустить с последними настройками (быстрый старт)"
  }
  @{
    Id    = "claude-zai"
    Label = "Z.AI - GLM-4.7 (paid, tool calling)"
  }
  @{
    Id    = "claude-zai-glm51"
    Label = "Z.AI - GLM-5.1 (paid, tool calling)"
  }
  @{
    Id    = "claude-zai-flash47"
    Label = "Z.AI - GLM-4.7-Flash (free, tool calling)"
  }
  @{
    Id    = "claude-zai-flash45"
    Label = "Z.AI - GLM-4.5-Flash (free, tool calling)"
  }
  @{
    Id    = "claude-nim-qwen"
    Label = "NVIDIA NIM - Qwen3.5-122B-A10B (tool calling)"
  }
  @{
    Id    = "claude-openrouter-deepseek-v4-flash"
    Label = "OpenRouter - DeepSeek V4 Flash (free, tool calling)"
  }
  @{
    Id    = "claude-openrouter-qwen3-coder"
    Label = "OpenRouter - Qwen3 Coder (free, tool calling)"
  }
  @{
    Id    = "claude-openrouter-nemotron"
    Label = "OpenRouter - Nemotron 3 Super 120B (free, tool calling)"
  }
  @{
    Id    = "claude-openrouter-laguna"
    Label = "OpenRouter - Poolside Laguna M.1 (free, tool calling, coding)"
  }
  @{
    Id    = "custom-model"
    Label = "Другая модель… → выбор провайдера и модели"
  }
  @{
    Id    = "native-login"
    Label = "Нативный логин (Anthropic OAuth / Console)"
  }
  @{
    Id    = "change-api-key"
    Label = "Сменить ключ API провайдера"
  }
)

function Get-LauncherState {
  if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
  try {
    return (Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Save-LauncherState {
  param(
    [Parameter(Mandatory = $true)][string]$ProfileId,
    [hashtable]$Extra = @{}
  )
  $obj = [ordered]@{
    profileId = $ProfileId
    updatedAt = (Get-Date).ToString("o")
  }
  foreach ($k in $Extra.Keys) {
    $obj[$k] = $Extra[$k]
  }
  ($obj | ConvertTo-Json -Compress) | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Resolve-ProfileFromState($state) {
  if (-not $state -or [string]::IsNullOrWhiteSpace($state.profileId)) { return $null }
  $id = [string]$state.profileId
  if ($id -in @(
      "claude-zai", "claude-zai-glm51", "claude-zai-flash47", "claude-zai-flash45", "claude-nim", "claude-nim-qwen",
      "claude-openrouter-hy3", "claude-openrouter-deepseek-v4-flash", "claude-openrouter-qwen3-coder", "claude-openrouter-nemotron", "claude-openrouter-laguna",
      "custom-claude-zai", "custom-claude-nim", "custom-claude-openrouter"
    )) { return $id }
  return $null
}

function Invoke-ClaudeCloudProfile {
  param(
    [Parameter(Mandatory = $true)][string]$ProfileId,
    # Быстрый старт без PrepareOnly: открыть observer один раз здесь (после меню Prepare уже открыл вкладку).
    [int]$OpenClaudeMemObserver = 0
  )

  Clear-Host
  Write-Host "Запуск сессии Claude Code (облако)…" -ForegroundColor Cyan
  Write-Host "Профиль: $ProfileId" -ForegroundColor DarkGray
  [Console]::Out.Flush()

  switch ($ProfileId) {
    "claude-zai" {
      & $SessionScript -Provider zai -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-zai-glm51" {
      & $SessionScript -Provider zai -ZaiAnthropicModelId "glm-5.1" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-zai-flash47" {
      & $SessionScript -Provider zai -ZaiAnthropicModelId "glm-4.7-flash" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-zai-flash45" {
      & $SessionScript -Provider zai -ZaiAnthropicModelId "glm-4.5-flash" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-nim" {
      & $SessionScript -Provider nim-qwen -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-nim-qwen" {
      & $SessionScript -Provider nim-qwen -ClaudeTools default `
        -ClaudeMemMaxWaitSec 60 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-openrouter-hy3" {
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId "deepseek/deepseek-v4-flash:free" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-openrouter-deepseek-v4-flash" {
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId "deepseek/deepseek-v4-flash:free" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-openrouter-qwen3-coder" {
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId "qwen/qwen3-coder:free" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-openrouter-nemotron" {
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId "nvidia/nemotron-3-super-120b-a12b:free" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-openrouter-laguna" {
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId "poolside/laguna-m.1:free" -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "custom-claude-zai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId в claude-cloud-launcher-state.json. Выберите модель в «Другая модель»."
      }
      & $SessionScript -Provider zai -ZaiAnthropicModelId $mid.Trim() -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "custom-claude-nim" {
      $st = Get-LauncherState
      $full = [string]$st.customNimModel
      if ([string]::IsNullOrWhiteSpace($full)) {
        throw "Нет customNimModel в claude-cloud-launcher-state.json."
      }
      $catalog = $full.Trim().ToLowerInvariant()
      while ($catalog.StartsWith("nvidia_nim/")) {
        $catalog = $catalog.Substring("nvidia_nim/".Length)
      }
      $claudeTools = if (Test-NvidiaNimOpenAiNativeToolCalling $catalog) { "default" } else { "minimal" }
      $port = Get-LauncherFreeTcpPort
      & $SessionScript -Provider nim -NimModel $full.Trim() -ProxyPort $port -ClaudeTools $claudeTools `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "custom-claude-openrouter" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId для custom-claude-openrouter. Выберите модель в «Другая модель»."
      }
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId $mid.Trim() -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    default {
      throw "Неизвестный профиль: $ProfileId"
    }
  }
}

if ($Quick -or $env:CLAUDE_CLOUD_LAUNCHER_QUICK -eq "1") {
  $st = Get-LauncherState
  $resolvedId = Resolve-ProfileFromState $st
  if (-not $resolvedId) {
    Write-Host "Нет сохранённого профиля Claude (облако). Один раз выберите провайдер в меню." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit 2
  }
  Invoke-ClaudeCloudProfile -ProfileId $resolvedId -OpenClaudeMemObserver 1
  exit $LASTEXITCODE
}

$state = Get-LauncherState
$lastId = Resolve-ProfileFromState $state
$items = $script:Profiles
$startIdx = 0
if ($lastId) {
  for ($i = 0; $i -lt $items.Count; $i++) {
    if ($items[$i].Id -eq $lastId) { $startIdx = $i; break }
  }
} else {
  $startIdx = 1
}

while ($true) {
  $choice = Show-TuiFramedMenu -AppBrand "Claude" -Title "Claude Code (облако) - провайдер" -Subtitle "Z.AI · NIM · OpenRouter (через free-claude-code)" -Items $items -InitialIndex $startIdx -MaxVisible 20
  if (-not $choice) {
    Write-Host "Отменено." -ForegroundColor Yellow
    exit 0
  }

  $profileId = [string]$choice.Id

  if ($profileId -eq "custom-model") {
    $w = Invoke-LauncherCustomModelWizard -App "Claude"
    if ($null -eq $w) {
      Write-Host "Отменено." -ForegroundColor Yellow
      exit 0
    }
    if ($true -eq $w.__menuBack) { continue }
    switch ($w.Provider) {
      "zai" {
        Save-LauncherState -ProfileId "custom-claude-zai" -Extra @{ customModelId = [string]$w.ModelId }
        Invoke-ClaudeCloudProfile -ProfileId "custom-claude-zai"
      }
      "openrouter" {
        Save-LauncherState -ProfileId "custom-claude-openrouter" -Extra @{ customModelId = [string]$w.ModelId }
        Invoke-ClaudeCloudProfile -ProfileId "custom-claude-openrouter"
      }
      default {
        Save-LauncherState -ProfileId "custom-claude-nim" -Extra @{ customNimModel = [string]$w.ClaudeNimModel }
        Invoke-ClaudeCloudProfile -ProfileId "custom-claude-nim"
      }
    }
    exit $LASTEXITCODE
  }

  if ($profileId -eq "native-login") {
    $claudeExe = Resolve-ClaudeExe
    if (-not $claudeExe) {
      Write-Host "Claude Code CLI не найден (claude). Установите: npm install -g @anthropic-ai/claude-code@latest" -ForegroundColor Red
      Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }
    $loginItems = @(
      @{ Id = "claude-sub"; Label = "Claude подписка (OAuth, браузер)" }
      @{ Id = "anthropic-console"; Label = "Anthropic Console (API-биллинг, браузер)" }
      @{ Id = "vanilla"; Label = "Запуск Claude Code (ванильный запуск)" }
    )
    $loginChoice = Show-TuiFramedMenu -AppBrand "Claude" -Title "Нативный логин Claude Code" -Subtitle "Anthropic авторизация" -Items $loginItems -MaxVisible 10
    if (-not $loginChoice) { continue }
    switch ([string]$loginChoice.Id) {
      "claude-sub" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Claude OAuth - авторизация через браузер" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Откроется браузер. Завершите авторизацию в нём." -ForegroundColor Yellow
        Write-Host "  Нужна подписка Claude Pro / Max (claude.ai)." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Запуск..." -ForegroundColor Cyan
        Invoke-CliCommand -ExePath $claudeExe -Arguments @("auth", "login", "--claudeai")
        Write-Host ""
        Write-Host "  Текущий статус:" -ForegroundColor Green
        Invoke-CliCommand -ExePath $claudeExe -Arguments @("auth", "status")
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
      "anthropic-console" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Anthropic Console - авторизация через браузер" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Откроется браузер. Завершите авторизацию." -ForegroundColor Yellow
        Write-Host "  Нужен аккаунт на console.anthropic.com." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Запуск..." -ForegroundColor Cyan
        Invoke-CliCommand -ExePath $claudeExe -Arguments @("auth", "login", "--console")
        Write-Host ""
        Write-Host "  Текущий статус:" -ForegroundColor Green
        Invoke-CliCommand -ExePath $claudeExe -Arguments @("auth", "status")
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
      "vanilla" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Запуск Claude Code (ванильный запуск)" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Команда: claude" -ForegroundColor Yellow
        Write-Host ""
        Invoke-CliCommand -ExePath $claudeExe
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
    }
    continue
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "Claude"
    continue
  }

  if ($profileId -eq "last") {
    $st = Get-LauncherState
    $profileId = Resolve-ProfileFromState $st
    if (-not $profileId) {
      Write-Host "Сохранённый профиль не найден. Выберите пункт меню один раз." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      exit 2
    }
  } else {
    Save-LauncherState -ProfileId $profileId
  }

  Invoke-ClaudeCloudProfile -ProfileId $profileId
  exit $LASTEXITCODE
}
