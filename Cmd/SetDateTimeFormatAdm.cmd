@echo off
if not defined Git_Root set "Git_Root=%~dp0..\.."
if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
net session >nul 2>&1
if %errorlevel% neq 0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/LCM_Inventory/tools/Invoke-PrivilegedTool.ps1" -Tool "SetDateTimeFormatAdm" -Arguments "%*"
  exit /b
)
pwsh.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/SystemConfiguration/Source/@02-Set_the_date_and_time_format_(ADM_systemwide).ps1" %*
