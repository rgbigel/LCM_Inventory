@echo off
if not defined Git_Root set "Git_Root=%~dp0..\.."
if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
pwsh.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/SystemConfiguration/Source/@03-Set_the_date_and_time_format_(HKCU_and_Current).reg" %*
