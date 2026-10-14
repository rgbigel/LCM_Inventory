<#
.SYNOPSIS
    Executes proposal lifecycle actions and configures lifecycle governance settings.
.DESCRIPTION
    Module: tools/Invoke-ProposalAction.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 10.0.0
    Date: 2026-10-13
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Action to perform on proposals or governance settings')]
    [ValidateSet('do', 'delete', 'defer', 'deferred', 'complete', 'completed', 'suggest', 'suggested', 'granularity', 'mode', 'testing-mode', 'testing', 'minimal-tests', 'doit-mode', 'list', 'progress', 'state', 'reject', 'rejected', 'approve', 'approved', 'bug', 'push', 'pushed', 'verify', 'bcr', 'cohort', 'priority', 'commit', 'committed', 'proceed', 'regression', 'regressions', 'check-regressions', 'generate-regression', 'workon', 'work-on', 'app', 'new-app', 'apps', 'list-apps', 'sync-apps', 'catalog', 'split-docs', 'splitdocs', 'doc', 'docs', 'show-doc', 'purge-bundle', 'hold', 'held', 'resume', 'continue', 'withdraw', 'retire', 'supersede', 'reopen', 'reinstate', 'reset', 'analyze', 'implement', 'operating-mode', 'analysis-mode', 'trip-breaker', 'circuit-breaker', 'reset-breaker')]
    [string]$Action = 'list',

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Target proposal expression (e.g. all, #1, 105, 100-105)')]
    [string]$TargetExpression = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Additional details or notes for proposal transition')]
    [string]$Details = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Concrete correction requests for reinstate; when omitted, reinstate returns the CRP to suggested')]
    [string]$Changes = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Target plan state to set (bug, suggested, approved, deferred, rejected, completed, pushed, held)')]
    [ValidateSet('bug', 'suggested', 'approved', 'deferred', 'deleted', 'completed', 'completed [minimal-tests]', 'rejected', 'pushed', 'processed', 'held')]
    [string]$State,

    [Parameter(Mandatory = $false, HelpMessage = 'Target implementation progress state to set')]
    [ValidateSet('undecided', 'queued', 'in_progress', 'verification', 'committed', 'completed', 'pushed', 'blocked', 'failed', 'deferred')]
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

    [Parameter(Mandatory = $false, HelpMessage = 'Set LCM testing mode: active (syntax/unit) or paused (deferred deep testing)')]
    [ValidateSet('active', 'paused')]
    [string]$TestingMode,

    [Parameter(Mandatory = $false, HelpMessage = 'Set a selected proposal switch to active or paused')]
    [ValidateSet('active', 'paused')]
    [string]$SwitchState,

    [Parameter(Mandatory = $false, HelpMessage = 'Single-cycle minimal testing scope: fast syntax and AST validation only')]
    [switch]$MinimalTests,

    [Parameter(Mandatory = $false, HelpMessage = 'Authorized exception to interactive visual-review confirmation only; does not waive lifecycle or preflight checks')]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = 'Emergency quality-check deferral; a single CRP target is reclassified as BUG, while a multi-target cohort requires a BUG; requires -Details and ends at BCR')]
    [switch]$Immediately,

    [Parameter(Mandatory = $false, HelpMessage = 'Resolve and report the BCR cohort without launching review or changing lifecycle state')]
    [switch]$Preview,

    [Parameter(Mandatory = $false, HelpMessage = 'Confirm an omitted or broadened BCR cohort after its resolution has been presented')]
    [switch]$Confirm,

    [Parameter(Mandatory = $false, HelpMessage = 'Baseline commit used for BCR cohort review')]
    [string]$BaseCommit = 'HEAD',

    [Parameter(Mandatory = $false, HelpMessage = 'Cohort action: create, add, remove, hold, reopen, or close')]
    [ValidateSet('create', 'add', 'remove', 'hold', 'reopen', 'close')]
    [string]$CohortAction,

    [Parameter(Mandatory = $false, HelpMessage = 'Declared cohort ID (COH-<prime proposal ID>)')]
    [ValidatePattern('^COH-\d+$')]
    [string]$CohortId = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Successor proposal ID required by the supersede action')]
    [int]$SuccessorId,

    [Parameter(Mandatory = $false, HelpMessage = 'Include unreviewed live paths during cohort completion')]
    [switch]$IncludeUnreviewed,

    [Parameter(Mandatory = $false, HelpMessage = 'Persisted cross-repository review-obligation ledger entry to satisfy through the normal BCR action')]
    [string]$ReviewObligationId = '',

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
    Write-Host "  Executes proposal lifecycle actions and configures lifecycle governance settings."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Invoke-ProposalAction.ps1 [[-Action] <str>] [[-TargetExpression] <str>] [-CohortAction <str>] [-CohortId <COH-nnn>] [-Preview] [-Confirm] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Action           : Action to perform (including bcr or cohort)."
    Write-Host "  -TargetExpression : Target proposal expression (e.g. all, #1, 105, 100-105)"
    Write-Host "  -Details          : Additional details or notes for proposal transition"
    Write-Host "  -ProgressState    : Target progress state (undecided, queued, in_progress, completed, pushed, etc.)"
    Write-Host "  -Priority         : Priority level (C, H, M, L, D)"
    Write-Host "  -Granularity      : Review granularity: coarse or tight"
    Write-Host "  -Force            : Visual-review confirmation exception only; lifecycle and preflight rules still apply"
    Write-Host "  -Immediately      : Emergency quality deferral; one CRP target becomes BUG, multi-target cohort requires BUG"
    Write-Host "  -CohortAction     : Cohort action: create, add, remove, hold, reopen, or close"
    Write-Host "  -CohortId         : Declared cohort identifier, COH-<prime proposal ID>"
    Write-Host "  -Preview          : Resolve and report a BCR cohort without launching review"
    Write-Host "  -Confirm          : Confirm broadened BCR scope or cross-repository cohort membership"
    Write-Host "  -Mode             : Governance mode: active or paused"
    Write-Host "  -SwitchState      : Proposal switch state for minimal-tests or doit-mode: active or paused"
    Write-Host "  -Help (-h, -?)    : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
