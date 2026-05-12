# Dot-source из лаунчеров: списки моделей по API-ключу (Z.AI Coding, NVIDIA NIM).

function Test-TcpPortListening([int]$Port) {
  try {
    $c = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalAddress -eq "127.0.0.1" -and $_.LocalPort -eq $Port })
    return ($c.Count -gt 0)
  } catch {
    return $false
  }
}

function Get-LauncherFreeTcpPort {
  param(
    [int]$Min = 8090,
    [int]$Max = 8140
  )
  for ($p = $Min; $p -le $Max; $p++) {
    if (-not (Test-TcpPortListening -Port $p)) { return $p }
  }
  throw "Не найден свободный TCP-порт на 127.0.0.1 в диапазоне $Min..$Max"
}

function Invoke-LauncherJsonGet {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [hashtable]$Headers = @{},
    [int]$TimeoutSec = 25
  )
  $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
  $useBasic = $iwr.Parameters.ContainsKey("UseBasicParsing")
  $params = @{
    Uri             = $Uri
    Method          = "Get"
    TimeoutSec      = $TimeoutSec
    ErrorAction     = "Stop"
  }
  if ($Headers.Count -gt 0) { $params.Headers = $Headers }
  if ($useBasic) { $params.UseBasicParsing = $true }
  $resp = Invoke-WebRequest @params
  return ($resp.Content | ConvertFrom-Json)
}

# У NVIDIA NIM (integrate OpenAI) нативный tool calling в Qwen Code имеет смысл только для моделей,
# явно помеченных в каталоге как Tool Calling / strict function calling (по списку пользователя).
# Для всех остальных NIM-моделей: в run-qwen-code-dynamic.ps1 - tool_choice=none, локальный прокси
# nim-integrate-string-content-proxy.mjs (content → string, trim messages по ctx tier), model.skipStartupContext; эвристика tier
# micro/standard/large (contextWindowSize + max_tokens) в run-qwen-code-dynamic.ps1; в free-claude-code
# providers/nvidia_nim/request.py - tool_choice=none, flatten content, cap max_tokens по тем же tier; custom Claude NIM -
# в run-claude-cloud-launcher.ps1 --tools minimal. Префикс nvidia_nim/ учитывается в Test-NvidiaNimOpenAiNativeToolCalling.
# чтобы не слать tool_choice=auto (ошибка vLLM 400 про --enable-auto-tool-choice).
function Test-NvidiaNimOpenAiNativeToolCalling {
  param([Parameter(Mandatory = $true)][string]$ModelId)
  $norm = $ModelId.Trim().ToLowerInvariant()
  while ($norm.StartsWith("nvidia_nim/")) {
    $norm = $norm.Substring("nvidia_nim/".Length)
  }
  foreach ($id in @(
      "z-ai/glm4.7"
      "qwen/qwen3.5-122b-a10b"
      "deepseek-ai/deepseek-v3.1-terminus"
    )) {
    if ($norm -eq $id) { return $true }
  }
  return $false
}

