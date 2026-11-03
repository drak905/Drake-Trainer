@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-Trainer.ps1" %*
echo.
pause
