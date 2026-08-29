<#
Module: tools/Create-WorkspaceBaseline.ps1
Purpose: Captures a full configuration baseline snapshot of all workspace repositories.
Path: tools/Create-WorkspaceBaseline.ps1
Authors: Rolf, Workspace_AI Engine
Version: 1.1.0
Date: 2026-08-28
Changelog:
- 2026-08-28: Renamed to Create-WorkspaceBaseline conforming to Creator naming taxonomy.
- 2026-08-15: Initial versioned implementation for multi-repo CM baseline capture.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage='Unique baseline identifier (e.g. BASELINE-v4.1.0-20260815)')]
    [string]$BaselineId,
    
    [Parameter(Mandatory=$false, HelpMessage='Description of baseline release')]
    [string]$Description,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " CREATE WORKSPACE BASELINE (v1.1.0)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Captures a full configuration baseline snapshot of all workspace repositories."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh Workspace_Inventory/tools/Create-WorkspaceBaseline.ps1 -BaselineId <str> [-Description <str>] [-h]"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$cmModule = Join-Path $PSScriptRoot '..\modules\WorkspaceCM.psm1'
Import-Module $cmModule -Force

if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = "Baseline snapshot $BaselineId created on $((Get-Date).ToString('yyyy-MM-dd'))"
}

New-WorkspaceBaseline -BaselineId $BaselineId -Description $Description
