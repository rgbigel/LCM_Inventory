[CmdletBinding()]
param(
    [Alias('h', '?')]
    [switch]$Help
)

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LOAD METHODS (LCM_Inventory/tools/LoadMethods.ps1)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS: Loads method script metadata for LCM_AI fix-module execution."
    Write-Host "USAGE:    pwsh tools/LoadMethods.ps1 [-h]"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

<#
Module: LoadMethods.ps1
Purpose: Load method script metadata for LCM_AI fix-module execution.
Path: tools/LoadMethods.ps1
Authors: LCM_AI Engine
Version: 10.0.0
Caller Contract: Called from APPLY/fix-module validation; returns a hashtable keyed by method file name.
Changelog:
- 2026-10-13: Updated active loader identity from Workspace_AC to LCM_AI.
- 2026-10-13: Added deterministic method loader for Fix_S1E03 deep consistency.
#>

$methodsRoot = $PSScriptRoot
$methods = @{}

Get-ChildItem -Path $methodsRoot -Filter '*.ps1' -File | Sort-Object -Property Name | ForEach-Object {
  $methodFile = $_
  $methods[$methodFile.Name] = [pscustomobject]@{
    Name = $methodFile.Name
    Path = $methodFile.FullName
  }
}

return $methods
