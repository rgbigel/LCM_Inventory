@echo off
setlocal

rem Usage:
rem   GIT_Repo_BC.cmd nextboottray
rem   GIT_Repo_BC.cmd nextboottray PS

if "%~1"=="" (
    echo Usage: %~nx0 ^<repoName^> [repoGroup]
    echo Example: %~nx0 nextboottray
    echo Example: %~nx0 nextboottray PS
    exit /b 1
)

set "REPO_NAME=%~1"
set "REPO_GROUP=%~2"
if "%REPO_GROUP%"=="" set "REPO_GROUP=PS"

set "BASE_REPO_DIR=D:\OneDrive\Git_Repositories\%REPO_GROUP%"
set "REPO_DIR=%BASE_REPO_DIR%\%REPO_NAME%"
set "HEAD_DIR=D:\Temp\%REPO_NAME%_HEAD"
set "BC_EXE=D:\Tools\Beyond Compare 5\BCompare.exe"

if not exist "%BC_EXE%" (
    echo ERROR: Beyond Compare not found: "%BC_EXE%"
    exit /b 1
)

if not exist "%REPO_DIR%\.git" (
    echo ERROR: Git repository not found: "%REPO_DIR%"
    exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
    echo ERROR: git is not available in PATH.
    exit /b 1
)

where tar >nul 2>&1
if errorlevel 1 (
    echo ERROR: tar is not available in PATH.
    exit /b 1
)

echo Repo: %REPO_DIR%
echo Group: %REPO_GROUP%
echo Head snapshot: %HEAD_DIR%

rem Always clear previous HEAD snapshot before recreating.
if exist "%HEAD_DIR%" (
    rmdir /s /q "%HEAD_DIR%"
)

mkdir "%HEAD_DIR%"
if errorlevel 1 (
    echo ERROR: Failed to create snapshot folder: "%HEAD_DIR%"
    exit /b 1
)

pushd "%REPO_DIR%"
if errorlevel 1 (
    echo ERROR: Failed to enter repository folder.
    exit /b 1
)

git archive HEAD | tar -x -f - -C "%HEAD_DIR%"
if errorlevel 1 (
    popd
    echo ERROR: Failed to export HEAD snapshot.
    exit /b 1
)

popd

start "" "%BC_EXE%" "%HEAD_DIR%" "%REPO_DIR%"

exit /b 0
