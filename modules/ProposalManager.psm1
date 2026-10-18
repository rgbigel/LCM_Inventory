# =====================================================================
# ProposalManager.psm1 - LCM Proposal & Two-Tier Review Governance Module
# =====================================================================
# Module: ProposalManager
# Purpose: Manages LCM proposal lifecycle (suggested -> processed -> deferred / completed / deleted),
#          batch operations, review granularity ('coarse' | 'tight'), repo review queue inspection,
#          and persistent ledger storage in LCM_Inventory.
# Authors: Rolf, LCM_AI Engine
# Version: 10.0.2
# Date: 2026-10-18
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ProposalStorePath {
    [CmdletBinding()]
    param()

    if (-not [string]::IsNullOrWhiteSpace($env:LCM_PROPOSAL_STORE_PATH)) {
        $overridePath = [System.IO.Path]::GetFullPath($env:LCM_PROPOSAL_STORE_PATH)
        $overrideDirectory = Split-Path -Path $overridePath -Parent
        if (-not (Test-Path -LiteralPath $overrideDirectory)) {
            New-Item -ItemType Directory -Path $overrideDirectory -Force | Out-Null
        }
        return $overridePath
    }

    $scriptRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        $scriptRoot = (Get-Location).Path
    }

    $item = Get-Item $scriptRoot
    while ($item -ne $null -and $item.Name -ne 'LCM_Inventory' -and $item.Name -ne 'Git_Repositories') {
        $item = $item.Parent
    }

    $wiRoot = if ($item -and $item.Name -eq 'LCM_Inventory') {
        $item.FullName
    } elseif ($item -and $item.Name -eq 'Git_Repositories') {
        Join-Path $item.FullName 'LCM_Inventory'
    } else {
        'D:\Git_Repositories\LCM_Inventory'
    }

    $proposalsDir = Join-Path $wiRoot 'data\proposals'
    if (-not (Test-Path $proposalsDir)) {
        New-Item -ItemType Directory -Path $proposalsDir -Force | Out-Null
    }

    return (Join-Path $proposalsDir 'proposals.json')
}

function Get-ProposalStore {
    [CmdletBinding()]
    param()

    $path = Get-ProposalStorePath
    if (-not (Test-Path $path)) {
        $initStore = [ordered]@{
            '$schema'            = 'https://json-schema.org/draft/2020-12/schema'
            title                = 'LCM Workspace Proposals Ledger'
            updated_at           = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
            review_granularity   = 'coarse'
            lcm_mode             = 'active'
            last_proposal_id     = 0
            proposals            = @()
        }
        $initStore | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
        return [PSCustomObject]$initStore
    }

    $json = Get-Content -Path $path -Raw -Encoding UTF8
    return ($json | ConvertFrom-Json)
}

function Set-ProposalStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Store
    )

    $path = Get-ProposalStorePath
    $Store.updated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    $Store | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
}

