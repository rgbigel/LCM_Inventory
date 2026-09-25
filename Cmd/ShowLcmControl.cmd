@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\Show-LcmControl.ps1" %*
