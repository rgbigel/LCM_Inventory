[CmdletBinding()]
param(
    [Alias('h', '?')]
    [switch]$Help
)

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LOAD ATOMS (LCM_Inventory/tools/LoadAtoms.ps1)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS: Loads atom files for LCM_AI fix-module execution."
    Write-Host "USAGE:    pwsh tools/LoadAtoms.ps1 [-h]"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

<#
Module: LoadAtoms.ps1
Purpose: Load atom files for LCM_AI fix-module execution.
Path: tools/LoadAtoms.ps1
Authors: LCM_AI Engine
Version: 1.0.1
Caller Contract: Called from APPLY/fix-module validation; returns a hashtable keyed by atom base name.
Changelog:
- 2026-08-01: Updated active loader identity from Workspace_AC to LCM_AI.
- 2026-07-31: Added deterministic atom loader for Fix_S1E03 deep consistency.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$atomsRoot = Join-Path $workspaceRoot '.agents\atoms'
$atoms = @{}

Get-ChildItem -Path $atomsRoot -Filter '*.atom' -File | Sort-Object -Property Name | ForEach-Object {
  $atomFile = $_
  $atomName = [System.IO.Path]::GetFileNameWithoutExtension($atomFile.Name)
  $atoms[$atomName] = Get-Content -Path $atomFile.FullName
}

return $atoms
