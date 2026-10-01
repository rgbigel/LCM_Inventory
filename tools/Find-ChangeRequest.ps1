<#
Module: tools/Find-ChangeRequest.ps1
Purpose: Queries and displays Change Requests from the central CM index and junction-mirrored proposals.
Path: tools/Find-ChangeRequest.ps1
Authors: Rolf, LCM_AI Engine
Version: 1.0.0
Date: 2026-08-15
Changelog:
- 2026-08-15: Initial versioned implementation with bundle and repo filtering.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0, HelpMessage='Search term matching CR ID, title, or repository')]
    [string]$Query,
    
    [Parameter(Mandatory=$false, HelpMessage='Filter by origin repository')]
    [string]$Repository,
    
    [Parameter(Mandatory=$false, HelpMessage='Filter by status (proposed, under-review, approved, implemented, verified, closed)')]
    [string]$Status,
    
    [Parameter(Mandatory=$false, HelpMessage='Filter by bundle ID')]
    [string]$BundleId,
    
    [Parameter(Mandatory=$false, HelpMessage='Filter by author')]
    [string]$Author,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " FIND CHANGE REQUEST (Find-ChangeRequest)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Queries and displays Change Requests from central CM index and proposals."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Find-ChangeRequest.ps1 [[-Query] <str>] [-Repository <str>] [-Status <str>] [-BundleId <str>] [-Author <str>] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Query         : Search term matching CR ID, title, or repository"
    Write-Host "  -Repository    : Filter by origin repository"
    Write-Host "  -Status        : Filter by status (proposed, under-review, approved, implemented, verified, closed)"
    Write-Host "  -BundleId      : Filter by bundle ID"
    Write-Host "  -Author        : Filter by author"
    Write-Host "  -Help (-h, -?) : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$crModule = Join-Path $PSScriptRoot '..\modules\ChangeRequestManager.psm1'
Import-Module $crModule -Force

$results = Find-ChangeRequest -Query $Query -Repository $Repository -Status $Status -BundleId $BundleId -Author $Author

if (@($results).Count -eq 0) {
    Write-Host "No Change Requests matched the search criteria." -ForegroundColor Yellow
    return
}

Write-Host "`nFound $(@($results).Count) matching Change Request(s):`n" -ForegroundColor Cyan

$results | Format-Table -Property @(
    @{ Name = 'CR ID'; Expression = { $_.cr_id }; Width = 14 },
    @{ Name = 'Origin'; Expression = { $_.origin_repo }; Width = 20 },
    @{ Name = 'Status'; Expression = { $_.status }; Width = 12 },
    @{ Name = 'Target Ver'; Expression = { "v$($_.target_lcm_version)" }; Width = 12 },
    @{ Name = 'Bundle'; Expression = { $_.bundle_id }; Width = 16 },
    @{ Name = 'Title'; Expression = { $_.title } }
)
