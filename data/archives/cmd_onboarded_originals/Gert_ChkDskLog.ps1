param()

<#
    Module:  Get_ChkDskLog.ps1
    Purpose: New script template
    Path: D:\OneDrive\Cmd\
    Authors: Rolf
    Version: 1.0
    Changelog:
      - Initial creation
#>Get-WinEvent -FilterHashtable @{logname='Application'; id=1001} |
  Where-Object {$_.ProviderName -match 'Wininit'} |
  Format-List TimeCreated, Message > c:\Temp\ChkDsk.log
Notepad++.exe C:\Temp\ChkDsk.log
