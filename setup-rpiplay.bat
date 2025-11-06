@echo off
set SCRIPT_DIR=%~dp0
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-rpiplay.ps1"
pause
