[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Делегируем в унифицированный dynamic launcher (единое пространство /resume)
& (Join-Path $PSScriptRoot "run-qwen-code-dynamic.ps1") -Provider zai -ModelId "glm-4.7"
