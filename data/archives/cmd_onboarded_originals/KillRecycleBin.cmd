@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM   Module:      KillRecycleBin.cmd
REM   Purpose:     Remove all content of the REAL Recycle Bin on
REM                a specific drive, without questions or prompts.
REM   Path:        D:\OneDrive\cmd\KillRecycleBin.cmd
REM   Authors:     Rolf
REM   Version:     1.0.0
REM   Changelog:
REM       1.0.0    Initial version. Force-clears Recycle Bin using
REM                Clear-RecycleBin and fallback deletion.
REM ============================================================


REM ------------------------------------------------------------
REM 1. Require drive letter
REM ------------------------------------------------------------

if "%~1"=="" (
    echo ABORT: Drive letter required.
    exit /b 1
)

set "DL=%~1"

REM Normalize: J -> J: -> J:\
if "%DL:~-1%"==":" (
    set "DL=%DL%\"
)

if not "%DL:~-1%"=="\" (
    set "DL=%DL%:\"
)

REM Now DL is guaranteed like: J:\


REM ------------------------------------------------------------
REM 2. Determine real Recycle Bin path
REM ------------------------------------------------------------

set "RB=%DL%$Recycle.bin"

if not exist "%RB%" (
    echo ABORT: Recycle Bin does not exist: %RB%
    exit /b 1
)


REM ------------------------------------------------------------
REM 3. First attempt: Clear-RecycleBin (PowerShell)
REM ------------------------------------------------------------

powershell -NoLogo -NoProfile -Command ^
    "Clear-RecycleBin -DriveLetter '%DL:~0,1%' -Force" >nul 2>&1


REM ------------------------------------------------------------
REM 4. Second attempt: brutal deletion
REM ------------------------------------------------------------

attrib -h -s "%RB%" >nul 2>&1

REM Delete files
del /f /q "%RB%\*" >nul 2>&1

REM Delete SID folders
for /d %%S in ("%RB%\*") do (
    rmdir /s /q "%%S" >nul 2>&1
)


REM ------------------------------------------------------------
REM 5. Final attempt: rename + recreate
REM ------------------------------------------------------------

if exist "%RB%" (
    ren "%RB%" "$Recycle.bin.broken" >nul 2>&1

    rmdir /s /q "%DL%$Recycle.bin.broken" >nul 2>&1

    mkdir "%RB%" >nul 2>&1
)


echo DONE: Recycle Bin cleaned on %DL%
endlocal
exit /b 0
