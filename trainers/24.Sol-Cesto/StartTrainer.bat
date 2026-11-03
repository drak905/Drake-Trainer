@echo off
REM Start the trainer when the game is ALREADY running with the debugging port.
REM Keep this window open while you play; close it to stop enforcement.
title Sol Cesto Trainer
cd /d "%~dp0"
python -u solcesto_trainer.py %*
echo.
echo Trainer stopped.
pause
