@echo off
setlocal EnableExtensions
set "GitRoot="
for /f "tokens=2,*" %%A in ('reg.exe query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Git_Root 2^>nul ^| findstr /I /R "^ *Git_Root"') do set "GitRoot=%%B"
if not defined GitRoot (
  echo ERROR: Machine Git_Root registry value is unavailable.
  exit /b 1
)
if not exist "%GitRoot%\LCM_Inventory\tools\Invoke-LCM_GoodNight.ps1" (
  echo ERROR: GoodNight tool was not found beneath machine Git_Root: %GitRoot%
  exit /b 1
)
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%GitRoot%\LCM_Inventory\tools\Invoke-LCM_GoodNight.ps1" %*
set "ExitCode=%ERRORLEVEL%"
endlocal & exit /b %ExitCode%

