rem echo off
setlocal EnableExtensions DisableDelayedExpansion

rem strip quotes
@echo Parm specified = %1%
set "PathToAdd=%~1%"
if /I "%PathToAdd%" == "ON" (
	set testing=ON
	set "PathToAdd=C:\Program Files (x86)\Common Files\Acronis\FileProtector64"
) else (
	set testing=OFF
)
@echo test for add of %PathToAdd% (no quotes) and testing=%testing%

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
@echo starting CheckPath
@echo System Path is 
@echo %SystemPath%

setlocal EnableDelayedExpansion
rem The folder path to add must contain \ (backslash) as directory
rem separator and not / (slash) and should not end with a backslash.
set "PathToAdd=!PathToAdd:/=\!"
if "!PathToAdd:~-1!" == "\" set "PathToAdd=!PathToAdd:~0,-1!"
@echo ------ PathToAdd is %PathToAdd%
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
	@echo PathToSet is NOT longer than 1024. 
)
@echo unverified PathToSet would be:
@echo %PathToSet%

@echo check if there PathToAdd already Specified, debugging 
rem Do nothing if the folder path to add without or with a backslash
rem at end with a semicolon appended for entire folder path check is
rem already in the system PATH value. This code does not work with
rem path to add contains an equal sign which is fortunately very rare.
if not "!PathCheck:%PathToAdd%;=!" == "!PathCheck!" (
	@echo SystemPath already contains "!PathCheck:%PathToAdd%;=!" with delimiter ";"
	goto EndBatch
)
if not "!PathCheck:%PathToAdd%\;=!" == "!PathCheck!" (
	@echo SystemPath already contains "!PathCheck:%PathToAdd%\;=!" with delimiters "\;"
	goto EndBatch
)

set "PathToSet=!SystemPath!%Separator%!PathToAdd!"
@echo PathToSet is 
@echo %PathToSet%
@echo _____ OK to here _____
echo on
@echo --------------------- begin test with testing ----------------------------
set Separator=;
set UseSetx=1
@echo ---- Testing %testing%: 
@echo ---- here now
	@echo %Systempath%
@echo ---- still here now

if /I "%testing%" == "ON" (
	@echo in test mode ON, use path
	set "SystemPath=d:\i wonder if this works;%path%;%PathToAdd%"
	echo Testing %testing%: 
	@echo ___________expecting no errors until now_______________
	@echo %Systempath%
) else (
	@echo in test mode OFF, don't use path
	set "SystemPath=d:\not adding path;%PathToAdd%"
	echo Testing %testing%: 
	@echo ___________using this system path:
	@echo %Systempath%
)

@echo --------------- Test ended ----------------

if not exist %SystemRoot%\System32\setx.exe (
	set "UseSetx="
	@echo %SystemRoot%\System32\setx.exe does not exist. Can't do AddToPath by Setx, using Registry
)	
@echo nowhambang 1
rem echo "UseSetx is '%UseSetx%', PathToSet is '%PathToSet%'"
@echo the echo worked 2
@echo if "!UseSetx!" == "1"
if "!UseSetx!" == "1" (
	echo UseSetx is 1
	@Echo "UseSetx is %UseSetx%, using setx.exe with parm:"
	@echo nowhambang 4 Echo    Path "!PathToSet!" /M:
	Echo    Path "!PathToSet!" /M 
	@echo Calling Setx with Path "!PathToSet!" /M
    	%SystemRoot%\System32\setx.exe Path "!PathToSet!" /M >nul
	echo WhamBang 2
) else (
	echo UseSetx is NOT 1
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