# Список free / preview NIM (вручную по каталогу build.nvidia.com, nim_type_preview).
# Обновляйте при необходимости: https://build.nvidia.com/models?filters=nimType%3Anim_type_preview
function Get-NvidiaNimBundledFreeModelIds {
  $raw = @(
    "z-ai/glm4.7"
    "z-ai/glm5"
    "z-ai/glm-5.1"
    "nvidia/nemotron-3-content-safety"
    "nvidia/synthetic-video-detector"
    "nvidia/active-speaker-detection"
    "minimaxai/minimax-m2.7"
    "nvidia/nemotron-voicechat"
    "nvidia/gliner-pii"
    "nvidia/cosmos-transfer2.5-2b"
    "stepfun-ai/step-3.5-flash"
    "nvidia/nemotron-content-safety-reasoning-4b"
    "deepseek-ai/deepseek-v3.2"
    "nvidia/riva-translate-4b-instruct-v1.1"
    "mistralai/devstral-2-123b-instruct-2512"
    "moonshotai/kimi-k2-thinking"
    "mistralai/mistral-large-3-675b-instruct-2512"
    "nvidia/streampetr"
    "nvidia/llama-3.1-nemotron-safety-guard-8b-v3"
    "deepseek-ai/deepseek-v3.1-terminus"
    "moonshotai/kimi-k2-instruct-0905"
    "bytedance/seed-oss-36b-instruct"
    "qwen/qwen3-coder-480b-a35b-instruct"
    "nvidia/llama-3_2-nemoretriever-300m-embed-v1"
    "moonshotai/kimi-k2-instruct"
    "mistralai/magistral-small-2506"
    "meta/llama-guard-4-12b"
    "google/gemma-3n-e4b-it"
    "google/gemma-3n-e2b-it"
    "nvidia/cosmos-transfer1-7b"
    "mistralai/mistral-nemotron"
    "nvidia/magpie-tts-zeroshot"
    "mistralai/mistral-medium-3-instruct"
    "meta/llama-4-maverick-17b-128e-instruct"
    "nvidia/cosmos-predict1-5b"
    "nvidia/sparsedrive"
    "nvidia/bevformer"
    "nvidia/nv-embedcode-7b-v1"
    "google/gemma-3-27b-it"
    "microsoft/phi-4-multimodal-instruct"
    "nvidia/usdcode"
    "nvidia/studiovoice"
    "abacusai/dracarys-llama-3.1-70b-instruct"
    "meta/esm2-650m"
    "nvidia/nemotron-mini-4b-instruct"
    "google/gemma-2-2b-it"
    "nvidia/usdvalidate"
    "nvidia/nv-embed-v1"
    "upstage/solar-10.7b-instruct"
    "google/paligemma"
    "nvidia/rerank-qa-mistral-4b"
    "meta/esmfold"
  )
  return ($raw | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-NvidiaNimModelIdsFromApi {
  param(
    [Parameter(Mandatory = $true)][string]$ApiKey,
    # Оставить только те ID, что есть и в ответе API, и во встроенном каталоге free/preview.
    [switch]$FilterToBundledFreeCatalog
  )
  $h = @{ Authorization = "Bearer $($ApiKey.Trim())" }
  $j = Invoke-LauncherJsonGet -Uri "https://integrate.api.nvidia.com/v1/models" -Headers $h
  if (-not $j.data) { return @() }
  $ids = [System.Collections.Generic.List[string]]::new()
  foreach ($row in @($j.data)) {
    $id = [string]$row.id
    if (-not [string]::IsNullOrWhiteSpace($id)) { $ids.Add($id.Trim()) | Out-Null }
  }
  $out = $ids | Sort-Object -Unique
  if ($FilterToBundledFreeCatalog) {
    $allow = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($x in @(Get-NvidiaNimBundledFreeModelIds)) { [void]$allow.Add($x) }
    $out = $out | Where-Object { $allow.Contains($_) }
  }
  return $out
}

function Get-ZaiCodingModelIdsFromApi {
  param([Parameter(Mandatory = $true)][string]$ApiKey)
  $h = @{ Authorization = "Bearer $($ApiKey.Trim())" }
  $uris = @(
    "https://api.z.ai/api/coding/paas/v4/models",
    "https://api.z.ai/api/paas/v4/models"
  )
  foreach ($u in $uris) {
    try {
      $j = Invoke-LauncherJsonGet -Uri $u -Headers $h -TimeoutSec 20
      if ($j.data) {
        $ids = [System.Collections.Generic.List[string]]::new()
        foreach ($row in @($j.data)) {
          $id = [string]$row.id
          if (-not [string]::IsNullOrWhiteSpace($id)) { $ids.Add($id.Trim()) | Out-Null }
        }
        if ($ids.Count -gt 0) { return ($ids | Sort-Object -Unique) }
      }
    } catch {
      continue
    }
  }
  return @(
    "glm-4.7", "glm-4.7-flash", "glm-4.7-flashx",
    "glm-4.6", "glm-4.6v", "glm-4.6v-flashx", "glm-4.6v-flash",
    "glm-4.5", "glm-4.5-x", "glm-4.5-air", "glm-4.5-airx", "glm-4.5-flash", "glm-4.5v",
    "glm-4-32b-0414-128k",
    "glm-5", "glm-5-turbo", "glm-5.1", "glm-5v-turbo"
  )
}

function Get-ZaiGeneralModelIds {
  return @(
    "glm-4.7", "glm-4.7-flash", "glm-4.7-flashx",
    "glm-4.6", "glm-4.6v", "glm-4.6v-flashx", "glm-4.6v-flash",
    "glm-4.5", "glm-4.5-x", "glm-4.5-air", "glm-4.5-airx", "glm-4.5-flash", "glm-4.5v",
    "glm-4-32b-0414-128k",
    "glm-5", "glm-5-turbo", "glm-5.1", "glm-5v-turbo",
    "glm-ocr"
  )
}

function Resolve-NvidiaNimFreeClaudeModel {
  param([Parameter(Mandatory = $true)][string]$OpenAiModelId)
  $m = $OpenAiModelId.Trim().Trim("/")
  if ($m.StartsWith("nvidia_nim/", [StringComparison]::OrdinalIgnoreCase)) { return $m }
  return ("nvidia_nim/{0}" -f $m)
}

function Get-GroqModelIdsFromApi {
  param([Parameter(Mandatory = $true)][string]$ApiKey)
  $hdr = @{ "Authorization" = "Bearer $ApiKey"; "Content-Type" = "application/json" }
  try {
    $resp = Invoke-LauncherJsonGet -Uri "https://api.groq.com/openai/v1/models" -Headers $hdr
    if ($resp -and $resp.data) {
      return @($resp.data | Sort-Object -Property id | ForEach-Object { $_.id })
    }
  } catch {
    # Groq API может быть заблокирован в РФ (403) - fallback на статический список
    Write-Host "Groq API недоступен (возможно заблокирован в РФ). Используем встроенный каталог." -ForegroundColor Yellow
  }
  return @(Get-GroqBundledFreeModelIds)
}

function Get-OpenRouterModelIdsFromApi {
  param([Parameter(Mandatory = $true)][string]$ApiKey)
  $hdr = @{ "Authorization" = "Bearer $ApiKey"; "Content-Type" = "application/json" }
  $resp = Invoke-LauncherJsonGet -Uri "https://openrouter.ai/api/v1/models" -Headers $hdr
  if (-not $resp -or -not $resp.data) { return @() }
  $ids = @($resp.data | Sort-Object -Property id | ForEach-Object { $_.id })
  return $ids
}

function Get-GroqBundledFreeModelIds {
  $raw = @(
    "llama-3.1-8b-instant"
    "llama-3.3-70b-versatile"
    "meta-llama/llama-4-scout-17b-16e-instruct"
    "openai/gpt-oss-120b"
    "openai/gpt-oss-20b"
    "qwen/qwen3-32b"
    "allam-2-7b"
    "gemma2-9b-it"
    "deepseek-r1-distill-llama-70b"
    "deepseek-r1-distill-qwen-32b"
    "distil-whisper-large-v3-en"
    "llama3-70b-8192"
    "llama3-8b-8192"
    "llama-3.2-1b-preview"
    "llama-3.2-3b-preview"
    "llama-3.2-11b-text-preview"
    "llama-3.2-90b-text-preview"
    "mixtral-8x7b-32768"
    "whisper-large-v3"
    "whisper-large-v3-turbo"
  )
  return ($raw | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-OpenRouterBundledFreeModelIds {
  $raw = @(
    "openrouter/free"
    "nvidia/nemotron-3-super-120b-a12b:free"
    "nvidia/nemotron-3-super:free"
    "inclusionai/ling-2.6-1t:free"
    "openai/gpt-oss-120b:free"
    "poolside/laguna-m.1:free"
    "openrouter/owl-alpha:free"
    "z-ai/glm-4.5-air:free"
    "minimax/minimax-m2.5:free"
    "nvidia/nemotron-3-nano-30b-a3b:free"
    "openai/gpt-oss-20b:free"
    "poolside/laguna-xs.2:free"
    "nvidia/nemotron-3-nano-omni:free"
    "google/gemma-4-31b:free"
    "nvidia/nemotron-nano-12b-2-vl:free"
    "nvidia/nemotron-nano-9b-v2:free"
    "google/gemma-4-26b-a4b:free"
    "meta-llama/llama-4-scout:free"
    "qwen/qwen3-235b-a22b:free"
    "qwen/qwen3-30b-a3b:free"
    "qwen/qwen3-32b:free"
    "qwen/qwen3-14b:free"
    "qwen/qwen3-8b:free"
    "qwen/qwen3-coder:free"
    "deepseek/deepseek-r1:free"
    "deepseek/deepseek-r1-0528:free"
    "deepseek/deepseek-chat-v3-0324:free"
    "deepseek/deepseek-r1-0528-qwen3-8b:free"
    "google/gemma-3-27b-it:free"
    "google/gemma-3-12b-it:free"
    "google/gemma-3-4b-it:free"
    "google/gemma-3-1b-it:free"
    "mistralai/mistral-small-3.1-24b-instruct:free"
    "meta-llama/llama-3.3-70b-instruct:free"
    "meta-llama/llama-3.1-8b-instruct:free"
    "microsoft/phi-4:free"
    "microsoft/mai-ds-r1:free"
    "moonshotai/kimi-vl-a3b-thinking:free"
    "bytedance-research/ui-tars-72b:free"
    "rekaai/reka-flash-3:free"
    "nousresearch/deephermes-3-llama-3-8b-preview:free"
    "allenai/molmo-7b-d-0924:free"
  )
  return ($raw | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
}
