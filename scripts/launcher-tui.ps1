# TUI-меню для лаунчеров Qwen / Claude (рамки, прокрутка, баннер).

function Set-LauncherTuiConsole {
  try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
  } catch {}
}

function Get-LauncherTuiBox {
  return @{
    TL = [char]0x2554; TR = [char]0x2557; BL = [char]0x255A; BR = [char]0x255D
    H  = [char]0x2550; V  = [char]0x2551
    LJ = [char]0x2560; RJ = [char]0x2563
  }
}

# В PowerShell нельзя писать [char] * N — только ([string][char]) * N
function Repeat-TuiChar {
  param(
    [char]$Ch,
    [int]$Count
  )
  if ($Count -lt 1) { return "" }
  return ([string]$Ch) * $Count
}

function Write-TuiRow {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text,
    [Parameter(Mandatory = $true)][int]$InnerWidth,
    [System.ConsoleColor]$Fg = "Gray"
  )
  $b = Get-LauncherTuiBox
  if ($Text.Length -gt $InnerWidth) {
    $Text = $Text.Substring(0, [Math]::Max(0, $InnerWidth - 1)) + [char]0x2026
  } else {
    $Text = $Text.PadRight($InnerWidth)
  }
  Write-Host ($b.V + $Text + $b.V) -ForegroundColor $Fg
}

function Write-TuiBannerQwen {
  param([int]$InnerWidth)
  # Тот же визуальный язык, что и у Claude (FIGlet «ANSI Shadow»), по центру как CLAUDE (ширина 59).
  $raw = @(
    " ██████╗ ██╗    ██╗███████╗███╗   ██╗"
    "██╔═══██╗██║    ██║██╔════╝████╗  ██║"
    "██║   ██║██║ █╗ ██║█████╗  ██╔██╗ ██║"
    "██║▄▄ ██║██║███╗██║██╔══╝  ██║╚██╗██║"
    "╚██████╔╝╚███╔███╔╝███████╗██║ ╚████║"
    " ╚══▀▀═╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═══╝"
  )
  $bannerW = 59
  foreach ($ln in $raw) {
    $len = $ln.Length
    if ($len -ge $bannerW) {
      $row = $ln.Substring(0, $bannerW)
    } else {
      $padL = [int][Math]::Floor(($bannerW - $len) / 2)
      $padR = $bannerW - $len - $padL
      $row = ((" " * $padL) + $ln + (" " * $padR))
    }
    Write-TuiRow -Text $row -InnerWidth $InnerWidth -Fg DarkCyan
  }
}

function Write-TuiBannerClaude {
  param([int]$InnerWidth)
  $lines = @(
    "   ██████╗██╗     ██╗      █████╗ ██╗   ██╗██████╗ ███████╗",
    "  ██╔════╝██║     ██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝",
    "  ██║     ██║     ██║     ███████║██║   ██║██║  ██║█████╗  ",
    "  ██║     ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  ",
    "  ╚██████╗███████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗",
    "   ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝"
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg DarkMagenta
  }
}

function Write-TuiBannerLlamaCpp {
  param([int]$InnerWidth)
  # Ширина баннера ~59, как у Claude/Qwen
  $lines = @(
    " ██╗     ██╗      █████╗ ███╗   ███╗ █████╗      ██████╗██████╗ ██████╗ "
    " ██║     ██║     ██╔══██╗████╗ ████║██╔══██╗    ██╔════╝██╔══██╗██╔══██╗"
    " ██║     ██║     ███████║██╔████╔██║███████║    ██║     ██████╔╝██████╔╝"
    " ██║     ██║     ██╔══██║██║╚██╔╝██║██╔══██║    ██║     ██╔═══╝ ██╔═══╝ "
    " ███████╗███████╗██║  ██║██║ ╚═╝ ██║██║  ██║    ╚██████╗██║     ██║     "
    " ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝     ╚═════╝╚═╝     ╚═╝     "
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg DarkGreen
  }
}

