@echo off
setlocal
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\Show-CrpDates.ps1" %*
endlocal
