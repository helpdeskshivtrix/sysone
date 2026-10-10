@echo off
title ShivTrix Core - PowerShell Diagnostic Bridge
echo ========================================================
echo   Launching ShivTrix Core Native PowerShell Bridge
echo ========================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0helper.ps1"
pause