function Write-TuiBannerLMStudio {
  param([int]$InnerWidth)
  $lines = @(
    " ██╗     ███╗   ███╗    ███████╗████████╗██╗   ██╗██████╗ ██╗ ██████╗ "
    " ██║     ████╗ ████║    ██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║██╔═══██╗"
    " ██║     ██╔████╔██║    ███████╗   ██║   ██║   ██║██║  ██║██║██║   ██║"
    " ██║     ██║╚██╔╝██║    ╚════██║   ██║   ██║   ██║██║  ██║██║██║   ██║"
    " ███████╗██║ ╚═╝ ██║    ███████║   ██║   ╚██████╔╝██████╔╝██║╚██████╔╝"
    " ╚══════╝╚═╝     ╚═╝    ╚══════╝   ╚═╝    ╚═════╝ ╚═════╝ ╚═╝ ╚═════╝ "
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg DarkCyan
  }
}

function Write-TuiBannerOpenCode {
  param([int]$InnerWidth)
  $lines = @(
    " ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗"
    "██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝"
    "██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║   ██║██║  ██║█████╗  "
    "██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║   ██║██║  ██║██╔══╝  "
    "╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗╚██████╔╝██████╔╝███████╗"
    " ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝"
  )
  foreach ($ln in $lines) {
    Write-TuiRow -Text $ln -InnerWidth $InnerWidth -Fg DarkGreen
  }
}

function Show-TuiFramedMenu {
  param(
    [ValidateSet("Qwen", "Claude", "LlamaCpp", "LMStudio", "OpenCode")]
    [string]$AppBrand,
    [Parameter(Mandatory = $true)][string]$Title,
    [string]$Subtitle = "",
    [Parameter(Mandatory = $true)][object[]]$Items,
    [int]$InitialIndex = 0,
    [int]$MaxVisible = 12,
    # Exit = Esc полностью отменяет (как главное меню). Back = Esc вернуться к предыдущему шагу (мастер «другая модель»).
    [ValidateSet("Exit", "Back")]
    [string]$EscapeAction = "Exit"
  )

  Set-LauncherTuiConsole
  $b = Get-LauncherTuiBox
  $win = $Host.UI.RawUI.WindowSize
  $frameW = [Math]::Min(90, [Math]::Max(54, $win.Width - 2))
  $inner = $frameW - 2
  $n = $Items.Count
  if ($n -lt 1) {
    throw "Show-TuiFramedMenu: список Items пуст."
  }
  $idx = [Math]::Max(0, [Math]::Min($InitialIndex, $n - 1))
  $heightCap = [Math]::Max(6, $win.Height - 20)
  $visible = [Math]::Max(4, [Math]::Min($MaxVisible, [Math]::Min($n, $heightCap)))
  # При dot-source $script: — область вызывающего файла; скролл ломался. Hashtable — общий изменяемый объект.
  $scroll = @{ Top = 0 }

  function Sync-TuiScroll {
    if ($idx -lt $scroll.Top) { $scroll.Top = $idx }
    $maxTop = [Math]::Max(0, $n - $visible)
    if ($idx -ge $scroll.Top + $visible) { $scroll.Top = $idx - $visible + 1 }
    if ($scroll.Top -gt $maxTop) { $scroll.Top = $maxTop }
    if ($scroll.Top -lt 0) { $scroll.Top = 0 }
  }

  function Redraw-TuiMenu {
    Sync-TuiScroll
    Clear-Host
    Write-Host ($b.TL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.TR) -ForegroundColor Cyan
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    switch ($AppBrand) {
      "Qwen" { Write-TuiBannerQwen -InnerWidth $inner }
      "Claude" { Write-TuiBannerClaude -InnerWidth $inner }
      "LlamaCpp" { Write-TuiBannerLlamaCpp -InnerWidth $inner }
      "LMStudio" { Write-TuiBannerLMStudio -InnerWidth $inner }
      "OpenCode" { Write-TuiBannerOpenCode -InnerWidth $inner }
      default { Write-TuiBannerClaude -InnerWidth $inner }
    }
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    Write-Host ($b.LJ + (Repeat-TuiChar $b.H $inner) + $b.RJ) -ForegroundColor DarkCyan
    Write-TuiRow -Text (" " + $Title.Trim()) -InnerWidth $inner -Fg White
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
      Write-TuiRow -Text (" " + $Subtitle.Trim()) -InnerWidth $inner -Fg DarkGray
    }
    Write-Host ($b.LJ + (Repeat-TuiChar $b.H $inner) + $b.RJ) -ForegroundColor DarkCyan
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    for ($r = 0; $r -lt $visible; $r++) {
      $i = $scroll.Top + $r
      if ($i -ge $n) {
        Write-TuiRow -Text "" -InnerWidth $inner
        continue
      }
      $lbl = [string]$Items[$i].Label
      $mark = if ($i -eq $idx) { ("  {0} " -f [char]0x25B6) } else { "     " }
      $row = $mark + $lbl
      $fg = if ($i -eq $idx) { "Yellow" } else { "Gray" }
      Write-TuiRow -Text $row -InnerWidth $inner -Fg $fg
    }
    Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
    $escHint = if ($EscapeAction -eq "Back") { "Esc — назад" } else { "Esc — выход" }
    $hint = ("  {0}{1}  выбор   Enter — OK   {2}   Home/End   PgUp/PgDn" -f [char]0x2191, [char]0x2193, $escHint)
    Write-TuiRow -Text $hint -InnerWidth $inner -Fg DarkGray
    if ($n -gt $visible) {
      $pg = ("  строки {0}-{1} из {2}" -f ($scroll.Top + 1), ([Math]::Min($scroll.Top + $visible, $n)), $n)
      Write-TuiRow -Text $pg -InnerWidth $inner -Fg DarkCyan
    }
    Write-Host ($b.BL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.BR) -ForegroundColor Cyan
  }

  $scroll.Top = 0
  Sync-TuiScroll
  [Console]::CursorVisible = $false
  try {
    Redraw-TuiMenu
    while ($true) {
      $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      switch ($key.VirtualKeyCode) {
        38 {
          if ($idx -gt 0) { $idx-- }
          Redraw-TuiMenu
        }
        40 {
          if ($idx -lt $n - 1) { $idx++ }
          Redraw-TuiMenu
        }
        33 {
          $idx = [Math]::Max(0, $idx - $visible)
          Redraw-TuiMenu
        }
        34 {
          $idx = [Math]::Min($n - 1, $idx + $visible)
          Redraw-TuiMenu
        }
        36 {
          $idx = 0
          Redraw-TuiMenu
        }
        35 {
          $idx = $n - 1
          Redraw-TuiMenu
        }
        13 { return $Items[$idx] }
        27 {
          if ($EscapeAction -eq "Back") {
            return [pscustomobject]@{ __menuBack = $true }
          }
          return $null
        }
      }
    }
  } finally {
    [Console]::CursorVisible = $true
  }
}

