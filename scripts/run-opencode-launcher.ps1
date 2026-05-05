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

$StatePath = Join-Path $PSScriptRoot "opencode-launcher-state.json"

$script:Profiles = @(
  @{
    Id    = "last"
    Label = "Запустить с последними настройками (быстрый старт)"
  }
  @{
    Id    = "zai-glm"
    Label = "Z.AI — GLM-4.7 (OpenAI-compatible Coding API)"
  }
  @{
    Id    = "nim-glm"
    Label = "NVIDIA NIM — GLM-4.7 (OpenAI-compatible, integrate API)"
  }
  @{
    Id    = "nim-deepseek"
    Label = "NVIDIA NIM — DeepSeek V3.1 Terminus (OpenAI-compatible)"
  }
  @{
    Id    = "custom-model"
    Label = "Другая модель… → Z.AI или NIM, список с API (прокрутка)"
  }
  @{
    Id    = "change-api-key"
    Label = "Сменить ключ API провайдера"
  }
)

function Get-LauncherState {
  if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
  try {
    $raw = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
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
  if ($id -in @("zai-glm", "nim-glm", "nim-deepseek", "custom-opencode-zai", "custom-opencode-nim")) { return $id }
  return $null
}

function Resolve-OpenCodeExe {
  # Проверяем npm bin в PATH
  $npmBin = Join-Path $env:APPDATA "npm"
  if ($npmBin -and (Test-Path -LiteralPath $npmBin)) {
    $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $npmBin.TrimEnd('\') })) {
      $env:PATH = $npmBin + ";" + $env:PATH
    }
  }

  # 1) .cmd — предпочтительный вариант (не завершает вызывающий скрипт через exit)
  $cmd = Get-Command opencode.cmd -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  # 2) Просто opencode
  $cmd = Get-Command opencode -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  # 3) Жёсткие пути
  foreach ($p in @(
      (Join-Path $npmBin "opencode.cmd"),
      (Join-Path $npmBin "opencode.ps1")
    )) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

function Write-OpenCodeConfig {
  param(
    [Parameter(Mandatory = $true)][string]$Provider,
    [Parameter(Mandatory = $true)][string]$Model,
    [Parameter(Mandatory = $true)][string]$BaseURL,
    [string]$ApiKey = ""
  )

  $configDir = Join-Path $PSScriptRoot "opencode-sessions"
  if (-not (Test-Path -LiteralPath $configDir)) {
    New-Item -ItemType Directory -Path $configDir | Out-Null
  }

  $apiKeyRef = ""
  if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
    $apiKeyRef = $ApiKey
  }

  $config = [ordered]@{
    '$schema' = "https://opencode.ai/config.json"
    provider  = [ordered]@{}
  }

  $providerConf = [ordered]@{
    npm     = "@ai-sdk/openai-compatible"
    name    = $Provider
    options = [ordered]@{
      baseURL = $BaseURL
    }
    models  = [ordered]@{}
  }

  if (-not [string]::IsNullOrWhiteSpace($apiKeyRef)) {
    $providerConf.options["apiKey"] = $apiKeyRef
  }

  $providerConf.models[$Model] = [ordered]@{
    name = $Model
  }

  $config.provider[$Provider] = $providerConf
  $config["model"] = "${Provider}/${Model}"

  $configPath = Join-Path $configDir "opencode.json"
  $json = ($config | ConvertTo-Json -Depth 10)
  [System.IO.File]::WriteAllText($configPath, $json, (New-Object System.Text.UTF8Encoding($false)))

  return $configPath
}

function Invoke-OpenCodeProfile {
  param([string]$ProfileId)

  $opencodeExe = Resolve-OpenCodeExe
  if (-not $opencodeExe) {
    throw "OpenCode CLI not found. Установите: npm install -g opencode-ai@latest"
  }

  $workingDir = Get-Location

  switch ($ProfileId) {
    "zai-glm" {
      $apiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = $env:ZAI_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User")
      }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        $apiKey = $env:OPENAI_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        throw "Z.AI API ключ не задан. Задайте ZAI_API_KEY или выберите «Сменить ключ API провайдера»."
      }

      $configPath = Write-OpenCodeConfig -Provider "zai" -Model "glm-4.7" -BaseURL "https://api.z.ai/api/openai/v1" -ApiKey $apiKey

      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (Z.AI GLM-4.7)…" -ForegroundColor Cyan
      & $opencodeExe
      return
    }
    "nim-glm" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = $env:NVIDIA_NIM_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "NVIDIA NIM API ключ не задан. Задайте NVIDIA_NIM_API_KEY или выберите «Сменить ключ API провайдера»."
      }

      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "z-ai/glm4.7" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey

      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM GLM-4.7)…" -ForegroundColor Cyan
      & $opencodeExe
      return
    }
    "nim-deepseek" {
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = $env:NVIDIA_NIM_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "NVIDIA NIM API ключ не задан. Задайте NVIDIA_NIM_API_KEY или выберите «Сменить ключ API провайдера»."
      }

      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model "deepseek-ai/deepseek-v3.1-terminus" -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey

      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM DeepSeek V3.1 Terminus)…" -ForegroundColor Cyan
      & $opencodeExe
      return
    }
    "custom-opencode-zai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId. Выберите модель в пункте «Другая модель»."
      }
      $apiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = $env:ZAI_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") { $apiKey = $env:OPENAI_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey) -or $apiKey -eq "__SET_ME__") {
        throw "Z.AI API ключ не задан. Задайте ZAI_API_KEY или выберите «Сменить ключ API провайдера»."
      }
      $configPath = Write-OpenCodeConfig -Provider "zai" -Model $mid.Trim() -BaseURL "https://api.z.ai/api/openai/v1" -ApiKey $apiKey
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (Z.AI custom: $($mid.Trim()))…" -ForegroundColor Cyan
      & $opencodeExe
      return
    }
    "custom-opencode-nim" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId. Выберите модель в пункте «Другая модель»."
      }
      $apiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = $env:NVIDIA_NIM_API_KEY }
      if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "NVIDIA NIM API ключ не задан. Задайте NVIDIA_NIM_API_KEY или выберите «Сменить ключ API провайдера»."
      }
      $configPath = Write-OpenCodeConfig -Provider "nvidia-nim" -Model $mid.Trim() -BaseURL "https://integrate.api.nvidia.com/v1" -ApiKey $apiKey
      $env:OPENCODE_CONFIG = $configPath
      Write-Host "Запуск OpenCode (NVIDIA NIM custom: $($mid.Trim()))…" -ForegroundColor Cyan
      & $opencodeExe
      return
    }
    default {
      throw "Неизвестный профиль: $ProfileId"
    }
  }
}

