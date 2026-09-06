<#
.SYNOPSIS
    Executes proposal batch actions ('do', 'delete', 'defer', 'complete', 'suggest') and sets review granularity.
.DESCRIPTION
    Module: tools/Invoke-ProposalAction.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.0.0
    Date: 2026-08-20
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('do', 'delete', 'defer', 'complete', 'suggest', 'granularity', 'mode', 'list', 'progress', 'verify', 'priority', 'commit', 'committed', 'proceed')]
    [string]$Action = 'list',

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$TargetExpression = '',

    [Parameter(Mandatory = $false)]
    [string]$Details = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('undecided', 'queued', 'in_progress', 'verification', 'committed', 'completed', 'pushed', 'blocked', 'failed')]
    [string]$ProgressState,

    [Parameter(Mandatory = $false)]
    [ValidateSet('C', 'H', 'M', 'L', 'D')]
    [string]$Priority,

    [Parameter(Mandatory = $false)]
    [ValidateSet('coarse', 'tight')]
    [string]$Granularity,

    [Parameter(Mandatory = $false)]
    [ValidateSet('active', 'paused')]
    [string]$Mode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