function Update-LcmControlHubAfterCompletion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int[]]$ProposalId
    )

    $inventoryRoot = Split-Path -Path $PSScriptRoot -Parent
    $rendererPath = Join-Path $inventoryRoot 'tools\Show-LcmControl.ps1'
    if (-not (Test-Path -LiteralPath $rendererPath -PathType Leaf)) {
        throw "ShowCM renderer was not found: $rendererPath"
    }

    & $rendererPath -NoLaunch | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "ShowCM renderer failed after completing proposal(s): $($ProposalId -join ', ')"
    }

    $payload = @{
        event        = 'proposal-completed'
        proposal_ids = @($ProposalId)
        timestamp    = (Get-Date).ToString('o')
    } | ConvertTo-Json -Compress

    try {
        $notification = Invoke-RestMethod -Uri 'http://127.0.0.1:9876/hub-refresh' -Method Post `
            -ContentType 'application/json' -Body $payload -TimeoutSec 2 -ErrorAction Stop
        if ([string]$notification.status -ne 'OK') {
            throw "Daemon returned status '$($notification.status)'."
        }
    } catch {
        Write-Warning "ShowCM was re-rendered for completed proposal(s) $($ProposalId -join ', '), but the daemon refresh notification was unavailable: $($_.Exception.Message)"
    }
}

function Get-WorkspaceProposals {
    [CmdletBinding()]
    param(
        [int[]]$Id,
        [string]$State,
        [string]$OriginRepo,
        [switch]$OpenOnly
    )

    $store = Get-ProposalStore
    $items = @($store.proposals)

    if ($OpenOnly) {
        $items = @($items | Where-Object { $_.state -in @('bug', 'suggested', 'approved', 'processed', 'deferred') })
    }

    if ($Id -and $Id.Count -gt 0) {
        $items = @($items | Where-Object { $Id -contains $_.id })
    }

    if (-not [string]::IsNullOrWhiteSpace($State)) {
        $s = $State.ToLowerInvariant()
        $items = @($items | Where-Object { $_.state.ToLowerInvariant() -eq $s })
    }

    if (-not [string]::IsNullOrWhiteSpace($OriginRepo)) {
        $r = $OriginRepo.ToLowerInvariant()
        $items = @($items | Where-Object { $_.origin_repo.ToLowerInvariant().Contains($r) })
    }

    return @($items | Sort-Object id)
}

function New-WorkspaceProposal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [string]$OriginRepo = 'LCM_Inventory',
        [string]$Details = '',
        [string]$BundleId = 'unassigned',
        [string]$CrId = '',
        [string]$Author = $env:USERNAME,
        [string]$PlanPath = '',
        [string]$WalkthroughPath = '',
        [string]$AppId = '',
        [string]$PrimaryApp = '',
        [string[]]$AffectedApps = @(),
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $store = Get-ProposalStore
    $newId = [int]$store.last_proposal_id + 1
    $store.last_proposal_id = $newId

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $isBug = ($OriginRepo -eq 'bug') -or ($CrId -match '^BUG-') -or ($Title -match '\[BUG\]')
    $prefix = if ($isBug) { 'BUG' } else { 'CRP' }
    $canonicalId = "{0}-{1:D3}" -f $prefix, $newId
    $cleanCrId = if ($CrId) { $CrId } else { $canonicalId }
    $safeCrId = $cleanCrId -replace '[^a-zA-Z0-9_-]', '_'

    # Active App Context Inheritance per RULE-LCM-019
    $activeCtx = Get-ActiveAppContext
    if ([string]::IsNullOrWhiteSpace($AppId) -and $activeCtx -and $activeCtx.app_id -and $activeCtx.app_id -ne 'Architecture') {
        $AppId = $activeCtx.app_id
    }

    # CRP-162 Proposal Bundle Directory Standard
    $cleanSlug = ($Title -replace '[^a-zA-Z0-9]', '-') -replace '-+', '-' -replace '^-|-$', ''
    if ($cleanSlug.Length -gt 50) { $cleanSlug = $cleanSlug.Substring(0, 50).TrimEnd('-') }
    $bundleDirName = "{0}-{1}" -f $canonicalId, $cleanSlug
    $bundleRelPath = "docs/Proposals/$bundleDirName"

    $targetRepoDir = if ($OriginRepo -and (Test-Path (Join-Path $WorkspaceRoot $OriginRepo))) {
        Join-Path $WorkspaceRoot $OriginRepo
    } else {
        Join-Path $WorkspaceRoot 'LCM_Inventory'
    }

    $bundleFullPath = Join-Path $targetRepoDir "docs\Proposals\$bundleDirName"
    if (-not (Test-Path $bundleFullPath)) {
        New-Item -ItemType Directory -Path $bundleFullPath -Force | Out-Null
    }

    # 1. Specification.md
    $specPath = Join-Path $bundleFullPath 'Specification.md'
    if (-not (Test-Path $specPath)) {
        $appDisplay = if ($AppId) { $AppId } else { "None" }
        $specContent = @"
# Change Request Proposal: $canonicalId

```yaml
CRP-ID: $canonicalId
Title: $Title
Scope: $OriginRepo
Baseline-Version: 10.0.1
Author: $Author
Date: $timestamp
Status: Suggested
Plan-State: suggested
Progress-State: undecided
Priority: High
App-ID: $appDisplay
```

---

## 1. Executive Summary & Intent
$Details

## 2. Gate 0 Contract
### Target State
Define the observable completed state this proposal will achieve.

### Invariants and Exit Criteria
Define the evidence that proves the target state while preserving applicable governance safeguards.

### Explicit Non-Goals
Define work intentionally excluded from this proposal. When this is ordinary,
evidently scoped work, the default Non-Goal applies: Cause no havoc; ask rather
than invent or infer, and avoid unnecessary complexity.

## 3. Technical Requirements & Invariants
- Invariant 1: Must conform to LCM governance standards.

"@
        Set-Content -Path $specPath -Value $specContent.Trim() -Encoding UTF8
    }

    # 2. Implementation_Plan.md
    $planFilePath = Join-Path $bundleFullPath 'Implementation_Plan.md'
    if (-not (Test-Path $planFilePath)) {
        $planContent = @"
# Implementation Plan: $canonicalId - $Title

## 1. Executive Summary & Problem Context
$Details

## 2. Gate 0 Traceability
- Map each implementation component and verification activity to the accepted Gate 0 target-state clause.

## 3. Proposed Changes
### Component 1: Initial Implementation
- Scaffolding baseline implementation for $Title.

## 4. Verification Plan
- Automated Pester tests and readiness quality gates.

"@
        Set-Content -Path $planFilePath -Value $planContent.Trim() -Encoding UTF8
    }

    # 3. Walkthrough.md
    $walkFilePath = Join-Path $bundleFullPath 'Walkthrough.md'
    if (-not (Test-Path $walkFilePath)) {
        $walkContent = @"
# Walkthrough: $canonicalId - $Title

## 1. Executive Summary
Implementation and verification records for $canonicalId.

## 2. Verification Evidence
- Pending implementation execution.

"@
        Set-Content -Path $walkFilePath -Value $walkContent.Trim() -Encoding UTF8
    }

    if ([string]::IsNullOrWhiteSpace($PlanPath)) {
        $PlanPath = "$bundleRelPath/Implementation_Plan.md"
    }
    if ([string]::IsNullOrWhiteSpace($WalkthroughPath)) {
        $WalkthroughPath = "$bundleRelPath/Walkthrough.md"
    }

    $proposal = [ordered]@{
        id               = $newId
        crp_id           = $canonicalId
        timestamp        = $timestamp
        title            = $Title
        origin_repo      = $OriginRepo
        cr_id            = $cleanCrId
        app_id           = if ($AppId) { $AppId } else { $null }
        primary_app      = if ($PrimaryApp) { $PrimaryApp } elseif ($isBug -and $AppId) { $AppId } else { $null }
        affected_apps    = if ($AffectedApps.Count -gt 0) { @($AffectedApps) } else { @() }
        state            = 'suggested'
        progress_state   = 'undecided'
        bundle_id        = $BundleId
        bundle_dir       = $bundleRelPath
        docs             = [ordered]@{
            specification = 'Specification.md'
            plan          = 'Implementation_Plan.md'
            walkthrough   = 'Walkthrough.md'
        }
        commit_sha       = $null
        github_url       = $null
        author           = if ($Author) { $Author } else { 'Rolf' }
        details          = $Details
        priority         = 5
        disposition      = $null
        flow_mode        = if ($isBug) { 'doit' } else { 'standard' }
        always_proceed   = if ($isBug) { $true } else { $false }
        plan_path        = $PlanPath
        walkthrough_path = $WalkthroughPath
    }

    $list = [System.Collections.Generic.List[object]]::new(@($store.proposals))
    $list.Add([PSCustomObject]$proposal)
    $store.proposals = @($list)

    Set-ProposalStore -Store $store
    $appSuffix = if ($AppId) { " | App: $AppId" } else { "" }
    Write-Host ("Created Proposal #{0}: {1} (Plan State: suggested | Progress: undecided{2})" -f $newId, $Title, $appSuffix) -ForegroundColor Green
    return [PSCustomObject]$proposal
}

function Get-LcmProposalLifecycleActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('suggested', 'in_progress', 'verified', 'in_review', 'completed', 'pushed', 'held', 'withdrawn', 'rejected', 'superseded')]
        [string]$State
    )

    $actions = @{
        suggested = @('edit', 'do', 'hold', 'withdraw', 'supersede')
        in_progress = @('edit', 'verify', 'hold', 'reset', 'withdraw', 'supersede')
        verified = @('bcr', 'reopen', 'hold', 'supersede')
        in_review = @('complete', 'commit', 'reject', 'reopen', 'hold')
        completed = @('push', 'hold', 'reinstate')
        pushed = @('view', 'reinstate')
        held = @('reopen', 'edit', 'withdraw')
        withdrawn = @('view', 'supersede')
        rejected = @('view', 'supersede', 'create-linked-bug')
        superseded = @('view')
    }
    return @($actions[$State])
}

function Test-LcmProposalLifecycleTransition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FromState,

        [Parameter(Mandatory = $true)]
        [string]$ToState
    )

    $allowed = @{
        suggested = @('in_progress', 'held', 'withdrawn', 'superseded')
        in_progress = @('suggested', 'verified', 'held', 'withdrawn', 'superseded')
        verified = @('in_progress', 'in_review', 'held', 'superseded')
        in_review = @('in_progress', 'completed', 'held', 'rejected')
        completed = @('pushed', 'held')
        pushed = @()
        held = @('suggested', 'in_progress', 'verified', 'in_review', 'completed', 'withdrawn')
        withdrawn = @('superseded')
        rejected = @('superseded')
        superseded = @()
    }
    return $ToState -in @($allowed[$FromState])
}

function New-LcmLifecycleFailureReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$TargetExpression,

        [Parameter(Mandatory = $true)]
        [psobject[]]$Failures
    )

    $routes = [System.Collections.Generic.List[psobject]]::new()
    foreach ($failure in $Failures) {
        switch ([string]$failure.conflict_type) {
            'invalid transition' {
                if ($Action -eq 'do' -and [string]$failure.current_state -eq 'in_review') {
                    $routes.Add([PSCustomObject]@{
                        rank = 1
                        required_user_action = 'Decision required: choose Complete after resolving every blocking 1 - REVIEW component and confirming the 2 - REVIEW disposition.'
                        affected_identities = @($failure.identity)
                        effect = 'Moves the accepted proposal from 2 - REVIEW to completed; it does not create another review commit.'
                    })
                    $routes.Add([PSCustomObject]@{
                        rank = 2
                        required_user_action = 'Choose Reopen only when further implementation is required.'
                        affected_identities = @($failure.identity)
                        effect = 'Returns the proposal to implementation and requires verification plus a new 2 - REVIEW.'
                    })
                } else {
                    $routes.Add([PSCustomObject]@{
                        rank = 1
                        required_user_action = 'Choose a lifecycle action valid for the current state.'
                        affected_identities = @($failure.identity)
                        effect = 'Changes lifecycle status only after an explicit valid action.'
                    })
                }
            }
            'incomplete evidence' {
                $routes.Add([PSCustomObject]@{
                    rank = 1
                    required_user_action = 'Supply or run the missing verification evidence, then retry the requested action.'
                    affected_identities = @($failure.identity)
                    effect = 'Adds verification evidence; does not accept review evidence.'
                })
            }
            'unresolved review obligation' {
                $routes.Add([PSCustomObject]@{
                    rank = 1
                    required_user_action = 'Review and resolve the listed blocking 1 - REVIEW component.'
                    affected_identities = @($failure.identity)
                    effect = 'Records review evidence before a later completion action.'
                })
            }
            'target-resolution failure' {
                $routes.Add([PSCustomObject]@{
                    rank = 1
                    required_user_action = 'Refresh the lifecycle ledger and select an existing CRP or cohort identity.'
                    affected_identities = @($failure.identity)
                    effect = 'Changes neither lifecycle state nor review evidence.'
                })
            }
        }
    }

    $deduplicatedRoutes = @(
        $routes | Group-Object required_user_action | ForEach-Object {
            $first = $_.Group[0]
            $first | Add-Member -NotePropertyName 'affected_identities' -NotePropertyValue @(
                $_.Group | ForEach-Object { $_.affected_identities } | Select-Object -Unique
            ) -Force
            $first
        } | Sort-Object rank | Select-Object -First 3
    )

    return [PSCustomObject]@{
        report_type = 'lifecycle-status-failure'
        generated_at = (Get-Date).ToString('o')
        requested_action = $Action
        target_expression = $TargetExpression
        direct_failures = @($Failures)
        escape_routes = $deduplicatedRoutes
    }
}

function Format-LcmLifecycleFailureReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Report
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('LIFECYCLE STATUS FAILURE REPORT')
    $lines.Add(("Request: {0} {1}" -f $Report.requested_action.ToUpperInvariant(), $Report.target_expression))
    foreach ($failure in @($Report.direct_failures)) {
        $lines.Add(("- {0}: {1}" -f $failure.identity, $failure.reason))
        $lines.Add(("  Current: {0}; requested: {1}; conflict: {2}" -f $failure.current_state, $failure.requested_state, $failure.conflict_type))
        $lines.Add(("  Source: {0} ({1})" -f $failure.source.path, $failure.source.symbol))
        if (@($failure.governing_references).Count -gt 0) {
            $lines.Add(("  Governing reference: {0}" -f ((@($failure.governing_references) -join '; '))))
        }
    }
    if (@($Report.escape_routes).Count -gt 0) {
        $lines.Add('Compliant escape routes (not executed):')
        foreach ($route in @($Report.escape_routes)) {
            $lines.Add(("  {0}. {1} Affected: {2}. Effect: {3}" -f $route.rank, $route.required_user_action, ($route.affected_identities -join ', '), $route.effect))
        }
    } else {
        $lines.Add('No compliant escape route was identified. Inspect the listed source and evidence.')
    }
    return @($lines)
}

function New-LcmLifecycleFailureException {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Report,

        [string]$Message = ''
    )

    $summary = @($Report.direct_failures | ForEach-Object {
        "{0}: {1}" -f $_.identity, $_.reason
    }) -join ' '
    $exception = [System.InvalidOperationException]::new(
        $(if ([string]::IsNullOrWhiteSpace($Message)) {
            "Lifecycle action '$($Report.requested_action)' was not applied to '$($Report.target_expression)'. $summary"
        } else {
            $Message
        })
    )
    $exception.Data['LcmLifecycleFailureReport'] = $Report | ConvertTo-Json -Depth 8 -Compress
    return $exception
}

function Get-LcmProposalReviewObligations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Proposal,

        [switch]$UnresolvedOnly
    )

    $store = Get-ProposalStore
    if (-not $store.PSObject.Properties['review_obligation_ledger'] -or
        $null -eq $store.review_obligation_ledger -or
        -not $store.review_obligation_ledger.PSObject.Properties['entries']) {
        return @()
    }

    $obligations = @($store.review_obligation_ledger.entries | Where-Object {
        [int]$_.proposal_id -eq [int]$Proposal.id
    })
    if ($UnresolvedOnly) {
        $obligations = @($obligations | Where-Object { [string]$_.status -ne 'completed' })
    }
    return $obligations
}

function Register-LcmCrossRepositoryReviewObligation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Repository,

        [string]$Reason = 'Durable cross-repository source changes were discovered during BCR preparation.'
    )

    $store = Get-ProposalStore
    $proposal = @($store.proposals | Where-Object { $_.id -eq $Id })[0]
    if ($null -eq $proposal) { throw "Proposal #$Id was not found." }

    $originRepository = if ($proposal.PSObject.Properties['origin_repo'] -and $proposal.origin_repo) {
        [string]$proposal.origin_repo
    } else {
        'LCM_Inventory'
    }
    if ($Repository.Equals($originRepository, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    if (-not $store.PSObject.Properties['review_obligation_ledger'] -or $null -eq $store.review_obligation_ledger) {
        $store | Add-Member -NotePropertyName 'review_obligation_ledger' -NotePropertyValue ([PSCustomObject]@{
            version = 1
            entries = @()
        }) -Force
    }
    if (-not $store.review_obligation_ledger.PSObject.Properties['entries'] -or $null -eq $store.review_obligation_ledger.entries) {
        $store.review_obligation_ledger | Add-Member -NotePropertyName 'entries' -NotePropertyValue @() -Force
    }
    $existingObligations = @($store.review_obligation_ledger.entries | Where-Object {
        [int]$_.proposal_id -eq $Id -and
        ([string]$_.repository).Equals($Repository, [System.StringComparison]::OrdinalIgnoreCase) -and
        [string]$_.status -ne 'completed'
    })
    $existing = @($existingObligations | Select-Object -First 1)
    if ($existing) {
        $observedReasons = @(
            foreach ($existingObligation in $existingObligations) {
                if ($existingObligation.PSObject.Properties['observed_reasons'] -and $null -ne $existingObligation.observed_reasons) {
                    @($existingObligation.observed_reasons)
                } elseif (-not [string]::IsNullOrWhiteSpace([string]$existingObligation.reason)) {
                    @([string]$existingObligation.reason)
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($Reason)) {
                $Reason
            }
        ) | Select-Object -Unique
        $existing | Add-Member -NotePropertyName 'observed_reasons' -NotePropertyValue @($observedReasons) -Force
        $existing | Add-Member -NotePropertyName 'last_observed_at' -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
        if ($existingObligations.Count -gt 1) {
            $store.review_obligation_ledger.entries = @(
                $store.review_obligation_ledger.entries | Where-Object {
                    -not (
                        [int]$_.proposal_id -eq $Id -and
                        ([string]$_.repository).Equals($Repository, [System.StringComparison]::OrdinalIgnoreCase) -and
                        [string]$_.status -ne 'completed'
                    )
                }
            ) + $existing
        }
        Set-ProposalStore -Store $store
        return $existing
    }

    $identity = if ($proposal.PSObject.Properties['crp_id'] -and $proposal.crp_id) {
        [string]$proposal.crp_id
    } elseif ($proposal.PSObject.Properties['cr_id'] -and $proposal.cr_id) {
        [string]$proposal.cr_id
    } else {
        "CRP-$Id"
    }
    $obligation = [PSCustomObject]@{
        id            = "${identity}::${Repository}"
        proposal_id   = $Id
        repository    = $Repository
        status        = 'open'
        discovered_at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        reason        = $Reason
        observed_reasons = @($Reason)
        bcr_identity  = $identity
    }
    $store.review_obligation_ledger.entries = @($store.review_obligation_ledger.entries) + $obligation
    Set-ProposalStore -Store $store
    return $obligation
}

function Complete-LcmCrossRepositoryReviewObligation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Repository,

        [Parameter(Mandatory = $true)]
        [string]$ReviewReceiptPath,

        [string]$CommitSha = ''
    )

    $store = Get-ProposalStore
    $proposal = @($store.proposals | Where-Object { $_.id -eq $Id })[0]
    if ($null -eq $proposal) { throw "Proposal #$Id was not found." }
    $obligations = @($store.review_obligation_ledger.entries | Where-Object {
        [int]$_.proposal_id -eq $Id -and
        [string]$_.status -ne 'completed' -and
        ([string]$_.repository).Equals($Repository, [System.StringComparison]::OrdinalIgnoreCase)
    })
    $obligation = if ($obligations.Count -gt 0) { $obligations[0] } else { $null }
    if ($null -eq $obligation) {
        throw "Proposal #$Id has no unresolved cross-repository BCR obligation for '$Repository'."
    }

    $obligation.status = 'completed'
    $obligation | Add-Member -NotePropertyName 'completed_at' -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
    $obligation | Add-Member -NotePropertyName 'review_receipt' -NotePropertyValue $ReviewReceiptPath -Force
    $obligation | Add-Member -NotePropertyName 'commit_sha' -NotePropertyValue $CommitSha -Force
    if ($proposal.PSObject.Properties['status_note'] -and [string]$proposal.status_note -like 'Review pending: cross-repository BCR obligation*') {
        $proposal.PSObject.Properties.Remove('status_note')
    }
    Set-ProposalStore -Store $store
    return $obligation
}

function Get-LcmProposalResumeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Proposal
    )

    if ($Proposal.PSObject.Properties['resume_state'] -and -not [string]::IsNullOrWhiteSpace([string]$Proposal.resume_state)) {
        return [string]$Proposal.resume_state
    }

    $history = @($Proposal.state_history)
    for ($index = $history.Count - 1; $index -ge 1; $index--) {
        if ([string]$history[$index].state -eq 'held') {
            return [string]$history[$index - 1].state
        }
    }

    return ''
}

function Move-LcmProposalLifecycleState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('suggested', 'in_progress', 'verified', 'in_review', 'completed', 'pushed', 'held', 'withdrawn', 'rejected', 'superseded')]
        [string]$State,

        [string]$Details,

        [PSCustomObject]$Store,

        [switch]$SkipPersist,

        [string]$CohortId = '',

        [string]$Gate = '',

        [ValidateSet('synchronized', 'no_op', '')]
        [string]$SynchronizationOutcome = ''
    )

    $store = if ($null -ne $Store) { $Store } else { Get-ProposalStore }
    $proposal = @($store.proposals | Where-Object { $_.id -eq $Id })[0]
    if ($null -eq $proposal) { throw "Proposal #$Id was not found." }
    $fromState = [string]$proposal.state
    if ($fromState -eq 'approved') {
        $fromState = 'in_progress'
        $proposal.state = $fromState
    }
    if (-not (Test-LcmProposalLifecycleTransition -FromState $fromState -ToState $State)) {
        throw "Invalid lifecycle transition for proposal #$($Id): $fromState -> $State"
    }
    if ($State -eq 'completed') {
        $unresolvedObligations = @(Get-LcmProposalReviewObligations -Proposal $proposal -UnresolvedOnly)
        if ($unresolvedObligations.Count -gt 0) {
            $blockingComponents = @($unresolvedObligations | ForEach-Object {
                "COH-$Id — 1 - REVIEW ($($_.repository))"
            } | Sort-Object -Unique)
            throw "Proposal #$Id cannot complete while blocking 1 - REVIEW component(s) remain: $($blockingComponents -join ', ')."
        }
        $hasDisposition = $proposal.PSObject.Properties['bcr_disposition'] -and
            -not [string]::IsNullOrWhiteSpace([string]$proposal.bcr_disposition)
        $hasAuthorizedBypass = $proposal.PSObject.Properties['bcr_bypass_authorized'] -and
            [bool]$proposal.bcr_bypass_authorized
        if (-not $hasDisposition -and -not $hasAuthorizedBypass) {
            throw "Proposal #$Id cannot pass the review gate without a recorded BCR disposition or explicit authorized BCR bypass."
        }
    }
    $legacyProgressState = @{
        suggested   = 'undecided'
        in_progress = 'in_progress'
        verified    = 'verification'
        in_review   = 'verification'
        completed   = 'completed'
        pushed      = 'pushed'
        held        = 'blocked'
        withdrawn   = 'deferred'
        rejected    = 'deferred'
        superseded  = 'deferred'
    }
    $legacyDisposition = @{
        completed   = 'completed'
        pushed      = 'published'
        held        = 'held'
        rejected    = 'rejected'
        withdrawn   = 'withdrawn'
        superseded  = 'superseded'
    }

    if ($State -eq 'held') {
        $proposal | Add-Member -NotePropertyName 'resume_state' -NotePropertyValue $fromState -Force
    }
    $proposal.state = $State
    $proposal | Add-Member -NotePropertyName 'progress_state' -NotePropertyValue $legacyProgressState[$State] -Force
    $proposal | Add-Member -NotePropertyName 'disposition' -NotePropertyValue $legacyDisposition[$State] -Force
    if ($State -ne 'held' -and $proposal.PSObject.Properties['hold_reason']) {
        $proposal.hold_reason = $null
    }
    if ($State -eq 'held' -and $Details) {
        $proposal | Add-Member -NotePropertyName 'hold_reason' -NotePropertyValue $Details -Force
    }
    if (-not $proposal.PSObject.Properties['state_history']) {
        $proposal | Add-Member -NotePropertyName 'state_history' -NotePropertyValue @() -Force
    }
    if (-not $proposal.PSObject.Properties['dates'] -or $null -eq $proposal.dates) {
        $proposal | Add-Member -NotePropertyName 'dates' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $proposal.dates | Add-Member -NotePropertyName $State -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
    $proposal.state_history = @($proposal.state_history) + [PSCustomObject]@{
        from_state              = $fromState
        state                   = $State
        timestamp               = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        user                    = $env:USERNAME
        note                    = $Details
        cohort_id               = $CohortId
        cohort_gate             = $Gate
        synchronization_outcome = $SynchronizationOutcome
    }
    if (-not $SkipPersist) {
        Set-ProposalStore -Store $store
        if ($State -eq 'completed') {
            Update-LcmControlHubAfterCompletion -ProposalId $Id
        }
    }
    return $proposal
}

function Start-LcmProposalReinstatement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [string]$Changes = '',

        [string]$Details = ''
    )

    $store = Get-ProposalStore
    $proposal = @($store.proposals | Where-Object { $_.id -eq $Id })[0]
    if ($null -eq $proposal) { throw "Proposal #$Id was not found." }

    $fromState = [string]$proposal.state
    if ($fromState -notin @('completed', 'pushed')) {
        throw "Proposal #$Id can be reinstated only from completed or pushed; found '$fromState'."
    }

    $hasConcreteChanges = -not [string]::IsNullOrWhiteSpace($Changes)
    $targetState = if ($hasConcreteChanges) { 'in_progress' } else { 'suggested' }
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $revision = 1
    foreach ($event in @($proposal.state_history)) {
        if ($event.PSObject.Properties['revision']) {
            $parsedRevision = 0
            if ([int]::TryParse([string]$event.revision, [ref]$parsedRevision)) {
                $revision = [Math]::Max($revision, $parsedRevision + 1)
            }
        }
    }

    $legacyProgressState = if ($targetState -eq 'in_progress') { 'in_progress' } else { 'undecided' }
    $proposal.state = $targetState
    $proposal | Add-Member -NotePropertyName 'progress_state' -NotePropertyValue $legacyProgressState -Force
    $proposal | Add-Member -NotePropertyName 'disposition' -NotePropertyValue $null -Force
    $proposal | Add-Member -NotePropertyName 'state_reason' -NotePropertyValue $(if ($hasConcreteChanges) {
        'Reinstated with concrete correction requests; implementation, verification, and exact-identity BCR are required.'
    } else {
        'Reinstated without concrete correction requests; awaiting revised proposal intent and plan approval.'
    }) -Force
    $proposal | Add-Member -NotePropertyName 'reinstatement_revision' -NotePropertyValue $revision -Force
    $proposal | Add-Member -NotePropertyName 'reinstatement_changes' -NotePropertyValue $Changes -Force
    if (-not $proposal.PSObject.Properties['dates'] -or $null -eq $proposal.dates) {
        $proposal | Add-Member -NotePropertyName 'dates' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $proposal.dates | Add-Member -NotePropertyName $targetState -NotePropertyValue $timestamp -Force
    if (-not $proposal.PSObject.Properties['state_history']) {
        $proposal | Add-Member -NotePropertyName 'state_history' -NotePropertyValue @() -Force
    }
    $proposal.state_history = @($proposal.state_history) + [PSCustomObject]@{
        from_state = $fromState
        state = $targetState
        timestamp = $timestamp
        user = $env:USERNAME
        note = if ($Details) { $Details } elseif ($hasConcreteChanges) { 'Reinstated with concrete correction requests.' } else { 'Reinstated for revised proposal intent.' }
        revision = $revision
        reinstatement = $true
        concrete_change_requests = $hasConcreteChanges
        changes = $Changes
    }
    Set-ProposalStore -Store $store
    return $proposal
}

function Restore-LcmProposalReviewState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Details
    )

    $store = Get-ProposalStore
    $proposal = @($store.proposals | Where-Object { $_.id -eq $Id })[0]
    if ($null -eq $proposal) { throw "Proposal #$Id was not found." }
    if ([string]$proposal.state -ne 'completed') {
        throw "Proposal #$Id can be restored to review only from completed; found '$($proposal.state)'."
    }

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $proposal.state = 'in_review'
    $proposal | Add-Member -NotePropertyName 'progress_state' -NotePropertyValue 'verification' -Force
    $proposal | Add-Member -NotePropertyName 'disposition' -NotePropertyValue $null -Force
    $proposal | Add-Member -NotePropertyName 'state_reason' -NotePropertyValue 'Prior completion was premature; awaiting the already-open review acceptance.' -Force
    $proposal | Add-Member -NotePropertyName 'bcr_disposition' -NotePropertyValue $null -Force
    $proposal | Add-Member -NotePropertyName 'bcr_disposition_at' -NotePropertyValue $null -Force
    $proposal | Add-Member -NotePropertyName 'review_state_repair' -NotePropertyValue ([PSCustomObject]@{
        timestamp = $timestamp
        reason = $Details
        from_state = 'completed'
        restored_state = 'in_review'
    }) -Force
    if (-not $proposal.PSObject.Properties['dates'] -or $null -eq $proposal.dates) {
        $proposal | Add-Member -NotePropertyName 'dates' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $proposal.dates | Add-Member -NotePropertyName 'in_review' -NotePropertyValue $timestamp -Force
    $proposal.state_history = @($proposal.state_history) + [PSCustomObject]@{
        from_state = 'completed'
        state = 'in_review'
        timestamp = $timestamp
        user = $env:USERNAME
        note = $Details
        repair = 'premature-completion'
    }
    Set-ProposalStore -Store $store
    return $proposal
}

function Set-LcmProposalBugIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Details
    )

    if ([string]::IsNullOrWhiteSpace($Details)) {
        throw 'BUG reclassification requires documented details.'
    }

    $store = Get-ProposalStore
    $proposal = @($store.proposals | Where-Object { $_.id -eq $Id })[0]
    if ($null -eq $proposal) { throw "Proposal #$Id was not found." }

    $identityProperty = if ($proposal.PSObject.Properties['crp_id'] -and $proposal.crp_id) { 'crp_id' } else { 'cr_id' }
    $currentIdentity = [string]$proposal.$identityProperty
    if ($currentIdentity -match '^BUG-\d+$') {
        return $proposal
    }

    if ([string]::IsNullOrWhiteSpace($currentIdentity)) {
        $currentIdentity = "CRP-$Id"
    }
    $bugIdentity = "BUG-$Id"

    $proposal | Add-Member -NotePropertyName 'original_crp_id' -NotePropertyValue $currentIdentity -Force
    $proposal | Add-Member -NotePropertyName 'crp_id' -NotePropertyValue $bugIdentity -Force
    if ($proposal.PSObject.Properties['cr_id']) {
        $proposal.cr_id = $null
    }
    $proposal | Add-Member -NotePropertyName 'bug_reclassified_at' -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
    $proposal | Add-Member -NotePropertyName 'bug_reclassification_reason' -NotePropertyValue $Details -Force
    if (-not $proposal.PSObject.Properties['identity_history']) {
        $proposal | Add-Member -NotePropertyName 'identity_history' -NotePropertyValue @() -Force
    }
    $proposal.identity_history = @($proposal.identity_history) + [PSCustomObject]@{
        from_identity = $currentIdentity
        identity      = $bugIdentity
        timestamp     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        user          = $env:USERNAME
        reason        = $Details
    }

    Set-ProposalStore -Store $store
    return $proposal
}

function Enable-LcmImmediateBugRecovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int[]]$Ids,

        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    if ([string]::IsNullOrWhiteSpace($Reason)) {
        throw '-Immediately requires -Details documenting the severity, deadlock, loop, race condition, or inability to self-remedy.'
    }

    $store = Get-ProposalStore
    $proposals = @()
    foreach ($id in $Ids) {
        $proposal = @($store.proposals | Where-Object { $_.id -eq $id })[0]
        if ($null -eq $proposal) { throw "Proposal #$Id was not found." }
        $proposals += $proposal
    }
    $triggerBugs = @($proposals | Where-Object {
        $proposalId = if ($_.PSObject.Properties['crp_id'] -and $_.crp_id) { [string]$_.crp_id } else { [string]$_.cr_id }
        $proposalId -match '^BUG-\d+$'
    })
    if ($triggerBugs.Count -eq 0) {
        if ($proposals.Count -ne 1) {
            throw '-Immediately requires an explicit multi-proposal cohort containing at least one BUG proposal.'
        }
        $reclassified = Set-LcmProposalBugIdentity -Id $proposals[0].id -Details $Reason
        $proposals = @($reclassified)
        $triggerBugs = @($reclassified)
        $store = Get-ProposalStore
    }
    $triggerBugIds = @($triggerBugs | ForEach-Object {
        if ($_.PSObject.Properties['crp_id'] -and $_.crp_id) { [string]$_.crp_id } else { [string]$_.cr_id }
    }) -join ', '
    foreach ($proposal in $proposals) {
        $proposal | Add-Member -NotePropertyName 'quality_checks_deferred' -NotePropertyValue $true -Force
        $proposal | Add-Member -NotePropertyName 'immediate_recovery_reason' -NotePropertyValue $Reason -Force
        $proposal | Add-Member -NotePropertyName 'immediate_recovery_started_at' -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
        $proposal | Add-Member -NotePropertyName 'immediate_recovery_trigger_bugs' -NotePropertyValue $triggerBugIds -Force
    }
    Set-ProposalStore -Store $store
    return @($proposals)
}

function Get-LcmProposalLifecycleAudit {
    [CmdletBinding()]
    param()

    $validStates = @('suggested', 'in_progress', 'verified', 'in_review', 'completed', 'pushed', 'held', 'withdrawn', 'rejected', 'superseded')
    $store = Get-ProposalStore
    $inventoryRoot = Split-Path (Split-Path (Split-Path (Get-ProposalStorePath) -Parent) -Parent) -Parent
    $findings = foreach ($proposal in @($store.proposals)) {
        $issues = @()
        if ($proposal.state -notin $validStates) {
            $issues += "invalid state '$($proposal.state)'"
        }
        $bundleDir = if ($proposal.PSObject.Properties['bundle_dir']) { [string]$proposal.bundle_dir } else { '' }
        if ([string]::IsNullOrWhiteSpace($bundleDir)) {
            $issues += 'missing bundle_dir'
        } else {
            $bundlePath = Join-Path $inventoryRoot $bundleDir
            if (-not (Test-Path -LiteralPath $bundlePath -PathType Container)) {
                $issues += "bundle directory not found: $bundleDir"
            } else {
                foreach ($documentName in @('specification', 'plan', 'walkthrough')) {
                    $documentPath = if ($proposal.PSObject.Properties['docs'] -and $proposal.docs -and $proposal.docs.PSObject.Properties[$documentName] -and $proposal.docs.$documentName) {
                        Join-Path $bundlePath $proposal.docs.$documentName
                    } else {
                        $null
                    }
                    if ([string]::IsNullOrWhiteSpace($documentPath) -or -not (Test-Path -LiteralPath $documentPath -PathType Leaf)) {
                        $issues += "missing $documentName document"
                    }
                }
            }
        }
        if ($issues.Count -gt 0) {
            [PSCustomObject]@{
                Id = $proposal.id
                CrpId = if ($proposal.crp_id) { $proposal.crp_id } else { $proposal.cr_id }
                State = $proposal.state
                Findings = $issues -join '; '
            }
        }
    }

    return @($findings)
}

function Set-WorkspaceProposalState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('bug', 'suggested', 'processed', 'approved', 'deferred', 'deleted', 'completed', 'completed [minimal-tests]', 'rejected', 'pushed', 'held')]
        [string]$State,

        [string]$Details
    )

    $lifecycleState = @{
        bug = 'in_progress'
        suggested = 'suggested'
        processed = 'in_progress'
        approved = 'in_progress'
        deferred = 'held'
        deleted = 'withdrawn'
        completed = 'completed'
        'completed [minimal-tests]' = 'completed'
        rejected = 'rejected'
        pushed = 'pushed'
        held = 'held'
    }[$State]
    return Move-LcmProposalLifecycleState -Id $Id -State $lifecycleState -Details $Details
}

function Set-WorkspaceProposalProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('undecided', 'queued', 'in_progress', 'verification', 'committed', 'completed', 'pushed', 'blocked', 'failed', 'deferred')]
        [string]$ProgressState,

        [string]$Details
    )

    $lifecycleState = @{
        undecided = 'suggested'
        queued = 'in_progress'
        in_progress = 'in_progress'
        verification = 'verified'
        committed = 'completed'
        completed = 'completed'
        pushed = 'pushed'
        blocked = 'held'
        failed = 'held'
        deferred = 'held'
    }[$ProgressState]
    return Move-LcmProposalLifecycleState -Id $Id -State $lifecycleState -Details $Details
}

function Set-WorkspaceProposalPriority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        $Priority,

        [string]$Details
    )

    $numericPrio = 5
    if ($Priority -is [int]) {
        $numericPrio = [Math]::Max(0, [Math]::Min(10, $Priority))
    } else {
        $str = ([string]$Priority).Trim()
        $parsed = 0
        if ([int]::TryParse($str, [ref]$parsed)) {
            $numericPrio = [Math]::Max(0, [Math]::Min(10, $parsed))
        } else {
            $numericPrio = switch -Regex ($str) {
                '^(?i)c(ritical)?$' { 10 }
                '^(?i)h(igh)?$'     { 8 }
                '^(?i)m(edium)?$'   { 5 }
                '^(?i)l(ow)?$'      { 3 }
                '^(?i)d(eferred)?$' { 1 }
                '^(?i)n(one)?$'     { 0 }
                default             { 5 }
            }
        }
    }

    $store = Get-ProposalStore
    $found = $null

    foreach ($p in $store.proposals) {
        if ($p.id -eq $Id) {
            $p | Add-Member -NotePropertyName "priority" -NotePropertyValue $numericPrio -Force
            if ($Details) {
                $p.details = $Details
            }
            $found = $p
            break
        }
    }

    if (-not $found) {
        Write-Error "Proposal #$Id not found in proposals store."
        return $null
    }

    Set-ProposalStore -Store $store
    Write-Host ("Updated Proposal #{0} priority to '{1}'." -f $Id, $numericPrio) -ForegroundColor Green
    return $found
}

function Save-ProposalPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [string]$PlanContent = '',
        [string]$SourceFilePath = ''
    )

    $store = Get-ProposalStore
    $target = $store.proposals | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $target) {
        throw "Proposal #$Id not found."
    }

    $wiRoot = (Get-Item (Get-ProposalStorePath)).Directory.Parent.FullName
    $relPath = if ($target.plan_path) { $target.plan_path } else { "LCM_Inventory/data/proposals/plans/Proposal-{0:D3}_Plan.md" -f $Id }
    $fullPath = Join-Path $wiRoot ($relPath -replace '^LCM_Inventory[\\\/]', '')

    $dir = [System.IO.Path]::GetDirectoryName($fullPath)
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($SourceFilePath) -and (Test-Path -LiteralPath $SourceFilePath)) {
        Copy-Item -LiteralPath $SourceFilePath -Destination $fullPath -Force
    } elseif (-not [string]::IsNullOrWhiteSpace($PlanContent)) {
        Set-Content -LiteralPath $fullPath -Value $PlanContent -Encoding UTF8
    } else {
        throw "Either -PlanContent or -SourceFilePath must be provided."
    }

    Write-Host "Archived Proposal #$Id Implementation Plan to CM: $fullPath" -ForegroundColor Green
    return $fullPath
}

function Save-ProposalWalkthrough {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [string]$WalkthroughContent = '',
        [string]$SourceFilePath = ''
    )

    $store = Get-ProposalStore
    $target = $store.proposals | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $target) {
        throw "Proposal #$Id not found."
    }

    $wiRoot = (Get-Item (Get-ProposalStorePath)).Directory.Parent.FullName
    $relPath = if ($target.walkthrough_path) { $target.walkthrough_path } else { "LCM_Inventory/data/proposals/plans/Proposal-{0:D3}_Walkthrough.md" -f $Id }
    $fullPath = Join-Path $wiRoot ($relPath -replace '^LCM_Inventory[\\\/]', '')

    $dir = [System.IO.Path]::GetDirectoryName($fullPath)
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($SourceFilePath) -and (Test-Path -LiteralPath $SourceFilePath)) {
        Copy-Item -LiteralPath $SourceFilePath -Destination $fullPath -Force
    } elseif (-not [string]::IsNullOrWhiteSpace($WalkthroughContent)) {
        Set-Content -LiteralPath $fullPath -Value $WalkthroughContent -Encoding UTF8
    } else {
        throw "Either -WalkthroughContent or -SourceFilePath must be provided."
    }

    Write-Host "Archived Proposal #$Id Walkthrough to CM: $fullPath" -ForegroundColor Green
    return $fullPath
}

function Resolve-ProposalIdExpression {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    $cleaned = $Expression.Trim().TrimStart('#').ToLowerInvariant()
    $store = Get-ProposalStore

    if ($cleaned -eq 'all') {
        $excludedStates = @('held', 'withdrawn', 'rejected', 'superseded', 'pushed')
        return @($store.proposals | Where-Object { $_.state -notin $excludedStates } | Select-Object -ExpandProperty id)
    }

    $targetIds = [System.Collections.Generic.List[int]]::new()

    # Split by comma or space
    $parts = $cleaned -split '[, ]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($part in $parts) {
        $p = ($part.Trim() -replace '(?i)^#?(?:crp|bug)-?', '').TrimStart('#')
        if ($p -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]
            if ($start -le $end) {
                for ($i = $start; $i -le $end; $i++) {
                    if (-not $targetIds.Contains($i)) { $targetIds.Add($i) }
                }
            } else {
                for ($i = $start; $i -ge $end; $i--) {
                    if (-not $targetIds.Contains($i)) { $targetIds.Add($i) }
                }
            }
        } elseif ($p -match '^\d+$') {
            $id = [int]$p
            if (-not $targetIds.Contains($id)) { $targetIds.Add($id) }
        }
    }

    return @($targetIds)
}

function Get-LcmReviewCohortResolution {
    [CmdletBinding()]
    param(
        [string]$Scope = '',

        [string]$BaseCommit = 'HEAD',

        [ValidateRange(1, 20)]
        [int]$MaxProposalCount = 3,

        [ValidateRange(1, 10)]
        [int]$MaxRepositoryCount = 1
    )

    $store = Get-ProposalStore
    $scopeValue = $Scope.Trim()
    $eligibleStates = @('in_progress', 'verified', 'in_review')
    $declaredCohorts = @(
    if ($store.PSObject.Properties['review_cohorts'] -and $store.review_cohorts) {
        @($store.review_cohorts | Where-Object {
            $state = if ($_.PSObject.Properties['state']) { [string]$_.state } else { 'open' }
            $state -eq 'open'
        })
    }
    )

    $resolutionKind = 'computed'
    $cohortId = $null
    $candidates = @()
    if ([string]::IsNullOrWhiteSpace($scopeValue)) {
        if ($declaredCohorts.Count -eq 1) {
            $declared = $declaredCohorts[0]
            $cohortId = if ($declared.PSObject.Properties['id']) { [string]$declared.id } else { [string]$declared.name }
            $memberIds = if ($declared.PSObject.Properties['proposal_ids']) { @($declared.proposal_ids) } else { @($declared.members) }
            if ($cohortId -notmatch '^COH-(\d+)$') {
                throw "Declared review cohort '$cohortId' must use the COH-<prime proposal ID> naming scheme."
            }
            if ($memberIds -notcontains [int]$Matches[1]) {
                throw "Declared review cohort '$cohortId' does not include its prime proposal ID."
            }
            $candidates = @($store.proposals | Where-Object { $_.id -in $memberIds })
            $resolutionKind = 'declared'
        } elseif ($declaredCohorts.Count -gt 1) {
            throw 'More than one declared open review cohort exists. Select an explicit cohort.'
        } else {
            $candidates = @($store.proposals | Where-Object { $_.state -in $eligibleStates })
        }
    } elseif ($scopeValue -match '^(?i)(?:#?(?:CRP|BUG)-?)?\d+(?:\s*,?\s*#?(?:CRP|BUG)-?\d+)*$') {
        $ids = @(Resolve-ProposalIdExpression -Expression $scopeValue)
        $candidates = @($store.proposals | Where-Object { $_.id -in $ids })
        if ($candidates.Count -ne $ids.Count) {
            throw "One or more explicit proposal identities in '$scopeValue' do not exist."
        }
        $resolutionKind = 'exact'
    } else {
        $declaredMatches = @($declaredCohorts | Where-Object {
            ($_.PSObject.Properties['id'] -and [string]$_.id -eq $scopeValue) -or
            ($_.PSObject.Properties['name'] -and [string]$_.name -eq $scopeValue)
        })
        if ($declaredMatches.Count -gt 1) {
            throw "Review cohort '$scopeValue' is ambiguous."
        }
        if ($declaredMatches.Count -eq 1) {
            $declared = $declaredMatches[0]
            $cohortId = if ($declared.PSObject.Properties['id']) { [string]$declared.id } else { [string]$declared.name }
            $memberIds = if ($declared.PSObject.Properties['proposal_ids']) { @($declared.proposal_ids) } else { @($declared.members) }
            if ($cohortId -notmatch '^COH-(\d+)$') {
                throw "Declared review cohort '$cohortId' must use the COH-<prime proposal ID> naming scheme."
            }
            if ($memberIds -notcontains [int]$Matches[1]) {
                throw "Declared review cohort '$cohortId' does not include its prime proposal ID."
            }
            $candidates = @($store.proposals | Where-Object { $_.id -in $memberIds })
            $resolutionKind = 'declared'
        } else {
            $candidates = @($store.proposals | Where-Object { $_.origin_repo -eq $scopeValue })
            if ($candidates.Count -eq 0) {
                throw "No declared review cohort, proposal, or repository matches '$scopeValue'."
            }
            $resolutionKind = 'repository'
        }
    }

    $members = @(
        foreach ($proposal in $candidates | Sort-Object id) {
            $state = [string]$proposal.state
            $classification = switch ($state) {
                'verified' { 'review_ready' }
                'in_review' { 'already_in_review' }
                'in_progress' { 'pending_verification' }
                default { 'excluded' }
            }
            [PSCustomObject]@{
                Id             = [int]$proposal.id
                Identity       = if ($proposal.PSObject.Properties['crp_id'] -and $proposal.crp_id) { [string]$proposal.crp_id } elseif ($proposal.PSObject.Properties['cr_id'] -and $proposal.cr_id) { [string]$proposal.cr_id } else { "CRP-$($proposal.id)" }
                Repository     = if ($proposal.PSObject.Properties['origin_repo'] -and $proposal.origin_repo) { [string]$proposal.origin_repo } else { 'LCM_Inventory' }
                State          = $state
                Classification = $classification
            }
        }
    )
    $repositories = @($members | Select-Object -ExpandProperty Repository -Unique | Sort-Object)
    $broadeningReasons = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($scopeValue)) { $broadeningReasons.Add('scope omitted') }
    if ($members.Count -gt 1) { $broadeningReasons.Add('multiple proposals') }
    if ($repositories.Count -gt 1) { $broadeningReasons.Add('multiple repositories') }
    if ($members.Count -gt $MaxProposalCount) { $broadeningReasons.Add("proposal limit $MaxProposalCount exceeded") }
    if ($repositories.Count -gt $MaxRepositoryCount) { $broadeningReasons.Add("repository limit $MaxRepositoryCount exceeded") }

    $needsSelection = $members.Count -eq 0 -or (
        $resolutionKind -ne 'declared' -and
        ($members.Count -gt $MaxProposalCount -or $repositories.Count -gt $MaxRepositoryCount)
    )
    $requiresConfirmation = $resolutionKind -ne 'declared' -and $broadeningReasons.Count -gt 0
    $receiptPayload = [ordered]@{
        resolution_kind     = $resolutionKind
        declared_cohort_id  = $cohortId
        scope               = $scopeValue
        baseline            = $BaseCommit
        members             = $members
        repositories        = $repositories
        broadening_reasons  = @($broadeningReasons)
        needs_selection     = $needsSelection
    }
    $fingerprintBytes = [Text.Encoding]::UTF8.GetBytes(($receiptPayload | ConvertTo-Json -Depth 5 -Compress))
    $fingerprint = ([Security.Cryptography.SHA256]::Create().ComputeHash($fingerprintBytes) | ForEach-Object ToString x2) -join ''

    return [PSCustomObject]@{
        ResolutionKind      = $resolutionKind
        DeclaredCohortId    = $cohortId
        Baseline            = $BaseCommit
        Members             = $members
        Repositories        = $repositories
        BroadeningReasons   = @($broadeningReasons)
        RequiresConfirmation = $requiresConfirmation
        NeedsSelection      = $needsSelection
        Fingerprint         = $fingerprint
    }
}

function Save-LcmReviewCohortReceipt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Resolution
    )

    $inventoryRoot = Split-Path (Split-Path (Split-Path (Get-ProposalStorePath) -Parent) -Parent) -Parent
    $receiptScope = if (-not [string]::IsNullOrWhiteSpace($Resolution.DeclaredCohortId)) {
        $Resolution.DeclaredCohortId
    } else {
        "BCR-Cohort-$($Resolution.Fingerprint.Substring(0, 12))"
    }
    $reviewsDirectory = Join-Path $inventoryRoot "scratch\BC_Review\$receiptScope"
    if (-not (Test-Path -LiteralPath $reviewsDirectory)) {
        New-Item -ItemType Directory -Path $reviewsDirectory -Force | Out-Null
    }
    $receipt = [ordered]@{
        resolved_at          = (Get-Date).ToString('o')
        resolution_kind      = $Resolution.ResolutionKind
        declared_cohort_id   = $Resolution.DeclaredCohortId
        baseline             = $Resolution.Baseline
        members              = $Resolution.Members
        repositories         = $Resolution.Repositories
        broadening_reasons   = $Resolution.BroadeningReasons
        requires_confirmation = $Resolution.RequiresConfirmation
        needs_selection      = $Resolution.NeedsSelection
        fingerprint          = $Resolution.Fingerprint
    }
    $receiptPath = Join-Path $reviewsDirectory ("BCR-Cohort-{0}.json" -f $Resolution.Fingerprint.Substring(0, 12))
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
    $canonicalPath = Join-Path $reviewsDirectory 'cohort-resolution.json'
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $canonicalPath -Encoding UTF8
    return $receiptPath
}

function Get-LcmReviewCohortCompletionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CohortId
    )

    $resolution = Get-LcmReviewCohortResolution -Scope $CohortId
    if ($resolution.ResolutionKind -ne 'declared') {
        throw "Completion requires a declared cohort; '$CohortId' did not resolve to one."
    }
    $notReviewing = @($resolution.Members | Where-Object { $_.State -ne 'in_review' })
    if ($notReviewing.Count -gt 0) {
        throw "Cohort '$CohortId' cannot complete because these members are not in_review: $($notReviewing.Identity -join ', ')."
    }
    $inventoryRoot = Split-Path (Split-Path (Split-Path (Get-ProposalStorePath) -Parent) -Parent) -Parent
    $stagingRoot = Join-Path $inventoryRoot "scratch\BC_Review\$CohortId"
    $candidateReceipts = @(
        (Join-Path $stagingRoot 'cohort-resolution.json')
    ) + @(Get-ChildItem -LiteralPath $stagingRoot -Filter 'BCR-Cohort-*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName)
    $existingReceipts = @($candidateReceipts | Where-Object { Test-Path -LiteralPath $_ })
    $receiptPath = if ($existingReceipts.Count -gt 0) { $existingReceipts[0] } else { $null }
    if (-not $receiptPath) {
        throw "Cohort staging receipt is missing: $(Join-Path $stagingRoot 'cohort-resolution.json')"
    }
    $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $receiptMemberIds = @($receipt.members | ForEach-Object { [int]$_.Id } | Sort-Object)
    $currentMemberIds = @($resolution.Members | ForEach-Object { [int]$_.Id } | Sort-Object)
    $memberMismatch = ($receiptMemberIds -join ',') -ne ($currentMemberIds -join ',')
    if ($receipt.fingerprint -ne $resolution.Fingerprint -and $memberMismatch) {
        throw "Cohort staging receipt is stale for '$CohortId'. Relaunch BCR before completion."
    }
    return [PSCustomObject]@{
        CohortId = $CohortId
        ReceiptPath = $receiptPath
        Repositories = @($resolution.Members | Group-Object Repository | ForEach-Object {
            [PSCustomObject]@{
                Repository = $_.Name
                Members = @($_.Group)
            }
        })
    }
}

function Complete-LcmReviewCohortAcceptance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^COH-\d+$')]
        [string]$CohortId,

        [Parameter(Mandatory = $true)]
        [string]$ResolutionReceiptPath,

        [Parameter(Mandatory = $true)]
        [hashtable]$ReviewReceiptPaths,

        [string]$Details = ''
    )

    $plan = Get-LcmReviewCohortCompletionPlan -CohortId $CohortId
    if (-not (Test-Path -LiteralPath $ResolutionReceiptPath -PathType Leaf)) {
        throw "Cohort BCR receipt is missing: $ResolutionReceiptPath"
    }

    $store = Get-ProposalStore
    $cohort = @($store.review_cohorts | Where-Object { $_.id -eq $CohortId })[0]
    if ($null -eq $cohort -or [string]$cohort.state -ne 'open') {
        throw "Review cohort '$CohortId' is not open for accepted completion."
    }

    $memberIds = @($cohort.proposal_ids | ForEach-Object { [int]$_ } | Sort-Object)
    $plannedMemberIds = @($plan.Repositories | ForEach-Object Members | ForEach-Object { [int]$_.Id } | Sort-Object)
    if (($memberIds -join ',') -ne ($plannedMemberIds -join ',')) {
        throw "Cohort '$CohortId' membership changed after completion preflight. Relaunch BCR before completion."
    }

    $failures = [System.Collections.Generic.List[string]]::new()
    foreach ($repositoryPlan in $plan.Repositories) {
        $repository = [string]$repositoryPlan.Repository
        if (-not $ReviewReceiptPaths.ContainsKey($repository) -or
            -not (Test-Path -LiteralPath ([string]$ReviewReceiptPaths[$repository]) -PathType Leaf)) {
            $failures.Add("Repository '$repository' has no accepted review receipt.")
        }
        foreach ($member in $repositoryPlan.Members) {
            $proposal = @($store.proposals | Where-Object { $_.id -eq $member.Id })[0]
            if ($null -eq $proposal) {
                $failures.Add("Proposal #$($member.Id) is missing.")
            } elseif ([string]$proposal.state -ne 'in_review') {
                $failures.Add("Proposal #$($member.Id) is '$($proposal.state)', not in_review.")
            } elseif (-not $proposal.PSObject.Properties['bcr_initiated_at'] -or
                [string]::IsNullOrWhiteSpace([string]$proposal.bcr_initiated_at)) {
                $failures.Add("Proposal #$($member.Id) has no BCR initiation evidence.")
            } elseif (-not $proposal.PSObject.Properties['bcr_scope'] -or
                [string]$proposal.bcr_scope -ne $CohortId) {
                $failures.Add("Proposal #$($member.Id) is not scoped to BCR cohort '$CohortId'.")
            }
        }
    }
    if ($failures.Count -gt 0) {
        throw "Cohort '$CohortId' accepted completion was rejected; no member changed. $($failures -join ' ')"
    }

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $updated = @()
    foreach ($repositoryPlan in $plan.Repositories) {
        $repository = [string]$repositoryPlan.Repository
        $reviewReceiptPath = [string]$ReviewReceiptPaths[$repository]
        foreach ($member in $repositoryPlan.Members) {
            $proposal = @($store.proposals | Where-Object { $_.id -eq $member.Id })[0]
            $proposal | Add-Member -NotePropertyName 'bcr_disposition' -NotePropertyValue 'Completed' -Force
            $proposal | Add-Member -NotePropertyName 'bcr_disposition_at' -NotePropertyValue $timestamp -Force
            $proposal | Add-Member -NotePropertyName 'bcr_disposition_notes' -NotePropertyValue $Details -Force
            $proposal | Add-Member -NotePropertyName 'bcr_resolution_receipt' -NotePropertyValue $ResolutionReceiptPath -Force
            $proposal | Add-Member -NotePropertyName 'bcr_review_receipt' -NotePropertyValue $reviewReceiptPath -Force
            $proposal | Add-Member -NotePropertyName 'bcr_audit' -NotePropertyValue @(
                [PSCustomObject]@{
                    disposition = 'Completed'
                    timestamp = $timestamp
                    cohort_id = $CohortId
                    resolution_receipt = $ResolutionReceiptPath
                    review_receipt = $reviewReceiptPath
                    note = $Details
                }
            ) -Force
            $updated += Move-LcmProposalLifecycleState -Id $member.Id -State completed -Details "Cohort $CohortId accepted review completed." -Store $store -SkipPersist -CohortId $CohortId -Gate Completion -SynchronizationOutcome synchronized
        }
    }

    $cohort | Add-Member -NotePropertyName 'state' -NotePropertyValue 'closed' -Force
    $cohort | Add-Member -NotePropertyName 'closed_at' -NotePropertyValue $timestamp -Force
    $cohort | Add-Member -NotePropertyName 'updated_at' -NotePropertyValue $timestamp -Force
    $cohort | Add-Member -NotePropertyName 'completion_audit' -NotePropertyValue ([PSCustomObject]@{
        disposition = 'Completed'
        timestamp = $timestamp
        resolution_receipt = $ResolutionReceiptPath
        review_receipts = $ReviewReceiptPaths
        member_ids = $memberIds
        note = $Details
    }) -Force
    Set-ProposalStore -Store $store
    if ($updated.Count -gt 0) {
        Update-LcmControlHubAfterCompletion -ProposalId @($updated | ForEach-Object { [int]$_.id })
    }
    return @($updated)
}

function Set-LcmReviewCohort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('create', 'add', 'remove', 'hold', 'reopen', 'close')]
        [string]$Action,

        [int[]]$ProposalIds = @(),

        [string]$CohortId = '',

        [switch]$AllowCrossRepository
    )

    $store = Get-ProposalStore
    if (-not $store.PSObject.Properties['review_cohorts'] -or $null -eq $store.review_cohorts) {
        $store | Add-Member -NotePropertyName 'review_cohorts' -NotePropertyValue @() -Force
    }
    $openCohorts = @($store.review_cohorts | Where-Object { $_.state -eq 'open' })
    if ($openCohorts.Count -gt 1) {
        throw 'The proposal ledger contains more than one open review cohort. Resolve the ledger conflict before changing membership.'
    }

    if ($Action -eq 'create') {
        if ($ProposalIds.Count -eq 0) {
            throw 'Creating a review cohort requires one explicit head/prime proposal ID; additional member IDs are optional.'
        }
        $primeId = $ProposalIds[0]
        $CohortId = if ([string]::IsNullOrWhiteSpace($CohortId)) { "COH-$primeId" } else { $CohortId }
        if ($CohortId -ne "COH-$primeId") {
            throw "Cohort ID '$CohortId' must match its first prime proposal ID: COH-$primeId."
        }
        $memberIds = @($ProposalIds | Select-Object -Unique)
        $members = @($store.proposals | Where-Object { $_.id -in $memberIds })
        if ($members.Count -ne $memberIds.Count) {
            throw 'A review cohort cannot include an unknown proposal ID.'
        }
        $repositories = @($members | ForEach-Object { if ($_.PSObject.Properties['origin_repo'] -and $_.origin_repo) { [string]$_.origin_repo } else { 'LCM_Inventory' } } | Select-Object -Unique)
        if ($repositories.Count -gt 1 -and -not $AllowCrossRepository) {
            throw 'A cross-repository cohort requires explicit confirmation.'
        }
        $cohort = [PSCustomObject]@{
            id                  = $CohortId
            state               = 'open'
            prime_proposal_id   = $primeId
            proposal_ids        = $memberIds
            repositories        = $repositories
            created_at          = (Get-Date).ToString('o')
            updated_at          = (Get-Date).ToString('o')
        }
        $persistStore = Get-ProposalStore
        if (-not $persistStore.PSObject.Properties['review_cohorts'] -or $null -eq $persistStore.review_cohorts) {
            $persistStore | Add-Member -NotePropertyName 'review_cohorts' -NotePropertyValue @() -Force
        }
        $persistOpenCohorts = @($persistStore.review_cohorts | Where-Object { $_.state -eq 'open' })
        if ($persistOpenCohorts.Count -gt 1) {
            throw 'The proposal ledger contains more than one open review cohort. Resolve the ledger conflict before creating another cohort.'
        }
        $cohort.state = if ($persistOpenCohorts.Count -eq 0) { 'open' } else { 'inactive' }
        $persistStore.review_cohorts = @($persistStore.review_cohorts) + $cohort
        Set-ProposalStore -Store $persistStore
        return $cohort
    }

    if ($Action -eq 'reopen') {
        if ($openCohorts.Count -ne 0) {
            throw "Open review cohort '$($openCohorts[0].id)' already exists. Close or hold it before reopening another cohort."
        }
        $inactiveCohorts = @($store.review_cohorts | Where-Object { $_.state -in @('held', 'inactive') })
        $reopenCandidates = if ([string]::IsNullOrWhiteSpace($CohortId)) {
            $inactiveCohorts
        } else {
            @($inactiveCohorts | Where-Object { $_.id -eq $CohortId })
        }
        if ($reopenCandidates.Count -eq 0) {
            throw 'No inactive review cohort is available to open.'
        }
        if ($reopenCandidates.Count -gt 1) {
            throw 'Multiple inactive review cohorts exist. Specify -CohortId to open one.'
        }
        $reopenCandidate = $reopenCandidates[0]
        $persistStore = Get-ProposalStore
        $persistOpenCohorts = @($persistStore.review_cohorts | Where-Object { $_.state -eq 'open' })
        if ($persistOpenCohorts.Count -ne 0) {
            throw "Open review cohort '$($persistOpenCohorts[0].id)' already exists. Close or hold it before reopening another cohort."
        }
        $persistCandidates = @($persistStore.review_cohorts | Where-Object {
            $_.id -eq $reopenCandidate.id -and $_.state -in @('held', 'inactive')
        })
        if ($persistCandidates.Count -ne 1) {
            throw "Inactive review cohort '$($reopenCandidate.id)' is no longer available to open."
        }
        $cohort = $persistCandidates[0]
        $cohort.state = 'open'
        $reopenedAt = (Get-Date).ToString('o')
        $cohort | Add-Member -NotePropertyName 'reopened_at' -NotePropertyValue $reopenedAt -Force
        $cohort.updated_at = $reopenedAt
        Set-ProposalStore -Store $persistStore
        return $cohort
    }

    if ($openCohorts.Count -eq 0) {
        throw 'No open review cohort exists. Create a review cohort before adding members.'
    }
    $cohort = $openCohorts[0]
    if (-not [string]::IsNullOrWhiteSpace($CohortId) -and $CohortId -ne $cohort.id) {
        throw "Open review cohort '$($cohort.id)' does not match requested cohort '$CohortId'."
    }

    if ($Action -eq 'close') {
        $cohort.state = 'closed'
        $closedAt = (Get-Date).ToString('o')
        $cohort | Add-Member -NotePropertyName 'closed_at' -NotePropertyValue $closedAt -Force
        $cohort.updated_at = $closedAt
        Set-ProposalStore -Store $store
        return $cohort
    }

    if ($Action -eq 'hold') {
        $cohort.state = 'held'
        $heldAt = (Get-Date).ToString('o')
        $cohort | Add-Member -NotePropertyName 'held_at' -NotePropertyValue $heldAt -Force
        $cohort.updated_at = $heldAt
        Set-ProposalStore -Store $store
        return $cohort
    }

    if ($ProposalIds.Count -eq 0) {
        throw "Cohort action '$Action' requires one or more explicit proposal IDs."
    }
    $persistStore = Get-ProposalStore
    $persistOpenCohorts = @($persistStore.review_cohorts | Where-Object { $_.state -eq 'open' })
    if ($persistOpenCohorts.Count -eq 0) {
        throw 'No open review cohort exists. Create a review cohort before adding members.'
    }
    if ($persistOpenCohorts.Count -gt 1) {
        throw 'The proposal ledger contains more than one open review cohort. Resolve the ledger conflict before changing membership.'
    }
    if ($persistOpenCohorts[0].id -ne $cohort.id) {
        throw "Open review cohort '$($persistOpenCohorts[0].id)' does not match requested cohort '$($cohort.id)'."
    }
    $cohort = $persistOpenCohorts[0]
    $currentIds = @($cohort.proposal_ids | ForEach-Object { [int]$_ })
    if ($Action -eq 'add') {
        $duplicateIds = @($ProposalIds | Where-Object { $currentIds -contains $_ } | Select-Object -Unique)
        if ($duplicateIds.Count -gt 0) {
            throw "Cohort '$($cohort.id)' already includes proposal ID(s): #$($duplicateIds -join ', #')."
        }
        $allIds = @($currentIds + $ProposalIds | Select-Object -Unique)
        $members = @($persistStore.proposals | Where-Object { $_.id -in $allIds })
        if ($members.Count -ne $allIds.Count) {
            throw 'A review cohort cannot include an unknown proposal ID.'
        }
        $repositories = @($members | ForEach-Object { if ($_.PSObject.Properties['origin_repo'] -and $_.origin_repo) { [string]$_.origin_repo } else { 'LCM_Inventory' } } | Select-Object -Unique)
        if ($repositories.Count -gt 1 -and -not $AllowCrossRepository) {
            throw 'Adding this proposal creates a cross-repository cohort and requires explicit confirmation.'
        }
        $cohort.proposal_ids = $allIds
        $cohort.repositories = $repositories
    } else {
        if ($ProposalIds -contains [int]$cohort.prime_proposal_id) {
            throw "The prime proposal #$($cohort.prime_proposal_id) cannot be removed from '$($cohort.id)'. Close the cohort instead."
        }
        $cohort.proposal_ids = @($currentIds | Where-Object { $_ -notin $ProposalIds })
        $cohort.repositories = @($persistStore.proposals | Where-Object { $_.id -in $cohort.proposal_ids } | ForEach-Object { if ($_.PSObject.Properties['origin_repo'] -and $_.origin_repo) { [string]$_.origin_repo } else { 'LCM_Inventory' } } | Select-Object -Unique)
    }
    $cohort | Add-Member -NotePropertyName 'updated_at' -NotePropertyValue (Get-Date).ToString('o') -Force
    Set-ProposalStore -Store $persistStore
    return $cohort
}

function Invoke-LcmCohortLifecycleAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CohortId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('do', 'proceed', 'verify', 'bcr', 'complete', 'push', 'hold', 'reopen', 'withdraw')]
        [string]$Action,

        [string]$Details
    )

    $gate = switch ($Action) {
        { $_ -in @('do', 'proceed') } { 'Gate1' }
        'verify' { 'Verification' }
        'bcr' { 'BCR' }
        'complete' { 'Completion' }
        default { '' }
    }
    if ($gate) {
        $synchronization = Sync-LcmCohortGateState -CohortId $CohortId -Gate $gate -Details $Details
        if ($Action -in @('do', 'proceed', 'verify')) {
            return @($synchronization.Members)
        }
        if ($Action -eq 'bcr') {
            return @($synchronization.Members)
        }
    }

    $store = Get-ProposalStore
    $cohort = @($store.review_cohorts | Where-Object { $_.id -eq $CohortId })[0]
    if ($null -eq $cohort) { throw "Review cohort '$CohortId' was not found." }
    $memberIds = @($cohort.proposal_ids | ForEach-Object { [int]$_ })
    $targetState = @{
        complete = 'completed'; push = 'pushed'; hold = 'held'; reopen = $null; withdraw = 'withdrawn'
    }[$Action]
    $failures = @()
    $members = @()
    foreach ($id in $memberIds) {
        $proposal = @($store.proposals | Where-Object { $_.id -eq $id })[0]
        if ($null -eq $proposal) {
            $failures += "Proposal #$id was not found."
            continue
        }
        $toState = if ($Action -eq 'reopen') {
            Get-LcmProposalResumeState -Proposal $proposal
        } else {
            $targetState
        }
        $fromState = if ([string]$proposal.state -eq 'approved') { 'in_progress' } else { [string]$proposal.state }
        if ([string]::IsNullOrWhiteSpace($toState) -or -not (Test-LcmProposalLifecycleTransition -FromState $fromState -ToState $toState)) {
            $failures += "Proposal #$id is '$fromState' and cannot transition for cohort action '$Action'."
            continue
        }
        if ($toState -eq 'completed') {
            $hasDisposition = $proposal.PSObject.Properties['bcr_disposition'] -and
                -not [string]::IsNullOrWhiteSpace([string]$proposal.bcr_disposition)
            $hasAuthorizedBypass = $proposal.PSObject.Properties['bcr_bypass_authorized'] -and
                [bool]$proposal.bcr_bypass_authorized
            if (-not $hasDisposition -and -not $hasAuthorizedBypass) {
                $failures += "Proposal #$id cannot pass the review gate without a recorded BCR disposition or explicit authorized BCR bypass."
                continue
            }
        }
        $members += [PSCustomObject]@{ Id = $id; State = $toState }
    }
    if ($failures.Count -gt 0) {
        throw "Cohort action '$Action' was rejected; no member changed. $($failures -join ' ')"
    }

    $updated = foreach ($member in $members) {
        Move-LcmProposalLifecycleState -Id $member.Id -State $member.State -Details $Details -Store $store -SkipPersist -CohortId $CohortId -Gate $gate -SynchronizationOutcome synchronized
    }
    $cohort | Add-Member -NotePropertyName 'updated_at' -NotePropertyValue (Get-Date).ToString('o') -Force
    Set-ProposalStore -Store $store
    if ($Action -eq 'complete' -and $updated.Count -gt 0) {
        Update-LcmControlHubAfterCompletion -ProposalId @($updated | ForEach-Object { [int]$_.id })
    }
    return @($updated)
}

function Test-LcmProposalVerificationPrecondition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Proposal
    )

    $status = if ($Proposal.PSObject.Properties['verification_status']) { [string]$Proposal.verification_status } else { '' }
    $hasEvidence = $Proposal.PSObject.Properties['verification_evidence'] -and
        -not [string]::IsNullOrWhiteSpace([string]$Proposal.verification_evidence)
    return $status -in @('passed', 'validated') -or $hasEvidence
}

function Sync-LcmCohortGateState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CohortId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Gate1', 'Verification', 'BCR', 'Completion')]
        [string]$Gate,

        [string]$Details = ''
    )

    $store = Get-ProposalStore
    $cohort = @($store.review_cohorts | Where-Object { $_.id -eq $CohortId })[0]
    if ($null -eq $cohort) { throw "Review cohort '$CohortId' was not found." }
    if ([string]$cohort.state -ne 'open') {
        throw "Review cohort '$CohortId' is '$($cohort.state)' and cannot pass lifecycle gate '$Gate'."
    }

    $requiredState = @{
        Gate1 = 'in_progress'
        Verification = 'verified'
        BCR = 'verified'
        Completion = 'in_review'
    }[$Gate]
    $memberIds = @($cohort.proposal_ids | ForEach-Object { [int]$_ } | Select-Object -Unique)
    $plans = @()
    $stopped = @()
    foreach ($id in $memberIds) {
        $proposal = @($store.proposals | Where-Object { $_.id -eq $id })[0]
        if ($null -eq $proposal) {
            $stopped += "Proposal #$id is missing."
            continue
        }
        $currentState = if ([string]$proposal.state -eq 'approved') { 'in_progress' } else { [string]$proposal.state }
        if ($currentState -eq $requiredState -or ($Gate -eq 'BCR' -and $currentState -eq 'in_review')) {
            $plans += [PSCustomObject]@{ Proposal = $proposal; TargetState = $requiredState; Outcome = 'no_op' }
            continue
        }
        if (($requiredState -eq 'in_progress' -and $currentState -in @('verified', 'in_review', 'completed', 'pushed')) -or
            ($requiredState -eq 'verified' -and $currentState -in @('in_review', 'completed', 'pushed'))) {
            $stopped += "Proposal #$id cannot synchronize from '$currentState' to '$requiredState' for $Gate because it has already passed the required gate state."
            continue
        }
        if ($requiredState -eq 'verified' -and $currentState -eq 'in_progress' -and -not (Test-LcmProposalVerificationPrecondition -Proposal $proposal)) {
            $stopped += "Proposal #$id cannot synchronize to verified: validated verification evidence is missing."
            continue
        }
        if (-not (Test-LcmProposalLifecycleTransition -FromState $currentState -ToState $requiredState)) {
            $stopped += "Proposal #$id cannot synchronize from '$currentState' to '$requiredState' for $Gate."
            continue
        }
        $plans += [PSCustomObject]@{ Proposal = $proposal; TargetState = $requiredState; Outcome = 'synchronized' }
    }
    if ($stopped.Count -gt 0) {
        $timestamp = (Get-Date).ToString('o')
        if (-not $cohort.PSObject.Properties['gate_history']) {
            $cohort | Add-Member -NotePropertyName 'gate_history' -NotePropertyValue @() -Force
        }
        $cohort.gate_history = @($cohort.gate_history) + [PSCustomObject]@{
            gate = $Gate
            required_state = $requiredState
            timestamp = $timestamp
            synchronized_member_ids = @()
            no_op_member_ids = @()
            stopped_members = @($stopped)
        }
        $cohort | Add-Member -NotePropertyName 'updated_at' -NotePropertyValue $timestamp -Force
        Set-ProposalStore -Store $store
        throw "Cohort gate '$Gate' stopped; no member changed. $($stopped -join ' ')"
    }

    $updated = foreach ($plan in $plans) {
        if ($plan.Outcome -eq 'no_op') {
            $plan.Proposal | Add-Member -NotePropertyName 'cohort_gate_last_outcome' -NotePropertyValue 'no_op' -Force
            $plan.Proposal | Add-Member -NotePropertyName 'cohort_gate_last_gate' -NotePropertyValue $Gate -Force
            $plan.Proposal
        } else {
            Move-LcmProposalLifecycleState -Id $plan.Proposal.id -State $plan.TargetState -Details $Details -Store $store -SkipPersist -CohortId $CohortId -Gate $Gate -SynchronizationOutcome synchronized
        }
    }
    $timestamp = (Get-Date).ToString('o')
    if (-not $cohort.PSObject.Properties['gate_history']) {
        $cohort | Add-Member -NotePropertyName 'gate_history' -NotePropertyValue @() -Force
    }
    $cohort.gate_history = @($cohort.gate_history) + [PSCustomObject]@{
        gate = $Gate
        required_state = $requiredState
        timestamp = $timestamp
        synchronized_member_ids = @($plans | Where-Object Outcome -eq 'synchronized' | ForEach-Object { $_.Proposal.id })
        no_op_member_ids = @($plans | Where-Object Outcome -eq 'no_op' | ForEach-Object { $_.Proposal.id })
        stopped_members = @()
    }
    $cohort | Add-Member -NotePropertyName 'updated_at' -NotePropertyValue $timestamp -Force
    Set-ProposalStore -Store $store
    return [PSCustomObject]@{
        CohortId = $CohortId
        Gate = $Gate
        RequiredState = $requiredState
        Members = @($updated)
        SynchronizedMemberIds = @($plans | Where-Object Outcome -eq 'synchronized' | ForEach-Object { $_.Proposal.id })
        NoOpMemberIds = @($plans | Where-Object Outcome -eq 'no_op' | ForEach-Object { $_.Proposal.id })
        StoppedMembers = @()
    }
}

function Set-LcmProposalSupersession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [int]$SuccessorId,

        [string]$Details
    )

    if ($Id -eq $SuccessorId) { throw 'A proposal cannot supersede itself.' }
    $store = Get-ProposalStore
    $proposal = @($store.proposals | Where-Object { $_.id -eq $Id })[0]
    $successor = @($store.proposals | Where-Object { $_.id -eq $SuccessorId })[0]
    if ($null -eq $proposal) { throw "Proposal #$Id was not found." }
    if ($null -eq $successor) { throw "Successor proposal #$SuccessorId was not found." }
    if ([string]$successor.state -in @('withdrawn', 'rejected', 'superseded')) {
        throw "Successor proposal #$SuccessorId is not active."
    }

    $updated = Move-LcmProposalLifecycleState -Id $Id -State superseded -Details $Details -Store $store -SkipPersist
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $updated | Add-Member -NotePropertyName 'superseded_by_id' -NotePropertyValue $SuccessorId -Force
    $updated | Add-Member -NotePropertyName 'superseded_at' -NotePropertyValue $timestamp -Force
    $successor | Add-Member -NotePropertyName 'supersedes_id' -NotePropertyValue $Id -Force
    $successor | Add-Member -NotePropertyName 'supersedes_at' -NotePropertyValue $timestamp -Force
    Set-ProposalStore -Store $store
    return $updated
}

function Set-LcmProposalRetirement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Details
    )

    if ([string]::IsNullOrWhiteSpace($Details)) {
        throw 'Retiring a proposal requires documented details.'
    }
    $updated = Move-LcmProposalLifecycleState -Id $Id -State withdrawn -Details $Details
    $updated | Add-Member -NotePropertyName 'retired_at' -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
    $updated | Add-Member -NotePropertyName 'retirement_reason' -NotePropertyValue $Details -Force
    Set-ProposalStore -Store (Get-ProposalStore)
    return $updated
}

function Invoke-ProposalBatchAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('do', 'delete', 'defer', 'deferred', 'complete', 'completed', 'suggest', 'suggested', 'reject', 'rejected', 'approve', 'approved', 'bug', 'push', 'pushed', 'hold', 'held', 'resume', 'continue', 'withdraw', 'supersede', 'reopen', 'reinstate', 'reset')]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$TargetExpression,

        [string]$Details = '',

        [string]$Changes = ''
    )

    $targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
    if ($targetIds.Count -eq 0) {
        throw "Target expression '$TargetExpression' did not resolve to any CRP IDs."
    }

    if ($TargetExpression.Trim().ToLowerInvariant() -ne 'all') {
        $store = Get-ProposalStore
        $knownIds = @($store.proposals | ForEach-Object { [int]$_.id })
        $unresolvedIds = @($targetIds | Where-Object { $_ -notin $knownIds })
        if ($unresolvedIds.Count -gt 0) {
            throw ("Target expression '{0}' contains unresolved CRP ID(s): {1}. No lifecycle action was applied." -f $TargetExpression, ($unresolvedIds -join ', '))
        }
    }

    $mappedState = switch ($Action) {
        { $_ -in @('do', 'approve', 'approved', 'bug') } { 'in_progress' }
        'reopen' { 'in_progress' }
        { $_ -in @('delete', 'defer', 'deferred', 'hold', 'held') } { 'held' }
        { $_ -in @('complete', 'completed') } { 'completed' }
        { $_ -in @('suggest', 'suggested', 'reset') } { 'suggested' }
        { $_ -in @('reject', 'rejected') } { 'rejected' }
        { $_ -in @('push', 'pushed') } { 'pushed' }
        'withdraw' { 'withdrawn' }
        'supersede' { 'superseded' }
        'reinstate' { $null }
    }

    if ($TargetExpression.Trim().ToLowerInvariant() -eq 'all') {
        $store = Get-ProposalStore
        $targetIds = @(
            foreach ($proposal in $store.proposals) {
                $currentState = [string]$proposal.state
                if ($currentState -eq 'approved') { $currentState = 'in_progress' }
                $targetState = $mappedState
                if ($Action -eq 'reinstate' -and $currentState -in @('completed', 'pushed')) {
                    $proposal.id
                } elseif ($Action -in @('resume', 'continue', 'reopen') -and $currentState -eq 'held') {
                    $targetState = Get-LcmProposalResumeState -Proposal $proposal
                }
                if (-not [string]::IsNullOrWhiteSpace($targetState) -and
                    (Test-LcmProposalLifecycleTransition -FromState $currentState -ToState $targetState)) {
                    $proposal.id
                }
            }
        )
        if ($targetIds.Count -eq 0) {
            throw "No proposals are eligible for lifecycle action '$Action'."
        }
    }

    $validationFailures = @()
    $failureRecords = @()
    foreach ($id in $targetIds) {
        $targetState = $mappedState
        $store = Get-ProposalStore
        $proposal = @($store.proposals | Where-Object { $_.id -eq $id })[0]
        if ($null -eq $proposal) {
            $validationFailures += "Proposal #$id was not found."
            $failureRecords += [PSCustomObject]@{
                identity = "CRP-$id"
                current_state = 'unresolved'
                requested_state = $targetState
                reason = "The requested proposal ID is not present in the lifecycle ledger."
                conflict_type = 'target-resolution failure'
                source = [PSCustomObject]@{ repository = 'LCM_Inventory'; path = 'modules\ProposalManager.psm1'; symbol = 'Invoke-ProposalBatchAction' }
                governing_references = @('ProposalReviewFlowPolicy.md: lifecycle target selection')
            }
            continue
        }
        $currentState = [string]$proposal.state
        if ($currentState -eq 'approved') {
            $currentState = 'in_progress'
        }
        if ($Action -eq 'do' -and $currentState -ne 'suggested') {
            $validationFailures += "Proposal #$id cannot run action 'do' from '$currentState'; Do is available only from suggested."
            $failureRecords += [PSCustomObject]@{
                identity = if ($proposal.PSObject.Properties['crp_id'] -and $proposal.crp_id) { [string]$proposal.crp_id } else { "CRP-$id" }
                current_state = $currentState
                requested_state = 'in_progress'
                reason = "Do is an activation action and is unavailable after this proposal has passed the suggested state."
                conflict_type = 'invalid transition'
                source = [PSCustomObject]@{ repository = 'LCM_Inventory'; path = 'modules\ProposalManager.psm1'; symbol = 'Invoke-ProposalBatchAction' }
                governing_references = @('RULE-LCM-014', 'ProposalReviewFlowPolicy.md: lifecycle action table')
            }
            continue
        }
        if ($Action -eq 'reinstate') {
            if ($currentState -notin @('completed', 'pushed')) {
                $validationFailures += "Proposal #$id can be reinstated only from completed or pushed; found '$currentState'."
                $failureRecords += [PSCustomObject]@{
                    identity = if ($proposal.PSObject.Properties['crp_id'] -and $proposal.crp_id) { [string]$proposal.crp_id } else { "CRP-$id" }
                    current_state = $currentState
                    requested_state = 'suggested or in_progress'
                    reason = 'Reinstatement preserves delivery evidence and is available only after completion or publication.'
                    conflict_type = 'invalid transition'
                    source = [PSCustomObject]@{ repository = 'LCM_Inventory'; path = 'modules\ProposalManager.psm1'; symbol = 'Invoke-ProposalBatchAction' }
                    governing_references = @('RULE-LCM-014', 'ProposalReviewFlowPolicy.md: lifecycle action table')
                }
            }
            continue
        }
        if ($Action -in @('resume', 'continue', 'reopen') -and $proposal.state -eq 'held') {
            $targetState = Get-LcmProposalResumeState -Proposal $proposal
        }
        if ([string]::IsNullOrWhiteSpace($targetState) -or
            -not (Test-LcmProposalLifecycleTransition -FromState $currentState -ToState $targetState)) {
            $validationFailures += "Proposal #$id cannot transition from '$currentState' for action '$Action'."
            $failureRecords += [PSCustomObject]@{
                identity = if ($proposal.PSObject.Properties['crp_id'] -and $proposal.crp_id) { [string]$proposal.crp_id } else { "CRP-$id" }
                current_state = $currentState
                requested_state = $targetState
                reason = "The requested action is not a valid lifecycle transition from the current state."
                conflict_type = 'invalid transition'
                source = [PSCustomObject]@{ repository = 'LCM_Inventory'; path = 'modules\ProposalManager.psm1'; symbol = 'Invoke-ProposalBatchAction' }
                governing_references = @('RULE-LCM-014', 'ProposalReviewFlowPolicy.md: lifecycle action table')
            }
        }
    }
    if ($validationFailures.Count -gt 0) {
        $report = New-LcmLifecycleFailureReport -Action $Action -TargetExpression $TargetExpression -Failures $failureRecords
        $message = "Lifecycle action '$Action' was not applied because the target set is ineligible: " + ($validationFailures -join ' ')
        throw (New-LcmLifecycleFailureException -Report $report -Message $message)
    }

    $updated = @()
    $completionBatch = $mappedState -eq 'completed' -and $targetIds.Count -gt 1
    $completionStore = if ($completionBatch) { Get-ProposalStore } else { $null }
    foreach ($id in $targetIds) {
        $targetState = $mappedState
        $store = if ($completionBatch) { $completionStore } else { Get-ProposalStore }
        $proposal = @($store.proposals | Where-Object { $_.id -eq $id })[0]
        if ($null -eq $proposal) { throw "Proposal #$Id was not found." }
        if ($Action -eq 'reinstate') {
            $updated += Start-LcmProposalReinstatement -Id $id -Changes $Changes -Details $Details
            continue
        }
        if ($Action -in @('resume', 'continue', 'reopen') -and $proposal.state -eq 'held') {
            $targetState = Get-LcmProposalResumeState -Proposal $proposal
            if ([string]::IsNullOrWhiteSpace($targetState)) {
                throw "Proposal #$Id cannot reopen because it has no recorded resume state or pre-hold history."
            }
        }

        $moveArgs = @{
            Id = $id
            State = $targetState
            Details = $Details
            Store = $store
        }
        if ($completionBatch) {
            $moveArgs.SkipPersist = $true
        }
        $res = Move-LcmProposalLifecycleState @moveArgs
        if ($Action -in @('do', 'approve', 'approved', 'bug')) {
            $store = Get-ProposalStore
            $proposal = @($store.proposals | Where-Object { $_.id -eq $id })[0]
            $proposal | Add-Member -NotePropertyName 'flow_mode' -NotePropertyValue 'doit' -Force
            $proposal | Add-Member -NotePropertyName 'always_proceed' -NotePropertyValue $true -Force
            Set-ProposalStore -Store $store
            $res = $proposal
        }
        $updated += $res
    }
    if ($completionBatch -and $updated.Count -gt 0) {
        Set-ProposalStore -Store $completionStore
        Update-LcmControlHubAfterCompletion -ProposalId @($updated | ForEach-Object { [int]$_.id })
    }

    return $updated
}

function Set-ReviewGranularity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('coarse', 'tight')]
        [string]$Granularity
    )

    $store = Get-ProposalStore
    if (-not $store.PSObject.Properties['review_granularity']) {
        $store | Add-Member -NotePropertyName 'review_granularity' -NotePropertyValue $Granularity.ToLowerInvariant()
    } else {
        $store.review_granularity = $Granularity.ToLowerInvariant()
    }
    Set-ProposalStore -Store $store
    Write-Host "Review granularity configured to: $($store.review_granularity)" -ForegroundColor Green
    return $store.review_granularity
}

function Get-ReviewGranularity {
    [CmdletBinding()]
    param()

    $store = Get-ProposalStore
    if ($store.PSObject.Properties['review_granularity'] -and $store.review_granularity) {
        return $store.review_granularity
    }
    return 'coarse'
}

function Set-LCMMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('active', 'paused')]
        [string]$Mode
    )

    $store = Get-ProposalStore
    if (-not $store.PSObject.Properties['lcm_mode']) {
        $store | Add-Member -NotePropertyName 'lcm_mode' -NotePropertyValue $Mode.ToLowerInvariant()
    } else {
        $store.lcm_mode = $Mode.ToLowerInvariant()
    }
    Set-ProposalStore -Store $store
    Write-Host "LCM Mode configured to: $($store.lcm_mode)" -ForegroundColor Green
    return $store.lcm_mode
}

function Get-LCMMode {
    [CmdletBinding()]
    param()

    $store = Get-ProposalStore
    if ($store.PSObject.Properties['lcm_mode'] -and $store.lcm_mode) {
        return $store.lcm_mode
    }
    return 'active'
}

function Set-TestingMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('active', 'paused')]
        [string]$Mode
    )

    $store = Get-ProposalStore
    if (-not $store.PSObject.Properties['testing_mode']) {
        $store | Add-Member -NotePropertyName 'testing_mode' -NotePropertyValue $Mode.ToLowerInvariant()
    } else {
        $store.testing_mode = $Mode.ToLowerInvariant()
    }
    Set-ProposalStore -Store $store
    Write-Host "Testing Mode configured to: $($store.testing_mode)" -ForegroundColor Green
    return $store.testing_mode
}

function Get-TestingMode {
    [CmdletBinding()]
    param()

    $store = Get-ProposalStore
    if ($store.PSObject.Properties['testing_mode'] -and $store.testing_mode) {
        return $store.testing_mode
    }
    return 'active'
}

# =====================================================================
# CRP-162 Proposal Bundle Directory Architecture & Git Object Resolver
# =====================================================================

function Get-LcmProposalDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int]$Id,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('Specification', 'Plan', 'Walkthrough', 'All')]
        [string]$DocumentType = 'Specification',

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $store = Get-ProposalStore
    $proposal = $store.proposals | Where-Object { $_.id -eq $Id } | Select-Object -First 1

    if (-not $proposal) {
        Write-Warning "Proposal #$Id not found in proposals store."
        return $null
    }

    $repoName = if ($proposal.origin_repo -and (Test-Path (Join-Path $WorkspaceRoot $proposal.origin_repo))) {
        $proposal.origin_repo
    } else {
        'LCM_Inventory'
    }
    $repoDir = Join-Path $WorkspaceRoot $repoName

    $docFileMap = @{
        'Specification' = 'Specification.md'
        'Plan'          = 'Implementation_Plan.md'
        'Walkthrough'   = 'Walkthrough.md'
    }

    $filesToFetch = if ($DocumentType -eq 'All') {
        @('Specification', 'Plan', 'Walkthrough')
    } else {
        @($DocumentType)
    }

    $results = @{}

    foreach ($dtype in $filesToFetch) {
        $fileName = $docFileMap[$dtype]
        $content = $null
        $sourceMode = 'None'
        $resolvedPath = ''

        # 1. Mode 1: Check live bundle directory on disk
        if ($proposal.PSObject.Properties['bundle_dir'] -and $proposal.bundle_dir) {
            $localBundleDir = Join-Path $repoDir $proposal.bundle_dir
            $localFilePath = Join-Path $localBundleDir $fileName
            if (Test-Path $localFilePath) {
                $content = Get-Content -Path $localFilePath -Raw -Encoding UTF8
                $sourceMode = 'LiveWorkingTree'
                $resolvedPath = $localFilePath
            }
        }

        # 2. Mode 2: If absent on disk, check local Git object database using commit_sha
        if ($null -eq $content -and $proposal.PSObject.Properties['commit_sha'] -and $proposal.commit_sha -and (Test-Path (Join-Path $repoDir '.git'))) {
            $bundleRel = if ($proposal.bundle_dir) { $proposal.bundle_dir.TrimStart('\', '/') } else { "docs/Proposals/$($proposal.crp_id)" }
            $gitPath = "$bundleRel/$fileName" -replace '\\', '/'
            $sha = $proposal.commit_sha

            try {
                $gitOutput = & git -C $repoDir show "${sha}:${gitPath}" 2>$null
                if ($LASTEXITCODE -eq 0 -and $gitOutput) {
                    $content = $gitOutput -join "`r`n"
                    $sourceMode = 'GitObject'
                    $resolvedPath = "git://${sha}:${gitPath}"
                }
            } catch {
                # Continue to next fallback
            }
        }

        # 3. Mode 3: Legacy flat file fallback
        if ($null -eq $content) {
            $legacyPath = switch ($dtype) {
                'Plan' { if ($proposal.PSObject.Properties['plan_path']) { $proposal.plan_path } else { '' } }
                'Walkthrough' { if ($proposal.PSObject.Properties['walkthrough_path']) { $proposal.walkthrough_path } else { '' } }
                'Specification' {
                    $propsDir = Join-Path $repoDir 'docs\Proposals'
                    if (Test-Path $propsDir) {
                        $match = Get-ChildItem -Path $propsDir -Filter "$($proposal.crp_id)*.md" | Select-Object -First 1
                        if ($match) { $match.FullName } else { '' }
                    } else { '' }
                }
            }

            if ($legacyPath) {
                $fullLegacyPath = if ([System.IO.Path]::IsPathRooted($legacyPath)) { $legacyPath } else { Join-Path $WorkspaceRoot $legacyPath }
                if (Test-Path $fullLegacyPath) {
                    $content = Get-Content -Path $fullLegacyPath -Raw -Encoding UTF8
                    $sourceMode = 'LegacyFlatDisk'
                    $resolvedPath = $fullLegacyPath
                }
            }
        }

        $results[$dtype] = [PSCustomObject]@{
            Id           = $Id
            CrpId        = $proposal.crp_id
            DocumentType = $dtype
            FileName     = $fileName
            SourceMode   = $sourceMode
            ResolvedPath = $resolvedPath
            Content      = if ($content) { $content } else { "<!-- Document not found for $dtype in Proposal #$Id -->" }
            Found        = ($null -ne $content)
        }
    }

    if ($DocumentType -eq 'All') {
        return $results
    } else {
        return $results[$DocumentType]
    }
}

function Remove-LcmProposalBundle {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int]$Id,

        [Parameter(Mandatory = $false)]
        [string]$CommitSha = '',

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $store = Get-ProposalStore
    $proposal = $store.proposals | Where-Object { $_.id -eq $Id } | Select-Object -First 1

    if (-not $proposal) {
        Write-Warning "Proposal #$Id not found in proposals store."
        return $null
    }

    $repoName = if ($proposal.origin_repo -and (Test-Path (Join-Path $WorkspaceRoot $proposal.origin_repo))) {
        $proposal.origin_repo
    } else {
        'LCM_Inventory'
    }
    $repoDir = Join-Path $WorkspaceRoot $repoName

    # 1. Capture commit SHA if not provided
    if ([string]::IsNullOrWhiteSpace($CommitSha) -and (Test-Path (Join-Path $repoDir '.git'))) {
        $capturedSha = & git -C $repoDir rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $capturedSha) {
            $CommitSha = $capturedSha.Trim()
        }
    }

    # 2. Update proposal record in ledger
    if ($CommitSha) {
        $proposal | Add-Member -NotePropertyName "commit_sha" -NotePropertyValue $CommitSha -Force
        $bundleRel = if ($proposal.PSObject.Properties['bundle_dir'] -and $proposal.bundle_dir) { $proposal.bundle_dir } else { "docs/Proposals/$($proposal.crp_id)" }
        $shortSha = $CommitSha.Substring(0, [Math]::Min(7, $CommitSha.Length))
        $githubUrl = "https://github.com/rgbig/$repoName/tree/$shortSha/$bundleRel" -replace '\\', '/'
        $proposal | Add-Member -NotePropertyName "github_url" -NotePropertyValue $githubUrl -Force
    }

    # 3. Purge local working tree bundle directory
    $purged = $false
    if ($proposal.PSObject.Properties['bundle_dir'] -and $proposal.bundle_dir) {
        $localBundleDir = Join-Path $repoDir $proposal.bundle_dir
        if (Test-Path $localBundleDir) {
            if ($PSCmdlet.ShouldProcess($localBundleDir, "Purge pushed proposal bundle from working tree")) {
                Remove-Item -Path $localBundleDir -Recurse -Force | Out-Null
                $purged = $true
                Write-Host ("  [+] Purged local working tree bundle: {0}" -f $proposal.bundle_dir) -ForegroundColor Green
            }
        }
    }

    Set-ProposalStore -Store $store

    return [PSCustomObject]@{
        Id        = $Id
        CrpId     = $proposal.crp_id
        Repo      = $repoName
        CommitSha = $CommitSha
        GithubUrl = if ($proposal.PSObject.Properties['github_url']) { $proposal.github_url } else { $null }
        Purged    = $purged
    }
}

# =====================================================================
# CRP-048 App-Centric Architecture, Active Context Engine & Catalog
# =====================================================================

function Get-ActiveAppContext {
    [CmdletBinding()]
    param()

    $store = Get-ProposalStore
    if ($store.PSObject.Properties['active_context'] -and $store.active_context) {
        return $store.active_context
    }
    return $null
}

function Set-ActiveAppContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Context = '',

        [Parameter(Mandatory = $false)]
        [string]$Repo = '',

        [Parameter(Mandatory = $false)]
        [string]$Details = '',

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $store = Get-ProposalStore
    $trimmed = if ($Context) { $Context.Trim() } else { '' }

    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed -in @('clear', 'reset', 'none', 'null')) {
        $store | Add-Member -NotePropertyName 'active_context' -NotePropertyValue $null -Force
        Set-ProposalStore -Store $store

        $wiDataDir = (Get-Item (Get-ProposalStorePath)).Directory.Parent.FullName
        $sessionDir = Join-Path $wiDataDir 'session_state'
        if (-not (Test-Path $sessionDir)) { New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null }
        $sessionFile = Join-Path $sessionDir 'active_session.json'
        @{
            active_context = $null
            updated_at     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        } | ConvertTo-Json -Depth 3 | Set-Content -Path $sessionFile -Encoding UTF8

        Write-Host "Active App Context cleared. Current focus: 🏛️ Master Architecture (Governing All Apps)." -ForegroundColor Green
        return $null
    }

    if ($trimmed -in @('Master', 'Architecture', 'Base', 'Root', '0', 'App: 0', 'A0')) {
        $targetRepo = if ($Repo) { $Repo } else { 'LCM_AI' }
        $appId = if ($trimmed -eq 'Architecture') { 'Architecture' } else { 'Master' }
        $appTitle = if ($trimmed -eq 'Architecture') { 'Foundational Tripartite Architecture' } else { 'Master Tripartite Architecture (Governing All Apps)' }
        $ctxObj = [ordered]@{
            app_id     = $appId
            app_number = 0
            app_title  = $appTitle
            repo       = $targetRepo
            set_at     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            details    = $Details
        }
        $store | Add-Member -NotePropertyName 'active_context' -NotePropertyValue ([PSCustomObject]$ctxObj) -Force
        Set-ProposalStore -Store $store

        $wiDataDir = (Get-Item (Get-ProposalStorePath)).Directory.Parent.FullName
        $sessionDir = Join-Path $wiDataDir 'session_state'
        if (-not (Test-Path $sessionDir)) { New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null }
        $sessionFile = Join-Path $sessionDir 'active_session.json'
        @{
            active_context = $ctxObj
            updated_at     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        } | ConvertTo-Json -Depth 3 | Set-Content -Path $sessionFile -Encoding UTF8

        Write-Host ("Active App Context set to: 🏛️ Master Architecture (Governing All Apps) [{0}]" -f $targetRepo) -ForegroundColor Green
        return [PSCustomObject]$ctxObj
    }

    # Normalize App identifier: 'A1', '1', 'App: 1', 'App 1', 'App: 1 - Title'
    $appNum = $null
    $appTitle = ''
    if ($trimmed -match '^(?i)(?:App:?\s*|A)?(\d+)(?:\s*-\s*(.+))?$') {
        $appNum = [int]$Matches[1]
        if ($Matches.Count -ge 3 -and $Matches[2]) {
            $appTitle = $Matches[2].Trim()
        }
    }

    $appId = if ($appNum -ne $null) { "App: $appNum" } else { $trimmed }

    # If title wasn't passed in context string, look up in catalog or tripartite docs
    $targetRepo = if ($Repo) { $Repo } else { 'LCM_AI' }
    if ([string]::IsNullOrWhiteSpace($appTitle) -and $appNum -ne $null) {
        $catalog = @(Get-LcmApps -Repo $targetRepo -WorkspaceRoot $WorkspaceRoot)
        $found = @($catalog | Where-Object { $_.number -eq $appNum })
        if ($found.Count -gt 0) {
            $appTitle = $found[0].title
        }
    }

    $ctxObj = [ordered]@{
        app_id     = $appId
        app_number = $appNum
        app_title  = $appTitle
        repo       = $targetRepo
        set_at     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        details    = $Details
    }

    $store | Add-Member -NotePropertyName 'active_context' -NotePropertyValue ([PSCustomObject]$ctxObj) -Force
    Set-ProposalStore -Store $store

    $wiDataDir = (Get-Item (Get-ProposalStorePath)).Directory.Parent.FullName
    $sessionDir = Join-Path $wiDataDir 'session_state'
    if (-not (Test-Path $sessionDir)) { New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null }
    $sessionFile = Join-Path $sessionDir 'active_session.json'
    @{
        active_context = $ctxObj
        updated_at     = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    } | ConvertTo-Json -Depth 3 | Set-Content -Path $sessionFile -Encoding UTF8

    $displayTitle = if ($appTitle) { " - $appTitle" } else { '' }
    Write-Host ("Active App Context set to: {0}{1} [{2}]" -f $appId, $displayTitle, $targetRepo) -ForegroundColor Green
    return [PSCustomObject]$ctxObj
}

function Get-LcmApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Repo = '',

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $targetRepos = @()
    if ($Repo) {
        $rPath = Join-Path $WorkspaceRoot $Repo
        if (Test-Path $rPath) {
            $targetRepos += [PSCustomObject]@{ Name = $Repo; Path = $rPath }
        }
    } else {
        $dirs = Get-ChildItem -Path $WorkspaceRoot -Directory | Where-Object { 
            (Test-Path (Join-Path $_.FullName 'docs')) -or (Test-Path (Join-Path $_.FullName '.git'))
        }
        foreach ($d in $dirs) {
            $targetRepos += [PSCustomObject]@{ Name = $d.Name; Path = $d.FullName }
        }
    }

    $allApps = @()

    foreach ($r in $targetRepos) {
        $docsDir = Join-Path $r.Path 'docs'
        if (!(Test-Path $docsDir)) {
            continue
        }
        $archPath = Join-Path $docsDir 'Architecture.md'
        $implPath = Join-Path $docsDir 'Implementation.md'
        $reqPath  = Join-Path $docsDir 'Requirements.md'

        $archOk = Test-Path $archPath
        $implOk = Test-Path $implPath
        $reqOk  = Test-Path $reqPath

        # 0. Include Master Tripartite Architecture Entry for the repository
        if ($archOk -or $implOk -or $reqOk) {
            $masterTitle = "Master Tripartite Architecture (Governing All Apps)"
            if ($archOk) {
                $topLines = @(Get-Content -Path $archPath -TotalCount 5 -Encoding UTF8 | Where-Object { $_ -match '^#\s+' })
                if ($topLines.Count -gt 0 -and $topLines[0] -match '^#\s+(.+)$') {
                    $rawH1 = $Matches[1].Trim()
                    if ($rawH1 -notmatch '(?i)App:') {
                        $masterTitle = "Master Architecture - $rawH1"
                    }
                }
            }

            $masterEntry = [ordered]@{
                id           = 'Master'
                number       = 0
                title        = $masterTitle
                repo         = $r.Name
                doc_layout   = 'MasterRoot'
                directory    = 'docs/'
                arch_defined = $archOk
                req_defined  = $reqOk
                impl_defined = $implOk
                is_master    = $true
                constituents = @()
            }
            $allApps += [PSCustomObject]$masterEntry
        }

        $appMap = @{}

        # 1. Scan directory-separated App documents under docs/App#*/ or legacy docs/App-*/
        $appsSubDirs = @()
        if (Test-Path $docsDir) {
            $directAppDirs = @(Get-ChildItem -Path $docsDir -Directory | Where-Object { $_.Name -match '^(?i)App[#-]?\d+' -and $_.Name -ne 'apps' })
            $appsSubDirs += $directAppDirs
            $appsBaseDir = Join-Path $docsDir 'apps'
            if (Test-Path $appsBaseDir) {
                $appsSubDirs += @(Get-ChildItem -Path $appsBaseDir -Directory)
            }
        }

        foreach ($sd in $appsSubDirs) {
            $num = $null
            $folderTitle = ''
            if ($sd.Name -match '^(?i)App[#-]?(\d+)(?:-(.*))?$') {
                $num = [int]$Matches[1]
                if ($Matches.Count -ge 3 -and $Matches[2]) { $folderTitle = $Matches[2].Trim() }
            } elseif ($sd.Name -match '^\d+$') {
                $num = [int]$sd.Name
            }

            if ($num -ne $null) {
                $subArch = Join-Path $sd.FullName 'Architecture.md'
                $subReq  = Join-Path $sd.FullName 'Requirements.md'
                $subImpl = Join-Path $sd.FullName 'Implementation.md'

                $archOk = Test-Path $subArch
                $reqOk  = Test-Path $subReq
                $implOk = Test-Path $subImpl

                $title = if ($folderTitle) { $folderTitle } else { "App $num" }

                # Extract title from Architecture.md or Implementation.md if available
                if ($archOk) {
                    $firstLine = (Get-Content -Path $subArch -TotalCount 5 -Encoding UTF8 | Where-Object { $_ -match '^#\s+' } | Select-Object -First 1)
                    if ($firstLine -match '(?i)^#\s+(?:App:\s*\d+\s*-\s*)?(.+?)(?:\s+Architecture)?$') {
                        $title = $Matches[1].Trim()
                    }
                }

                $constituents = @()
                if ($implOk) {
                    $implContent = Get-Content -Path $subImpl -Raw -Encoding UTF8
                    $implLines = $implContent -split '\r?\n'
                    $inManifest = $false
                    foreach ($line in $implLines) {
                        if ($line -match '(?i)Constituent Manifest') {
                            $inManifest = $true
                        } elseif ($inManifest -and $line -match '^\|\s*([^\|]+)\|\s*([^\|]+)\|\s*([^\|]+)\|\s*([^\|]+)\|') {
                            $cPath = $Matches[1].Trim()
                            $cRole = $Matches[2].Trim()
                            $cEntry = $Matches[3].Trim()
                            $cTest = $Matches[4].Trim()
                            if ($cPath -notmatch '^:?-+:?$' -and $cPath -notmatch '(?i)Relative Path' -and $cPath -notmatch '^[\|\s:-]+$') {
                                $constituents += [PSCustomObject]@{
                                    Path        = $cPath
                                    Role        = $cRole
                                    Entrypoints = $cEntry
                                    TestSuite   = $cTest
                                }
                            }
                        } elseif ($line -match '^#{2,3}\s+' -and $inManifest) {
                            $inManifest = $false
                        }
                    }
                }

                $relDir = $sd.FullName.Substring($r.Path.Length).TrimStart('\', '/')
                $appMap[$num] = [ordered]@{
                    id           = "App: $num"
                    number       = $num
                    title        = $title
                    repo         = $r.Name
                    doc_layout   = 'Directory'
                    directory    = $relDir
                    arch_defined = $archOk
                    req_defined  = $reqOk
                    impl_defined = $implOk
                    constituents = $constituents
                }
            }
        }

        # 2. Scan in-document sections from root Architecture.md
        if (Test-Path $archPath) {
            $archLines = Get-Content -Path $archPath -Encoding UTF8
            foreach ($line in $archLines) {
                if ($line -match '(?i)^#{2,3}\s+App:\s*(\d+)\s*-\s*(.+)$') {
                    $num = [int]$Matches[1]
                    $title = $Matches[2].Trim()
                    if (-not $appMap.ContainsKey($num)) {
                        $appMap[$num] = [ordered]@{
                            id           = "App: $num"
                            number       = $num
                            title        = $title
                            repo         = $r.Name
                            doc_layout   = 'InDocument'
                            directory    = 'docs/'
                            arch_defined = $true
                            req_defined  = $false
                            impl_defined = $false
                            constituents = @()
                        }
                    } else {
                        $appMap[$num].arch_defined = $true
                    }
                }
            }
        }

        # 3. Scan in-document sections from root Requirements.md
        if (Test-Path $reqPath) {
            $reqLines = Get-Content -Path $reqPath -Encoding UTF8
            foreach ($line in $reqLines) {
                if ($line -match '(?i)^#{2,3}\s+App:\s*(\d+)') {
                    $num = [int]$Matches[1]
                    if ($appMap.ContainsKey($num)) {
                        $appMap[$num].req_defined = $true
                    } else {
                        $title = if ($line -match '(?i)^#{2,3}\s+App:\s*\d+\s*-\s*(.+)$') { $Matches[1].Trim() } else { "App $num" }
                        $appMap[$num] = [ordered]@{
                            id           = "App: $num"
                            number       = $num
                            title        = $title
                            repo         = $r.Name
                            doc_layout   = 'InDocument'
                            directory    = 'docs/'
                            arch_defined = $false
                            req_defined  = $true
                            impl_defined = $false
                            constituents = @()
                        }
                    }
                }
            }
        }

        # 4. Scan in-document sections from root Implementation.md
        if (Test-Path $implPath) {
            $implContent = Get-Content -Path $implPath -Raw -Encoding UTF8
            $implLines = $implContent -split '\r?\n'
            $currentAppNum = $null
            $inManifest = $false

            foreach ($line in $implLines) {
                if ($line -match '(?i)^#{2,3}\s+App:\s*(\d+)') {
                    $currentAppNum = [int]$Matches[1]
                    $inManifest = $false
                    if ($appMap.ContainsKey($currentAppNum)) {
                        $appMap[$currentAppNum].impl_defined = $true
                    } else {
                        $title = if ($line -match '(?i)^#{2,3}\s+App:\s*\d+\s*-\s*(.+)$') { $Matches[1].Trim() } else { "App $currentAppNum" }
                        $appMap[$currentAppNum] = [ordered]@{
                            id           = "App: $currentAppNum"
                            number       = $currentAppNum
                            title        = $title
                            repo         = $r.Name
                            doc_layout   = 'InDocument'
                            directory    = 'docs/'
                            arch_defined = $false
                            req_defined  = $false
                            impl_defined = $true
                            constituents = @()
                        }
                    }
                } elseif ($currentAppNum -ne $null -and $line -match '(?i)Constituent Manifest') {
                    $inManifest = $true
                } elseif ($inManifest -and $line -match '^\|\s*([^\|]+)\|\s*([^\|]+)\|\s*([^\|]+)\|\s*([^\|]+)\|') {
                    $cPath = $Matches[1].Trim()
                    $cRole = $Matches[2].Trim()
                    $cEntry = $Matches[3].Trim()
                    $cTest = $Matches[4].Trim()
                    if ($cPath -notmatch '^:?-+:?$' -and $cPath -notmatch '(?i)Relative Path' -and $cPath -notmatch '^[\|\s:-]+$') {
                        $appMap[$currentAppNum].constituents += [PSCustomObject]@{
                            Path        = $cPath
                            Role        = $cRole
                            Entrypoints = $cEntry
                            TestSuite   = $cTest
                        }
                    }
                } elseif ($line -match '^#{2,3}\s+') {
                    $inManifest = $false
                }
            }
        }

        # 5. Scan code files in repo for DOX header `App: App: # - <Title>`
        $codeFiles = @(Get-ChildItem -Path $r.Path -Recurse -Include *.ps1, *.psm1, *.js, *.py -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName -notmatch '[\\/](\.git|\.agents|data|logs|scratch|node_modules)[\\/]'
        })
        foreach ($cf in $codeFiles) {
            $first20 = @(Get-Content -Path $cf.FullName -TotalCount 25 -ErrorAction SilentlyContinue)
            foreach ($line in $first20) {
                if ($line -match '(?i)\bApp:\s*(?:App:\s*)?(\d+)(?:\s*-\s*(.+))?') {
                    $num = [int]$Matches[1]
                    $rel = $cf.FullName.Substring($r.Path.Length).TrimStart('\', '/')
                    if ($appMap.ContainsKey($num)) {
                        $existingPaths = @($appMap[$num].constituents | ForEach-Object { $_.Path })
                        if ($existingPaths -notcontains $rel) {
                            $appMap[$num].constituents += [PSCustomObject]@{
                                Path        = $rel
                                Role        = 'Source / Asset'
                                Entrypoints = '-'
                                TestSuite   = '-'
                            }
                        }
                    }
                }
            }
        }

        foreach ($k in ($appMap.Keys | Sort-Object)) {
            $allApps += [PSCustomObject]$appMap[$k]
        }
    }

    return $allApps
}

