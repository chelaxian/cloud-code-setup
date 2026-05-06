[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("zai", "nim", "groq", "openrouter")]
  [string]$Provider,

  [Parameter(Mandatory = $true)]
  [string]$ModelId
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")
. (Join-Path $PSScriptRoot "launcher-provider-models.ps1")

function Read-SecretText([string]$Prompt) {
  $sec = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Ensure-NpmBinInPath {
  $npmBin = Join-Path $env:APPDATA "npm"
  if (Test-Path -LiteralPath $npmBin) {
    $env:PATH = $npmBin + ";" + $env:PATH
  }
}

function Resolve-QwenExe {
  $cmd = Get-Command qwen -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($p in @(
      (Join-Path $env:APPDATA "npm\qwen.cmd"),
      (Join-Path $env:APPDATA "npm\qwen.ps1")
    )) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

function Get-SafeDirName([string]$s) {
  $x = ($s -replace '[^a-zA-Z0-9._-]', '_')
  if ($x.Length -gt 48) { $x = $x.Substring(0, 48) }
  if ([string]::IsNullOrWhiteSpace($x)) { $x = "model" }
  return $x
}

function Build-QwenSettingsZai([string]$Mid) {
  return @{
    modelProviders = @{
      openai = @(
        @{
          id           = $Mid
          name         = ("Z.AI — {0} (dynamic)" -f $Mid)
          description  = "Coding API; extra_body как у GLM-4.7"
          envKey       = "OPENAI_API_KEY"
          baseUrl      = "https://api.z.ai/api/coding/paas/v4"
          generationConfig = @{
            timeout            = 600000
            maxRetries         = 4
            contextWindowSize  = 202752
            extra_body         = @{
              enable_thinking       = $true
              chat_template_kwargs  = @{
                enable_thinking = $true
                clear_thinking  = $false
              }
            }
            samplingParams = @{
              temperature = 0.6
              top_p         = 0.95
              max_tokens    = 81920
            }
          }
        }
      )
    }
    security = @{
      auth = @{ selectedType = "openai" }
    }
    model = @{ name = $Mid }
  }
}

function Build-QwenSettingsOpenAI {
  param(
    [Parameter(Mandatory = $true)][string]$Mid,
    [Parameter(Mandatory = $true)][string]$BaseUrl,
    [int]$ContextWindowSize = 131072,
    [int]$MaxTokens = 81920,
    [switch]$SkipStartupContext
  )
  $modelBlock = [ordered]@{ name = $Mid }
  if ($SkipStartupContext) {
    $modelBlock["skipStartupContext"] = $true
  }
  return @{
    modelProviders = @{
      openai = @(
        @{
          id           = $Mid
          name         = ("OpenAI-compat — {0}" -f $Mid)
          envKey       = "OPENAI_API_KEY"
          baseUrl      = $BaseUrl
          generationConfig = @{
            timeout            = 600000
            maxRetries         = 4
            contextWindowSize  = $ContextWindowSize
            samplingParams     = @{
              temperature = 0.6
              top_p         = 0.95
              max_tokens    = $MaxTokens
            }
          }
        }
      )
    }
    security = @{
      auth = @{ selectedType = "openai" }
    }
    model    = $modelBlock
  }
}

function Get-FreeListenPort {
  param([int]$Min = 39080, [int]$Max = 39179)
  for ($p = $Min; $p -le $Max; $p++) {
    $c = $null
    try {
      $c = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $p)
      $c.Start()
      $c.Stop()
      return $p
    } catch {
      if ($c) { try { $c.Stop() } catch {} }
    }
  }
  throw "Не найден свободный TCP-порт в диапазоне $Min-$Max для NIM-прокси."
}

function Wait-TcpListen {
  param([int]$Port, [int]$TimeoutSec = 15)
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
  while ([DateTime]::UtcNow -lt $deadline) {
    $c = $null
    try {
      $c = New-Object System.Net.Sockets.TcpClient
      $c.ReceiveTimeout = 800
      $c.SendTimeout = 800
      $ar = $c.BeginConnect("127.0.0.1", $Port, $null, $null)
      if (-not $ar.AsyncWaitHandle.WaitOne(900)) { continue }
      $c.EndConnect($ar)
      return
    } catch {
    } finally {
      if ($c) { try { $c.Close() } catch {} }
    }
    Start-Sleep -Milliseconds 200
  }
  throw "Прокси NIM не поднялся на 127.0.0.1:$Port за $TimeoutSec с."
}

function Start-NimStringContentProxy {
  param([int]$Port)
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) { throw "node не в PATH — нужен для nim-integrate-string-content-proxy.mjs" }
  $scriptPath = Join-Path $PSScriptRoot "nim-integrate-string-content-proxy.mjs"
  if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Не найден $scriptPath" }
  Start-Process -FilePath $node.Source -ArgumentList @("`"$scriptPath`"", "$Port") -WorkingDirectory $PSScriptRoot -WindowStyle Hidden | Out-Null
}

# Лимиты для динамических NIM вне белого списка (integrate часто даёт 4k–8k на «малых» free-моделях).
function Get-NimDynamicCompatLimits {
  param([Parameter(Mandatory = $true)][string]$ModelId)
  $l = $ModelId.Trim().ToLowerInvariant()
  while ($l.StartsWith("nvidia_nim/")) {
    $l = $l.Substring("nvidia_nim/".Length)
  }
  # ~4k суммарного контекста: мини-инструкт, safety, embed, tts, transfer tiny, riva, детекторы
  if ($l -match 'nemotron-mini|nemotron-3-content-safety|content-safety-reasoning|/gliner|/pii|\b300m\b|nemoretriever|nv-embed|embedcode|cosmos-transfer|cosmos-predict|magpie-tts|voicechat|safety-guard|zeroshot|llama-3\.1-nemotron-safety|transfer2\.5-2b|transfer1-7b|riva-translate|synthetic-video|active-speaker|video-detector|parakeet|whisper|/tts|text-to-speech') {
    return @{
      ContextWindowSize = 4096
      MaxTokens         = 512
      EnvMaxOutput      = 512
      Tier              = "micro"
    }
  }
  # Крупные чат-модели из каталога (всё ещё без нативного tool-calling в whitelist)
  if ($l -match '480b|235b|405b|70b|8x7b|8x22b|106b-a47b|\b128k\b|\b1m\b|qwen3-coder|minimax-m2|step-3\.5|solar-10\.7') {
    return @{
      ContextWindowSize = 131072
      MaxTokens         = 8192
      EnvMaxOutput      = 8192
      Tier              = "large"
    }
  }
  return @{
    ContextWindowSize = 16384
    MaxTokens         = 2048
    EnvMaxOutput      = 2048
    Tier              = "standard"
  }
}

function Build-QwenSettingsNim {
  param(
    [string]$Mid,
    [string]$BaseUrl = "https://integrate.api.nvidia.com/v1",
    [switch]$MinimalCompat,
    [hashtable]$CompatLimits = $null
  )

  # Модели с нативным tool calling на NIM — полный путь (как пресеты): прямой integrate, эвристики thinking.
  # Остальные динамические NIM: MinimalCompat + локальный прокси (content → string), без стартового контекста, tool_choice=none.
  $nativeTools = Test-NvidiaNimOpenAiNativeToolCalling $Mid

  $extra = [ordered]@{}
  if (-not $MinimalCompat) {
    $lower = $Mid.ToLowerInvariant()
    if ($lower -match "deepseek|terminus") {
      $extra["chat_template_kwargs"] = @{ thinking = $true }
    } elseif ($lower -match "glm|z-ai") {
      $extra["chat_template_kwargs"] = @{ enable_thinking = $true; clear_thinking = $false }
    }
  }
  if (-not $nativeTools) {
    $extra["tool_choice"] = "none"
  }
  $extraHt = @{}
  foreach ($k in $extra.Keys) { $extraHt[$k] = $extra[$k] }

  if ($MinimalCompat) {
    if (-not $CompatLimits) {
      $CompatLimits = Get-NimDynamicCompatLimits $Mid
    }
    $ctxWin = [int]$CompatLimits.ContextWindowSize
    $maxTok = [int]$CompatLimits.MaxTokens
    $tier = [string]$CompatLimits.Tier
    $desc = ("127.0.0.1 прокси → integrate; tier={0} ctx={1} max_out={2}; content string; skipStartupContext; tool_choice=none" -f $tier, $ctxWin, $maxTok)
  } elseif ($nativeTools) {
    $desc = "Прямой integrate.api.nvidia.com/v1; NIM + нативный tool calling (каталог)"
  } else {
    $desc = "Прямой integrate.api.nvidia.com/v1; NIM без tool_choice=auto (extra_body.tool_choice=none)"
  }

  if (-not $MinimalCompat) {
    $maxTok = 81920
    $ctxWin = 131072
  }

  $modelBlock = @{ name = $Mid }
  if ($MinimalCompat) {
    $modelBlock["skipStartupContext"] = $true
  }

  return @{
    modelProviders = @{
      openai = @(
        @{
          id           = $Mid
          name         = ("NVIDIA NIM — {0} (dynamic)" -f $Mid)
          description  = $desc
          envKey       = "OPENAI_API_KEY"
          baseUrl      = $BaseUrl
          generationConfig = @{
            timeout            = 600000
            maxRetries         = 4
            contextWindowSize  = $ctxWin
            extra_body         = $extraHt
            samplingParams     = @{
              temperature = 0.6
              top_p         = 0.95
              max_tokens    = $maxTok
            }
          }
        }
      )
    }
    security = @{
      auth = @{ selectedType = "openai" }
    }
    model    = $modelBlock
  }
}

Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_OPUS_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_SONNET_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:OPENAI_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:OPENAI_MODEL -ErrorAction SilentlyContinue
Remove-Item Env:DASHSCOPE_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:QWEN_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:ALIYUN_API_KEY -ErrorAction SilentlyContinue

$rootBase = Join-Path (Split-Path -Parent $PSScriptRoot) "qwen-sessions\_shared"
$sessionRoot = $rootBase
$qwenDir = Join-Path $sessionRoot ".qwen"
if (-not (Test-Path -LiteralPath $qwenDir)) {
  New-Item -ItemType Directory -Path $qwenDir -Force | Out-Null
}

if ($Provider -eq "zai") {
  $key = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = $env:ZAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = $env:OPENAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = Read-SecretText "Z.AI API key" }
  $env:OPENAI_API_KEY = $key.Trim()
  $cfg = Build-QwenSettingsZai -Mid $ModelId.Trim()
} elseif ($Provider -eq "zai-general") {
  $key = [Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = $env:ZAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = $env:OPENAI_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "__SET_ME__") { $key = Read-SecretText "Z.AI API key" }
  $env:OPENAI_API_KEY = $key.Trim()
  $mid = $ModelId.Trim()
  $cfg = @{
    modelProviders = @{
      openai = @(
        @{
          id              = $mid
          name            = "Z.AI General — $mid"
          envKey          = "OPENAI_API_KEY"
          baseUrl         = "https://api.z.ai/api/paas/v4"
          generationConfig = @{
            timeout         = 600000
            maxRetries      = 4
            contextWindowSize = 131072
            samplingParams  = @{
              temperature = 0.6
              top_p       = 0.95
              max_tokens  = 8192
            }
          }
        }
      )
    }
    security  = @{ auth = @{ selectedType = "openai" } }
    model     = @{ name = $mid }
    '$version' = 3
  }
} elseif ($Provider -eq "groq") {
  $key = [Environment]::GetEnvironmentVariable("GROQ_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($key)) { $key = $env:GROQ_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key)) { $key = Read-SecretText "Groq API key" }
  $env:OPENAI_API_KEY = $key.Trim()
  # Groq free tier: очень низкий TPM (6-12K). Урезаем контекст и пропускаем startup context.
  $groqCtx = 4096
  $groqMaxTok = 2048
  $groqMaxOut = 2048
  $groqMid = $ModelId.Trim().ToLowerInvariant()
  if ($groqMid -match "qwen3-32b") {
    $groqCtx = 4096
    $groqMaxTok = 2048
    $groqMaxOut = 2048
  } elseif ($groqMid -match "llama-3\.3-70b") {
    $groqCtx = 4096
    $groqMaxTok = 2048
    $groqMaxOut = 2048
  } elseif ($groqMid -match "llama-3\.1-8b") {
    $groqCtx = 4096
    $groqMaxTok = 2048
    $groqMaxOut = 2048
  } elseif ($groqMid -match "llama-4-scout") {
    $groqMaxTok = 4096
    $groqMaxOut = 4096
  } elseif ($groqMid -match "gpt-oss-120b") {
    $groqMaxTok = 4096
    $groqMaxOut = 4096
  } elseif ($groqMid -match "gpt-oss-20b") {
    $groqMaxTok = 4096
    $groqMaxOut = 4096
  }
  $cfg = Build-QwenSettingsOpenAI -Mid $ModelId.Trim() -BaseUrl "https://api.groq.com/openai/v1" -ContextWindowSize $groqCtx -MaxTokens $groqMaxTok -SkipStartupContext
  $script:GroqMaxOutput = $groqMaxOut
} elseif ($Provider -eq "openrouter") {
  $key = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($key)) { $key = $env:OPENROUTER_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key)) { $key = Read-SecretText "OpenRouter API key" }
  $env:OPENAI_API_KEY = $key.Trim()
  $orCtx = 16384
  $orMaxTok = 8192
  $orMaxOut = 8192
  $orMid = $ModelId.Trim().ToLowerInvariant()
  $cfg = Build-QwenSettingsOpenAI -Mid $ModelId.Trim() -BaseUrl "https://openrouter.ai/api/v1" -ContextWindowSize $orCtx -MaxTokens $orMaxTok -SkipStartupContext
  $script:OpenRouterMaxOutput = $orMaxOut
} else {
  $key = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY", "User")
  if ([string]::IsNullOrWhiteSpace($key)) { $key = $env:NVIDIA_NIM_API_KEY }
  if ([string]::IsNullOrWhiteSpace($key)) { $key = Read-SecretText "NVIDIA NIM API key" }
  $env:OPENAI_API_KEY = $key.Trim()
  $midTrim = $ModelId.Trim()
  $script:NimDynamicCompat = $false
  $script:NimCompatLimits = $null
  if (Test-NvidiaNimOpenAiNativeToolCalling $midTrim) {
    $cfg = Build-QwenSettingsNim -Mid $midTrim -BaseUrl "https://integrate.api.nvidia.com/v1"
  } else {
    $script:NimDynamicCompat = $true
    $script:NimCompatLimits = Get-NimDynamicCompatLimits $midTrim
    $px = Get-FreeListenPort
    Start-NimStringContentProxy -Port $px
    Wait-TcpListen -Port $px
    $cfg = Build-QwenSettingsNim -Mid $midTrim -BaseUrl ("http://127.0.0.1:{0}/v1" -f $px) -MinimalCompat -CompatLimits $script:NimCompatLimits
  }
}

$json = ($cfg | ConvertTo-Json -Depth 20)
$settingsPath = Join-Path $qwenDir "settings.json"
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))

$env:API_TIMEOUT_MS = "600000"
if ($Provider -eq "nim" -and $script:NimDynamicCompat -and $script:NimCompatLimits) {
  $env:QWEN_CODE_MAX_OUTPUT_TOKENS = [string]$script:NimCompatLimits.EnvMaxOutput
  $env:QWEN_CODE_EMIT_TOOL_USE_SUMMARIES = "0"
} elseif ($Provider -eq "groq" -and $script:GroqMaxOutput) {
  $env:QWEN_CODE_MAX_OUTPUT_TOKENS = [string]$script:GroqMaxOutput
  $env:QWEN_CODE_EMIT_TOOL_USE_SUMMARIES = "0"
} elseif ($Provider -eq "openrouter" -and $script:OpenRouterMaxOutput) {
  $env:QWEN_CODE_MAX_OUTPUT_TOKENS = [string]$script:OpenRouterMaxOutput
  $env:QWEN_CODE_EMIT_TOOL_USE_SUMMARIES = "0"
} else {
  $env:QWEN_CODE_MAX_OUTPUT_TOKENS = "81920"
  $env:QWEN_CODE_EMIT_TOOL_USE_SUMMARIES = "1"
}

Ensure-NpmBinInPath
$qwenExe = Resolve-QwenExe
if (-not $qwenExe) {
  throw "Qwen Code CLI не найден. npm install -g @qwen-code/qwen-code@latest"
}

Write-Host ("Qwen Code: {0} / модель {1} → {2}" -f $Provider, $ModelId, $sessionRoot) -ForegroundColor Cyan
Write-Host ("Все сессии /resume в едином пространстве (смена модели сохраняет историю)." -f "") -ForegroundColor DarkGray
if ($Provider -eq "nim" -and $script:NimDynamicCompat -and $script:NimCompatLimits) {
  Write-Host ("NIM (динамика): прокси string-content, skipStartupContext, tier={0} ctx={1} max_out={2}." -f $script:NimCompatLimits.Tier, $script:NimCompatLimits.ContextWindowSize, $script:NimCompatLimits.MaxTokens) -ForegroundColor DarkCyan
}

Push-Location $sessionRoot
try {
  if ($Provider -eq "groq") {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  Groq free tier: контекст уменьшен до 4K для стабильности.      ║" -ForegroundColor Yellow
    Write-Host "║  Agent mode работает с ограничениями TPM.                       ║" -ForegroundColor Yellow
    Write-Host "║  Для полного agent mode используйте Z.AI / NIM / OpenRouter.    ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    & $qwenExe
  } else {
    & $qwenExe
  }
} finally {
  Pop-Location
}
