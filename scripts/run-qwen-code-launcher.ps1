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

$StatePath = Join-Path $PSScriptRoot "qwen-code-launcher-state.json"

$script:Profiles = @(
  @{
    Id          = "last"
    Label       = "Запустить с последними настройками (быстрый старт)"
    Description = "Пропуск меню: последний выбранный профиль"
  }
  @{
    Id          = "nim-glm"
    Label       = "NVIDIA NIM — GLM-4.7 (free, tool calling)"
    NimModel    = "nim-glm-4.7-tools"
  }
  @{
    Id          = "nim-qwen"
    Label       = "NVIDIA NIM — Qwen3.5-122B-A10B (free, tool calling)"
    NimModel    = "nim-qwen3.5-122b-a10b-tools"
  }
  @{
    Id          = "zai-glm"
    Label       = "Z.AI — GLM-4.7 (free, tool calling)"
  }
  @{
    Id          = "zai-glm51"
    Label       = "Z.AI — GLM-5.1 (free, tool calling)"
  }
  @{
    Id          = "groq-llama"
    Label       = "Groq — Llama 3.3 70B (free, chat only)"
  }
  @{
    Id          = "groq-qwen"
    Label       = "Groq — Qwen3 32B (free, chat only)"
  }
  @{
    Id          = "openrouter-qwen-coder"
    Label       = "OpenRouter — Qwen3 Coder (free, tool calling)"
  }
  @{
    Id          = "custom-model"
    Label       = "Другая модель… → выбор провайдера и модели"
  }
  @{
    Id          = "native-login"
    Label       = "Нативный логин (Qwen OAuth / Coding Plan)"
  }
  @{
    Id          = "change-api-key"
    Label       = "Сменить ключ API провайдера"
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
  if ($id -in @("nim-glm", "nim-qwen", "zai-glm", "zai-glm51", "groq-llama", "groq-qwen", "openrouter-qwen-coder", "custom-qwen-zai", "custom-qwen-nim", "custom-qwen-groq", "custom-qwen-openrouter")) { return $id }
  return $null
}

function Invoke-QwenProfile {
  param([string]$ProfileId)

  switch ($ProfileId) {
    "nim-glm" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "nim-glm-4.7-tools"
      return
    }
    "nim-qwen" {
      & (Join-Path $PSScriptRoot "run-qwen-code-nvidia-nim.ps1") -Model "nim-qwen3.5-122b-a10b-tools"
      return
    }
    "zai-glm" {
      & (Join-Path $PSScriptRoot "run-qwen-code-cloud-zai-glm47.ps1")
      return
    }
    "zai-glm51" {
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider zai -ModelId "glm-5.1"
      return
    }
    "groq-llama" {
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider groq -ModelId "llama-3.3-70b-versatile"
      return
    }
    "groq-qwen" {
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider groq -ModelId "qwen/qwen3-32b"
      return
    }
    "openrouter-qwen-coder" {
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider openrouter -ModelId "qwen/qwen3-coder:free"
      return
    }
    "custom-qwen-zai" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "В qwen-code-launcher-state.json нет customModelId для custom-qwen-zai. Выберите модель в пункте «Другая модель»."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider zai -ModelId $mid.Trim()
      return
    }
    "custom-qwen-nim" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "В qwen-code-launcher-state.json нет customModelId для custom-qwen-nim."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider nim -ModelId $mid.Trim()
      return
    }
    "custom-qwen-groq" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId для custom-qwen-groq. Выберите модель в «Другая модель»."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider groq -ModelId $mid.Trim()
      return
    }
    "custom-qwen-openrouter" {
      $st = Get-LauncherState
      $mid = [string]$st.customModelId
      if ([string]::IsNullOrWhiteSpace($mid)) {
        throw "Нет customModelId для custom-qwen-openrouter. Выберите модель в «Другая модель»."
      }
      & (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider openrouter -ModelId $mid.Trim()
      return
    }
    default {
      throw "Неизвестный профиль: $ProfileId"
    }
  }
}

