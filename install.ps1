# cloud-code-setup - 1-click Windows installer
# Usage (PowerShell 5.1+):
#   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install.ps1 | iex

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch {}

$tmpFile = Join-Path $env:TEMP "cloud-code-setup-installer.ps1"
$url = "https://raw.githubusercontent.com/chelaxian/cloud-code-setup/main/install-full.ps1"

Write-Host ""
Write-Host "  cloud-code-setup :: downloading..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $url -OutFile $tmpFile -UseBasicParsing
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  TLS error? Run this first:" -ForegroundColor Yellow
    Write-Host "  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12" -ForegroundColor White
    Read-Host "Press Enter to exit"
    return
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmpFile
Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue
