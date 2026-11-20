<#
.SYNOPSIS
  Multi-repository push and remote synchronization engine for LCM governed workspace.
.DESCRIPTION
  Module: tools/Invoke-LCM_Push.ps1
  Purpose: Iterates across all governed and child repositories under D:\Git_Repositories, detects if a Git remote exists and if local branch is ahead of remote tracking branch, and executes git push with structured audit logging.
  Path: LCM_Inventory/tools/Invoke-LCM_Push.ps1
  Implementation Choices (BUG-349): the SQL ledger projections (data/proposals/proposals.sql,
  strategies.sql) are bookkeeping artifacts (RULE-EFF-001); the push exports them in their final
  state and commits them (chore(ledger), path-limited, no hooks) before pushing, so the pre-push
  projection check never aborts a push (RULE-EFF-002, operator 2026-11-17).
  Authors: Rolf, LCM_AI Engine, Claude
    Implementation Choices (BUG-348): -DryRun skips every mutating pre-push step (Update-Gemini export commit,
    tool catalog snapshot commit, the second full maintenance run); before, a dry run committed and deleted
    186 script logs.
    Version: 10.2.9
    Date: 2026-11-20
    Implementation Choices (BUG-383): no learned-advice gate; learned advice is administrative data and a push is
    maintenance and backup (RULE-CTX-005 item 7).
    Implementation Choices (CRP-366): the ledger dump runs on the registered interpreter (RULE-PY-010).
    Implementation Choices (BUG-380 B12): the push targets every workspace repository with commits ahead of its
    remote, governed or not (operator rule 2026-11-20); repositories that become ahead through the pre-push
    commits are added before the push; a remote without upstream tracking is reported, not pushed.
    Implementation Choices (operator review item 10 and its correction, 2026-11-20): governed = LCM core plus the
    repositories the inventory classifies as governed; a governed repository outside the core that is not converged
    to the active LCM version is held back and reported, never pushed. A non-governed repository is pushed as backup
    and never fails by LCM rules (an 'LCM Standard Pre-Push Hook' found there is not run); its failed push is reported
    without blocking the governed cohort or the pushed transition.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Commit reason and audit message for the push operation')]
    [string]$Reason = "feat(cm): sync completed workspace proposals and governance updates",

    [Parameter(Mandatory = $false, HelpMessage = 'Specific repositories to push (defaults to all ahead repositories)')]
    [string[]]$Repositories,

    [Parameter(Mandatory = $false, HelpMessage = 'Specific proposal IDs to transition to pushed state')]
    [object[]]$ProposalIds,

    [Parameter(Mandatory = $false, HelpMessage = 'Skip the pre-push Gemini export and knowledge base mirror pipeline')]
    [switch]$SkipGemini,

    [Parameter(Mandatory = $false, HelpMessage = 'Force git push even if validation warnings exist')]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = 'Automatically execute stepwise requalification without interactive prompt')]
    [switch]$ForceRequalify,

    [Parameter(Mandatory = $false, HelpMessage = 'Bypass the pre-push relief / minimal-tests gate and record an audit waiver')]
    [Alias('SkipReliefGate', 'ForceRelief')]
    [switch]$BypassReliefGate,

    [Parameter(Mandatory = $false, HelpMessage = 'Run in non-interactive mode; fail closed if triage decisions are required')]
    [switch]$NonInteractive,

    [Parameter(Mandatory = $false, HelpMessage = 'Simulate the push operation and show actions without modifying remotes')]
    [Alias('WhatIf')]
    [switch]$DryRun,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Invoke-LCM_Push.ps1 requires PowerShell 7 (pwsh.exe). Windows PowerShell (powershell.exe) is not supported.'
}

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM MULTI-REPOSITORY PUSH & SYNC ENGINE (Invoke-LCM_Push)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Pushes all ahead workspace repositories to remote Git repositories in lockstep."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Invoke-LCM_Push.ps1 [[-Reason] <str>] [-Repositories <str[]>] [-SkipGemini] [-Force] [-DryRun] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Reason          : Commit reason and audit message"
    Write-Host "  -Repositories    : Specific repositories to push"
    Write-Host "  -SkipGemini      : Skip pre-push Gemini export"
    Write-Host "  -Force           : Force git push"
    Write-Host "  -DryRun          : Simulate push without modifying remotes"
    Write-Host "  -Help (-h, -?)   : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$workspaceRoot = 'D:\Git_Repositories'
