<#
.SYNOPSIS
    Displays all open LCM proposals in chronological order.
.DESCRIPTION
    Module: tools/Get-OpenProposals.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 1.1.0
    Date: 2026-09-10
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Display all proposals regardless of state')]
    [switch]$All,

    [Parameter(Mandatory = $false, HelpMessage = 'Filter by proposal state (suggested, approved, in_progress, completed, pushed, deferred)')]
    [string]$State,

    [Parameter(Mandatory = $false, HelpMessage = 'Filter by origin repository name')]
    [string]$OriginRepo,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " GET OPEN PROPOSALS (Get-OpenProposals)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Displays all open LCM proposals in chronological order."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Get-OpenProposals.ps1 [-All] [-State <str>] [-OriginRepo <str>] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -All             : Display all proposals regardless of state"
    Write-Host "  -State           : Filter by proposal state"
    Write-Host "  -OriginRepo      : Filter by origin repository name"
    Write-Host "  -Help (-h, -?)   : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$workspaceRoot = 'D:\Git_Repositories'
$moduleCandidates = @(
    (Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'),
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

$proposals = if ($All) {
    Get-WorkspaceProposals -State $State -OriginRepo $OriginRepo
} else {
    Get-WorkspaceProposals -OpenOnly -State $State -OriginRepo $OriginRepo
}

Format-ProposalsTable -Proposals $proposals
