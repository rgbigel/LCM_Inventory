<#
.SYNOPSIS
  Multi-repository push and remote synchronization engine for LCM governed workspace.
.DESCRIPTION
  Module: tools/Invoke-LCM_Push.ps1
  Purpose: Iterates across all governed and child repositories under D:\Git_Repositories, detects if a Git remote exists and if local branch is ahead of remote tracking branch, and executes git push with structured audit logging.
  Path: LCM_Inventory/tools/Invoke-LCM_Push.ps1
  Authors: Rolf, LCM_AI Engine
    Version: 10.0.3
    Date: 2026-11-08 22:08:00
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

# Learned-advice review gate (RULE-CTX-005): no publish while candidates are pending.
$learnReview = Join-Path $workspaceRoot 'LCM_Inventory\tools\Invoke-LearnedAdviceReview.ps1'
if (Test-Path -LiteralPath $learnReview) {
    & pwsh -NoProfile -File $learnReview -Check
    if ($LASTEXITCODE -ne 0) {
        throw 'PUSH refused: learned-advice candidates are pending review. Run Invoke-LearnedAdviceReview.ps1, decide each one, then push again.'
    }
}

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
$pushPlan = Resolve-WorkspacePushPlan -Proposals @($ledgerJson.proposals) -RequestedRepositories $requestedRepositories -ProposalIds $requestedProposalIds

$repositoryStates = @(
    foreach ($repoName in $pushPlan.RequiredRepositories) {
        $repoPath = if ($repoName -eq 'Git_Repositories') { $workspaceRoot } else { Join-Path $workspaceRoot $repoName }
        $hasGit = Test-Path -LiteralPath (Join-Path $repoPath '.git')
        $hasRemote = $false
        $aheadCount = 0
        $branch = ''

        if ($hasGit) {
            $remotes = @(git -C $repoPath remote)
            $hasRemote = $remotes.Count -gt 0
            if ($hasRemote) {
                $branch = (git -C $repoPath rev-parse --abbrev-ref HEAD).Trim()
                $statusSummary = (git -C $repoPath status -sb) -join "`n"
                if ($statusSummary -match 'ahead\s+(\d+)') {
                    $aheadCount = [int]$Matches[1]
                }
            }
        }

        [pscustomobject]@{
            Name = $repoName
            Path = $repoPath
            HasGit = $hasGit
            HasRemote = $hasRemote
            AheadCount = $aheadCount
            Branch = $branch
        }
    }
)

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
if (-not $SkipGemini) {
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
if (Test-Path -LiteralPath $updateCatalogScript) {
    Write-Host "`n[Pre-Push Pipeline] Synchronizing Tool Catalog snapshot..." -ForegroundColor Yellow
    & pwsh -File $updateCatalogScript -Silent
    $rootDirty = git -C $workspaceRoot status --porcelain
    if ($rootDirty -match 'LCM_Inventory[/\\]config[/\\]tool_catalog\.json') {
        git -C $workspaceRoot add LCM_Inventory/config/tool_catalog.json
        git -C $workspaceRoot commit -m "chore(lcm): pre-push snapshot synchronization of tool_catalog.json" | Out-Null
    }
}

# ------------------------------------------------------------------------------
# 3. Workspace Maintenance & Daemon Log Truncation
# ------------------------------------------------------------------------------
$maintenanceScript = Join-Path $workspaceRoot "LCM_Inventory\tools\Invoke-LCM_Maintenance.ps1"
if (Test-Path -LiteralPath $maintenanceScript) {
    Write-Host "`n[Pre-Push Pipeline] Executing Workspace Maintenance & Daemon Log Truncation..." -ForegroundColor Yellow
    & pwsh -File $maintenanceScript -TailLines 100
}

# ------------------------------------------------------------------------------
# 4. Ensure LCM_AI (Governance & Copilot Authority) is Considered by Publish
# ------------------------------------------------------------------------------
$aiPath = Join-Path $workspaceRoot "LCM_AI"
if (Test-Path -LiteralPath (Join-Path $aiPath '.git')) {
    $aiBranch = (git -C $aiPath rev-parse --abbrev-ref HEAD).Trim()
    $aiStatus = (git -C $aiPath status -sb) -join "`n"
    $aiAhead = 0
    if ($aiStatus -match 'ahead\s+(\d+)') {
        $aiAhead = [int]$Matches[1]
    }
    if ($aiAhead -gt 0 -and (-not ($repositoryStates | Where-Object { $_.Name -eq 'LCM_AI' }))) {
        $repositoryStates += [pscustomobject]@{
            Name = 'LCM_AI'
            Path = $aiPath
            HasGit = $true
            HasRemote = $true
            AheadCount = $aiAhead
            Branch = $aiBranch
        }
        Write-Host "  -> Included LCM_AI authority in push cohort ($aiAhead ahead commit(s))." -ForegroundColor Green
    }
}

$pushedRepos = @()
$skippedRepos = @()
$failedRepos = @()

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

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $pushOutput = git -C $repoPath push origin $branch 2>&1
    $pushExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    if ($pushExit -eq 0) {
        Write-Host "    -> $pushOutput" -ForegroundColor Green
        $pushedRepos += $repoName
    } else {
        Write-Host "    -> ERROR (Exit Code $pushExit): $pushOutput" -ForegroundColor Red
        $failedRepos += $repoName
    }
}

$cohortPushed = $failedRepos.Count -eq 0 -and $pushedRepos.Count -ge $pushPlan.RequiredRepositories.Count
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
        $lcmVersion = "10.0.0"
        $invFile = Join-Path $workspaceRoot "LCM_Inventory\data\inventory.json"
        if (Test-Path -LiteralPath $invFile) {
            try {
                $invData = Get-Content -LiteralPath $invFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($invData.GlobalLCMVersion) { $lcmVersion = "v$($invData.GlobalLCMVersion.TrimStart('v'))" }
            } catch { }
        }
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
Write-Host "==========================================================================" -ForegroundColor Cyan