$cmLogFile = Join-Path $workspaceRoot "LCM_Inventory\logs\cm_activity.log"
$proposalsFile = Join-Path $workspaceRoot "LCM_Inventory\data\proposals\proposals.json"
$eligibilityModule = Join-Path $workspaceRoot "LCM_Inventory\modules\LCM_PushEligibility.psm1"

$targetProposalSet = [System.Collections.Generic.HashSet[int]]::new()
if ($null -ne $ProposalIds) {
    foreach ($item in $ProposalIds) {
        foreach ($sub in "$item".Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)) {
            if ($sub.Trim() -match '^\d+$') {
                [void]$targetProposalSet.Add([int]$sub.Trim())
            }
        }
    }
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM MULTI-REPOSITORY PUSH & REMOTE SYNCHRONIZATION ENGINE" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
$lastPushStr = try {
    (Get-ItemProperty -Path 'HKLM:\SOFTWARE\LCM' -Name 'MRPushTimeStamp' -ErrorAction SilentlyContinue).MRPushTimeStamp
} catch { $null }
$lastPushBanner = if (-not [string]::IsNullOrWhiteSpace($lastPushStr)) { " (Last Push: $lastPushStr)" } else { "" }
Write-Host " Push Reason : $Reason$lastPushBanner"
Write-Host " Timestamp   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "==========================================================================" -ForegroundColor Cyan

# Learned advice never blocks a push (BUG-383, RULE-CTX-005 item 7); the former review gate is removed.

# ------------------------------------------------------------------------------
# 0. Read-only completion and lockstep preflight. This must precede all mutation.
# ------------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $proposalsFile)) {
    throw "PUSH cannot continue because the proposal ledger was not found: $proposalsFile"
}
if (-not (Test-Path -LiteralPath $eligibilityModule)) {
    throw "PUSH cannot continue because the eligibility module was not found: $eligibilityModule"
}

