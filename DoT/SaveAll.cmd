@echo off
setlocal
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\LCM_Inventory\tools\Invoke-LCM_GoodNight.ps1" %*
exit /b %ERRORLEVEL%
