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

$VaultPath = "C:\Users\chelaxian\Documents\Obsidian Vault"
$ObsidianExe = "C:\Users\chelaxian\AppData\Local\Programs\Obsidian\Obsidian.exe"

$StatePath = Join-Path $PSScriptRoot "claude-cloud-launcher-state.json"
$SessionScript = Join-Path $PSScriptRoot "run-claude-cloud-session.ps1"

if (-not (Test-Path -LiteralPath $SessionScript)) {
  throw "Не найден скрипт: $SessionScript"
}

Write-Host "Claude (облако): общая подготовка (claude-mem, Obsidian, настройки)…" -ForegroundColor DarkCyan
& $SessionScript -PrepareOnly `
  -VaultPath $VaultPath `
  -ObsidianExe $ObsidianExe `
  -OpenClaudeMemObserver 1 `
  -ClaudeMemMaxWaitSec 35

$script:Profiles = @(
  @{
    Id    = "last"
    Label = "Запустить с последними настройками (быстрый старт)"
  }
  @{
    Id    = "claude-zai"
    Label = "Z.AI — GLM-4.7 (free, tool calling)"
  }
  @{
    Id    = "claude-zai-glm51"
    Label = "Z.AI — GLM-5.1 (free, tool calling)"
  }
  @{
    Id    = "claude-nim"
    Label = "NVIDIA NIM — GLM-4.7 (free, tool calling)"
  }
  @{
    Id    = "claude-nim-qwen"
    Label = "NVIDIA NIM — Qwen3.5-122B-A10B (free, tool calling)"
  }
  @{
    Id    = "claude-openrouter-sonnet"
    Label = "OpenRouter — Claude Sonnet 4 (paid, tool calling)"
  }
  @{
    Id    = "custom-model"
    Label = "Другая модель… → выбор провайдера и модели"
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
      "claude-zai", "claude-zai-glm51", "claude-nim", "claude-nim-qwen",
      "claude-openrouter-sonnet",
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
  Write-Host "Профиль: $ProfileId   Vault: $VaultPath" -ForegroundColor DarkGray
  [Console]::Out.Flush()

  switch ($ProfileId) {
    "claude-zai" {
      & $SessionScript -Provider zai -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-zai-glm51" {
      & $SessionScript -Provider zai -ZaiAnthropicModelId "glm-5.1" -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-nim" {
      & $SessionScript -Provider nim -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-nim-qwen" {
      & $SessionScript -Provider nim-qwen -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "claude-openrouter-sonnet" {
      & $SessionScript -Provider openrouter -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "custom-claude-zai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId в claude-cloud-launcher-state.json. Выберите модель в «Другая модель»."
      }
      & $SessionScript -Provider zai -ZaiAnthropicModelId $mid.Trim() -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
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
      & $SessionScript -Provider nim -NimModel $full.Trim() -ProxyPort $port -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools $claudeTools `
        -ClaudeMemMaxWaitSec 25 -OpenClaudeMemObserver $OpenClaudeMemObserver -SkipCommonPreamble
      return
    }
    "custom-claude-openrouter" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId для custom-claude-openrouter. Выберите модель в «Другая модель»."
      }
      & $SessionScript -Provider openrouter -ZaiAnthropicModelId $mid.Trim() -VaultPath $VaultPath -ObsidianExe $ObsidianExe -ClaudeTools default `
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
  $choice = Show-TuiFramedMenu -AppBrand "Claude" -Title "Claude Code (облако) — провайдер" -Subtitle "Z.AI · NIM · Groq · OpenRouter (через free-claude-code)" -Items $items -InitialIndex $startIdx -MaxVisible 14
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
