@echo off
echo.
echo ===============================================================================
echo [DEPRECATION ALERT] 'lcm' is DEPRECATED and superseded by 'run'!
echo Please use 'run' or 'run.cmd' directly.
echo ===============================================================================
echo.
call "%~dp0run.cmd" %*
exit /b %ERRORLEVEL%
