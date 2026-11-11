@echo off
:: Governed by CRP-316 Trampoline Header Invariant
if not defined Git_Root set "Git_Root=%~dp0..\.."
if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
echo # [LCM Launcher] %~nx0 - Goal: Executes all system customizations and configuration scripts in numeric sequence.
net session >nul 2>&1
if %errorlevel% neq 0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/LCM_Inventory/tools/Invoke-PrivilegedTool.ps1" -Tool "ApplyAllCustomization" -Arguments "%*"
  exit /b
)
pwsh.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/LCM_SystemConfiguration/Source/Apply-AllCustomizations.ps1" %*
