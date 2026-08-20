<#
.SYNOPSIS
    Displays all open LCM proposals in chronological order.
.DESCRIPTION
    Module: tools/Get-OpenProposals.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.0.0
    Date: 2026-08-20
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$All,

    [Parameter(Mandatory = $false)]
    [string]$State,

    [Parameter(Mandatory = $false)]
    [string]$OriginRepo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
Import-Module $modulePath -Force

$proposals = if ($All) {
    Get-WorkspaceProposals -State $State -OriginRepo $OriginRepo
} else {
    Get-WorkspaceProposals -OpenOnly -State $State -OriginRepo $OriginRepo
}

Format-ProposalsTable -Proposals $proposals
