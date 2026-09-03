@echo off
REM Double-click launcher — calls PowerShell script with Bypass
setlocal
set SCRIPT=%~dp0launch-browser-debug.ps1
powershell -ExecutionPolicy Bypass -File "%SCRIPT%" %*
if errorlevel 1 pause