function Sync-LcmAppCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Repo = '',

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $catalogDir = Join-Path $WorkspaceRoot 'LCM_Inventory\data\catalog'
    if (-not (Test-Path $catalogDir)) {
        New-Item -ItemType Directory -Path $catalogDir -Force | Out-Null
    }

    $apps = @(Get-LcmApps -Repo $Repo -WorkspaceRoot $WorkspaceRoot)
    $catalogPath = Join-Path $catalogDir 'apps.json'

    $catalogObj = [ordered]@{
        '$schema'    = 'https://json-schema.org/draft/2020-12/schema'
        title        = 'LCM Workspace App-Centric Architecture Catalog'
        updated_at   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        total_apps   = $apps.Count
        apps         = $apps
    }

    $catalogObj | ConvertTo-Json -Depth 6 | Set-Content -Path $catalogPath -Encoding UTF8
    Write-Host ("Synchronized App Catalog ({0} App(s) indexed) -> {1}" -f $apps.Count, $catalogPath) -ForegroundColor Green
    return [PSCustomObject]$catalogObj
}

function Assert-LcmProposalImplementationEligibility {
    [CmdletBinding()]
    param(
        [int]$ProposalId = 0,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Repository,

        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $store = Get-ProposalStore
    $proposal = @($store.proposals | Where-Object { [int]$_.id -eq $ProposalId } | Select-Object -First 1)
    if ($proposal.Count -eq 0) {
        throw "GOVERNANCE BLOCK: Repository '$Repository' requires an explicit originating proposal. Proposal #$ProposalId was not found. Create and accept the proposal before structural implementation."
    }

    $originRepository = [string]$proposal[0].origin_repo
    if (-not $originRepository.Equals($Repository, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "GOVERNANCE BLOCK: Proposal #$ProposalId originates from '$originRepository', not '$Repository'. Select the matching proposal before structural implementation."
    }

    $eligibleStates = @('in_progress', 'verified', 'in_review')
    $proposalState = [string]$proposal[0].state
    if ($proposalState -notin $eligibleStates) {
        throw "GOVERNANCE BLOCK: Proposal #$ProposalId is '$proposalState'. Structural implementation requires Gate 1 acceptance and an eligible state: $($eligibleStates -join ', ')."
    }

    $bundlePath = if ($proposal[0].PSObject.Properties['bundle_dir'] -and $proposal[0].bundle_dir) {
        [string]$proposal[0].bundle_dir
    } elseif ($proposal[0].PSObject.Properties['plan_path'] -and $proposal[0].plan_path) {
        Split-Path -Path ([string]$proposal[0].plan_path) -Parent
    } else {
        ''
    }
    if ([string]::IsNullOrWhiteSpace($bundlePath)) {
        throw "GOVERNANCE BLOCK: Proposal #$ProposalId has no proposal bundle. Create its specification before structural implementation."
    }

    $specificationPath = Join-Path -Path (Join-Path -Path $WorkspaceRoot -ChildPath $Repository) -ChildPath (Join-Path -Path $bundlePath -ChildPath 'Specification.md')
    if (-not (Test-Path -LiteralPath $specificationPath -PathType Leaf)) {
        throw "GOVERNANCE BLOCK: Proposal #$ProposalId does not have a specification at '$specificationPath'. Create the bundle before structural implementation."
    }

    return $proposal[0]
}

function New-LcmApp {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [string]$Repo = 'LCM_AI',

        [Parameter(Mandatory = $false)]
        [string]$Description = '',

        [int]$ProposalId = 0,

        [Parameter(Mandatory = $false)]
        [switch]$SplitDocs = $false,

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $targetRepoDir = Join-Path $WorkspaceRoot $Repo
    if (-not (Test-Path $targetRepoDir)) {
        throw "Target repository '$Repo' does not exist at: $targetRepoDir"
    }

    if ($ProposalId -gt 0) {
        Assert-LcmProposalImplementationEligibility -ProposalId $ProposalId -Repository $Repo -WorkspaceRoot $WorkspaceRoot | Out-Null
    }

    # Find existing App IDs across the repo
    $existingApps = @(Get-LcmApps -Repo $Repo -WorkspaceRoot $WorkspaceRoot)
    $maxNum = 0
    foreach ($a in $existingApps) {
        if ($a.number -gt $maxNum) {
            $maxNum = $a.number
        }
    }

    $newNum = $maxNum + 1
    $appId = "App: $newNum"
    $fullTitle = "$appId - $Title"
    $cleanModName = ($Title -replace '[^a-zA-Z0-9]', '')
    $docsDir = Join-Path $targetRepoDir 'docs'
    if (-not (Test-Path $docsDir)) {
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
    }

    if ($SplitDocs) {
        $folderName = "App#$newNum-$cleanModName"
        $appTargetDir = Join-Path $docsDir $folderName

        if ($PSCmdlet.ShouldProcess($appTargetDir, "Scaffold directory-separated tripartite documents for '$fullTitle'")) {
            if (-not (Test-Path $appTargetDir)) {
                New-Item -ItemType Directory -Path $appTargetDir -Force | Out-Null
            }

            # 1. Architecture.md
            $archSnippet = @"
# $fullTitle Architecture

## 1. Architectural Concept & End-User Perspective
$Description

## 2. User Mental Model & Topology
<!-- Add Mermaid topology or functional diagram -->

"@
            Set-Content -Path (Join-Path $appTargetDir 'Architecture.md') -Value $archSnippet.Trim() -Encoding UTF8

            # 2. Requirements.md
            $reqSnippet = @"
# $fullTitle Requirements

## 1. Technical Invariants & Prerequisites
- Invariant 1: Must conform to LCM governance standards.

## 2. Safety & Error Handling Boundaries
- Boundary 1: Clean degradation and zero-state recovery.

"@
            Set-Content -Path (Join-Path $appTargetDir 'Requirements.md') -Value $reqSnippet.Trim() -Encoding UTF8

            # 3. Implementation.md
            $implSnippet = @"
# $fullTitle Implementation

## 1. Constituent Manifest Table
| Relative Path | Role / Layer | Primary Cmdlets / Entrypoints | Pester Test Suite |
|:---|:---|:---|:---|
| `modules/$($cleanModName).psm1` | Core Logic | `Get-$($cleanModName)` | `tests/$($cleanModName).Tests.ps1` |

## 2. Exported Interfaces & Public Contracts
- Cmdlet / API contracts defined in `data/catalog/contracts.json`.

"@
            Set-Content -Path (Join-Path $appTargetDir 'Implementation.md') -Value $implSnippet.Trim() -Encoding UTF8

            Write-Host ("Successfully scaffolded {0} in docs/{1}/ and set as active context." -f $fullTitle, $folderName) -ForegroundColor Green
        }
    } else {
        # Flat in-document scaffolding (default)
        $archFile = Join-Path $docsDir 'Architecture.md'
        $reqFile  = Join-Path $docsDir 'Requirements.md'
        $implFile = Join-Path $docsDir 'Implementation.md'

        if ($PSCmdlet.ShouldProcess("$Repo/docs/", "Scaffold in-document section for '$fullTitle'")) {
            # Scaffold in Architecture.md
            if (Test-Path $archFile) {
                $archSnippet = @"


---

## $fullTitle

### 1. Architectural Concept & End-User Perspective
$Description

### 2. User Mental Model & Topology
<!-- Add Mermaid topology or functional diagram -->

"@
                Add-Content -Path $archFile -Value $archSnippet -Encoding UTF8
            }

            # Scaffold in Requirements.md
            if (Test-Path $reqFile) {
                $reqSnippet = @"


---

## $fullTitle

### 1. Technical Invariants & Prerequisites
- Invariant 1: Must conform to LCM governance standards.

### 2. Safety & Error Handling Boundaries
- Boundary 1: Clean degradation and zero-state recovery.

"@
                Add-Content -Path $reqFile -Value $reqSnippet -Encoding UTF8
            }

            # Scaffold in Implementation.md
            if (Test-Path $implFile) {
                $implSnippet = @"


---

## $fullTitle

### 1. Constituent Manifest Table
| Relative Path | Role / Layer | Primary Cmdlets / Entrypoints | Pester Test Suite |
|:---|:---|:---|:---|
| `modules/$($cleanModName).psm1` | Core Logic | `Get-$($cleanModName)` | `tests/$($cleanModName).Tests.ps1` |

### 2. Exported Interfaces & Public Contracts
- Cmdlet / API contracts defined in `data/catalog/contracts.json`.

"@
                Add-Content -Path $implFile -Value $implSnippet -Encoding UTF8
            }

            Write-Host ("Successfully scaffolded {0} across {1}/docs/ and set as active context." -f $fullTitle, $Repo) -ForegroundColor Green
        }
    }

    # Set active context to newly minted App
    Set-ActiveAppContext -Context "A$newNum" -Repo $Repo -Details $Title -WorkspaceRoot $WorkspaceRoot | Out-Null

    # Sync catalog
    Sync-LcmAppCatalog -Repo $Repo -WorkspaceRoot $WorkspaceRoot | Out-Null

    return [PSCustomObject]@{
        Id          = $appId
        Number      = $newNum
        Title       = $Title
        FullTitle   = $fullTitle
        Repo        = $Repo
        Description = $Description
        DocLayout   = if ($SplitDocs) { 'Directory' } else { 'InDocument' }
        Directory   = if ($SplitDocs) { "docs/$folderName" } else { 'docs/' }
    }
}

function Split-LcmAppDocs {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Repo,

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $targetRepoDir = Join-Path $WorkspaceRoot $Repo
    if (-not (Test-Path $targetRepoDir)) {
        throw "Target repository '$Repo' does not exist at: $targetRepoDir"
    }

    $docsDir = Join-Path $targetRepoDir 'docs'
    if (-not (Test-Path $docsDir)) {
        throw "Documentation directory 'docs' does not exist at: $docsDir"
    }

    $archPath = Join-Path $docsDir 'Architecture.md'
    $reqPath  = Join-Path $docsDir 'Requirements.md'
    $implPath = Join-Path $docsDir 'Implementation.md'

    # 1. Parse existing in-document Apps from Architecture.md, Requirements.md, Implementation.md
    $archContent = if (Test-Path $archPath) { Get-Content -Path $archPath -Raw -Encoding UTF8 } else { '' }
    $reqContent  = if (Test-Path $reqPath)  { Get-Content -Path $reqPath -Raw -Encoding UTF8 } else { '' }
    $implContent = if (Test-Path $implPath) { Get-Content -Path $implPath -Raw -Encoding UTF8 } else { '' }

    # Helper function to split markdown content into preamble and per-App sections
    $splitSections = {
        param([string]$Content)
        $lines = $Content -split '\r?\n'
        $preamble = @()
        $sections = @{}
        $currNum = $null
        $currTitle = ''
        $currLines = @()

        foreach ($line in $lines) {
            if ($line -match '(?i)^#{2,3}\s+App:\s*(\d+)(?:\s*-\s*(.+))?$') {
                if ($currNum -ne $null) {
                    $sections[$currNum] = @{
                        Number = $currNum
                        Title  = $currTitle
                        Body   = ($currLines -join "`r`n").Trim()
                    }
                }
                $currNum = [int]$Matches[1]
                $currTitle = if ($Matches.Count -ge 3 -and $Matches[2]) { $Matches[2].Trim() } else { "App $currNum" }
                $currLines = @()
            } elseif ($currNum -eq $null) {
                $preamble += $line
            } else {
                $currLines += $line
            }
        }

        if ($currNum -ne $null) {
            $sections[$currNum] = @{
                Number = $currNum
                Title  = $currTitle
                Body   = ($currLines -join "`r`n").Trim()
            }
        }

        return @{
            Preamble = ($preamble -join "`r`n").TrimEnd()
            Sections = $sections
        }
    }

    $archSplit = & $splitSections $archContent
    $reqSplit  = & $splitSections $reqContent
    $implSplit = & $splitSections $implContent

    $allAppNums = @($archSplit.Sections.Keys + $reqSplit.Sections.Keys + $implSplit.Sections.Keys | Sort-Object -Unique)

    if ($allAppNums.Count -eq 0) {
        Write-Host "No in-document '## App: #' sections found in $Repo/docs/ to split." -ForegroundColor Yellow
        return @()
    }

    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host (" SPLITTING APP DOCUMENTATION FOR REPOSITORY: {0}" -f $Repo) -ForegroundColor Green
    Write-Host (" Discovered {0} in-document App slice(s): {1}" -f $allAppNums.Count, ($allAppNums -join ', ')) -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan

    $migrated = @()

    foreach ($num in $allAppNums) {
        $title = if ($archSplit.Sections.ContainsKey($num) -and $archSplit.Sections[$num].Title) {
            $archSplit.Sections[$num].Title
        } elseif ($reqSplit.Sections.ContainsKey($num) -and $reqSplit.Sections[$num].Title) {
            $reqSplit.Sections[$num].Title
        } elseif ($implSplit.Sections.ContainsKey($num) -and $implSplit.Sections[$num].Title) {
            $implSplit.Sections[$num].Title
        } else {
            "App $num"
        }

        $cleanSlug = ($title -replace '[^a-zA-Z0-9]', '')
        $folderName = "App#$num-$cleanSlug"
        $appTargetDir = Join-Path $docsDir $folderName

        $fullAppTitle = "App: $num - $title"

        if ($PSCmdlet.ShouldProcess($appTargetDir, "Extract $fullAppTitle tripartite docs")) {
            if (-not (Test-Path $appTargetDir)) {
                New-Item -ItemType Directory -Path $appTargetDir -Force | Out-Null
            }

            # 1. Architecture.md
            $archBody = if ($archSplit.Sections.ContainsKey($num)) { $archSplit.Sections[$num].Body } else { "### 1. Architectural Concept`n$title capability slice." }
            $archDocContent = @"
# $fullAppTitle Architecture

$archBody

"@
            Set-Content -Path (Join-Path $appTargetDir 'Architecture.md') -Value $archDocContent.Trim() -Encoding UTF8

            # 2. Requirements.md
            $reqBody = if ($reqSplit.Sections.ContainsKey($num)) { $reqSplit.Sections[$num].Body } else { "### 1. Technical Invariants`n- Invariant: Conforms to LCM governance standards." }
            $reqDocContent = @"
# $fullAppTitle Requirements

$reqBody

"@
            Set-Content -Path (Join-Path $appTargetDir 'Requirements.md') -Value $reqDocContent.Trim() -Encoding UTF8

            # 3. Implementation.md
            $implBody = if ($implSplit.Sections.ContainsKey($num)) { $implSplit.Sections[$num].Body } else { "### 1. Constituent Manifest Table`n| Relative Path | Role / Layer | Primary Cmdlets / Entrypoints | Test Suite |`n|:---|:---|:---|:---|`n| modules/$cleanSlug.psm1 | Core Logic | Get-$cleanSlug | tests/$cleanSlug.Tests.ps1 |" }
            $implDocContent = @"
# $fullAppTitle Implementation

$implBody

"@
            Set-Content -Path (Join-Path $appTargetDir 'Implementation.md') -Value $implDocContent.Trim() -Encoding UTF8

            $migrated += [PSCustomObject]@{
                Number    = $num
                Title     = $title
                Directory = "docs/$folderName"
            }
            Write-Host ("  [+] Migrated {0} -> docs/{1}/" -f $fullAppTitle, $folderName) -ForegroundColor Green
        } else {
            Write-Host ("  [WhatIf] Would migrate {0} -> docs/{1}/" -f $fullAppTitle, $folderName) -ForegroundColor Yellow
        }
    }

    # 4. Clean up root Architecture.md, Requirements.md, Implementation.md
    if ($PSCmdlet.ShouldProcess("$Repo/docs/", "Clean up root tripartite documents and add App index")) {
        # Build App Index table for root Architecture.md
        $indexRows = @()
        foreach ($m in $migrated) {
            $indexRows += "| App: $($m.Number) | $($m.Title) | [``$($m.Directory)/``](file:///$($m.Directory)) | [Arch](file:///$($m.Directory)/Architecture.md) · [Req](file:///$($m.Directory)/Requirements.md) · [Impl](file:///$($m.Directory)/Implementation.md) |"
        }

        $appIndexSection = @"


---

## App Subsystems & Sliced Specifications
The following modular App slices are documented in dedicated subdirectories per RULE-DOC-007:

| App ID | Title | Directory | Sliced Specifications |
|:---|:---|:---|:---|
$($indexRows -join "`r`n")
"@

        # Write clean root files
        $cleanArch = ($archSplit.Preamble.TrimEnd() -replace '(?s)\n---\s*$', '') + $appIndexSection
        Set-Content -Path $archPath -Value $cleanArch.Trim() -Encoding UTF8

        $cleanReq = $reqSplit.Preamble.TrimEnd() -replace '(?s)\n---\s*$', ''
        Set-Content -Path $reqPath -Value $cleanReq.Trim() -Encoding UTF8

        $cleanImpl = $implSplit.Preamble.TrimEnd() -replace '(?s)\n---\s*$', ''
        Set-Content -Path $implPath -Value $cleanImpl.Trim() -Encoding UTF8

        # 5. Re-synchronize App catalog
        Sync-LcmAppCatalog -Repo $Repo -WorkspaceRoot $WorkspaceRoot | Out-Null
        Write-Host "`n[SUCCESS] SplitDocs completed for repository '$Repo'." -ForegroundColor Green
        Format-LcmAppsTable -WorkspaceRoot $WorkspaceRoot
    }

    return $migrated
}

function Format-LcmAppsTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Apps,

        [Parameter(Mandatory = $false)]
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    if ($null -eq $Apps) {
        $Apps = Get-LcmApps -WorkspaceRoot $WorkspaceRoot
    }

    $activeCtx = Get-ActiveAppContext
    $activeId = if ($activeCtx) { 
        if ($activeCtx.app_id -in @('Master', 'Architecture', 'Base')) {
            "🏛️ Master Architecture (Governing All Apps) [$($activeCtx.repo)]"
        } else {
            "$($activeCtx.app_id) [$($activeCtx.repo)]"
        }
    } else { 
        '🏛️ Master Architecture (Governing All Apps)' 
    }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host (" LCM Workspace App Catalog (Active Focus: {0})" -f $activeId) -ForegroundColor Cyan
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    if (@($Apps).Count -eq 0) {
        Write-Host " No modular Apps currently registered across workspace repositories." -ForegroundColor Gray
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        return
    }

    Write-Host (" {0,-10} | {1,-22} | {2,-7} | {3,-13} | {4}" -f 'App ID', 'Repository', 'Docs', 'Constituents', 'Title') -ForegroundColor Yellow
    Write-Host "-----------+------------------------+---------+---------------+----------------------------------" -ForegroundColor DarkGray

    foreach ($a in $Apps) {
        $isMasterEntry = ($a.id -eq 'Master' -or $a.number -eq 0)
        $isActive = if ($isMasterEntry) {
            ($null -eq $activeCtx -or $activeCtx.app_id -in @('Master', 'Architecture', 'Base'))
        } else {
            ($activeCtx -and $activeCtx.app_id -eq $a.id -and $activeCtx.repo -eq $a.repo)
        }

        $color = if ($isActive) { 
            [ConsoleColor]::Green 
        } elseif ($isMasterEntry) {
            [ConsoleColor]::Cyan
        } else { 
            [ConsoleColor]::White 
        }

        $docsFlag = ""
        $docsFlag += if ($a.arch_defined) { "A" } else { "-" }
        $docsFlag += if ($a.req_defined)  { "R" } else { "-" }
        $docsFlag += if ($a.impl_defined) { "I" } else { "-" }

        $constCount = if ($isMasterEntry) { "Master Specs" } else { "$(@($a.constituents).Count) file(s)" }
        $idDisplay = if ($isActive) { "*$($a.id)" } else { " $($a.id)" }

        Write-Host (" {0,-10} | {1,-22} | {2,-7} | {3,-13} | {4}" -f $idDisplay, $a.repo, $docsFlag, $constCount, $a.title) -ForegroundColor $color
    }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
}

# =====================================================================
# CRP-135 Automated Regression & DAG Engine
# =====================================================================

function Test-RegressionTrigger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Proposal,
        [Parameter(Mandatory = $false)]
        [object[]]$AllProposals
    )

    $triggers = @()
    $isRegressionNeeded = $false

    # 1. Explicit Author Intent
    if ($Proposal.PSObject.Properties['regression_needed'] -and $Proposal.regression_needed -eq $true) {
        $triggers += 'Explicit author intent'
        $isRegressionNeeded = $true
    }

    # 2. Semantic Scope Filter (Global Workspace Scope)
    $scope = if ($Proposal.PSObject.Properties['origin_repo']) { $Proposal.origin_repo } else { '' }
    $title = if ($Proposal.PSObject.Properties['title']) { $Proposal.title } else { '' }
    $details = if ($Proposal.PSObject.Properties['details']) { $Proposal.details } else { '' }
    $combined = "$scope $title $details".ToLowerInvariant()

    if ($scope -in @('LCM', 'LCM_AI') -or $combined -match '(all repositories|all child repos|workspace-wide|governance rule|\.agents/rules)') {
        $triggers += 'Global scope pattern detected'
        $isRegressionNeeded = $true
    }

    # 3. Active Dependency Overlap
    if ($AllProposals -and $AllProposals.Count -gt 0) {
        $activeProps = @($AllProposals | Where-Object { 
            $_.id -ne $Proposal.id -and $_.state -in @('bug', 'suggested', 'approved', 'processed') -and 
            $_.PSObject.Properties['regression_needed'] -and $_.regression_needed -eq $true 
        })
        if ($activeProps.Count -gt 0) {
            foreach ($ap in $activeProps) {
                if ($ap.origin_repo -eq $Proposal.origin_repo -and $Proposal.origin_repo -ne 'LCM_Inventory') {
                    $triggers += "Active dependency overlap with CRP-$($ap.id) on repo '$($ap.origin_repo)'"
                    $isRegressionNeeded = $true
                }
            }
        }
    }

    return [PSCustomObject]@{
        ProposalId         = $Proposal.id
        RegressionNeeded   = $isRegressionNeeded
        RegressionTriggers = $triggers
    }
}

function Assert-RegressionSafety {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ParentProposalId,
        [Parameter(Mandatory = $false)]
        [int]$ProposedDepth = 1,
        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 2,
        [Parameter(Mandatory = $false)]
        [object[]]$AllProposals
    )

    if ($null -eq $AllProposals) {
        $store = Get-ProposalStore
        $AllProposals = @($store.proposals)
    }

    # 1. Max Regression Depth Guard (MaxRegressionDepth = 2)
    if ($ProposedDepth -gt $MaxDepth) {
        throw "MaxRegressionDepth limit ($MaxDepth) exceeded for Proposal #$ParentProposalId (Proposed Depth: $ProposedDepth). Regression cascade halted."
    }

    # 2. DAG Cycle Detection (A -> B -> A)
    $visited = New-Object 'System.Collections.Generic.HashSet[int]'
    $currId = $ParentProposalId
    [void]$visited.Add($currId)

    while ($currId -gt 0) {
        $parentProp = $AllProposals | Where-Object { $_.id -eq $currId }
        if ($null -eq $parentProp -or -not $parentProp.PSObject.Properties['parent_crp_id'] -or -not $parentProp.parent_crp_id) {
            break
        }
        
        $nextParentId = [int]$parentProp.parent_crp_id
        if ($visited.Contains($nextParentId)) {
            throw "Blocked_Cycle: Circular dependency detected in regression DAG between Proposal #$ParentProposalId and Parent #$nextParentId."
        }
        [void]$visited.Add($nextParentId)
        $currId = $nextParentId
    }

    return $true
}

