@echo off
rem ==============================================================================
rem  LCM UNIVERSAL COMMAND GATEWAY (lcm do)
rem  Authors: Rolf, LCM_AI Engine. Version: 10.0.1. Date: 2026-11-08.
rem ==============================================================================
setlocal
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\Invoke-LcmAction.ps1" %*
exit /b %ERRORLEVEL%

