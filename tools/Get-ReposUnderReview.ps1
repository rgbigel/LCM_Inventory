<#
.SYNOPSIS
    Displays all repositories under review, dirty file counts, and BC5 review statuses.
.DESCRIPTION
    Module: tools/Get-ReposUnderReview.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.0.0
    Date: 2026-08-20
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleCandidates = @(
    (Join-Path $WorkspaceRoot 'Workspace_Inventory\modules\ProposalManager.psm1'),
    (Join-Path $PSScriptRoot '..\Workspace_Inventory\modules\ProposalManager.psm1'),
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
