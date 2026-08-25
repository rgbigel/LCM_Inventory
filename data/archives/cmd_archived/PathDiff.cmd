@echo off
setlocal ENABLEDELAYEDEXPANSION

:: ============================================================
:: PathDiff.cmd
:: Compares two PATH strings and prints a two-column diff:
:: OLD VALUE (left) | NEW VALUE (right)
::
:: Added entries appear as:
::   -- added ------>   <path>
::
:: Removed entries appear as:
::   <path>             <------ removed --
::
:: Unchanged entries appear on the same row.
::
:: Usage:
::   PathDiff.cmd "<oldpath>" "<newpath>"
:: ============================================================

if "%~1"=="" (
    echo ERROR: Missing old PATH argument.
    exit /b 1
)

if "%~2"=="" (
    echo ERROR: Missing new PATH argument.
    exit /b 1
)

set "OLD=%~1"
set "NEW=%~2"

set "PSNorm=powershell -NoProfile -ExecutionPolicy Bypass -Command"

:: ------------------------------------------------------------
:: Normalize OLD PATH entries
:: ------------------------------------------------------------
setlocal disableDelayedExpansion
set "OLDRAW=%OLD%"
setlocal enableDelayedExpansion

set "i=0"
for %%A in ("%OLDRAW:;=" "%") do (
    set "entry=%%~A"
    set "entry=!entry:"=!"
    if not "!entry!"=="" (
        for /f "usebackq tokens=*" %%X in (`
            %PSNorm% "try { (Resolve-Path -LiteralPath '%entry%' -ErrorAction Stop).ProviderPath.TrimEnd('\') } catch { '%entry%'.TrimEnd('\') }"
        `) do (
            set /a i+=1
            set "OLDN[!i!]=%%X"
        )
    )
)
set "OLDCOUNT=%i%"

:: ------------------------------------------------------------
:: Normalize NEW PATH entries
:: ------------------------------------------------------------
setlocal disableDelayedExpansion
set "NEWR=%NEW%"
setlocal enableDelayedExpansion

set "j=0"
for %%A in ("%NEWR:;=" "%") do (
    set "entry=%%~A"
    set "entry=!entry:"=!"
    if not "!entry!"=="" (
        for /f "usebackq tokens=*" %%X in (`
            %PSNorm% "try { (Resolve-Path -LiteralPath '%entry%' -ErrorAction Stop).ProviderPath.TrimEnd('\') } catch { '%entry%'.TrimEnd('\') }"
        `) do (
            set /a j+=1
            set "NEWN[!j!]=%%X"
        )
    )
)
set "NEWCOUNT=%j%"

:: ------------------------------------------------------------
:: Build lookup tables
:: ------------------------------------------------------------
for /l %%k in (1,1,%OLDCOUNT%) do (
    set "OLDMAP[!OLDN[%%k!]!]=1"
)

for /l %%k in (1,1,%NEWCOUNT%) do (
    set "NEWMAP[!NEWN[%%k!]!]=1"
)

:: ------------------------------------------------------------
:: Print header
:: ------------------------------------------------------------
echo ============================================================
echo PATH DIFF
echo ============================================================
echo.
echo OLD VALUE                                   ^| NEW VALUE
echo --------------------------------------------+-----------------------------

:: ------------------------------------------------------------
:: Print unchanged and removed entries
:: ------------------------------------------------------------
for /l %%k in (1,1,%OLDCOUNT%) do (
    set "val=!OLDN[%%k]!"
    if defined NEWMAP[!val!] (
        echo !val! ^| !val!
    ) else (
        echo !val! ^| <------ removed --
    )
)

:: ------------------------------------------------------------
:: Print added entries (your requested format)
:: ------------------------------------------------------------
for /l %%k in (1,1,%NEWCOUNT%) do (
    set "val=!NEWN[%%k]!"
    if not defined OLDMAP[!val!] (
        echo -- added ------^> ^| !val!
    )
)

echo.
echo ============================================================
echo END OF DIFF
echo ============================================================

endlocal & endlocal & endlocal