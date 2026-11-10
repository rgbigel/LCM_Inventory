<#
.SYNOPSIS
  Atomic elevated registry modifier for authorized LCM machine namespaces.
.DESCRIPTION
  Module: tools/Set-LcmMachineRegistry.ps1
  Purpose: Executes targeted atomic writes to HKLM:\SOFTWARE\LCM\* or machine environment
  variables under administrative elevation per RULE-ELEV-007.
  Rejects any target key outside legitimate LCM namespaces.
  Path: LCM_Inventory/tools/Set-LcmMachineRegistry.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-11-09 12:35:00
.PARAMETER KeyPath
  Target registry key path (must start with HKLM:\SOFTWARE\LCM\ or HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment).
.PARAMETER Name
  Name of the registry property to set.
.PARAMETER Value
  Value to assign to the registry property.
.PARAMETER PropertyType
  Type of registry property (Default: String).
.PARAMETER Help
  Displays this parameter reference and usage instructions.
.NOTES
  Part of CRP-310 (Atomic Elevation Governance).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Target registry key path')]
  [ValidateNotNullOrEmpty()]
  [string]$KeyPath,

  [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'Name of the registry property')]
  [ValidateNotNullOrEmpty()]
  [string]$Name,

  [Parameter(Mandatory = $true, Position = 2, HelpMessage = 'Value to assign')]
  [object]$Value,

  [Parameter(Mandatory = $false, Position = 3, HelpMessage = 'Registry property type')]
  [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')]
  [string]$PropertyType = 'String',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Set-LcmMachineRegistry.ps1 -KeyPath <path> -Name <name> -Value <val> [-PropertyType <type>] [-h]'
  Write-Host '  Atomic elevated registry modifier for authorized LCM machine namespaces (RULE-ELEV-007).'
  return
}

# 1. Legitimacy check (RULE-ELEV-007)
$isLegitimate = $KeyPath -match '^(?i)HKLM:\\SOFTWARE\\LCM(?:\\[^\\]+)*$' -or
                $KeyPath -match '^(?i)HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment$'
if (-not $isLegitimate) {
  throw "Security Exception: Registry path '$KeyPath' is outside legitimate LCM namespaces (RULE-ELEV-007)."
}

# 2. Check execution elevation
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
$isElevated = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isElevated) {
  # Dispatches transparent UAC elevation using explicit script and arguments per RULE-ELEV-005
  $thisScript = $MyInvocation.MyCommand.Path
  Write-Host '==========================================================================' -ForegroundColor Yellow
  Write-Host ' [LCM-ELEVATION] Administrative Elevation Required (RULE-ELEV-005 / 007)' -ForegroundColor Yellow
  Write-Host '==========================================================================' -ForegroundColor Yellow
  Write-Host " Target Script : $thisScript" -ForegroundColor White
  Write-Host " Arguments     : -KeyPath '$KeyPath' -Name '$Name' -Value '$Value' -PropertyType '$PropertyType'" -ForegroundColor White
  Write-Host ' Required Priv : Administrator' -ForegroundColor White
  Write-Host '==========================================================================' -ForegroundColor Yellow

  $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$thisScript`" -KeyPath `"$KeyPath`" -Name `"$Name`" -Value `"$Value`" -PropertyType `"$PropertyType`""
  $proc = Start-Process -FilePath 'pwsh.exe' -ArgumentList $argList -Verb RunAs -PassThru
  $proc.WaitForExit()
  if ($proc.ExitCode -ne 0) {
    throw "Elevated registry write failed with exit code $($proc.ExitCode)."
  }
  return
}

# 3. Perform write under confirmed elevation
if (-not (Test-Path -LiteralPath $KeyPath)) {
  New-Item -Path $KeyPath -Force | Out-Null
}
Set-ItemProperty -Path $KeyPath -Name $Name -Value $Value -Type $PropertyType -Force | Out-Null
Write-Host "Registry successfully updated: $KeyPath\$Name = '$Value'" -ForegroundColor Green

