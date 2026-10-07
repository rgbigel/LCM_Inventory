[CmdletBinding()]
param(
    [Alias('h', '?')]
    [switch]$Help
)

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LOAD RULES (LCM_Inventory/tools/LoadRules.ps1)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS: Loads LCM_AI rule files for native governance validation."
    Write-Host "USAGE:    pwsh tools/LoadRules.ps1 [-h]"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

<#
Module: LoadRules.ps1
Purpose: Load LCM_AI rule files for native governance validation.
Path: tools/LoadRules.ps1
Authors: LCM_AI Engine
Version: 1.0.0
Caller Contract: Called by validation scripts; returns a hashtable keyed by rule family.
Changelog:
- 2026-08-12: Added standard LCM_AI script header.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$root = Join-Path $workspaceRoot ".agents\rules"

$rules = @{
    invariant  = Get-Content (Join-Path $root "InvariantRules.md")
    powershell = Get-Content (Join-Path $root "PowerShellRules.md")
    cmd        = Get-Content (Join-Path $root "CMDRules.md")
    json       = Get-Content (Join-Path $root "JsonRules.md")
}

return $rules