function Get-RegressionDAGOrder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Proposals
    )

    if ($null -eq $Proposals) {
        $store = Get-ProposalStore
        $Proposals = @($store.proposals)
    }

    $nodes = @{}
    $inDegree = @{}
    $edges = @{}

    foreach ($p in $Proposals) {
        $nodes[$p.id] = $p
        $inDegree[$p.id] = 0
        $edges[$p.id] = @()
    }

    foreach ($p in $Proposals) {
        if ($p.PSObject.Properties['parent_crp_id'] -and $p.parent_crp_id) {
            $parentId = [int]$p.parent_crp_id
            if ($nodes.ContainsKey($parentId)) {
                $edges[$parentId] += $p.id
                $inDegree[$p.id] = $inDegree[$p.id] + 1
            }
        }
    }

    $queue = [System.Collections.Generic.Queue[int]]::new()
    foreach ($id in $nodes.Keys) {
        if ($inDegree[$id] -eq 0) {
            $queue.Enqueue($id)
        }
    }

    $topologicalOrder = @()
    while ($queue.Count -gt 0) {
        $curr = $queue.Dequeue()
        $topologicalOrder += $nodes[$curr]

        foreach ($dep in $edges[$curr]) {
            $inDegree[$dep] = $inDegree[$dep] - 1
            if ($inDegree[$dep] -eq 0) {
                $queue.Enqueue($dep)
            }
        }
    }

    if ($topologicalOrder.Count -ne $nodes.Count) {
        Write-Warning "Cycle detected in proposal graph. Some proposals have unresolved circular dependencies."
    }

    return $topologicalOrder
}

