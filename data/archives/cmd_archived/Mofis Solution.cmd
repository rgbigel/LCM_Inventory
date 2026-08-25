@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "KeyName=HKLM\SOFTWARE\Ansoft\Designer\2014.0\Desktop"
set "ValueName=InstallationDirectory"
for /F "skip=2 tokens=1,2*" %%G in ('%SystemRoot%\System32\reg.exe query "%KeyName%" /v "%ValueName%" 2^>nul') do (
    if /I "%%G" == "%ValueName%" (
        set "PathToAdd=%%I"
        if defined PathToAdd goto GetSystemPath
    )
)
echo Error: Could not find non-empty value "%ValueName%" under key
echo        %KeyName%
echo(
endlocal
pause
exit /B

:GetSystemPath
for /F "skip=2 tokens=1,2*" %%G in ('%SystemRoot%\System32\reg.exe query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v "Path" 2^>nul') do (
    if /I "%%G" == "Path" (
        set "SystemPath=%%I"
        if defined SystemPath goto CheckPath
    )
)
echo Error: System environment variable PATH not found with a non-empty value.
echo(
endlocal
pause
exit /B

:CheckPath
setlocal EnableDelayedExpansion
rem The folder path to add must contain \ (backslash) as directory
rem separator and not / (slash) and should not end with a backslash.
set "PathToAdd=!PathToAdd:/=\!"
if "!PathToAdd:~-1!" == "\" set "PathToAdd=!PathToAdd:~0,-1!"
if "!SystemPath:~-1!" == ";" (set "Separator=") else set "Separator=;"
set "PathCheck=!SystemPath!%Separator%"
rem Do nothing if the folder path to add without or with a backslash
rem at end with a semicolon appended for entire folder path check is
rem already in the system PATH value. This code does not work with
rem path to add contains an equal sign which is fortunately very rare.
if not "!PathCheck:%PathToAdd%;=!" == "!PathCheck!" goto EndBatch
if not "!PathCheck:%PathToAdd%\;=!" == "!PathCheck!" goto EndBatch
set "PathToSet=!SystemPath!%Separator%!PathToAdd!"
set "UseSetx=1"
if not "!PathToSet:~1024,1!" == "" set "UseSetx="
if not exist %SystemRoot%\System32\setx.exe set "UseSetx="
if defined UseSetx (
    %SystemRoot%\System32\setx.exe Path "!PathToSet!" /M >nul
) else (
    set "ValueType=REG_EXPAND_SZ"
    if "!PathToSet:%%=!" == "!PathToSet!" set "ValueType=REG_SZ"
    %SystemRoot%\System32\reg.exe ADD "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /f /v Path /t !ValueType! /d "!PathToSet!" >nul
)
:EndBatch
endlocal
endlocal