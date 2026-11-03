@echo off
REM Double-click this to launch Sol Cesto with the trainer.
REM Bypasses PowerShell's execution policy for this one script only.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PlaySolCesto.ps1" %*
pause
