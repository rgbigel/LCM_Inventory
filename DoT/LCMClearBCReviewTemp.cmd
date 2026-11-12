@echo off
if not defined Git_Root set "Git_Root=%~dp0..\.."
if not exist "%Git_Root%\LCM_Inventory" (
  echo [ERROR] Target repository not found relative to Git_Root: %Git_Root%
  exit /b 1
)
pwsh.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/LCM_Inventory/tools/Clear-BCReviewTemp.ps1" %*