Import-Module -Name $eligibilityModule -Force
Import-Module -Name (Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1') -Force
$ledgerJson = Get-Content -LiteralPath $proposalsFile -Raw -Encoding UTF8 | ConvertFrom-Json
$requestedProposalIds = @($targetProposalSet)
$requestedRepositories = if ($null -eq $Repositories) { @() } else { @($Repositories | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
# BUG-380 B12: push targets are the repositories with commits ahead of their remote, governed or not.
$allRepositoryStates = @(Get-LCM_PushRepositoryStates -WorkspaceRoot $workspaceRoot)
# Operator 2026-11-20: governed repositories outside the LCM core are pushed only once converged to the active LCM version.
$inventoryRepositories = @()
$inventoryFile = Join-Path $workspaceRoot 'LCM_Inventory\data\inventory.json'
if (Test-Path -LiteralPath $inventoryFile) {
    $inventoryRepositories = @((Get-Content -LiteralPath $inventoryFile -Raw -Encoding UTF8 | ConvertFrom-Json).repositories)
}
$activeLcmVersion = [string](Get-Content -LiteralPath (Join-Path $workspaceRoot 'LCM_AI\.agents\version.json') -Raw | ConvertFrom-Json).version
$heldRepositories = @(Get-LCM_UnconvergedPushRepositories -InventoryRepositories $inventoryRepositories -LcmVersion $activeLcmVersion)
foreach ($held in $heldRepositories) {
    $heldState = @($allRepositoryStates | Where-Object { $_.Name -eq $held.Name -and $_.AheadCount -gt 0 })
    if ($heldState.Count -gt 0) {
        Write-Host "  [$($held.Name)] governed, $($held.Reason): held back, $($heldState[0].AheadCount) commit(s) stay local until LCM convergence." -ForegroundColor Yellow
    }
}
$aheadRepositories = @($allRepositoryStates | Where-Object { $_.HasRemote -and $_.AheadCount -gt 0 } | ForEach-Object { $_.Name })
foreach ($noUpstream in @($allRepositoryStates | Where-Object { $_.HasRemote -and -not $_.HasUpstream })) {
    Write-Host "  [$($noUpstream.Name)] remote without upstream tracking branch: not pushed (set the upstream once by hand)." -ForegroundColor Yellow
}
if (@($aheadRepositories).Count -eq 0 -and @($requestedRepositories).Count -eq 0) {
    # BUG-389: nothing ahead is no failure (a GoodNight -Push on a quiet day must not fail).
    Write-Host '  -> No repository has commits ahead of its remote; nothing to push.' -ForegroundColor Green
    return
}
$pushPlan = Resolve-WorkspacePushPlan -Proposals @($ledgerJson.proposals) -AheadRepositories $aheadRepositories -RequestedRepositories $requestedRepositories -ProposalIds $requestedProposalIds -HeldRepositories @($heldRepositories | ForEach-Object { $_.Name })

# ------------------------------------------------------------------------------
# RULE-DEC-005 Preflight: Stepwise Requalification & Dynamic Pre-Publish Triage
# ------------------------------------------------------------------------------
$requalModule = Join-Path $workspaceRoot 'LCM_Inventory\modules\LcmPushRequalification.psm1'
Import-Module -Name $requalModule -Force

$preflightCheck = Test-LcmPublishPreflight -PushPlan $pushPlan -WorkspaceRoot $workspaceRoot -ProposalsFile $proposalsFile

if ($preflightCheck.HasReliefOrDebt) {
    if ($BypassReliefGate -or $Force) {
        Write-Host "`n[RULE-DEC-005 PREFLIGHT] Bypass active (-BypassReliefGate / -Force). Proceeding with publish..." -ForegroundColor Yellow
        $waiverDir = Join-Path $workspaceRoot "LCM_Inventory\data\reviews\push_receipts"
        if (-not (Test-Path -LiteralPath $waiverDir)) { New-Item -ItemType Directory -Path $waiverDir -Force | Out-Null }
        $waiverFile = Join-Path $waiverDir ("bypass_waiver_{0:yyyyMMdd_HHmmss}.json" -f (Get-Date))
        $waiverPayload = @{
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Summary   = $preflightCheck.Summary
            Actor     = $env:USERNAME
            Bypass    = $true
        }
        [System.IO.File]::WriteAllText($waiverFile, ($waiverPayload | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
    } elseif ($ForceRequalify) {
        Write-Host "`n[RULE-DEC-005 PREFLIGHT] -ForceRequalify specified. Initiating Stepwise Requalification..." -ForegroundColor Cyan
        $requalResult = Invoke-LcmStepwiseRequalification -PushPlan $pushPlan -WorkspaceRoot $workspaceRoot -ProposalsFile $proposalsFile -NonInteractive:$NonInteractive
        if (-not $requalResult.Success) {
            throw "Stepwise Requalification failed or was aborted by operator at Step $($requalResult.FailedStep)."
        }
    } elseif ($NonInteractive) {
        throw "PUSH refused by RULE-DEC-005: Workspace has active relief mode or test debt ($($preflightCheck.Summary)). Re-run with -ForceRequalify or -BypassReliefGate."
    } else {
        $triageChoice = Show-LcmPublishTriagePrompt -PreflightCheck $preflightCheck
        switch ($triageChoice) {
            'requalify' {
                $requalResult = Invoke-LcmStepwiseRequalification -PushPlan $pushPlan -WorkspaceRoot $workspaceRoot -ProposalsFile $proposalsFile
                if (-not $requalResult.Success) {
                    throw "Stepwise Requalification failed or was aborted by operator at Step $($requalResult.FailedStep)."
                }
            }
            'circumvent' {
                Write-Host "`n[RULE-DEC-005 PREFLIGHT] Operator selected Circumvent / Force Push. Proceeding with publish..." -ForegroundColor Yellow
            }
            'continue' {
                Write-Host "`n[RULE-DEC-005 PREFLIGHT] Continuing without requalification. Downstream checks may fail." -ForegroundColor Yellow
                if ($preflightCheck.DebtProposals.Count -gt 0) {
                    throw "PUSH refused by RULE-DEC-005: Proposal #$($preflightCheck.DebtProposals[0].id) is marked '[minimal-tests]' or has deferred quality checks. Full verification required before remote push."
                }
            }
            'cancel' {
                Write-Host "`n[PUBLISH] Cancelled by operator. Working tree and git remotes untouched." -ForegroundColor Yellow
                return
            }
        }
    }
}

$repositoryStates = @($allRepositoryStates | Where-Object { $_.Name -in $pushPlan.RequiredRepositories })

Test-WorkspacePushCohort -PushPlan $pushPlan -RepositoryStates $repositoryStates | Out-Null
Test-WorkspaceProposalBundlesInHead -PushPlan $pushPlan -RepositoryStates $repositoryStates | Out-Null
Write-Host "  -> Lockstep preflight passed for: $($pushPlan.RequiredRepositories -join ', ')" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 0b. Bounded log maintenance after eligibility preflight and before publication.
# ------------------------------------------------------------------------------
$maintenanceScript = Join-Path $workspaceRoot 'LCM_Inventory\tools\Invoke-LCM_Maintenance.ps1'
if (-not (Test-Path -LiteralPath $maintenanceScript)) {
    throw "PUSH cannot continue because log maintenance was not found: $maintenanceScript"
}
Write-Host "`n[Pre-Push Pipeline] Maintaining active daemon and transient logs..." -ForegroundColor Yellow
$maintenanceArgs = @('-NoProfile', '-File', $maintenanceScript, '-LogOnly')
if ($DryRun) {
    $maintenanceArgs += '-DryRun'
}
& pwsh @maintenanceArgs
if ($LASTEXITCODE -ne 0) {
    throw "PUSH cannot continue because log maintenance failed with exit code $LASTEXITCODE."
}

# ------------------------------------------------------------------------------
# 1. Synchronize Gemini AI & Knowledge Base Mirror (RULE-LCM-013)
# ------------------------------------------------------------------------------
# BUG-348: a dry run never runs a mutating pre-push step (export commits, catalog commit, maintenance deletions).
if ($DryRun) {
    Write-Host "`n[Pre-Push Pipeline] DryRun: skipping Update-Gemini export, tool catalog snapshot commit and workspace maintenance (they would change or delete files)." -ForegroundColor Yellow
}
if (-not $SkipGemini -and -not $DryRun) {
    Write-Host "`n[Pre-Push Pipeline] Executing Update-Gemini Context & Knowledge Base Synchronization..." -ForegroundColor Yellow
    $updateGeminiScript = Join-Path $workspaceRoot "LCM_Inventory\tools\Update-Gemini.ps1"
    if (Test-Path -LiteralPath $updateGeminiScript) {
        & pwsh -File $updateGeminiScript
        # If LCM_AI updated export files, stage and commit them
        $aiStatus = git -C (Join-Path $workspaceRoot "LCM_AI") status --porcelain
        if ($aiStatus) {
            git -C (Join-Path $workspaceRoot "LCM_AI") add -A
            git -C (Join-Path $workspaceRoot "LCM_AI") commit -m "chore(gemini): pre-push synchronization of rules export and knowledge base" | Out-Null
        }
    } else {
        Write-Warning "Update-Gemini.ps1 not found at $updateGeminiScript"
    }
}

# ------------------------------------------------------------------------------
# 2. Synchronize Tool Catalog & CM Metadata Snapshot for Root Container
# ------------------------------------------------------------------------------
$updateCatalogScript = Join-Path $workspaceRoot "LCM_Inventory\tools\Update-ToolCatalog.ps1"
if (-not $DryRun -and (Test-Path -LiteralPath $updateCatalogScript)) {
    Write-Host "`n[Pre-Push Pipeline] Synchronizing Tool Catalog snapshot..." -ForegroundColor Yellow
    & pwsh -File $updateCatalogScript -Silent
    # CRP-358: the catalog lives in tools.db; its publish projection data/tools/tools.sql is written and committed in step 2a.
}

# ------------------------------------------------------------------------------
# 2a. Commit SQL Ledger Projections of LCM_Inventory (BUG-349, RULE-EFF-001/002)
# ------------------------------------------------------------------------------
$inventoryRepoPath = Join-Path $workspaceRoot 'LCM_Inventory'
$ledgerDumpScript = Join-Path $inventoryRepoPath 'tools\sync_proposals_db.py'
if (-not $DryRun -and (Test-Path -LiteralPath $ledgerDumpScript)) {
    Write-Host "`n[Pre-Push Pipeline] Exporting and committing SQL ledger projections..." -ForegroundColor Yellow
    Push-Location -LiteralPath $inventoryRepoPath
    try {
        Import-Module -Name (Join-Path $inventoryRepoPath 'modules\LcmRuntimeAtoms.psm1') -Force
        & (Get-LcmRuntimePath -Key 'python') $ledgerDumpScript --action dump --silent
        # CRP-358: tools.sql is the publish projection of tools.db (written only here; restore after a pull)
        & (Get-LcmRuntimePath -Key 'python') (Join-Path $inventoryRepoPath 'tools\sync_tool_catalog_db.py') --action dump --silent
    } finally {
        Pop-Location
    }
    $ledgerPaths = @('data/proposals/proposals.sql', 'data/proposals/strategies.sql', 'data/tools/tools.sql')
    $ledgerDirty = @(git -C $inventoryRepoPath status --porcelain -- $ledgerPaths)
    if ($ledgerDirty.Count -gt 0) {
        git -C $inventoryRepoPath add -- $ledgerPaths
        git -C $inventoryRepoPath commit --no-verify -m 'chore(ledger): pre-push SQL projections of proposals.db and tools.db' -- $ledgerPaths | Out-Null
        Write-Host '  -> Committed SQL ledger projections (bookkeeping, RULE-EFF-001).' -ForegroundColor Green
    }
}

# ------------------------------------------------------------------------------
# 3. Workspace Maintenance & Daemon Log Truncation
# ------------------------------------------------------------------------------
$maintenanceScript = Join-Path $workspaceRoot "LCM_Inventory\tools\Invoke-LCM_Maintenance.ps1"
if (-not $DryRun -and (Test-Path -LiteralPath $maintenanceScript)) {
    Write-Host "`n[Pre-Push Pipeline] Executing Workspace Maintenance & Daemon Log Truncation..." -ForegroundColor Yellow
    & pwsh -File $maintenanceScript -TailLines 100
}

# ------------------------------------------------------------------------------
# 4. Refresh the cohort after the pre-push commits (BUG-380 B12; LCM_AI authority included as before)
# ------------------------------------------------------------------------------
$refreshedStates = @(Get-LCM_PushRepositoryStates -WorkspaceRoot $workspaceRoot)
foreach ($refreshed in @($refreshedStates | Where-Object { $_.HasRemote -and $_.AheadCount -gt 0 })) {
    $existing = @($repositoryStates | Where-Object { $_.Name -eq $refreshed.Name })
    if ($existing.Count -gt 0) {
        $existing[0].AheadCount = $refreshed.AheadCount
        continue
    }
    if ($refreshed.Name -in @($heldRepositories | ForEach-Object { $_.Name })) {
        continue
    }
    if ($requestedRepositories.Count -eq 0 -or $refreshed.Name -eq 'LCM_AI') {
        $repositoryStates += $refreshed
        Write-Host "  -> Included $($refreshed.Name) in push cohort ($($refreshed.AheadCount) ahead commit(s))." -ForegroundColor Green
    }
}

$pushedRepos = @()
$skippedRepos = @()
$failedRepos = @()
$failedNonGovernedRepos = @()

foreach ($repositoryState in $repositoryStates) {
    $repoName = $repositoryState.Name
    $repoPath = $repositoryState.Path
    $branch = $repositoryState.Branch
    $aheadCount = $repositoryState.AheadCount

    if ($DryRun) {
        Write-Host "  [$repoName] [DRY RUN] Would push $aheadCount commit(s) on branch '$branch' to remote 'origin':" -ForegroundColor Yellow
        $commits = git -C $repoPath log "origin/$branch..HEAD" --oneline 2>$null
        if ($commits) {
            foreach ($c in $commits) {
                Write-Host "      * $c" -ForegroundColor Gray
            }
        }
        $pushedRepos += $repoName
        continue
    }

    Write-Host "  [$repoName] PUSHING $aheadCount commit(s) on branch '$branch' to remote 'origin'..." -ForegroundColor Cyan

    # Operator review item 10: a non-governed repository is pushed as plain backup; LCM hooks do not apply there.
    $isGoverned = Test-LCM_GovernedPushRepository -RepositoryName $repoName -InventoryRepositories $inventoryRepositories
    $pushArguments = @('-C', $repoPath, 'push', 'origin', $branch)
    if (-not $isGoverned) {
        $hooksDir = [string](git -C $repoPath rev-parse --git-path hooks 2>$null)
        $hooksPathSetting = [string](git -C $repoPath config core.hooksPath 2>$null)
        if (-not [string]::IsNullOrWhiteSpace($hooksPathSetting)) { $hooksDir = $hooksPathSetting }
        $hookFile = if ([IO.Path]::IsPathRooted($hooksDir)) { Join-Path $hooksDir 'pre-push' } else { Join-Path (Join-Path $repoPath $hooksDir) 'pre-push' }
        if ((Test-Path -LiteralPath $hookFile) -and (Select-String -LiteralPath $hookFile -Pattern 'LCM Standard Pre-Push Hook' -SimpleMatch -Quiet)) {
            $pushArguments += '--no-verify'
            Write-Host "    -> [$repoName] non-governed: LCM pre-push hook not applied (operator requirement 2026-11-20)." -ForegroundColor DarkGray
        }
    }

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $pushOutput = git @pushArguments 2>&1
    $pushExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    if ($pushExit -eq 0) {
        Write-Host "    -> $pushOutput" -ForegroundColor Green
        $pushedRepos += $repoName
    } else {
        Write-Host "    -> ERROR (Exit Code $pushExit): $pushOutput" -ForegroundColor Red
        if ($isGoverned) {
            $failedRepos += $repoName
        } else {
            # Operator review item 10: reported, never blocks the governed cohort.
            $failedNonGovernedRepos += $repoName
        }
    }
}

$governedRequired = @($pushPlan.RequiredRepositories | Where-Object { Test-LCM_GovernedPushRepository -RepositoryName $_ -InventoryRepositories $inventoryRepositories })
$governedPushed = @($pushedRepos | Where-Object { Test-LCM_GovernedPushRepository -RepositoryName $_ -InventoryRepositories $inventoryRepositories })
$cohortPushed = $failedRepos.Count -eq 0 -and $governedPushed.Count -ge $governedRequired.Count
$pushTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
if (-not $cohortPushed) {
    Write-Host "`n  -> PUSH cohort did not complete. No proposal state will transition to 'pushed'." -ForegroundColor Red
}

if ($cohortPushed) {
    if ($DryRun) {
        Write-Host "`n  -> [DRY RUN] Would append PUSH_EXECUTED record to cm_activity.log for: $($pushedRepos -join ', ')" -ForegroundColor Yellow
        foreach ($proposal in $pushPlan.CompletedProposals) {
            Write-Host "      * [DRY RUN] Would transition Proposal $($proposal.Id) in $($proposal.Repository) to 'pushed'" -ForegroundColor Gray
        }
        Write-Host "  -> [DRY RUN] Total $($pushPlan.CompletedProposalIds.Count) completed proposal(s) would transition to 'pushed'." -ForegroundColor Yellow
    } else {
        # BUG-389: the LCM version comes from LCM_AI/.agents/version.json (authority); before, the inventory lookup
        # read a top-level GlobalLCMVersion that does not exist and logged the fallback 10.0.0.
        $lcmVersion = "v$($activeLcmVersion.TrimStart('v'))"
        $logEntry = "[$pushTimestamp] [SUCCESS] [Target: MULTI] [Version: $lcmVersion] [PushDate: $pushTimestamp] [AffectedRepos: $($pushedRepos -join ', ')] PUSH_EXECUTED - Pushed $($pushedRepos.Count) repository/repositories to remote ($($pushedRepos -join ', ')). Reason: $Reason"
        Add-Content -LiteralPath $cmLogFile -Value $logEntry -Encoding UTF8
        Write-Host "`n  -> Appended PUSH_EXECUTED record to cm_activity.log" -ForegroundColor Green

        try {
            $lcmRegKey = 'HKLM:\SOFTWARE\LCM'
            if (-not (Test-Path -LiteralPath $lcmRegKey)) {
                New-Item -Path $lcmRegKey -Force | Out-Null
            }
            Set-ItemProperty -Path $lcmRegKey -Name 'MRPushTimeStamp' -Value $pushTimestamp -Force | Out-Null
            Write-Host "  -> Updated host telemetry HKLM:\SOFTWARE\LCM\MRPushTimeStamp: $pushTimestamp" -ForegroundColor Green
        } catch {
            Write-Warning "Could not update registry MRPushTimeStamp: $($_.Exception.Message)"
        }

        # Transition only completed proposals in the successfully pushed cohort.
        $transitionCount = 0
        foreach ($p in $ledgerJson.proposals) {
            $plannedProposal = @($pushPlan.CompletedProposals | Where-Object { $_.Id -eq [int]$p.id })
            if ($plannedProposal.Count -eq 0 -or $plannedProposal[0].Repository -notin $pushedRepos) {
                continue
            }

            $transitioned = Move-LcmProposalLifecycleState -Id $p.id -State 'pushed' -Details "Pushed to remote ($($pushedRepos -join ', '))"
            $proposalStore = Get-ProposalStore
            $updatedProposal = @($proposalStore.proposals | Where-Object { $_.id -eq $transitioned.id })[0]
            $updatedProposal | Add-Member -NotePropertyName 'pushed_at' -NotePropertyValue $pushTimestamp -Force
            Set-ProposalStore -Store $proposalStore
            $transitionCount++
        }
        if ($transitionCount -gt 0) {
            Write-Host "  -> Transitioned $transitionCount proposal(s) from 'completed' to 'pushed' state in proposals.json." -ForegroundColor Green
        }

        # RULE-DEC-005 Post-Push Clean State & Relief Switch Reset
        Write-Host "`n[Clean State Pipeline (RULE-DEC-005)] Resetting development relief switches..." -ForegroundColor Yellow
        try {
            Set-ReviewGranularity -Granularity 'tight' | Out-Null
            Set-TestingMode -Mode 'active' | Out-Null
            $store = Get-ProposalStore
            if ($store.PSObject.Properties['flow_mode']) { $store.flow_mode = 'standard' }
            if ($store.PSObject.Properties['always_proceed']) { $store.always_proceed = $false }
            Set-ProposalStore -Store $store
            Write-Host "  -> Relief switches deactivated: Granularity=tight, TestingMode=active, FlowMode=standard, AlwaysProceed=false." -ForegroundColor Green
        } catch {
            Write-Warning "Failed to reset relief switches: $($_.Exception.Message)"
        }
    }
}

# ------------------------------------------------------------------------------
# Post-Push Automated Cleanup: BCR Scratch & Stale Baseline Purge
# ------------------------------------------------------------------------------
$clearBcrScript = Join-Path $workspaceRoot "LCM_Inventory\tools\Clear-BCReviewTemp.ps1"
if ($cohortPushed -and (Test-Path -LiteralPath $clearBcrScript)) {
    if ($DryRun) {
        Write-Host "`n  -> [DRY RUN] Would execute automated Beyond Compare review scratch cleanup (Clear-BCReviewTemp -Purge)" -ForegroundColor Yellow
    } else {
        Write-Host "`n[Post-Push Pipeline] Executing automated Beyond Compare review scratch cleanup..." -ForegroundColor Yellow
        & pwsh -File $clearBcrScript -Purge -NoExplorer
    }
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " [SUMMARY] Workspace Push Completed" -ForegroundColor Green
Write-Host " Pushed Repos  : $($pushedRepos.Count) ($($pushedRepos -join ', '))"
Write-Host " Skipped Repos : $($skippedRepos.Count)"
Write-Host " Failed Repos  : $($failedRepos.Count)"
if ($failedNonGovernedRepos.Count -gt 0) {
    Write-Host " Not pushed (non-governed, not blocking): $($failedNonGovernedRepos -join ', ')" -ForegroundColor Yellow
}
Write-Host "==========================================================================" -ForegroundColor Cyan
