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

$modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
Import-Module $modulePath -Force

$repos = Get-ReposUnderReview -WorkspaceRoot $WorkspaceRoot
Format-ReposUnderReviewTable -Repos $repos
