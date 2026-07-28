@echo off
:: Request admin elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

title PoE Hideout Hunter
powershell -ExecutionPolicy Bypass -File "%~dp0poe-log-monitor.ps1"
pause
