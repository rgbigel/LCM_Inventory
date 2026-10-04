@echo off
if not defined Git_Root set "Git_Root=%~dp0..\.."
if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
pwsh.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/HaSSD06/tools/Register-BleSupervisionTask.ps1" %*
