# Dot-source после launcher-tui.ps1 и launcher-provider-models.ps1
# Возврат: [pscustomobject]@{ Provider = 'zai'|'nim'; ModelId = '...'; ClaudeNimModel = 'nvidia_nim/...' }
# Мастер показывает только динамически получаемые списки моделей из endpoint провайдера.

function Read-SecretTextWizard([string]$Prompt) {
  Write-Host -NoNewline $Prompt
  $key = ""
  while ($true) {
    $cki = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($cki.Key -eq "Enter" -or [int]$cki.Character -eq 13 -or [int]$cki.Character -eq 10) {
      Write-Host ""
      break
    } elseif ($cki.Key -eq "Backspace") {
      if ($key.Length -gt 0) {
        $key = $key.Substring(0, $key.Length - 1)
        Write-Host -NoNewline "`b `b"
      }
    } elseif ($cki.Key -eq "Escape") {
      Write-Host ""
      return ""
    } elseif ($cki.Character -and [int]$cki.Character -ge 32) {
      $key += $cki.Character
      Write-Host -NoNewline "*"
    }
  }
  return $key
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
    [pscustomobject]@{ Id = "zai"; Label = "Z.AI - Coding / Anthropic (GET /models по вашему ключу)" }
    [pscustomobject]@{ Id = "nim"; Label = "NVIDIA NIM - полный каталог (GET /v1/models)" }
    [pscustomobject]@{ Id = "groq"; Label = "Groq - полный каталог моделей (paid, GET /v1/models)" }
    [pscustomobject]@{ Id = "openrouter"; Label = "OpenRouter - полный каталог моделей (GET /v1/models)" }
  )

  # Groq не поддерживается для Claude Code (ограничение free-claude-code: nvidia_nim transport)
  if ($App -eq "Claude") {
    $provItems = @($provItems | Where-Object { $_.Id -notlike "groq*" })
  }

  while ($true) {
    $p1 = Show-TuiFramedMenu -AppBrand $brand -Title "Другая модель" -Subtitle "Шаг 1 из 2 - выберите провайдера" -Items $provItems -InitialIndex 0 -EscapeAction Back
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
      elseif ($provSource -eq "groq") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога Groq (paid)…"
        $key = Resolve-GroqKeyForWizard
        $ids = @(Get-GroqModelIdsFromApi -ApiKey $key)
      }
      elseif ($provSource -eq "openrouter") {
        Show-TuiWaitFrame -AppBrand $brand -Message "Загрузка каталога OpenRouter…"
        $key = Resolve-OpenRouterKeyForWizard
        $ids = @(Get-OpenRouterModelIdsFromApi -ApiKey $key)
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
      Write-Host "Провайдер вернул пустой список моделей." -ForegroundColor Red
      Write-Host "Нажмите любую клавишу…" -ForegroundColor DarkYellow
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      return $null
    }

    $prov = if ($provSource -eq "nim") { "nim" } elseif ($provSource -eq "groq") { "groq" } elseif ($provSource -eq "openrouter") { "openrouter" } else { $provSource }
    $provLabel = switch ($provSource) {
      "zai" { "Z.AI Coding" }
      "nim" { "NIM (полный API)" }
      "groq" { "Groq (paid API)" }
      "openrouter" { "OpenRouter (полный API)" }
      default { $provSource.ToUpper() }
    }

    $modelItems = foreach ($id in $ids) {
      [pscustomobject]@{ Id = $id; Label = $id }
    }

    $pick = Show-TuiFramedMenu -AppBrand $brand -Title "Другая модель" -Subtitle ("Шаг 2 из 2 - {0}, моделей: {1}" -f $provLabel, $ids.Count) -Items $modelItems -InitialIndex 0 -MaxVisible 14 -EscapeAction Back
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
