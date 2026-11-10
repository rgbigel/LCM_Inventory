@echo off
rem ==============================================================================
rem  LCM PURE TRAMPOLINE (DismountMacriumBaseline)
rem ==============================================================================
setlocal
set "TargetScript=%~dp0..\tools\Dismount-MacriumCurrentBaseline.ps1"
if not exist "%TargetScript%" (
  echo ERROR: Target script was not found: %TargetScript%
  exit /b 1
)
call "%~dp0lcm.cmd" do DismountMacriumBaseline %*
exit /b %ERRORLEVEL%
