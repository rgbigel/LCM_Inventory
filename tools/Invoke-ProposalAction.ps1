<#
.SYNOPSIS
    Executes proposal batch actions ('do', 'delete', 'defer', 'complete', 'suggest') and sets review granularity.
.DESCRIPTION
    Module: tools/Invoke-ProposalAction.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 1.1.0
    Date: 2026-09-10
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Action to perform on proposals or governance settings')]
    [ValidateSet('do', 'delete', 'defer', 'deferred', 'complete', 'completed', 'suggest', 'suggested', 'granularity', 'mode', 'list', 'progress', 'state', 'reject', 'rejected', 'approve', 'approved', 'bug', 'push', 'pushed', 'verify', 'priority', 'commit', 'committed', 'proceed', 'regression', 'regressions', 'check-regressions', 'generate-regression', 'workon', 'work-on', 'app', 'new-app', 'apps', 'list-apps', 'sync-apps', 'catalog', 'split-docs', 'splitdocs', 'doc', 'docs', 'show-doc', 'purge-bundle')]
    [string]$Action = 'list',

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Target proposal expression (e.g. all, #1, 105, 100-105)')]
    [string]$TargetExpression = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Additional details or notes for proposal transition')]
    [string]$Details = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Target plan state to set (bug, suggested, approved, deferred, rejected, completed, pushed)')]
    [ValidateSet('bug', 'suggested', 'approved', 'deferred', 'deleted', 'completed', 'rejected', 'pushed', 'processed')]
    [string]$State,

    [Parameter(Mandatory = $false, HelpMessage = 'Target implementation progress state to set')]
    [ValidateSet('undecided', 'queued', 'in_progress', 'verification', 'committed', 'completed', 'pushed', 'blocked', 'failed')]
    [string]$ProgressState,

    [Parameter(Mandatory = $false, HelpMessage = 'Priority level to assign (C=Critical, H=High, M=Medium, L=Low, D=Deferred)')]
    [ValidateSet('C', 'H', 'M', 'L', 'D')]
    [string]$Priority,

    [Parameter(Mandatory = $false, HelpMessage = 'Target repository for child regression proposal or App context')]
    [Alias('Repo', 'OriginRepo')]
    [string]$TargetRepo = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Reason or trigger description for child regression proposal')]
    [string]$Reason = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Max regression depth limit (default: 2)')]
    [int]$MaxRegressionDepth = 2,

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
    Write-Host "  pwsh LCM_Inventory/tools/Invoke-ProposalAction.ps1 [[-Action] <str>] [[-TargetExpression] <str>] [-Details <str>] [-ProgressState <str>] [-Priority <str>] [-Granularity <str>] [-Mode <str>] [-h]"
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

switch -Regex ($Action) {
    '^granularity$' {
        if ($TargetExpression -in @('coarse', 'tight')) {
            Set-ReviewGranularity -Granularity $TargetExpression | Out-Null
        } else {
            Write-Host "Current Review Granularity: $(Get-ReviewGranularity)" -ForegroundColor Cyan
        }
        break
    }
    '^mode$' {
        if ($TargetExpression -in @('active', 'paused')) {
            Set-LCMMode -Mode $TargetExpression | Out-Null
        } else {
            Write-Host "Current LCM Mode: $(Get-LCMMode)" -ForegroundColor Cyan
        }
        break
    }
    '^list$' {
        Format-ProposalsTable
        break
    }
    '^state$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression (e.g. '78', 'all') is required for action 'state'."
        }
        if ([string]::IsNullOrWhiteSpace($State)) {
            throw "-State (e.g. 'rejected', 'approved', 'bug', 'suggested', 'deferred', 'completed', 'pushed') is required."
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        $updated = @()
        foreach ($id in $targetIds) {
            $p = Set-WorkspaceProposalState -Id $id -State $State -Details $Details
            if ($p) { $updated += $p }
        }
        Write-Host "`nUpdated Proposal(s) Plan State:" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
        break
    }
    '^progress$' {
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
        break
    }
    '^verify$' {
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
        break
    }
    '^(commit|committed)$' {
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
        break
    }
    '^proceed$' {
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
        break
    }
    '^priority$' {
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
        break
    }
    '^(regression|regressions|check-regressions)$' {
        $store = Get-ProposalStore
        $allProps = @($store.proposals)
        $targets = if ($TargetExpression) {
            $ids = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
            @($allProps | Where-Object { $ids -contains $_.id })
        } else {
            @($allProps | Where-Object { $_.state -in @('bug', 'suggested', 'approved', 'processed') })
        }

        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host " LCM AUTOMATED REGRESSION & COLLISION SCAN REPORT" -ForegroundColor Cyan
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $regCount = 0
        foreach ($p in $targets) {
            $res = Test-RegressionTrigger -Proposal $p -AllProposals $allProps
            if ($res.RegressionNeeded) {
                $regCount++
                $prio = if ($p.priority) { $p.priority } else { 'M' }
                $depth = if ($p.PSObject.Properties['regression_depth'] -and $p.regression_depth) { $p.regression_depth } else { 0 }
                Write-Host "  [!] #$($p.id) [$($p.origin_repo)] $($p.title) (Prio: $prio, Depth: $depth)" -ForegroundColor Yellow
                foreach ($t in $res.RegressionTriggers) {
                    Write-Host "     -> Trigger: $t" -ForegroundColor Gray
                }
            }
        }

        if ($regCount -eq 0) {
            Write-Host "  [OK] No active proposals require downstream regression." -ForegroundColor Green
        } else {
            Write-Host "`n  Total flagged for regression: $regCount proposal(s)." -ForegroundColor Yellow
        }
        Write-Host "==========================================================================" -ForegroundColor Cyan
        break
    }
    '^generate-regression$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression (Parent Proposal ID, e.g. '135') is required for 'generate-regression'."
        }
        if ([string]::IsNullOrWhiteSpace($TargetRepo)) {
            throw "-TargetRepo is required for 'generate-regression'."
        }
        if ([string]::IsNullOrWhiteSpace($Reason)) {
            $Reason = if ($Details) { $Details } else { 'Downstream component interface dependency' }
        }

        $parentId = [int](Resolve-ProposalIdExpression -Expression $TargetExpression)[0]
        $child = New-ChildRegressionProposal -ParentProposalId $parentId -TargetRepo $TargetRepo -Reason $Reason -MaxDepth $MaxRegressionDepth

        Write-Host "`nGenerated Child Regression Proposal:" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals @($child)
        break
    }
    '^(workon|work-on)$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            $ctx = Get-ActiveAppContext
            if ($ctx -and $ctx.app_id -notin @('Master', 'Architecture', 'Base')) {
                $disp = if ($ctx.app_title) { " - $($ctx.app_title)" } else { '' }
                Write-Host "Current Active Focus: $($ctx.app_id)$disp [$($ctx.repo)] (Set at: $($ctx.set_at))" -ForegroundColor Cyan
            } else {
                $repo = if ($ctx -and $ctx.repo) { $ctx.repo } else { 'Governing All Apps' }
                Write-Host "Current Active Focus: 🏛️ Master Architecture (Governing All Apps) [$repo]" -ForegroundColor Cyan
            }
        } else {
            $res = Set-ActiveAppContext -Context $TargetExpression -Repo $TargetRepo -Details $Details
        }
        break
    }
    '^(app|new-app)$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression (App Title, e.g. 'Realtime Log Streamer') is required for 'app'."
        }
        $targetR = if ($TargetRepo) { $TargetRepo } else { 'LCM_AI' }
        $res = New-LcmApp -Title $TargetExpression -Repo $targetR -Description $Details
        break
    }
    '^(apps|list-apps)$' {
        Format-LcmAppsTable
        break
    }
    '^(sync-apps|catalog)$' {
        $res = Sync-LcmAppCatalog -Repo $TargetRepo
        break
    }
    '^(split-docs|splitdocs)$' {
        $targetR = if ($TargetRepo) { $TargetRepo } elseif ($TargetExpression) { $TargetExpression } else { throw "Target repository is required for 'split-docs' (specify -TargetRepo <Repo> or pass as first argument)." }
        $res = Split-LcmAppDocs -Repo $targetR
        break
    }
    '^(doc|docs|show-doc)$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression (Proposal ID, e.g. '162') is required for 'docs'."
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        $docType = if ($State) { $State } elseif ($Details) { $Details } else { 'All' }
        foreach ($id in $targetIds) {
            $docResult = Get-LcmProposalDocument -Id $id -DocumentType $docType
            if ($docType -eq 'All') {
                Write-Host "==========================================================================" -ForegroundColor Cyan
                Write-Host (" PROPOSAL #{0} DOCUMENTS (CRP-162 DUAL-MODE RESOLVER)" -f $id) -ForegroundColor Green
                Write-Host "==========================================================================" -ForegroundColor Cyan
                foreach ($k in $docResult.Keys) {
                    $item = $docResult[$k]
                    Write-Host ("`n--- [{0}] {1} (Source: {2} | Path: {3}) ---" -f $item.DocumentType, $item.FileName, $item.SourceMode, $item.ResolvedPath) -ForegroundColor Yellow
                    Write-Host $item.Content
                }
            } else {
                Write-Host ("`n--- [{0}] {1} (Source: {2} | Path: {3}) ---" -f $docResult.DocumentType, $docResult.FileName, $docResult.SourceMode, $docResult.ResolvedPath) -ForegroundColor Yellow
                Write-Host $docResult.Content
            }
        }
        break
    }
    '^(purge-bundle)$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression (Proposal ID, e.g. '162') is required for 'purge-bundle'."
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        foreach ($id in $targetIds) {
            $res = Purge-LcmPushedProposalBundle -Id $id -CommitSha $Details
        }
        break
    }
    default {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression (e.g. '1-3', 'all', '1,2') is required for action '$Action'."
        }
        $updated = Invoke-ProposalBatchAction -Action $Action -TargetExpression $TargetExpression -Details $Details
        Write-Host "`nUpdated Proposal(s):" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
        break
    }
}
