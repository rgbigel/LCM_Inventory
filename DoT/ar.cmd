@echo off
setlocal
if exist "D:\OneDrive\cmd\Invoke-ReasoningAnalysisAuto.ps1" (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "D:\OneDrive\cmd\Invoke-ReasoningAnalysisAuto.ps1" -Auto %*
) else (
  if not defined Git_Root set "Git_Root=%~dp0..\.."
if not exist "%Git_Root%\LCM_Inventory" (
  echo [ERROR] Target repository not found relative to Git_Root: %Git_Root%
  exit /b 1
)
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%Git_Root%/LCM_Inventory/tools/Invoke-ReasoningAnalysis.ps1" %*
)
set "EXIT_CODE=%ERRORLEVEL%"
endlocal
exit /b %EXIT_CODE%
