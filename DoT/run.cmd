@echo off
rem ==============================================================================
rem  LCM UNIVERSAL COMMAND GATEWAY (run do / run progress / run action)
rem ==============================================================================
setlocal
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\Invoke-LcmAction.ps1" %*
exit /b %ERRORLEVEL%