Import-Module $modulePath -Force

$analysisModulePath = Join-Path $PSScriptRoot '..\modules\AnalysisGovernance.psm1'
Import-Module $analysisModulePath -Force

function Convert-LegacyProposalStateToLifecycleState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('state', 'progress')]
        [string]$Source
    )

    $map = if ($Source -eq 'state') {
        @{
            bug = 'in_progress'; suggested = 'suggested'; approved = 'in_progress'; processed = 'in_progress'
            deferred = 'held'; deleted = 'withdrawn'; completed = 'completed'; 'completed [minimal-tests]' = 'completed'
            rejected = 'rejected'; pushed = 'pushed'; held = 'held'
        }
    } else {
        @{
            undecided = 'suggested'; queued = 'in_progress'; in_progress = 'in_progress'; verification = 'verified'
            committed = 'completed'; completed = 'completed'; pushed = 'pushed'; blocked = 'held'; failed = 'held'; deferred = 'held'
        }
    }

    if (-not $map.ContainsKey($Value)) {
        throw "Legacy $Source value '$Value' has no lifecycle transition equivalent."
    }
    return $map[$Value]
}

# Assert implementation allowed for modifying actions unless -Force is specified
if ($Action -in @('do', 'proceed', 'commit', 'verify') -and -not $Force) {
    Assert-LcmImplementationAllowed
}

if ($Granularity) {
    Set-ReviewGranularity -Granularity $Granularity | Out-Null
}

if ($Mode) {
    Set-LCMMode -Mode $Mode | Out-Null
}

if ($TestingMode) {
    Set-TestingMode -Mode $TestingMode | Out-Null
}

if ($Immediately) {
    if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
        throw '-Immediately requires an explicit target. A single CRP target is reclassified as BUG; a multi-proposal cohort must contain a BUG.'
    }
    Enable-LcmImmediateBugRecovery -Ids @(Resolve-ProposalIdExpression -Expression $TargetExpression) -Reason $Details
}

if ($TargetExpression -match '^COH-\d+$' -and $Action -in @('do', 'proceed', 'verify', 'push', 'hold', 'reopen', 'withdraw')) {
    $updated = @(Invoke-LcmCohortLifecycleAction -CohortId $TargetExpression -Action $Action -Details $Details)
    $memberIds = @($updated | Select-Object -ExpandProperty id)
    Write-Host "`nApplied '$Action' atomically to cohort ${TargetExpression}: $($memberIds.Count) member(s) affected (#$($memberIds -join ', #'))." -ForegroundColor Cyan
    Format-ProposalsTable -Proposals $updated
    return
}

