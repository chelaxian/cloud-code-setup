# cloud-code-setup - 1-click Windows installer
# Usage: irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | iex
# This bootstrap downloads the full installer to a temp file and runs it

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch {}

$tmpFile = Join-Path $env:TEMP "cloud-code-setup-installer.ps1"
$url = "https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install-full.ps1"

Write-Host ""
Write-Host "  cloud-code-setup :: downloading..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $url -OutFile $tmpFile -UseBasicParsing
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    return
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmpFile
Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue
