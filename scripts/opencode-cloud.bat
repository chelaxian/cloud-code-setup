@echo off
set SCRIPT_DIR=%%~dp0
if exist \
%%SCRIPT_DIR%%\run-opencode-launcher.ps1\ (
    powershell -NoProfile -ExecutionPolicy Bypass -File \
%%SCRIPT_DIR%%\run-opencode-launcher.ps1\ -Provider openrouter -ModelId nvidia/nemotron-3-super-120b-a12b:free
) else if exist \
%%SCRIPT_DIR%%..scripts\run-opencode-launcher.ps1\ (
    powershell -NoProfile -ExecutionPolicy Bypass -File \
%%SCRIPT_DIR%%..scripts\run-opencode-launcher.ps1\ -Provider openrouter -ModelId nvidia/nemotron-3-super-120b-a12b:free
) else (
    echo ERROR: run-opencode-launcher.ps1 not found in %%SCRIPT_DIR%%
    pause
)