function Show-TuiWaitFrame {
  param(
    [ValidateSet("Qwen", "Claude", "LlamaCpp", "LMStudio", "OpenCode")]
    [string]$AppBrand,
    [Parameter(Mandatory = $true)][string]$Message
  )
  Set-LauncherTuiConsole
  $b = Get-LauncherTuiBox
  $win = $Host.UI.RawUI.WindowSize
  $frameW = [Math]::Min(82, [Math]::Max(50, $win.Width - 4))
  $inner = $frameW - 2
  Clear-Host
  Write-Host ($b.TL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.TR) -ForegroundColor Cyan
  Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
  switch ($AppBrand) {
    "Qwen" { Write-TuiBannerQwen -InnerWidth $inner }
    "Claude" { Write-TuiBannerClaude -InnerWidth $inner }
    "LlamaCpp" { Write-TuiBannerLlamaCpp -InnerWidth $inner }
    "LMStudio" { Write-TuiBannerLMStudio -InnerWidth $inner }
    "OpenCode" { Write-TuiBannerOpenCode -InnerWidth $inner }
    default { Write-TuiBannerClaude -InnerWidth $inner }
  }
  Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
  Write-TuiRow -Text ("  " + $Message) -InnerWidth $inner -Fg Yellow
  Write-TuiRow -Text ("".PadRight($inner)) -InnerWidth $inner
  Write-Host ($b.BL + (Repeat-TuiChar $b.H ($frameW - 2)) + $b.BR) -ForegroundColor Cyan
}
