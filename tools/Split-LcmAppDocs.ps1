<#
.SYNOPSIS
    Migrates a repository's in-document App sections into dedicated tripartite subdirectories.
.DESCRIPTION
    Module: tools/Split-LcmAppDocs.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 7.6.0
    Date: 2026-09-20
    Purpose: High-Order Lifecycle Operator that parses monolithic in-document App: # sections
             from root Architecture.md, Requirements.md, and Implementation.md and extracts
             them into dedicated docs/App#<N>-<Title>/ subdirectories per RULE-DOC-007.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Target repository name to split into dedicated App documents')]
    [string]$Repo = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Workspace root path')]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help -or [string]::IsNullOrWhiteSpace($Repo)) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " SPLIT LCM APP DOCS (Split-LcmAppDocs)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Extracts in-document App: # sections into dedicated docs/App#*/ subdirectories."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh Workspace_Inventory/tools/Split-LcmAppDocs.ps1 [-Repo] <str> [-WorkspaceRoot <path>] [-WhatIf] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Repo          : Target repository name (e.g. 'BackgroundModifier', 'Workspace_AI')"
    Write-Host "  -WorkspaceRoot : Workspace root directory (default: D:\Git_Repositories)"
    Write-Host "  -WhatIf        : Previews the planned extraction without modifying files"
    Write-Host "  -Help (-h, -?) : Displays this parameter reference"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
Import-Module $modulePath -Force

$targetRepoPath = Join-Path $WorkspaceRoot $Repo
if (-not (Test-Path -LiteralPath $targetRepoPath)) {
    throw "Target repository '$Repo' not found at: $targetRepoPath"
}

Split-LcmAppDocs -Repo $Repo -WorkspaceRoot $WorkspaceRoot
