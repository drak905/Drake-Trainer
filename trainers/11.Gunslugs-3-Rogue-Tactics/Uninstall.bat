@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
if errorlevel 1 (
    echo.
    echo [ERROR] Uninstallation failed.
    pause
    exit /b 1
)
echo.
pause
