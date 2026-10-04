@echo off
if not defined Git_Root set "Git_Root=%~dp0..\.."
if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
net session >nul 2>&1
if %errorlevel% neq 0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/LCM_Inventory/tools/Invoke-PrivilegedTool.ps1" -Tool "SkipTpmCheckDynamicUpdate" -Arguments "%*"
  exit /b
)
call "%Git_Root%/SystemConfiguration/Source/@00-Skip_TPM_Check_on_Dynamic_Update.cmd" %*
