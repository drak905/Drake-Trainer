@echo off
REM Afterimage Vietnamese pack - uninstaller launcher
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1" %*
pause