# ── Быстрый старт ────────────────────────────────────────────────────────────

if ($Quick -or $env:OPENCODE_LAUNCHER_QUICK -eq "1") {
  $st = Get-LauncherState
  $resolvedId = Resolve-ProfileFromState $st
  if (-not $resolvedId) {
    Write-Host "Нет сохранённого профиля. Один раз выберите модель в меню." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit 2
  }
  Invoke-OpenCodeProfile -ProfileId $resolvedId
  exit $LASTEXITCODE
}

# ── Главное меню ─────────────────────────────────────────────────────────────

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
  $choice = Show-TuiFramedMenu -AppBrand "OpenCode" -Title "OpenCode — выбор провайдера" -Subtitle "Z.AI · NVIDIA NIM (OpenAI-compatible)" -Items $items -InitialIndex $startIdx -MaxVisible 14
  if (-not $choice) {
    Write-Host "Отменено." -ForegroundColor Yellow
    exit 0
  }

  $profileId = [string]$choice.Id

  if ($profileId -eq "custom-model") {
    $w = Invoke-LauncherCustomModelWizard -App "OpenCode"
    if ($null -eq $w) {
      Write-Host "Отменено." -ForegroundColor Yellow
      exit 0
    }
    if ($true -eq $w.__menuBack) { continue }
    $newId = if ($w.Provider -eq "zai") { "custom-opencode-zai" } else { "custom-opencode-nim" }
    Save-LauncherState -ProfileId $newId -Extra @{ customModelId = [string]$w.ModelId }
    Invoke-OpenCodeProfile -ProfileId $newId
    exit $LASTEXITCODE
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "OpenCode"
    continue
  }

  if ($profileId -eq "last") {
    $st = Get-LauncherState
    $profileId = Resolve-ProfileFromState $st
    if (-not $profileId) {
      Write-Host "Сохранённый профиль не найден. Выберите провайдер один раз." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      exit 2
    }
  } else {
    Save-LauncherState -ProfileId $profileId
  }

  Invoke-OpenCodeProfile -ProfileId $profileId
  exit $LASTEXITCODE
}
