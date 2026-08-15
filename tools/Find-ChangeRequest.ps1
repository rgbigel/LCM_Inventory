<#
Module: tools/Find-ChangeRequest.ps1
Purpose: Queries and displays Change Requests from the central CM index and junction-mirrored proposals.
Path: tools/Find-ChangeRequest.ps1
Authors: Rolf, Workspace_AI Engine
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
    [string]$Author
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
