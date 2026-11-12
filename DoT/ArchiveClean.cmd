@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\LCM_Inventory\tools\Archive-Clean.ps1" %*
