@echo off
if not defined Git_Root set "Git_Root=%~dp0..\.."
if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
net session >nul 2>&1
if %errorlevel% neq 0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/LCM_Inventory/tools/Invoke-PrivilegedTool.ps1" -Tool "RestoreSystemSettings" -Arguments "%*"
  exit /b
)
pwsh.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/LCM_Inventory/tools/Restore-SystemSettings.ps1" %*