function New-ChildRegressionProposal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ParentProposalId,
        [Parameter(Mandatory = $true)]
        [string]$TargetRepo,
        [Parameter(Mandatory = $true)]
        [string]$Reason,
        [Parameter(Mandatory = $false)]
        [string]$Scope = 'tools',
        [Parameter(Mandatory = $false)]
        [int]$NegativePriorityIndex = -1,
        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 2
    )

    $store = Get-ProposalStore
    $allProps = @($store.proposals)
    $parentProp = $allProps | Where-Object { $_.id -eq $ParentProposalId }

    if (-not $parentProp) {
        throw "Parent proposal #$ParentProposalId not found."
    }

    $parentDepth = if ($parentProp.PSObject.Properties['regression_depth'] -and $parentProp.regression_depth) { [int]$parentProp.regression_depth } else { 0 }
    $childDepth = $parentDepth + 1

    Assert-RegressionSafety -ParentProposalId $ParentProposalId -ProposedDepth $childDepth -MaxDepth $MaxDepth -AllProposals $allProps

    $childTitle = "Regression: $TargetRepo for CRP-$ParentProposalId ($($parentProp.title))"
    $childDetails = "Automated downstream regression proposal for $TargetRepo. Triggered by CRP-${ParentProposalId}: $Reason"

    # Mint child proposal in 'suggested' state (OPEN progress state) per RULE-LCM-015
    $newProp = New-WorkspaceProposal -Title $childTitle -OriginRepo $TargetRepo -Details $childDetails -State 'suggested'

    # Set regression metadata
    $newProp | Add-Member -NotePropertyName 'parent_crp_id' -NotePropertyValue $ParentProposalId -Force
    $newProp | Add-Member -NotePropertyName 'regression_depth' -NotePropertyValue $childDepth -Force
    $newProp | Add-Member -NotePropertyName 'negative_priority' -NotePropertyValue $NegativePriorityIndex -Force
    $newProp | Add-Member -NotePropertyName 'max_regression_depth' -NotePropertyValue $MaxDepth -Force

    # Save to store
    $store = Get-ProposalStore
    $idx = $store.proposals.FindIndex([System.Predicate[object]]{ param($item) $item.id -eq $newProp.id })
    if ($idx -ge 0) {
        $store.proposals[$idx] = $newProp
    }
    Set-ProposalStore -Store $store

    Write-Host "Minted Child Regression Proposal #$($newProp.id) (Depth: $childDepth, Prio: $NegativePriorityIndex) for Parent CRP-$ParentProposalId on repo '$TargetRepo'." -ForegroundColor Green
    return $newProp
}

