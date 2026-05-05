# Dot-source после launcher-tui.ps1 и launcher-provider-models.ps1
# Возврат: [pscustomobject]@{ Provider = 'zai'|'nim'; ModelId = '...'; ClaudeNimModel = 'nvidia_nim/...' }
# NIM в мастере: полный API, пересечение с каталогом free/preview, или только встроенный статический список.

function Read-SecretTextWizard([string]$Prompt) {
  $sec = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Resolve-ZaiKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") { $k = $env:ZAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") { $k = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") { $k = $env:OPENAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k) -or $k -eq "__SET_ME__") {
    $k = Read-SecretTextWizard "Z.AI API key (не сохраняется)"
  }
  return $k.Trim()
}

function Resolve-NimKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k)) { $k = $env:NVIDIA_NIM_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k)) {
    $k = Read-SecretTextWizard "NVIDIA NIM API key (не сохраняется)"
  }
  return $k.Trim()
}

function Resolve-GroqKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("GROQ_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k)) { $k = $env:GROQ_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k)) {
    $k = Read-SecretTextWizard "Groq API key (не сохраняется)"
  }
  return $k.Trim()
}

function Resolve-OpenRouterKeyForWizard {
  $k = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($k)) { $k = $env:OPENROUTER_API_KEY }
  if ([string]::IsNullOrWhiteSpace($k)) {
    $k = Read-SecretTextWizard "OpenRouter API key (не сохраняется)"
  }
  return $k.Trim()
}

function Invoke-LauncherCustomModelWizard {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Qwen", "Claude", "OpenCode")]
    [string]$App
  )

  $brand = $App
  $provItems = @(
    [pscustomobject]@{ Id = "zai"; Label = "Z.AI — Coding / Anthropic (список моделей по вашему ключу)" }
    [pscustomobject]@{ Id = "nim"; Label = "NVIDIA NIM — полный каталог (GET /v1/models, все ID)" }
    [pscustomobject]@{ Id = "nim-bundled"; Label = "NVIDIA NIM — только free/preview (API ∩ встроенный список ~50)" }
    [pscustomobject]@{ Id = "nim-free"; Label = "NVIDIA NIM — free/preview (только статический список, без API)" }
    [pscustomobject]@{ Id = "groq"; Label = "Groq — полный каталог моделей (GET /v1/models, заблокирован в РФ)" }
    [pscustomobject]@{ Id = "groq-free"; Label = "Groq — только бесплатные модели (статический список)" }
    [pscustomobject]@{ Id = "openrouter"; Label = "OpenRouter — полный каталог моделей (GET /v1/models)" }
    [pscustomobject]@{ Id = "openrouter-free"; Label = "OpenRouter — только бесплатные модели (статический список)" }
  )

  while ($true) {
    $p1 = Show-TuiFramedMenu -AppBrand $brand -Title "Другая модель" -Subtitle "Шаг 1 из 2 — выберите провайдера" -Items $provItems -InitialIndex 0 -EscapeAction Back
    if ($null -eq $p1) { return $null }
    if ($true -eq $p1.__menuBack) { return [pscustomobject]@{ __menuBack = $true } }
    $provSource = [string]$p1.Id

    $ids = @()
    try {
      if ($provSource -eq "zai") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога моделей с API…"
        $key = Resolve-ZaiKeyForWizard
        $ids = @(Get-ZaiCodingModelIdsFromApi -ApiKey $key)
      }
      elseif ($provSource -eq "nim") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога NVIDIA NIM (полный список)…"
        $key = Resolve-NimKeyForWizard
        $ids = @(Get-NvidiaNimModelIdsFromApi -ApiKey $key)
      }
      elseif ($provSource -eq "nim-bundled") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка NIM и фильтр по каталогу free/preview…"
        $key = Resolve-NimKeyForWizard
        $ids = @(Get-NvidiaNimModelIdsFromApi -ApiKey $key -FilterToBundledFreeCatalog)
      }
      elseif ($provSource -eq "nim-free") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Встроенный каталог free/preview NIM (без GET /v1/models)…"
        $null = Resolve-NimKeyForWizard
        $ids = @(Get-NvidiaNimBundledFreeModelIds)
      }
      elseif ($provSource -eq "groq") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога Groq…"
        $key = Resolve-GroqKeyForWizard
        $ids = @(Get-GroqModelIdsFromApi -ApiKey $key)
      }
      elseif ($provSource -eq "groq-free") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка бесплатных моделей Groq…"
        $null = Resolve-GroqKeyForWizard
        $ids = @(Get-GroqBundledFreeModelIds)
      }
      elseif ($provSource -eq "openrouter") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога OpenRouter…"
        $key = Resolve-OpenRouterKeyForWizard
        $ids = @(Get-OpenRouterModelIdsFromApi -ApiKey $key)
      }
      elseif ($provSource -eq "openrouter-free") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка бесплатных моделей OpenRouter…"
        $null = Resolve-OpenRouterKeyForWizard
        $ids = @(Get-OpenRouterBundledFreeModelIds)
      }
      else {
        throw ("Неизвестный провайдер: {0}" -f $provSource)
      }
    } catch {
      Write-Host ("Ошибка API: {0}" -f $_.Exception.Message) -ForegroundColor Red
      Write-Host "Нажмите любую клавишу…" -ForegroundColor DarkYellow
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      return $null
    }

    if ($ids.Count -eq 0) {
      if ($provSource -eq "nim-bundled") {
        Write-Host "После фильтра free/preview список пуст. Проверьте NVIDIA_NIM_API_KEY или обновите Get-NvidiaNimBundledFreeModelIds в launcher-provider-models.ps1." -ForegroundColor Red
      } else {
        Write-Host "Провайдер вернул пустой список моделей." -ForegroundColor Red
      }
      Write-Host "Нажмите любую клавишу…" -ForegroundColor DarkYellow
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      return $null
    }

    $prov = if ($provSource -in @("nim", "nim-free", "nim-bundled")) { "nim" } elseif ($provSource -in @("groq", "groq-free")) { "groq" } elseif ($provSource -in @("openrouter", "openrouter-free")) { "openrouter" } else { $provSource }
    $provLabel = switch ($provSource) {
      "zai" { "Z.AI" }
      "nim" { "NIM (полный API)" }
      "nim-free" { "NIM free/preview (стат.)" }
      "nim-bundled" { "NIM (API ∩ free)" }
      "groq" { "Groq (полный API)" }
      "groq-free" { "Groq free (стат.)" }
      "openrouter" { "OpenRouter (полный API)" }
      "openrouter-free" { "OpenRouter free (стат.)" }
      default { $provSource.ToUpper() }
    }

    $modelItems = foreach ($id in $ids) {
      [pscustomobject]@{ Id = $id; Label = $id }
    }

    $pick = Show-TuiFramedMenu -AppBrand $brand -Title "Другая модель" -Subtitle ("Шаг 2 из 2 — {0}, моделей: {1}" -f $provLabel, $ids.Count) -Items $modelItems -InitialIndex 0 -MaxVisible 14 -EscapeAction Back
    if ($null -eq $pick) { return $null }
    if ($pick.__menuBack) { continue }

    $mid = [string]$pick.Id
    $claudeNim = $null
    if ($App -eq "Claude" -and $prov -eq "nim") {
      $claudeNim = Resolve-NvidiaNimFreeClaudeModel -OpenAiModelId $mid
    }

    return [pscustomobject]@{
      Provider        = $prov
      ModelId         = $mid
      ClaudeNimModel  = $claudeNim
    }
  }
}
