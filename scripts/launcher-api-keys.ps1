# Модуль для управления API ключами в лаунчерах Qwen/Claude

function Get-CurrentApiKey {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("NVIDIA_NIM", "ZAI")]
    [string]$Provider
  )

  switch ($Provider) {
    "NVIDIA_NIM" {
      $key = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($key)) {
        $key = $env:NVIDIA_NIM_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        return ""
      } else {
        return $key.Trim()
      }
    }
    "ZAI" {
      $key = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        $key = $env:ZAI_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        $key = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User")
      }
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        $key = $env:OPENAI_API_KEY
      }
      if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") {
        return ""
      } else {
        return $key.Trim()
      }
    }
    default { return "" }
  }
}

function Read-SecretText {
  param([string]$Prompt)
  $sec = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Set-ProviderApiKey {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("NVIDIA_NIM", "ZAI")]
    [string]$Provider,
    [Parameter(Mandatory = $true)]
    [string]$NewKey
  )

  if ([string]::IsNullOrWhiteSpace($NewKey)) {
    throw "API ключ не может быть пустым"
  }

  switch ($Provider) {
    "NVIDIA_NIM" {
      [Environment]::SetEnvironmentVariable("NVIDIA_NIM_API_KEY", $NewKey.Trim(), "User")
      Write-Host "NVIDIA NIM API ключ обновлён в переменных пользователя." -ForegroundColor Green
    }
    "ZAI" {
      [Environment]::SetEnvironmentVariable("ZAI_API_KEY", $NewKey.Trim(), "User")
      Write-Host "Z.AI API ключ обновлён в переменных пользователя." -ForegroundColor Green
    }
  }
}

function Show-ApiKeyChangeMenu {
  param(
    [ValidateSet("Qwen", "Claude", "OpenCode")]
    [string]$AppBrand = "Qwen"
  )

  . (Join-Path $PSScriptRoot "launcher-tui.ps1")

  $providers = @(
    @{
      Id    = "nim"
      Label = "NVIDIA NIM API ключ"
    }
    @{
      Id    = "zai"
      Label = "Z.AI API ключ"
    }
  )

  while ($true) {
    $choice = Show-TuiFramedMenu -AppBrand $AppBrand -Title "Сменить ключ API провайдера" -Subtitle "Выберите провайдер" -Items $providers -EscapeAction "Back"
    
    if ($null -eq $choice) {
      return $null
    }

    if ($choice.__menuBack) {
      return $null
    }

    $providerId = [string]$choice.Id
    $envVarName = if ($providerId -eq "nim") { "NVIDIA_NIM" } else { "ZAI" }
    $currentKey = Get-CurrentApiKey -Provider $envVarName

    Clear-Host
    Write-Host ("Провайдер: {0}" -f $choice.Label) -ForegroundColor Cyan
    if ([string]::IsNullOrWhiteSpace($currentKey)) {
      Write-Host "Текущий ключ: (не задан)" -ForegroundColor Yellow
    } else {
      $masked = if ($currentKey.Length -gt 12) {
        $currentKey.Substring(0, 6) + "..." + $currentKey.Substring($currentKey.Length - 6)
      } else {
        "***"
      }
      Write-Host ("Текущий ключ: {0}" -f $masked) -ForegroundColor Green
    }
    Write-Host ""
    
    $newKey = Read-SecretText "Введите новый API ключ (или оставьте пустым для отмены): "
    
    if ([string]::IsNullOrWhiteSpace($newKey)) {
      Write-Host "Отмена — ключ не изменён." -ForegroundColor Yellow
      Write-Host "Нажмите любую клавишу для продолжения..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      continue
    }

    try {
      Set-ProviderApiKey -Provider $envVarName -NewKey $newKey
      Write-Host ""
      Write-Host "Нажмите любую клавишу для продолжения..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
      Write-Host ("Ошибка: {0}" -f $_.Exception.Message) -ForegroundColor Red
      Write-Host "Нажмите любую клавишу для продолжения..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
  }
}
