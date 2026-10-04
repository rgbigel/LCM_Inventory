@echo off
if not defined Git_Root set "Git_Root=%~dp0..\.."
if not exist "%Git_Root%\LCM_Inventory" set "Git_Root=D:\Git_Repositories"
setlocal
python "%Git_Root%/HaSSD06/scan_community_issues.py" %*
endlocal
