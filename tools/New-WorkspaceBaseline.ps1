<#
Module: tools/New-WorkspaceBaseline.ps1
Purpose: Captures a full configuration baseline snapshot of all workspace repositories.
Path: tools/New-WorkspaceBaseline.ps1
Authors: Rolf, Workspace_AI Engine
Version: 1.0.0
Date: 2026-08-15
Changelog:
- 2026-08-15: Initial versioned implementation for multi-repo CM baseline capture.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage='Unique baseline identifier (e.g. BASELINE-v4.1.0-20260815)')]
    [string]$BaselineId,
    
    [Parameter(Mandatory=$false, HelpMessage='Description of baseline release')]
    [string]$Description
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cmModule = Join-Path $PSScriptRoot '..\modules\WorkspaceCM.psm1'
Import-Module $cmModule -Force

if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = "Baseline snapshot $BaselineId created on $((Get-Date).ToString('yyyy-MM-dd'))"
}

New-WorkspaceBaseline -BaselineId $BaselineId -Description $Description
