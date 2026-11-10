<#
.SYNOPSIS
    Displays all repositories under review, dirty file counts, and BC5 review statuses.
.DESCRIPTION
    Module: tools/Get-ReposUnderReview.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 10.2.0
    Date: 2026-10-13
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Root workspace directory to inspect for repositories under review')]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " GET REPOSITORIES UNDER REVIEW (Get-ReposUnderReview)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Displays all repositories under review, dirty file counts, and BC5 review statuses."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Get-ReposUnderReview.ps1 [[-WorkspaceRoot] <str>] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -WorkspaceRoot   : Root workspace directory to inspect (default: D:\Git_Repositories)"
    Write-Host "  -Help (-h, -?)   : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$moduleCandidates = @(
    (Join-Path $WorkspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'),
    (Join-Path $PSScriptRoot '..\LCM_Inventory\modules\ProposalManager.psm1'),
    (Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1')
)
$modulePath = $null
foreach ($c in $moduleCandidates) {
    if (Test-Path -LiteralPath $c) {
        $modulePath = $c
        break
    }
}
if ($modulePath) {
    Import-Module $modulePath -Force
} else {
    throw "ProposalManager module not found in candidate paths."
}

$repos = Get-ReposUnderReview -WorkspaceRoot $WorkspaceRoot
Format-ReposUnderReviewTable -Repos $repos
