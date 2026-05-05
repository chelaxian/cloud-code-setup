[CmdletBinding(DefaultParameterSetName = "Full")]
param(
  [Parameter(ParameterSetName = "Full", Mandatory = $true)]
  [ValidateSet("zai", "nim", "nim-qwen", "openrouter")]
  [string]$Provider,

  [Parameter(ParameterSetName = "Prepare")]
  [switch]$PrepareOnly,

  [Parameter(ParameterSetName = "Full")]
  [switch]$SkipCommonPreamble,

  [string]$VaultPath = "C:\Users\chelaxian\Documents\Obsidian Vault",
  [string]$ObsidianExe = "C:\Users\chelaxian\AppData\Local\Programs\Obsidian\Obsidian.exe",
  # 0 = don't open browser tab, 1 = open viewer
  [int]$OpenClaudeMemObserver = 0,
  [int]$DryRun = 0,

  # Z.AI (Anthropic-compatible)
  [string]$ZaiApiKey = "",
  # Если задано (лаунчер «другая модель»), подставляется в ANTHROPIC_DEFAULT_* вместо glm-4.7.
  [string]$ZaiAnthropicModelId = "",

  # NVIDIA NIM via free-claude-code proxy
  [string]$NvidiaNimApiKey = "",
  [string]$FreeClaudeCodeDir = "I:\qwen-local-setup\free-claude-code",
  [int]$ProxyPort = 8082,
  [string]$ProxyAuthToken = "freecc",
  # Для -Provider nim-qwen значение ниже не используется (жёстко nvidia_nim/qwen/qwen3.5-122b-a10b); порт по умолчанию 8083.
  [string]$NimModel = "nvidia_nim/z-ai/glm4.7",

  # Claude Code knobs
  [string]$ClaudeTools = "default",

  # Не блокировать запуск Claude Code ожиданием claude-mem (37777)
  [switch]$SkipClaudeMem,
  # Макс. секунд ожидания claude-mem после npx start (холодный кэш npx может занять 30–60 с).
  [int]$ClaudeMemMaxWaitSec = 45
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

. (Join-Path $PSScriptRoot "ensure-streaming-friendly-terminal.ps1")

function Ensure-NpmBinInPath {
  # Claude Code / npx: в ярлыках cmd /k и -NoProfile часто нет Roaming\npm и Node.
  $npmBin = Join-Path $env:APPDATA "npm"
  if ($npmBin -and (Test-Path -LiteralPath $npmBin)) {
    $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $npmBin.TrimEnd('\') })) {
      $env:PATH = $npmBin + ";" + $env:PATH
    }
  }
}

function Ensure-ClaudeSidecarPath {
  Ensure-NpmBinInPath
  foreach ($nodeDir in @(
      (Join-Path ${env:ProgramFiles} "nodejs"),
      (Join-Path ${env:ProgramFiles(x86)} "nodejs")
    )) {
    if ($nodeDir -and (Test-Path -LiteralPath $nodeDir)) {
      $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
      $nd = $nodeDir.TrimEnd('\')
      if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $nd })) {
        $env:PATH = $nodeDir + ";" + $env:PATH
      }
    }
  }
  $bunBin = Join-Path $HOME ".bun\bin"
  if (Test-Path -LiteralPath $bunBin) {
    $parts = @($env:PATH -split ';' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    $bb = $bunBin.TrimEnd('\')
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $bb })) {
      $env:PATH = $bunBin + ";" + $env:PATH
    }
  }
}

function Test-HttpOk([string]$Url,[int]$TimeoutSec = 3) {
  try {
    # Avoid the "Script Execution Risk" prompt in Windows PowerShell (5.1).
    $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
    if ($iwr.Parameters.ContainsKey("UseBasicParsing")) {
      $r = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec $TimeoutSec -UseBasicParsing
    } else {
      $r = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec $TimeoutSec
    }
    return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400)
  } catch {
    return $false
  }
}

