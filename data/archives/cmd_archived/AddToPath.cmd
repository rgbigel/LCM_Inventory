rem @echo off
setlocal EnableExtensions DisableDelayedExpansion
set PathToAdd=%~1%
@echo test for add of %PathToAdd% (no quotes)

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
rem @echo System Path is %SystemPath%
setlocal EnableDelayedExpansion
rem The folder path to add must contain \ (backslash) as directory
rem separator and not / (slash) and should not end with a backslash.
set "PathToAdd=!PathToAdd:/=\!"
if "!PathToAdd:~-1!" == "\" set "PathToAdd=!PathToAdd:~0,-1!"
rem @echo PathToAdd is %PathToAdd%
if "!SystemPath:~-1!" == ";" (set "Separator=") else set "Separator=;"
set "PathCheck=!SystemPath!%Separator%"
@echo PathCheck value is 
@echo           !SystemPath!%Separator%
@echo PathToAdd is "!PathToAdd!"

set "PathToSet=!SystemPath!%Separator%!PathToAdd!"

if not "!PathToSet:~1024,1!" == "" (
	set "UseSetx="
	@echo PathToSet is longer than 1024. Can't do AddToPath using Setx, will use reg.exe
) else (
	@echo check if there PathToAdd already Specified, debugging 
)
@echo unverified PathToSet would be:
@echo %PathToSet%

rem Do nothing if the folder path to add without or with a backslash
rem at end with a semicolon appended for entire folder path check is
rem already in the system PATH value. This code does not work with
rem path to add contains an equal sign which is fortunately very rare.
if not "!PathCheck:%PathToAdd%;=!" == "!PathCheck!" (
	@echo SystemPath already contains "!PathCheck:%PathToAdd%;=!" with delimiter ";"
	goto EndBatch
)
if not "!PathCheck:%PathToAdd%\;=!" == "!PathCheck!" (
	@echo SystemPath already contains "!PathCheck:%PathToAdd%\;=!" with delimiter "\;"
	goto EndBatch
)
set "PathToSet=!SystemPath!%Separator%!PathToAdd!"
set "UseSetx=1"
if not exist %SystemRoot%\System32\setx.exe (
	set "UseSetx="
	@echo %SystemRoot%\System32\setx.exe does not exist. Can't do AddToPath by Setx, using Registry
)	
@echo nowhambang 1
rem echo "UseSetx is '%UseSetx%', PathToSet is '%PathToSet%'"
@echo nowhambang 2

if defined UseSetx (
	echo nowhambang 3
	@Echo "UseSetx is %UseSetx%, using setx.exe with parm:"
@echo nowhambang 4
	Echo    Path "!PathToSet!" /M 
echo WhamBang 1
    %SystemRoot%\System32\setx.exe Path "!PathToSet!" /M >nul
echo WhamBang 2
) else (
    set "ValueType=REG_EXPAND_SZ"
	@echo ValueType is %ValueType%
    if "!PathToSet:%%=!" == "!PathToSet!" set "ValueType=REG_SZ"
	@Echo ValueType is %ValueType%, using reg.exe with parm:
	@Echo     ADD "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /f /v Path /t !ValueType! /d "!PathToSet!"
    %SystemRoot%\System32\reg.exe ADD "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /f /v Path /t !ValueType! /d "!PathToSet!" >nul
	@echo System Path has been set to: 
	@echo %PathToSet%
)
:EndBatch
endlocal
endlocal