switch -Regex ($Action) {
    '^analyze$' {
        Set-LcmOperatingMode -Mode 'READ_ONLY_ANALYSIS' | Out-Null
        Write-Host "Operating Mode switched to: READ_ONLY_ANALYSIS per RULE-ANA-001" -ForegroundColor Cyan
        break
    }
    '^implement$' {
        Set-LcmOperatingMode -Mode 'GOVERNED_IMPLEMENTATION' | Out-Null
        Write-Host "Operating Mode switched to: GOVERNED_IMPLEMENTATION per RULE-ANA-004" -ForegroundColor Green
        break
    }
    '^(operating-mode|analysis-mode)$' {
        if ($TargetExpression -in @('READ_ONLY_ANALYSIS', 'GOVERNED_IMPLEMENTATION', 'CIRCUIT_BREAKER_HALT')) {
            Set-LcmOperatingMode -Mode $TargetExpression | Out-Null
        }
        $analysisState = Get-LcmAnalysisState
        Write-Host "LCM Operating Mode : $($analysisState.operating_mode)" -ForegroundColor Cyan
        Write-Host "Active Gate        : $($analysisState.active_gate)" -ForegroundColor Cyan
        Write-Host "Search Radius      : $($analysisState.search_radius)" -ForegroundColor Cyan
        $cbColor = if ($analysisState.circuit_breaker) { 'Red' } else { 'Green' }
        Write-Host "Circuit Breaker    : $($analysisState.circuit_breaker)" -ForegroundColor $cbColor
        break
    }
    '^(trip-breaker|circuit-breaker)$' {
        $reason = if ($Details) { $Details } else { 'Manual or execution block tripped circuit breaker' }
        Invoke-LcmCircuitBreaker -Reason $reason | Out-Null
        Write-Host "Circuit Breaker Tripped! Mode is now: CIRCUIT_BREAKER_HALT" -ForegroundColor Red
        break
    }
    '^reset-breaker$' {
        Reset-LcmCircuitBreaker | Out-Null
        Write-Host "Circuit Breaker Reset. Mode returned to: READ_ONLY_ANALYSIS" -ForegroundColor Yellow
        break
    }
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
    '^(testing-mode|testing)$' {
        if ($TestingMode) {
            Set-TestingMode -Mode $TestingMode | Out-Null
        } elseif ($TargetExpression -in @('active', 'paused')) {
            Set-TestingMode -Mode $TargetExpression | Out-Null
        } else {
            Write-Host "Current Testing Mode: $(Get-TestingMode)" -ForegroundColor Cyan
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
        $lifecycleState = Convert-LegacyProposalStateToLifecycleState -Value $State -Source state
        foreach ($id in $targetIds) {
            $p = Move-LcmProposalLifecycleState -Id $id -State $lifecycleState -Details $Details
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
        $lifecycleState = Convert-LegacyProposalStateToLifecycleState -Value $ProgressState -Source progress
        foreach ($id in $targetIds) {
            $p = Move-LcmProposalLifecycleState -Id $id -State $lifecycleState -Details $Details
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
            $p = Move-LcmProposalLifecycleState -Id $id -State 'verified' -Details $Details
            if ($p) { $updated += $p }
        }
        Write-Host "`nUpdated Proposal(s) to Verification:" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
        break
    }
    '^minimal-tests$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression is required for action 'minimal-tests'."
        }
        if ([string]::IsNullOrWhiteSpace($SwitchState)) {
            throw "-SwitchState (active or paused) is required for action 'minimal-tests'."
        }
        $enabled = $SwitchState -eq 'active'
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        $store = Get-ProposalStore
        $updated = @()
        foreach ($id in $targetIds) {
            $proposal = $store.proposals | Where-Object { $_.id -eq $id } | Select-Object -First 1
            if ($null -eq $proposal) { throw "Proposal #$id was not found." }
            $proposal | Add-Member -NotePropertyName 'minimal_tests' -NotePropertyValue $enabled -Force
            $proposal | Add-Member -NotePropertyName 'test_scope' -NotePropertyValue $(if ($enabled) { 'minimal' } else { 'full' }) -Force
            $updated += $proposal
        }
        Set-ProposalStore -Store $store
        Write-Host "`nUpdated Proposal(s) Minimal Tests switch:" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
        break
    }
    '^doit-mode$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression is required for action 'doit-mode'."
        }
        if ([string]::IsNullOrWhiteSpace($SwitchState)) {
            throw "-SwitchState (active or paused) is required for action 'doit-mode'."
        }
        $enabled = $SwitchState -eq 'active'
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        $store = Get-ProposalStore
        $updated = @()
        foreach ($id in $targetIds) {
            $proposal = $store.proposals | Where-Object { $_.id -eq $id } | Select-Object -First 1
            if ($null -eq $proposal) { throw "Proposal #$id was not found." }
            $isBug = ($proposal.crp_id -like 'BUG-*') -or ($proposal.cr_id -like 'BUG-*')
            if ($isBug -and -not $enabled) {
                throw "Proposal #$id is a BUG report and must retain -DOIT mode."
            }
            $proposal | Add-Member -NotePropertyName 'flow_mode' -NotePropertyValue $(if ($enabled) { 'doit' } else { 'standard' }) -Force
            $proposal | Add-Member -NotePropertyName 'always_proceed' -NotePropertyValue $enabled -Force
            $updated += $proposal
        }
        Set-ProposalStore -Store $store
        Write-Host "`nUpdated Proposal(s) -DOIT switch:" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
        break
    }
    '^cohort$' {
        if ([string]::IsNullOrWhiteSpace($CohortAction)) {
            throw "-CohortAction (create, add, remove, hold, reopen, or close) is required for action 'cohort'."
        }
        $ids = if ([string]::IsNullOrWhiteSpace($TargetExpression)) { @() } else { @(Resolve-ProposalIdExpression -Expression $TargetExpression) }
        $cohortArgs = @{
            Action = $CohortAction
            ProposalIds = $ids
            CohortId = $CohortId
        }
        if ($Confirm) { $cohortArgs.AllowCrossRepository = $true }
        $cohort = Set-LcmReviewCohort @cohortArgs
        Write-Host "Cohort $($cohort.id) is $($cohort.state): #$($cohort.proposal_ids -join ', #')" -ForegroundColor Green
        break
    }
    '^retire$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression is required for action 'retire'."
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        if ($targetIds.Count -ne 1) {
            throw "Retire requires exactly one CRP target."
        }
        $updated = Set-LcmProposalRetirement -Id $targetIds[0] -Details $Details
        Format-ProposalsTable -Proposals @($updated)
        break
    }
    '^supersede$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression) -or $SuccessorId -le 0) {
            throw "Supersede requires one CRP target and -SuccessorId <proposal ID>."
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        if ($targetIds.Count -ne 1) {
            throw "Supersede requires exactly one CRP target."
        }
        $updated = Set-LcmProposalSupersession -Id $targetIds[0] -SuccessorId $SuccessorId -Details $Details
        Format-ProposalsTable -Proposals @($updated)
        break
    }
    '^bcr$' {
        if (-not [string]::IsNullOrWhiteSpace($ReviewObligationId)) {
            $store = Get-ProposalStore
            $obligation = @($store.review_obligation_ledger.entries | Where-Object {
                [string]$_.id -eq $ReviewObligationId -and [string]$_.status -ne 'completed'
            }) | Select-Object -First 1
            if ($null -eq $obligation) {
                throw "No open review-obligation ledger entry matches '$ReviewObligationId'."
            }
            $proposal = @($store.proposals | Where-Object { [int]$_.id -eq [int]$obligation.proposal_id })[0]
            if ($null -eq $proposal) {
                throw "Review-obligation ledger entry '$ReviewObligationId' references a missing proposal."
            }
            $identity = if ($proposal.crp_id) { [string]$proposal.crp_id } elseif ($proposal.cr_id) { [string]$proposal.cr_id } else { "CRP-$($proposal.id)" }
            $isolatedReviewIdentity = "${identity}_$($obligation.repository)"
            & (Join-Path $PSScriptRoot 'Invoke-BeyondCompareReview.ps1') -RepositoryName $obligation.repository -CRP $identity -ReviewIdentity $isolatedReviewIdentity -BaseCommit $BaseCommit
            Write-Host "Opened normal BCR for review-obligation ledger entry '$ReviewObligationId' as '$isolatedReviewIdentity'." -ForegroundColor Cyan
            break
        }
        $resolution = Get-LcmReviewCohortResolution -Scope $TargetExpression -BaseCommit $BaseCommit
        $synchronization = $null
        if (-not [string]::IsNullOrWhiteSpace($resolution.DeclaredCohortId)) {
            $synchronization = Sync-LcmCohortGateState -CohortId $resolution.DeclaredCohortId -Gate BCR -Details $Details
            Write-Host ("Cohort gate synchronization for {0}: {1} synchronized, {2} already aligned, {3} stopped." -f `
                $resolution.DeclaredCohortId, $synchronization.SynchronizedMemberIds.Count, `
                $synchronization.NoOpMemberIds.Count, $synchronization.StoppedMembers.Count) -ForegroundColor Cyan
            $resolution = Get-LcmReviewCohortResolution -Scope $TargetExpression -BaseCommit $BaseCommit
        }
        $receiptPath = Save-LcmReviewCohortReceipt -Resolution $resolution
        Write-Host "`nResolved BCR Cohort ($($resolution.ResolutionKind)):" -ForegroundColor Cyan
        $resolution.Members | Format-Table Identity, Repository, State, Classification -AutoSize
        Write-Host "Resolution receipt: $receiptPath" -ForegroundColor DarkGray

        if ($Preview) {
            break
        }
        if ($resolution.NeedsSelection) {
            throw "BCR cohort requires explicit selection: $($resolution.BroadeningReasons -join '; ')."
        }
        if ($resolution.RequiresConfirmation -and -not $Confirm) {
            throw "BCR cohort requires confirmation: $($resolution.BroadeningReasons -join '; '). Re-run with -Confirm after reviewing the receipt."
        }

        $updated = @()
        $reviewReady = @($resolution.Members | Where-Object { $_.Classification -eq 'review_ready' })
        $alreadyInReview = @($resolution.Members | Where-Object { $_.Classification -eq 'already_in_review' })
        $granularity = Get-ReviewGranularity

        foreach ($reviewGroup in @($reviewReady | Group-Object Repository)) {
            $groupMembers = @($reviewGroup.Group)
            for ($index = 0; $index -lt $groupMembers.Count; $index++) {
                $member = $groupMembers[$index]
                $id = $member.Id
                $launchReview = $granularity -eq 'tight' -or $index -eq 0
                $reviewArgs = @{
                    RepositoryName = $member.Repository
                    CRP = $member.Identity
                    BaseCommit = $BaseCommit
                }
                if (-not $launchReview) { $reviewArgs.NoLaunch = $true }
                & (Join-Path $PSScriptRoot 'Invoke-BeyondCompareReview.ps1') @reviewArgs
            }
        }

        foreach ($member in $alreadyInReview) {
            & (Join-Path $PSScriptRoot 'Invoke-BeyondCompareReview.ps1') -RepositoryName $member.Repository -CRP $member.Identity -BaseCommit $BaseCommit
        }

        $store = Get-ProposalStore
        foreach ($member in $reviewReady) {
            $id = $member.Id
            $p = Move-LcmProposalLifecycleState -Id $id -State 'in_review' -Details $Details -Store $store -SkipPersist `
                -CohortId $resolution.DeclaredCohortId -Gate BCR -SynchronizationOutcome synchronized
            $reviewedProposal = @($store.proposals | Where-Object { $_.id -eq $id })[0]
            $reviewedProposal | Add-Member -NotePropertyName 'bcr_initiated_at' -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
            $reviewedProposal | Add-Member -NotePropertyName 'bcr_disposition' -NotePropertyValue $null -Force
            $reviewedProposal | Add-Member -NotePropertyName 'bcr_scope' -NotePropertyValue $(if ($resolution.DeclaredCohortId) { $resolution.DeclaredCohortId } else { $member.Identity }) -Force
            $updated += $p
        }
        if ($reviewReady.Count -gt 0) {
            Set-ProposalStore -Store $store
        }

        foreach ($id in @($updated | Select-Object -ExpandProperty id)) {
            $store = Get-ProposalStore
            $proposal = @($store.proposals | Where-Object { $_.id -eq $id })[0]
            if ($proposal.PSObject.Properties['quality_checks_deferred'] -and $proposal.quality_checks_deferred) {
                $proposal.quality_checks_deferred = $false
                $proposal | Add-Member -NotePropertyName 'immediate_recovery_ended_at' -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
                Set-ProposalStore -Store $store
            }
        }
        Write-Host "`nUpdated Proposal(s) to Review Pending:" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
        break
    }
    '^(commit|committed|complete|completed)$' {
        if ([string]::IsNullOrWhiteSpace($TargetExpression)) {
            throw "TargetExpression is required for action '$Action'."
        }
        $targetCohortId = $null
        if ($TargetExpression -match '^COH-\d+$') {
            $targetCohortId = $TargetExpression
        } else {
            $store = Get-ProposalStore
            $matchingCohorts = @($store.review_cohorts | Where-Object { $_.state -eq 'open' -and ($TargetExpression -eq $_.id -or $TargetExpression -in $_.repositories) })
            if ($matchingCohorts.Count -eq 1) {
                $targetCohortId = $matchingCohorts[0].id
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($targetCohortId)) {
            $cohortArgs = @{
                CohortId = $targetCohortId
                Notes = $Details
            }
            if ($IncludeUnreviewed) { $cohortArgs.IncludeUnreviewed = $true }
            & (Join-Path $PSScriptRoot 'Complete-ReviewCohort.ps1') @cohortArgs
            break
        }
        $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
        $updated = @()
        foreach ($id in $targetIds) {
            $store = Get-ProposalStore
            $proposal = @($store.proposals | Where-Object { $_.id -eq $id })[0]
            if ($null -eq $proposal) { throw "Proposal #$Id was not found." }
            $repo = if ($proposal.origin_repo) { $proposal.origin_repo } else { 'LCM_Inventory' }
            $crpTag = if ($proposal.crp_id) { $proposal.crp_id } elseif ($proposal.cr_id) { $proposal.cr_id } else { "CRP-$id" }
            $reviewResultArgs = @{
                RepositoryPath = $repo
                CRP = $crpTag
                Result = 'Completed'
                Notes = $Details
            }
            if ($MinimalTests) { $reviewResultArgs.MinimalTests = $true }
            if ($Force) { $reviewResultArgs.Force = $true }
            & (Join-Path $PSScriptRoot 'Submit-ReviewResult.ps1') @reviewResultArgs
            $p = Get-ProposalStore | ForEach-Object { @($_.proposals | Where-Object { $_.id -eq $id })[0] }
            if ($p) { $updated += $p }
        }
        Write-Host "`nCompleted Proposal(s) through the exact-CRP review result path:" -ForegroundColor Cyan
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
                $cur = if ($existing -and $existing.state) { $existing.state } else { 'suggested' }
                switch ($cur) {
                    'suggested'    { 'in_progress' }
                    'approved'     { 'verified' }
                    'held'         { if ($existing.resume_state) { $existing.resume_state } else { 'in_progress' } }
                    'in_progress'  { 'verified' }
                    default        { throw "Proceed cannot transition proposal #$id from '$cur'. Use BCR, COMPLETE, or PUSH as required by the lifecycle." }
                }
            }
            Move-LcmProposalLifecycleState -Id $id -State $targetProg -Details $Details | Out-Null
            if ($MinimalTests) {
                $store = Get-ProposalStore
                foreach ($item in $store.proposals) {
                    if ($item.id -eq $id) {
                        $item.minimal_tests = $true
                        $item.test_scope = 'minimal'
                    }
                }
                Set-ProposalStore -Store $store
            }
            $p = Get-ProposalStore | ForEach-Object { @($_.proposals | Where-Object { $_.id -eq $id })[0] }
            if ($p) {
                $updated += $p
            }
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
        $updated = @(Invoke-ProposalBatchAction -Action $Action -TargetExpression $TargetExpression -Details $Details -Changes $Changes)
        if ($updated.Count -eq 0) {
            throw "Action '$Action' resolved no current proposal targets for expression '$TargetExpression'; the result cannot be formatted."
        }
        Write-Host "`nUpdated Proposal(s):" -ForegroundColor Cyan
        Format-ProposalsTable -Proposals $updated
        break
    }
}
