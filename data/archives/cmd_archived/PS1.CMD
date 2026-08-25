::@echo off
:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Now running elevated, call the PowerShell script
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0.ps1" %*