function Test-HttpResponding([string]$Url,[int]$TimeoutSec = 3) {
  # "Responding" means the server returned any HTTP response (including 401/403/404).
  # This is used for readiness checks where auth may be required for 2xx.
  try {
    $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
    $useBasic = $iwr.Parameters.ContainsKey("UseBasicParsing")

    # Prefer GET for readiness. Some servers log noisy 405 for HEAD (e.g. /v1/models).
    if ($useBasic) {
      $null = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSec -UseBasicParsing
    } else {
      $null = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSec
    }
    return $true
  } catch {
    try {
      if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { return $true }
    } catch {}
    return $false
  }
}

function Ensure-ClaudeSettingsNoBom {
  $dir = Join-Path $HOME ".claude"
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $path = Join-Path $dir "settings.json"
  $obj = @{}
  if (Test-Path -LiteralPath $path) {
    try { $obj = (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json) } catch { $obj = @{} }
  }
  if (-not $obj.env) { $obj | Add-Member -NotePropertyName env -NotePropertyValue @{} -Force }
  $obj.env.CLAUDE_CODE_ATTRIBUTION_HEADER = "0"
  $obj.env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
  $json = ($obj | ConvertTo-Json -Depth 10)
  [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Test-ClaudeMemTcp37777 {
  $c = $null
  try {
    $c = New-Object System.Net.Sockets.TcpClient
    $ar = $c.BeginConnect("127.0.0.1", 37777, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne(800)) { return $false }
    $c.EndConnect($ar)
    return $c.Connected
  } catch {
    return $false
  } finally {
    if ($c) { try { $c.Close() } catch {} }
  }
}

function Test-ClaudeMemWorkerUp {
  if (Test-ClaudeMemTcp37777) { return $true }
  try {
    $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
    $useBasic = $iwr.Parameters.ContainsKey("UseBasicParsing")
    if ($useBasic) {
      $r = Invoke-WebRequest -Uri "http://127.0.0.1:37777/" -Method Get -TimeoutSec 2 -UseBasicParsing
    } else {
      $r = Invoke-WebRequest -Uri "http://127.0.0.1:37777/" -Method Get -TimeoutSec 2
    }
    return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500)
  } catch {
    return $false
  }
}

function Ensure-ClaudeMemWorker {
  if ($SkipClaudeMem) { return }
  if (Test-ClaudeMemWorkerUp) { return }
  Ensure-ClaudeSidecarPath

  $logDir = Join-Path $HOME ".qwen-local-setup"
  if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $outLog = Join-Path $logDir "claude-mem.cloud.$stamp.out.log"
  $errLog = Join-Path $logDir "claude-mem.cloud.$stamp.err.log"

  $memStarter = Join-Path $PSScriptRoot "start-claude-mem.ps1"
  $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
  if (-not $psExe) { $psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" }

  try {
    # 1) Тот же сценарий, что у вас вручную: bun в PATH + npx (не обрезать stdout у .cmd — иначе пустые логи и сбой джоба).
    if (Test-Path -LiteralPath $memStarter) {
      # Без перенаправления stdout/stderr: у npx.cmd + .cmd цепочек редирект в фоне часто даёт пустые логи и нестарт.
      Start-Process `
        -FilePath $psExe `
        -WorkingDirectory $HOME `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $memStarter, "-OpenBrowser", "0", "-SkipStatus") `
        -WindowStyle Hidden `
        | Out-Null
    } else {
      $npmCmd = Join-Path (Join-Path $env:APPDATA "npm") "npm.cmd"
      if (Test-Path -LiteralPath $npmCmd) {
        Start-Process `
          -FilePath $npmCmd `
          -WorkingDirectory $HOME `
          -ArgumentList @("exec", "--yes", "--", "claude-mem", "start") `
          -WindowStyle Hidden `
          -RedirectStandardOutput $outLog `
          -RedirectStandardError $errLog `
          | Out-Null
      } else {
        $npxCmd = Join-Path (Join-Path $env:APPDATA "npm") "npx.cmd"
        if (Test-Path -LiteralPath $npxCmd) {
          Start-Process `
            -FilePath $npxCmd `
            -WorkingDirectory $HOME `
            -ArgumentList @("--yes", "claude-mem", "start") `
            -WindowStyle Hidden `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            | Out-Null
        } else {
          throw "Не найдены npm/npx (ожидалось в $env:APPDATA\npm)."
        }
      }
    }
  } catch {
    Write-Host ("Предупреждение: не удалось стартовать claude-mem: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow
  }

  $waitSec = [Math]::Max(5, $ClaudeMemMaxWaitSec)
  $deadline = (Get-Date).AddSeconds($waitSec)
  while ((Get-Date) -lt $deadline) {
    if (Test-ClaudeMemWorkerUp) { return }
    Start-Sleep -Milliseconds 400
  }
  Write-Host ("Предупреждение: claude-mem (127.0.0.1:37777) не готов за {0} с. Смотрите логи: {1} и {2}" -f $waitSec, $outLog, $errLog) -ForegroundColor DarkYellow
}

function Read-SecretText([string]$Prompt) {
  $s = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Start-Obsidian([string]$Exe,[string]$Vault) {
  try {
    if (Get-Process -Name "Obsidian" -ErrorAction SilentlyContinue) {
      Write-Host "Obsidian уже запущен — пропуск повторного старта." -ForegroundColor DarkGray
      return
    }
  } catch {}
  if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Host "Предупреждение: Obsidian.exe не найден: $Exe" -ForegroundColor DarkYellow
    return
  }
  if (-not (Test-Path -LiteralPath $Vault)) {
    Write-Host "Предупреждение: папка хранилища Obsidian не найдена: $Vault" -ForegroundColor DarkYellow
  }
  try {
    $cmdLine = "start """" ""$Exe"" --vault ""$Vault"""
    Start-Process -FilePath "cmd.exe" -ArgumentList @("/d", "/c", $cmdLine) -WindowStyle Hidden | Out-Null
    Write-Host "Obsidian: запуск с хранилищем «$Vault»" -ForegroundColor DarkCyan
  } catch {
    try {
      Start-Process -FilePath $Exe -ArgumentList @("--vault", $Vault) -WindowStyle Hidden | Out-Null
      Write-Host "Obsidian: запуск (fallback)." -ForegroundColor DarkCyan
    } catch {
      Write-Host ("Предупреждение: не удалось запустить Obsidian: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow
    }
  }
}

function Ensure-FreeClaudeCodeProxy {
  param(
    [string]$Dir,
    [int]$Port,
    [string]$NimKey,
    [string]$Model,
    [string]$AuthToken,
    [hashtable]$ExtraEnv = @{}
  )

  # Be strict: require a listening socket (HTTP checks can false-positive on some failures).
  try {
    $conn = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $Port -State Listen -ErrorAction Stop
    if ($conn) { return }
  } catch {}
  if (-not (Test-Path -LiteralPath $Dir)) { throw "free-claude-code dir not found: $Dir" }

  $uv = "C:\Users\chelaxian\.local\bin\uv.exe"
  if (-not (Test-Path -LiteralPath $uv)) { throw "uv.exe not found at $uv" }

  Push-Location $Dir
  try {
    # Ensure Python 3.14 exists (no-op if already installed)
    & $uv python install 3.14 | Out-Null

    # Prepare env vars for the proxy process (avoid writing secrets to disk).
    $env:NVIDIA_NIM_API_KEY = $NimKey
    $env:MODEL = $Model
    $env:ANTHROPIC_AUTH_TOKEN = $AuthToken

    foreach ($ek in $ExtraEnv.Keys) {
      Set-Item -Path "env:$ek" -Value $ExtraEnv[$ek]
    }

    # Start proxy in background with logs.
    $logDir = Join-Path $HOME ".qwen-local-setup"
    if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outLog = Join-Path $logDir "free-claude-code-$stamp.out.log"
    $errLog = Join-Path $logDir "free-claude-code-$stamp.err.log"

    $cmd = "& `"$uv`" run uvicorn server:app --host 127.0.0.1 --port $Port"
    $p = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-Command",$cmd) -WindowStyle Hidden -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog
  } finally {
    Pop-Location
  }

  for ($i = 0; $i -lt 60; $i++) {
    try {
      $conn = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $Port -State Listen -ErrorAction Stop
      if ($conn) { return }
    } catch {}
    if ($p -and $p.HasExited) {
      throw "free-claude-code proxy exited early (exit=$($p.ExitCode)). Logs: $errLog ; $outLog"
    }
    Start-Sleep -Seconds 1
  }
  throw "free-claude-code proxy did not become ready on port $Port. Logs: $errLog ; $outLog"
}

# PATH до npx/node — до любых sidecar и до claude.cmd.
Ensure-ClaudeSidecarPath

if (-not $SkipCommonPreamble) {
  Ensure-ClaudeSettingsNoBom
}

# claude-mem и Obsidian нужны при каждом входе в сессию: при -SkipCommonPreamble раньше они не вызывались,
# и если PrepareOnly не успел за 8 с — воркер так и не поднимался.
Ensure-ClaudeMemWorker
if ($OpenClaudeMemObserver -ne 0) {
  try {
    if (Test-ClaudeMemWorkerUp) {
      Start-Process -FilePath "http://127.0.0.1:37777/" | Out-Null
      Write-Host "Открыт claude-mem observer: http://127.0.0.1:37777/" -ForegroundColor DarkCyan
    } else {
      Start-Process -FilePath "http://127.0.0.1:37777/" | Out-Null
      Write-Host "Открыт браузер на 37777 (воркер ещё может подниматься)." -ForegroundColor DarkYellow
    }
  } catch {}
}
Start-Obsidian -Exe $ObsidianExe -Vault $VaultPath

if ($PrepareOnly) {
  Write-Host "Claude (облако): общая подготовка выполнена (settings, claude-mem, Obsidian, PATH npm)." -ForegroundColor Green
  exit 0
}

if ($Provider -eq "zai") {
  if (-not $ZaiApiKey -or $ZaiApiKey.Trim().Length -eq 0 -or $ZaiApiKey -eq "__SET_ME__") {
    $ZaiApiKey = [Environment]::GetEnvironmentVariable("ZAI_API_KEY","User")
  }
  if (-not $ZaiApiKey -or $ZaiApiKey.Trim().Length -eq 0 -or $ZaiApiKey -eq "__SET_ME__") {
    $ZaiApiKey = $env:ZAI_API_KEY
  }
  if (-not $ZaiApiKey -or $ZaiApiKey.Trim().Length -eq 0 -or $ZaiApiKey -eq "__SET_ME__") {
    $ZaiApiKey = Read-SecretText "Enter Z.AI API key (will not be saved)"
  }
  $env:ANTHROPIC_AUTH_TOKEN = $ZaiApiKey
  $env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"
  $env:API_TIMEOUT_MS = "3000000"
  $zModel = "glm-4.7"
  if (-not [string]::IsNullOrWhiteSpace($ZaiAnthropicModelId)) {
    $zModel = $ZaiAnthropicModelId.Trim()
  }
  $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $zModel
  $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $zModel
  $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $zModel

  if ($DryRun -ne 0) {
    if (-not (Test-HttpOk -Url "https://api.z.ai/api/anthropic" -TimeoutSec 5)) {
      throw "Z.AI endpoint not reachable: https://api.z.ai/api/anthropic"
    }
    # Also verify Claude Code is discoverable in this environment (common failure under -NoProfile).
    $cc = Get-Command claude.cmd -ErrorAction SilentlyContinue
    if (-not $cc) { $cc = Get-Command claude -ErrorAction SilentlyContinue }
    if (-not $cc) { throw "Claude Code not found on PATH. Expected: $($env:APPDATA)\\npm\\claude.cmd" }
    Write-Host "dry-run:ZAI:OK" -ForegroundColor Green
    return
  }
}

if ($Provider -in @("nim", "nim-qwen")) {
  $nimModelResolved = $NimModel
  $proxyPortResolved = $ProxyPort
  if ($Provider -eq "nim-qwen") {
    $nimModelResolved = "nvidia_nim/qwen/qwen3.5-122b-a10b"
    if ($PSBoundParameters.ContainsKey("ProxyPort")) {
      $proxyPortResolved = $ProxyPort
    } else {
      $proxyPortResolved = 8083
    }
  }

  if (-not $NvidiaNimApiKey -or $NvidiaNimApiKey.Trim().Length -eq 0 -or $NvidiaNimApiKey -eq "__SET_ME__") {
    $NvidiaNimApiKey = [Environment]::GetEnvironmentVariable("NVIDIA_NIM_API_KEY","User")
  }
  if (-not $NvidiaNimApiKey -or $NvidiaNimApiKey.Trim().Length -eq 0 -or $NvidiaNimApiKey -eq "__SET_ME__") {
    $NvidiaNimApiKey = $env:NVIDIA_NIM_API_KEY
  }
  if (-not $NvidiaNimApiKey -or $NvidiaNimApiKey.Trim().Length -eq 0 -or $NvidiaNimApiKey -eq "__SET_ME__") {
    $NvidiaNimApiKey = Read-SecretText "Enter NVIDIA NIM API key (will not be saved)"
  }
  Ensure-FreeClaudeCodeProxy -Dir $FreeClaudeCodeDir -Port $proxyPortResolved -NimKey $NvidiaNimApiKey -Model $nimModelResolved -AuthToken $ProxyAuthToken
  $env:ANTHROPIC_AUTH_TOKEN = $ProxyAuthToken
  $env:ANTHROPIC_BASE_URL = ("http://127.0.0.1:{0}" -f $proxyPortResolved)
  $env:API_TIMEOUT_MS = "3000000"

  if ($DryRun -ne 0) {
    if (-not (Test-HttpResponding -Url ("http://127.0.0.1:{0}/v1/models" -f $proxyPortResolved) -TimeoutSec 3)) {
      throw "free-claude-code not responding on http://127.0.0.1:$proxyPortResolved"
    }
    $cc = Get-Command claude.cmd -ErrorAction SilentlyContinue
    if (-not $cc) { $cc = Get-Command claude -ErrorAction SilentlyContinue }
    if (-not $cc) { throw "Claude Code not found on PATH. Expected: $($env:APPDATA)\\npm\\claude.cmd" }
    Write-Host "dry-run:NIM:OK" -ForegroundColor Green
    return
  }
}

if ($Provider -eq "openrouter") {
  $orKey = [Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY","User")
  if ([string]::IsNullOrWhiteSpace($orKey)) { $orKey = $env:OPENROUTER_API_KEY }
  if ([string]::IsNullOrWhiteSpace($orKey)) { $orKey = Read-SecretText "Enter OpenRouter API key (will not be saved)" }

  $orModel = "open_router/anthropic/claude-sonnet-4-20250514"
  if (-not [string]::IsNullOrWhiteSpace($ZaiAnthropicModelId)) {
    $orModel = "open_router/$($ZaiAnthropicModelId.Trim())"
  }

  $orPort = 8084
  if ($PSBoundParameters.ContainsKey("ProxyPort")) { $orPort = $ProxyPort }

  Ensure-FreeClaudeCodeProxy -Dir $FreeClaudeCodeDir -Port $orPort -NimKey $orKey -Model $orModel -AuthToken $ProxyAuthToken -ExtraEnv @{ OPENROUTER_API_KEY = $orKey }
  $env:OPENROUTER_API_KEY = $orKey
  $env:ANTHROPIC_AUTH_TOKEN = $ProxyAuthToken
  $env:ANTHROPIC_BASE_URL = ("http://127.0.0.1:{0}" -f $orPort)
  $env:API_TIMEOUT_MS = "3000000"

  if ($DryRun -ne 0) {
    if (-not (Test-HttpResponding -Url ("http://127.0.0.1:{0}/v1/models" -f $orPort) -TimeoutSec 3)) {
      throw "free-claude-code not responding on http://127.0.0.1:$orPort"
    }
    Write-Host "dry-run:OPENROUTER:OK" -ForegroundColor Green
    return
  }
}

Push-Location $VaultPath
try {
  # IMPORTANT: call the Claude Code launcher, not any other "claude" shim.
  $claudeCmd = Get-Command claude.cmd -ErrorAction SilentlyContinue
  if (-not $claudeCmd) {
    $expected = Join-Path (Join-Path $env:APPDATA "npm") "claude.cmd"
    if (Test-Path -LiteralPath $expected) {
      $claudeExe = $expected
    } else {
      $claudeExe = "claude"
    }
  } else {
    $claudeExe = $claudeCmd.Source
  }

  if ($ClaudeTools -eq "default") {
    & $claudeExe
  } else {
    & $claudeExe --tools $ClaudeTools
  }
} finally {
  Pop-Location
}

