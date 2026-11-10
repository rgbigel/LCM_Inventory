[CmdletBinding()]
param(
    [Alias('h', '?')]
    [switch]$Help
)

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LOAD FIXES (LCM_Inventory/tools/LoadFixes.ps1)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS: Loads fix-module descriptors for LCM_AI fix-module execution."
    Write-Host "USAGE:    pwsh tools/LoadFixes.ps1 [-h]"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

<#
Module: LoadFixes.ps1
Purpose: Load fix-module descriptors for LCM_AI fix-module execution.
Path: tools/LoadFixes.ps1
Authors: LCM_AI Engine
Version: 10.2.0
Caller Contract: Called from APPLY/fix-module validation; returns a hashtable keyed by fix id and module name.
Changelog:
- 2026-10-13: Updated active loader identity from Workspace_AC to LCM_AI.
- 2026-10-13: Added deterministic fix-module loader for Fix_S1E03 deep consistency.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$fixesRoot = Join-Path $workspaceRoot '.copilot\Fixes'
$fixes = @{}

if (Test-Path $fixesRoot) {
  Get-ChildItem -Path $fixesRoot -Filter '*.json' -File | Sort-Object -Property Name | ForEach-Object {
    $fixFile = $_
    $fixModule = Get-Content -Raw -Path $fixFile.FullName | ConvertFrom-Json
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($fixFile.Name)
    $fixes[$moduleName] = $fixModule

    if ($fixModule.PSObject.Properties['id']) {
      $fixes[$fixModule.id] = $fixModule
    }
  }
}

return $fixes
