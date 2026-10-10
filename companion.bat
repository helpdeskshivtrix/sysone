@echo off
title ShivTrix Core - Companion and Web Server
echo ===================================================================
echo   ShivTrix Core - Companion and Web Server  (http://127.0.0.1:9871)
echo ===================================================================
set PY=python
where python >nul 2>nul || set PY=py -3
echo Checking psutil (real hardware telemetry)...
%PY% -m pip install --quiet psutil
echo.
echo Opening ShivTrix Core in your browser in 2 seconds...
start "" cmd /c "timeout /t 2 >nul & start http://127.0.0.1:9871"
%PY% "%~dp0companion.py"
echo.
echo Companion stopped.
pause
