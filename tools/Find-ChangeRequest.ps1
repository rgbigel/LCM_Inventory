<#
.SYNOPSIS
    Queries and displays Change Requests from the central CM index.

.PARAMETER Query
    Search text to match in CR ID, title, or repository.

.PARAMETER Repository
    Filter CRs by origin or affected repository.

.PARAMETER Status
    Filter CRs by status (e.g. proposed, under-review, approved, implemented, verified, closed).

.EXAMPLE
    .\tools\Find-ChangeRequest.ps1 -Query "Inventory"
    .\tools\Find-ChangeRequest.ps1 -Status "closed"
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Query,
    
    [string]$Repository,
    
    [string]$Status,
    
    [string]$Author
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$crModule = Join-Path $PSScriptRoot '..\modules\ChangeRequestManager.psm1'
Import-Module $crModule -Force

$results = Find-ChangeRequest -Query $Query -Repository $Repository -Status $Status -Author $Author

if ($results.Count -eq 0) {
    Write-Host "No Change Requests matched the search criteria." -ForegroundColor Yellow
    return
}

Write-Host "`nFound $($results.Count) matching Change Request(s):`n" -ForegroundColor Cyan

$results | Format-Table -Property @(
    @{ Name = 'CR ID'; Expression = { $_.cr_id }; Width = 14 },
    @{ Name = 'Origin'; Expression = { $_.origin_repo }; Width = 20 },
    @{ Name = 'Status'; Expression = { $_.status }; Width = 12 },
    @{ Name = 'Target Ver'; Expression = { "v$($_.target_lcm_version)" }; Width = 12 },
    @{ Name = 'Title'; Expression = { $_.title } }
)