function Get-ReposUnderReview {
    [CmdletBinding()]
    param(
        [string]$WorkspaceRoot = 'D:\Git_Repositories'
    )

    $openProposals = Get-WorkspaceProposals -OpenOnly
    $repos = @()
    if (Test-Path (Join-Path $WorkspaceRoot '.git')) {
        $repos += (Get-Item $WorkspaceRoot)
    }
    $repos += @(Get-ChildItem -Path $WorkspaceRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName '.git') })
    $results = @()

    $reviewsDir = Join-Path $WorkspaceRoot 'LCM_Inventory\data\reviews'

    foreach ($r in $repos) {
        $repoPath = $r.FullName
        $repoName = $r.Name

        $rawDirty = @(git -C $repoPath status --porcelain 2>$null)
        $dirtyFiles = @($rawDirty | Where-Object {
            $filePath = $_.Substring(3).Trim()
            -not ($filePath -like "data/logs/*" -or $filePath -like "data\logs\*" -or
                  $filePath -like "logs/*" -or $filePath -like "logs\*" -or
                  $filePath -like "LCM_Inventory/data/logs/lcm/*" -or $filePath -like "LCM_Inventory\data\logs\lcm\*" -or
                  $filePath -like "scratch/*" -or $filePath -like "scratch\*" -or
                  $filePath -like "LCM_Inventory/scratch/*" -or $filePath -like "LCM_Inventory\scratch\*")
        })

        # Path-aware review discrimination for LCM_Inventory per CRP-054 / RULE-LCM-004
        if ($repoName -eq 'LCM_Inventory') {
            # Filter out auto-accepted dynamic data (data/, logs/, scratch/) per RULE-EFF-001
            $dirtyFiles = @($dirtyFiles | Where-Object {
                $filePath = $_.Substring(3).Trim()
                -not ($filePath -like "data/*" -or $filePath -like "data\*")
            })
        }

        $isDirty = ($dirtyFiles.Count -gt 0)

        # Match proposals associated with this repo
        $matchingProps = @($openProposals | Where-Object { $_.origin_repo -eq $repoName })
        $propIds = if ($matchingProps.Count -gt 0) { ($matchingProps | ForEach-Object { "#$($_.id)" }) -join ', ' } else { '-' }

        if ($repoName -eq 'LCM_Inventory' -and -not $isDirty -and $matchingProps.Count -eq 0) {
            continue
        }

        # Check latest review record if available
        $latestReview = 'Pending Review'
        if (Test-Path $reviewsDir) {
            $revFiles = @(Get-ChildItem -Path $reviewsDir -Filter "REVIEW-$repoName-*.json" | Sort-Object LastWriteTime -Descending)
            if ($revFiles.Count -gt 0) {
                try {
                    $revData = Get-Content -Path $revFiles[0].FullName -Raw | ConvertFrom-Json
                    $latestReview = $revData.ReviewResult
                } catch { }
            }
        }

        if ($isDirty -or $matchingProps.Count -gt 0) {
            $commitStatus = if ($latestReview -in @('Accepted', 'AcceptedWithEdits', 'AcceptedAll')) {
                'Ready to Commit'
            } elseif ($latestReview -eq 'Deferred') {
                'Commit Deferred'
            } else {
                'Waiting for BC5 Review'
            }

            $results += [PSCustomObject]@{
                Repository        = $repoName
                DirtyFileCount    = $dirtyFiles.Count
                DirtyFiles        = $dirtyFiles
                Proposals         = $propIds
                BC5ReviewStatus   = $latestReview
                CommitStatus      = $commitStatus
                Path              = $repoPath
            }
        }
    }

    return $results
}

