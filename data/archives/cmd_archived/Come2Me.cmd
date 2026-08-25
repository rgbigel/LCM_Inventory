@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================================
:: ComeToMe.cmd — Unified Architecture (Best of All Worlds)
:: PATH Management Utility with:
::   - BNF-driven semantics
::   - Declarative defaults
::   - Procedural argument parsing
::   - Canonical normalization layer
::   - Diff-aware idempotence
::   - Layered trace/debug model
:: ============================================================================

:: -----------------------------
:: DEFAULTS (BNF contract)
:: -----------------------------
set "ACTION=addpath"
set "BASEDIR=D:\OneDrive\cmd"
set "TRACE=0"
set "DEBUG_MODE=0"

:: -----------------------------
:: PRE-PARSE: detect -debug early
:: -----------------------------
for %%A in (%*) do (
    if /I "%%~A"=="-debug" (
        set "DEBUG_MODE=1"
    )
)
if "%DEBUG_MODE%"=="1" @echo on

:: -----------------------------
:: ARGUMENT PARSING (procedural)
:: -----------------------------
if "%~1"=="" goto args_parsed

:parse_args
if "%~1"=="" goto args_parsed

if /I "%~1"=="-debug" (
    set "DEBUG_MODE=1"
    set "TRACE=1"
) else if /I "%~1"=="-trace" (
    set "TRACE=1"

) else if /I "%~1"=="addpath" (
    set "ACTION=addpath"
) else if /I "%~1"=="-addpath" (
    set "ACTION=addpath"

) else if /I "%~1"=="addsubpaths" (
    set "ACTION=addsubpaths"
) else if /I "%~1"=="-addsubpaths" (
    set "ACTION=addsubpaths"
) else if /I "%~1"=="-addsubpath" (
    set "ACTION=addsubpaths"

) else if /I "%~1"=="removepath" (
    set "ACTION=removepath"
) else if /I "%~1"=="-removepath" (
    set "ACTION=removepath"

) else if /I "%~1"=="removesubpaths" (
    set "ACTION=removesubpaths"
) else if /I "%~1"=="-removesubpaths" (
    set "ACTION=removesubpaths"

) else if /I "%~1"=="basepath" (
    shift
    if "%~1"=="" (
        @echo [E01] Missing value for basepath
        exit /b 1
    )
    set "BASEDIR=%~1"

) else if /I "%~1"=="-h" (
    goto :help
) else if /I "%~1"=="-help" (
    goto :help

) else (
    @echo [E02] Unknown argument: %~1
    @echo.
    goto :help_brief
)

shift
goto parse_args

:args_parsed

:: -----------------------------
:: VALIDATION
:: -----------------------------
if not exist "%BASEDIR%" (
    @echo [E03] Base directory '%BASEDIR%' does not exist.
    exit /b 1
)

:: -----------------------------
:: NORMALIZATION LAYER
:: -----------------------------
if "%TRACE%"=="1" @echo [TRACE1] Normalizing path...

for /f "usebackq tokens=*" %%P in (
    `powershell -NoProfile -Command "try { (Resolve-Path -Path '%BASEDIR%' -ErrorAction Stop).ProviderPath } catch { exit 1 }" 2^>nul`
) do set "NORMDIR=%%P"

if not defined NORMDIR (
    @echo [E04] Failed to normalize '%BASEDIR%'.
    exit /b 1
)

if "%TRACE%"=="1" @echo [TRACE1] Normalized: %NORMDIR%

:: -----------------------------
:: DIFF LAYER (idempotence check)
:: -----------------------------
if "%TRACE%"=="1" @echo [TRACE2] Computing diff...

for /f "usebackq tokens=*" %%D in (
    `powershell -NoProfile -Command "('%PATH%'.Split(';') -contains '%NORMDIR%')" 2^>nul`
) do set "ALREADY_PRESENT=%%D"

if /I "%ACTION%"=="addpath" (
    if /I "%ALREADY_PRESENT%"=="True" (
        if "%TRACE%"=="1" @echo [TRACE2] Path already present
        @echo [SUCCESS] Path already present.
        exit /b 0
    )
)

if /I "%ACTION%"=="removepath" (
    if /I "%ALREADY_PRESENT%"=="False" (
        if "%TRACE%"=="1" @echo [TRACE2] Path not present — idempotent no-op.
        @echo [SUCCESS] Path already absent.
        exit /b 0
    )
)

