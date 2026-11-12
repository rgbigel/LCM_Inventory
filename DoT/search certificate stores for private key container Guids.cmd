@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\SystemConfiguration\Source\search certificate stores for private key container Guids.ps1" %*