if ($Quick -or $env:QWEN_CODE_LAUNCHER_QUICK -eq "1") {
  $st = Get-LauncherState
  $resolvedId = Resolve-ProfileFromState $st
  if (-not $resolvedId) {
    Write-Host "Нет сохранённого профиля. Один раз выберите модель в меню или уберите -Quick." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit 2
  }
  Invoke-QwenProfile -ProfileId $resolvedId
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
  $choice = Show-TuiFramedMenu -AppBrand "Qwen" -Title "Qwen Code — выбор профиля" -Subtitle "OpenAI Coding (Z.AI / NIM) + пресеты" -Items $items -InitialIndex $startIdx -MaxVisible 14
  if (-not $choice) {
    Write-Host "Отменено." -ForegroundColor Yellow
    exit 0
  }

  $profileId = [string]$choice.Id

  if ($profileId -eq "custom-model") {
    $w = Invoke-LauncherCustomModelWizard -App "Qwen"
    if ($null -eq $w) {
      Write-Host "Отменено." -ForegroundColor Yellow
      exit 0
    }
    if ($true -eq $w.__menuBack) { continue }
    $newId = switch ($w.Provider) {
      "zai" { "custom-qwen-zai" }
      "groq" { "custom-qwen-groq" }
      "openrouter" { "custom-qwen-openrouter" }
      default { "custom-qwen-nim" }
    }
    Save-LauncherState -ProfileId $newId -Extra @{ customModelId = [string]$w.ModelId }
    Invoke-QwenProfile -ProfileId $newId
    exit $LASTEXITCODE
  }

  if ($profileId -eq "native-login") {
    $loginItems = @(
      @{ Id = "qwen-oauth"; Label = "Qwen OAuth (браузер, подписка Qwen)" }
      @{ Id = "coding-plan"; Label = "Alibaba Cloud Coding Plan (API-ключ)" }
    )
    $loginChoice = Show-TuiFramedMenu -AppBrand "Qwen" -Title "Нативный логин Qwen Code" -Subtitle "Выберите способ авторизации" -Items $loginItems -MaxVisible 10
    if (-not $loginChoice) { continue }
    switch ([string]$loginChoice.Id) {
      "qwen-oauth" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Qwen OAuth — авторизация через браузер" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Откроется браузер. Завершите авторизацию в нём." -ForegroundColor Yellow
        Write-Host "  Для этого нужна подписка Qwen (qwen.ai)." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Если браузер не открылся — проверьте что у вас" -ForegroundColor DarkGray
        Write-Host "  есть аккаунт на qwen.ai и подписка." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Запуск..." -ForegroundColor Cyan
        & qwen auth qwen-oauth
        Write-Host ""
        Write-Host "  Авторизация завершена. Текущий статус:" -ForegroundColor Green
        & qwen auth status
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
      "coding-plan" {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Alibaba Cloud Coding Plan" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Регион: china или global" -ForegroundColor Yellow
        Write-Host "  Потребуется API-ключ от Alibaba Cloud." -ForegroundColor Yellow
        Write-Host ""
        & qwen auth coding-plan
        Write-Host ""
        Write-Host "  Текущий статус:" -ForegroundColor Green
        & qwen auth status
        Write-Host ""
        Write-Host "Нажмите любую клавишу для возврата в меню…" -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      }
    }
    continue
  }

  if ($profileId -eq "change-api-key") {
    Show-ApiKeyChangeMenu -AppBrand "Qwen"
    continue
  }

  if ($profileId -eq "last") {
    $st = Get-LauncherState
    $profileId = Resolve-ProfileFromState $st
    if (-not $profileId) {
      Write-Host "Сохранённый профиль не найден. Выберите пресет или «Другая модель» один раз." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      exit 2
    }
  } else {
    Save-LauncherState -ProfileId $profileId
  }

  Invoke-QwenProfile -ProfileId $profileId
  exit $LASTEXITCODE
}