:: -----------------------------
:: DISPATCHER (PowerShell layer)
:: -----------------------------
if "%TRACE%"=="1" @echo [TRACE3] Dispatching action: %ACTION%

if /I "%ACTION%"=="addpath" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "Add2Path.ps1" -AddPath "%NORMDIR%" -Trace:%TRACE%
) else if /I "%ACTION%"=="addsubpaths" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "Add2Path.ps1" -AddSubPaths "%NORMDIR%" -Trace:%TRACE%
) else if /I "%ACTION%"=="removepath" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "RemoveFromPath.ps1" -RemovePath "%NORMDIR%" -Trace:%TRACE%
) else if /I "%ACTION%"=="removesubpaths" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "RemoveFromPath.ps1" -RemoveSubPaths "%NORMDIR%" -Trace:%TRACE%
) else (
    @echo [E06] Internal error: unknown ACTION '%ACTION%'.
    exit /b 1
)

if errorlevel 1 (
    @echo [E05] PowerShell action failed.
    exit /b 1
)

@echo [SUCCESS] Operation completed successfully.
endlocal
exit /b 0

:: ============================================================================
:: HELP
:: ============================================================================
:help
endlocal
@echo.
@echo ComeToMe.cmd - PATH Management Utility
@echo ======================================
@echo.
@echo SYNTAX (BNF):
@echo.
@echo   ComeToMe.cmd ::= [^<action^>] [^<basepath-spec^>] [^<options^>]
@echo.
@echo   ^<action^>        ::= ["-"]("addpath" ^| "addsubpaths" ^| "removepath" ^| "removesubpaths")
@echo   ^<basepath-spec^> ::= ["-"]"basepath" ^<directory^>
@echo   ^<directory^>     ::= ^<valid-filesystem-path^>
@echo   ^<options^>       ::= ["-trace"] ["-debug"] ["-h" ^| "-help"]
@echo.
@echo DEFAULTS:
@echo   Action:          addpath
@echo   Base directory:  D:\OneDrive\cmd
@echo   (Arguments override these defaults)
@echo.
@echo ACTIONS:
@echo   addpath          Add the specified directory to USER PATH
@echo   addsubpaths      Add the directory and all subdirectories to USER PATH
@echo   removepath       Remove the specified directory from USER PATH
@echo   removesubpaths   Remove the directory and all subdirectories from USER PATH
@echo.
@echo   Note: Actions can be specified with or without a leading dash (-)
@echo         Alias: -addsubpath (singular) also accepted
@echo.
@echo OPTIONS:
@echo   -trace           Enable layered trace output (TRACE1/2/3)
@echo   -debug           Enable command echo (@echo on) and implies -trace
@echo   -h, -help        Display this help message
@echo.
@echo FEATURES:
@echo   - Idempotence: Detects if path already exists/absent before modification
@echo   - Normalization: Resolves relative paths and symlinks automatically
@echo   - Error codes: [E01-E06] for systematic troubleshooting
@echo   - Trace layers: TRACE1 (normalize), TRACE2 (diff), TRACE3 (dispatch)
@echo.
@echo EXAMPLES:
@echo   ComeToMe.cmd
@echo     (Uses defaults: addpath basepath "D:\OneDrive\cmd")
@echo.
@echo   ComeToMe.cmd -debug -trace -addsubpaths
@echo     (Uses default directory with debug, trace, and addsubpaths action)
@echo.
@echo   ComeToMe.cmd removepath
@echo     (Remove default directory from PATH)
@echo.
@echo   ComeToMe.cmd -addpath -basepath "C:\MyTools"
@echo     (Override directory with dash-prefixed flags)
@echo.
@echo   ComeToMe.cmd addsubpaths basepath "C:\DevTools" -trace
@echo     (Override both action and directory with trace enabled)
@echo.
@echo   ComeToMe.cmd basepath "C:\Scripts"
@echo     (Override directory only, uses default action: addpath)
@echo.
@echo   ComeToMe.cmd removesubpaths basepath "C:\OldTools" -debug
@echo     (Remove directory tree with full debug output)
@echo.
exit /b 0

:help_brief
endlocal
@echo Run "ComeToMe.cmd -help" for usage information.
exit /b 1