function Format-ProposalsTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Proposals
    )

    if ($null -eq $Proposals) {
        $Proposals = Get-WorkspaceProposals -OpenOnly
    }

    $granularity = Get-ReviewGranularity
    $mode = Get-LCMMode
    $activeCtx = Get-ActiveAppContext
    $activeId = if ($activeCtx) { $activeCtx.app_id } else { 'None (Base)' }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host (" LCM Workspace Proposals Ledger (Mode: {0} | Granularity: {1} | Active Focus: {2})" -f $mode.ToUpper(), $granularity.ToUpper(), $activeId) -ForegroundColor Cyan
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    if (@($Proposals).Count -eq 0) {
        Write-Host " No open proposals currently tracked." -ForegroundColor Gray
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        return
    }

    Write-Host (" {0,-7} | {1,-4} | {2,-8} | {3,-19} | {4,-11} | {5,-13} | {6,-18} | {7}" -f 'CRP ID', 'Prio', 'App', 'Timestamp', 'Plan State', 'STATUS', 'Origin Repo', 'Title') -ForegroundColor Yellow
    Write-Host "---------+------+----------+---------------------+-------------+---------------+--------------------+-----------------------" -ForegroundColor DarkGray

    foreach ($p in $Proposals) {
        $color = switch ($p.state) {
            'bug'       { [ConsoleColor]::Red }
            'suggested' { [ConsoleColor]::White }
            'processed' { [ConsoleColor]::Green }
            'approved'  { [ConsoleColor]::Green }
            'deferred'  { [ConsoleColor]::Yellow }
            'completed' { [ConsoleColor]::Cyan }
            'deleted'   { [ConsoleColor]::DarkGray }
            default     { [ConsoleColor]::Gray }
        }

        $idStr = if ($null -ne $p.PSObject.Properties['crp_id'] -and $p.crp_id) { $p.crp_id } else { if (($null -ne $p.PSObject.Properties['state'] -and $p.state -eq 'bug') -or ($null -ne $p.PSObject.Properties['cr_id'] -and $p.cr_id.StartsWith('BUG-'))) { "BUG-{0:D3}" -f [int]$p.id } else { "CRP-{0:D3}" -f [int]$p.id } }
        $prog = if ($null -ne $p.PSObject.Properties['progress_state'] -and $p.progress_state) { $p.progress_state } else { 'undecided' }
        $prio = if ($null -ne $p.PSObject.Properties['priority'] -and $p.priority) { $p.priority } else { 'M' }
        $appTag = if ($null -ne $p.PSObject.Properties['app_id'] -and $p.app_id) { $p.app_id -replace '(?i)^App:\s*', 'A' } else { '-' }
        $ts = if ($null -ne $p.PSObject.Properties['timestamp'] -and $p.timestamp) { $p.timestamp } elseif ($null -ne $p.PSObject.Properties['dates'] -and $null -ne $p.dates.PSObject.Properties['created']) { $p.dates.created } else { '-' }
        $scope = if ($null -ne $p.PSObject.Properties['origin_repo'] -and $p.origin_repo) { $p.origin_repo } else { 'LCM' }
        $pState = if ($null -ne $p.PSObject.Properties['state'] -and $p.state) { $p.state } else { 'suggested' }
        $title = if ($null -ne $p.PSObject.Properties['title'] -and $p.title) { $p.title } else { '' }
        Write-Host (" {0,-7} | {1,-4} | {2,-8} | {3,-19} | {4,-11} | {5,-13} | {6,-18} | {7}" -f $idStr, $prio, $appTag, $ts, $pState, $prog, $scope, $title) -ForegroundColor $color
    }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
}

function Format-ReposUnderReviewTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$Repos
    )

    if ($null -eq $Repos) {
        $Repos = Get-ReposUnderReview
    }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host " Repositories Under Review Queue" -ForegroundColor Cyan
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    if ($null -eq $Repos -or @($Repos).Length -eq 0 -or (@($Repos).Length -eq 1 -and $null -eq @($Repos)[0])) {
        Write-Host " No repositories currently pending review or commit." -ForegroundColor Gray
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        return
    }

    Write-Host (" {0,-22} | {1,-11} | {2,-12} | {3,-18} | {4}" -f 'Repository', 'Dirty Files', 'Proposals', 'BC5 Review Status', 'Commit Status') -ForegroundColor Yellow
    Write-Host "-----------------------+-------------+--------------+--------------------+----------------" -ForegroundColor DarkGray

    foreach ($r in $Repos) {
        $color = switch ($r.CommitStatus) {
            'Ready to Commit'       { [ConsoleColor]::Green }
            'Commit Deferred'       { [ConsoleColor]::Yellow }
            'Waiting for BC5 Review'{ [ConsoleColor]::Cyan }
            default                 { [ConsoleColor]::Gray }
        }

        Write-Host (" {0,-22} | {1,-11} | {2,-12} | {3,-18} | {4}" -f $r.Repository, "$($r.DirtyFileCount) file(s)", $r.Proposals, $r.BC5ReviewStatus, $r.CommitStatus) -ForegroundColor $color
    }

    Write-Host "==========================================================================================" -ForegroundColor Cyan
}

Set-Alias -Name Parse-ProposalIdExpression -Value Resolve-ProposalIdExpression
Set-Alias -Name Workon -Value Set-ActiveAppContext
Set-Alias -Name Apps -Value Format-LcmAppsTable
Set-Alias -Name App -Value New-LcmApp
Set-Alias -Name SplitDocs -Value Split-LcmAppDocs
Set-Alias -Name Purge-LcmPushedProposalBundle -Value Remove-LcmProposalBundle
Set-Alias -Name Purge-Bundle -Value Remove-LcmProposalBundle
Set-Alias -Name Get-Doc -Value Get-LcmProposalDocument

Export-ModuleMember -Function Get-ProposalStorePath, Get-ProposalStore, Set-ProposalStore, `
    Get-WorkspaceProposals, New-WorkspaceProposal, Get-LcmProposalLifecycleActions, Test-LcmProposalLifecycleTransition, Get-LcmProposalReviewObligations, Register-LcmCrossRepositoryReviewObligation, Complete-LcmCrossRepositoryReviewObligation, Move-LcmProposalLifecycleState, Start-LcmProposalReinstatement, Restore-LcmProposalReviewState, Set-LcmProposalBugIdentity, Enable-LcmImmediateBugRecovery, Get-LcmProposalLifecycleAudit, Set-WorkspaceProposalState, Set-WorkspaceProposalProgress, `
    Set-WorkspaceProposalPriority, Save-ProposalPlan, Save-ProposalWalkthrough, `
    Resolve-ProposalIdExpression, Get-LcmReviewCohortResolution, Save-LcmReviewCohortReceipt, Get-LcmReviewCohortCompletionPlan, Complete-LcmReviewCohortAcceptance, Set-LcmReviewCohort, Test-LcmProposalVerificationPrecondition, Sync-LcmCohortGateState, Invoke-LcmCohortLifecycleAction, Set-LcmProposalSupersession, Set-LcmProposalRetirement, Invoke-ProposalBatchAction, New-LcmLifecycleFailureReport, Format-LcmLifecycleFailureReport, New-LcmLifecycleFailureException, `
    Set-ReviewGranularity, Get-ReviewGranularity, Set-LCMMode, Get-LCMMode, Set-TestingMode, Get-TestingMode, `
    Get-ActiveAppContext, Set-ActiveAppContext, Get-LcmApps, Sync-LcmAppCatalog, Assert-LcmProposalImplementationEligibility, New-LcmApp, Split-LcmAppDocs, Format-LcmAppsTable, `
    Get-LcmProposalDocument, Remove-LcmProposalBundle, `
    Test-RegressionTrigger, Assert-RegressionSafety, Get-RegressionDAGOrder, New-ChildRegressionProposal, `
    Get-ReposUnderReview, Format-ProposalsTable, Format-ReposUnderReviewTable `
    -Alias Parse-ProposalIdExpression, Workon, Apps, App, SplitDocs, Purge-LcmPushedProposalBundle, Purge-Bundle, Get-Doc
