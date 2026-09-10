<#
.SYNOPSIS
    Executes proposal batch actions ('do', 'delete', 'defer', 'complete', 'suggest') and sets review granularity.
.DESCRIPTION
    Module: tools/Invoke-ProposalAction.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.1.0
    Date: 2026-09-10
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Action to perform on proposals or governance settings')]
    [ValidateSet('do', 'delete', 'defer', 'complete', 'suggest', 'granularity', 'mode', 'list', 'progress', 'verify', 'priority', 'commit', 'committed', 'proceed')]
    [string]$Action = 'list',

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Target proposal expression (e.g. all, #1, 105, 100-105)')]
    [string]$TargetExpression = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Additional details or notes for proposal transition')]
    [string]$Details = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Target implementation progress state to set')]
    [ValidateSet('undecided', 'queued', 'in_progress', 'verification', 'committed', 'completed', 'pushed', 'blocked', 'failed')]
    [string]$ProgressState,

    [Parameter(Mandatory = $false, HelpMessage = 'Priority level to assign (C=Critical, H=High, M=Medium, L=Low, D=Deferred)')]
    [ValidateSet('C', 'H', 'M', 'L', 'D')]
    [string]$Priority,

    [Parameter(Mandatory = $false, HelpMessage = 'Set review granularity: coarse (single BC5 review) or tight (BC5 review per proposal)')]
    [ValidateSet('coarse', 'tight')]
    [string]$Granularity,

    [Parameter(Mandatory = $false, HelpMessage = 'Set LCM governance mode: active (proposal-first) or paused')]
    [ValidateSet('active', 'paused')]
    [string]$Mode,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " INVOKE PROPOSAL ACTION (Invoke-ProposalAction)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Executes proposal batch actions ('do', 'delete', 'defer', etc.) and configures review granularity."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh Workspace_Inventory/tools/Invoke-ProposalAction.ps1 [[-Action] <str>] [[-TargetExpression] <str>] [-Details <str>] [-ProgressState <str>] [-Priority <str>] [-Granularity <str>] [-Mode <str>] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Action           : Action to perform (do, delete, defer, complete, suggest, granularity, mode, list, etc.)"
    Write-Host "  -TargetExpression : Target proposal expression (e.g. all, #1, 105, 100-105)"
    Write-Host "  -Details          : Additional details or notes for proposal transition"
    Write-Host "  -ProgressState    : Target progress state (undecided, queued, in_progress, completed, pushed, etc.)"
    Write-Host "  -Priority         : Priority level (C, H, M, L, D)"
    Write-Host "  -Granularity      : Review granularity: coarse or tight"
    Write-Host "  -Mode             : Governance mode: active or paused"
    Write-Host "  -Help (-h, -?)    : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
Import-Module $modulePath -Force

if ($Granularity) {
    Set-ReviewGranularity -Granularity $Granularity | Out-Null
}

if ($Mode) {
    Set-LCMMode -Mode $Mode | Out-Null
}

switch ($Action) {
    'granularity' {
        if ($TargetExpression -in @('coarse', 'tight')) {
            Set-ReviewGranularity -Granularity $TargetExpression | Out-Null
        } else {
            Write-Host "Current Review Granularity: $(Get-ReviewGranularity)" -ForegroundColor Cyan
        }
    }
    'mode' {
        if ($TargetExpression -in @('active', 'paused')) {
            Set-LCMMode -Mode $TargetExpression | Out-Null
        } else {
            Write-Host "Current LCM Mode: $(Get-LCMMode)" -ForegroundColor Cyan
        }
    }
    'list' {
        Format-ProposalsTable
    }
    'progress' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression (e.g. '78', 'all') is required for action 'progress'."
        }
        if ([string]::IsNullOrWhiteSpace($ProgressState)) {
            throw "-ProgressState (e.g. 'verification', 'completed', 'in_progress') is required."
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        $updated = @()
        foreach ($id in $targetIds) {
            $p = Set-WorkspaceProposalProgress -Id $id -ProgressState $ProgressState -Details $Details
            if ($p) { $updated += $p }
        }
        Write-Host "`nUpdated Proposal(s) Progress:" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
    }
    'verify' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression is required for action 'verify'."
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        $updated = @()
        foreach ($id in $targetIds) {
            $p = Set-WorkspaceProposalProgress -Id $id -ProgressState 'verification' -Details $Details
            if ($p) { $updated += $p }
        }
        Write-Host "`nUpdated Proposal(s) to Verification:" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
    }
    { $_ -in @('commit', 'committed') } {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression is required for action 'commit'."
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        $updated = @()
        foreach ($id in $targetIds) {
            $p = Set-WorkspaceProposalProgress -Id $id -ProgressState 'committed' -Details $Details
            if ($p) { $updated += $p }
        }
        Write-Host "`nUpdated Proposal(s) to Committed:" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
    }
    'proceed' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression is required for action 'proceed'."
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        $updated = @()
        $store = Get-ProposalStore
        foreach ($id in $targetIds) {
            $existing = $store.proposals | Where-Object { $_.id -eq $id } | Select-Object -First 1
            $targetProg = if ($ProgressState) {
                $ProgressState
            } else {
                $cur = if ($existing -and $existing.progress_state) { $existing.progress_state } else { 'undecided' }
                switch ($cur) {
                    'undecided'    { 'in_progress' }
                    'queued'       { 'in_progress' }
                    'in_progress'  { 'verification' }
                    'verification' { 'committed' }
                    'committed'    { 'completed' }
                    default        { 'verification' }
                }
            }
            if ($targetProg -eq 'completed') {
                Set-WorkspaceProposalState -Id $id -State 'completed' -Details $Details | Out-Null
            } elseif ($existing.state -eq 'suggested') {
                Set-WorkspaceProposalState -Id $id -State 'processed' -Details $Details | Out-Null
            }
            $p = Set-WorkspaceProposalProgress -Id $id -ProgressState $targetProg -Details $Details
            if ($p) { $updated += $p }
        }
        Write-Host "`nProceeded Proposal(s):" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
    }
    'priority' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression (e.g. '79', 'all') is required for action 'priority'."
        }
        if ([string]::IsNullOrWhiteSpace($Priority)) {
            throw "-Priority (one of 'C', 'H', 'M', 'L', 'D') is required."
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        $updated = @()
        foreach ($id in $targetIds) {
            $p = Set-WorkspaceProposalPriority -Id $id -Priority $Priority -Details $Details
            if ($p) { $updated += $p }
        }
        Write-Host "`nUpdated Proposal(s) Priority:" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
    }
    default {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression (e.g. '1-3', 'all', '1,2') is required for action '$Action'."
        }
        $updated = Invoke-ProposalBatchAction -Action $Action -TargetExpression $TargetExpression -Details $Details
        Write-Host "`nUpdated Proposal(s):" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
    }
}
