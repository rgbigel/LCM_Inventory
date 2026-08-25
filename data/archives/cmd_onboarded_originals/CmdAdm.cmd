@echo off
rem ============================================================
rem Module: GoAdm.cmd
rem Purpose: Pure CMD elevation helper, identical to cmdadm.cmd predecessor.
rem Path: \cmd\GoAdm.cmd
rem Authors: Rolf + Copilot
rem Version: 2.0.1
rem Changelog:
rem   2.0.1 - Removed argument parser. Only -t is recognized.
rem ============================================================

setlocal ENABLEDELAYEDEXPANSION

set TRACE_FLAG=

if /I "%~1"=="-t" set TRACE_FLAG=1

rem Detect elevation (Administrator group)
whoami /groups | find "S-1-5-32-544" >nul
if %errorlevel%==0 goto elevated

rem ------------------------------------------------------------
rem Non-elevated CMD ? runas ? new elevated CMD window
rem ------------------------------------------------------------
if defined TRACE_FLAG echo Not elevated. Launching new elevated CMD window.

runas /noprofile /env /savecred /user:Administrator "cmd.exe"
exit /b

:elevated
rem ------------------------------------------------------------
rem Already elevated CMD ? do nothing
rem ------------------------------------------------------------
if defined TRACE_FLAG echo Already elevated.
exit /b
