[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Name or path of the repository')]
    [Alias('RepositoryName', 'Repo', 'Name')]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $false, HelpMessage = 'Review outcome disposition (Completed, Complete, CompleteAll, CompleteStaged, CompleteWithEdits, Rejected, Deferred)')]
    [ValidateSet("Completed", "Complete", "CompleteAll", "CompleteStaged", "CompleteWithEdits", "Rejected", "Deferred", "ALL", "COMPLETE ALL")]
    [string]$Result,

    [Parameter(Mandatory = $false, HelpMessage = 'Review notes, rationale, or instructions for the audit receipt')]
    [string]$Notes,

    [Parameter(Mandatory = $false, HelpMessage = 'Legacy compatibility switch; accepted reviews commit the live working tree')]
    [switch]$All,

    [Parameter(Mandatory = $false, HelpMessage = 'Single-cycle minimal testing scope: fast syntax and AST validation only')]
    [switch]$MinimalTests,

    [Parameter(Mandatory = $false, HelpMessage = 'Authorized exception to interactive visual-review confirmation only; does not waive lifecycle or preflight checks')]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = 'Exact CRP or BUG identifier (e.g. CRP-257)')]
    [Alias('Cr', 'ChangeRequest', 'Proposal', 'ProposalId')]
    [ValidatePattern('^(CRP|BUG)-\d+$')]
    [string]$CRP = '',

    [Alias('h', '?')]
    [switch]$Help
)

<#
.SYNOPSIS
    Interactive review acceptance recorder and exact-CRP commit gate for Beyond Compare and LCM governance.
.DESCRIPTION
    Module: tools/Submit-ReviewResult.ps1
    Purpose: Records operator review acceptance from Beyond Compare and commits the accepted live working tree
             through the exact-CRP review gate.
    Path: tools/Submit-ReviewResult.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 8.3.0
    Date: 2026-10-02
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-StagedDiffSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $diff = git -C $Path diff --cached --binary
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read the staged Git diff for '$Path'."
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($diff -join "`n"))
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " SUBMIT REVIEW RESULT (Submit-ReviewResult)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Records an accepted Beyond Compare review and commits the reviewed live worktree."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Submit-ReviewResult.ps1 -CRP <CRP-ID> [[-RepositoryPath] <str>] [-Result <str>] [-Notes <str>] [-All] [-MinimalTests] [-Force] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -RepositoryPath  : Name or path of the repository"
    Write-Host "  -Result          : Review disposition (Completed, CompleteAll, CompleteWithEdits, Rejected, Deferred)"
    Write-Host "  -Notes           : Review notes or rationale"
    Write-Host "  -All             : Legacy compatibility switch; accepted reviews commit the live worktree"
    Write-Host "  -MinimalTests    : Single-cycle minimal testing scope: fast syntax and AST validation only"
    Write-Host "  -Force           : Visual-review confirmation exception only; lifecycle and preflight rules still apply"
    Write-Host "  -CRP             : Exact CRP or BUG identifier required for completion"
    Write-Host "  -Help (-h, -?)   : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

if ([string]::IsNullOrWhiteSpace($CRP)) {
    throw '-CRP is required. Repository-based proposal completion is not permitted.'
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
    $workspaceRoot = Split-Path $PSScriptRoot -Parent
}
$adminModeModulePath = Join-Path $workspaceRoot 'LCM_Inventory\modules\AdminMode.psm1'
if (-not (Test-Path -LiteralPath $adminModeModulePath -PathType Leaf)) {
    throw "ADMINMODE module not found: $adminModeModulePath"
}
Import-Module -Name $adminModeModulePath -Force

$targetRepoPath = $null
if (-not [string]::IsNullOrWhiteSpace($RepositoryPath)) {
    $resolvedPath = $RepositoryPath.Trim('"', "'")
    if ($resolvedPath -in @('.', 'root', 'Git_Repositories', (Split-Path $workspaceRoot -Leaf))) {
        $targetRepoPath = $workspaceRoot
    } elseif (Test-Path -LiteralPath $resolvedPath) {
        $curr = $resolvedPath
        while ($curr -and $curr -ne (Split-Path $curr -Parent)) {
            if (Test-Path -LiteralPath (Join-Path $curr '.git')) {
                $targetRepoPath = $curr
                break
            }
            $curr = Split-Path $curr -Parent
        }
    }
    if (-not $targetRepoPath) {
        $candidatePath = Join-Path $workspaceRoot $resolvedPath
        if (Test-Path -LiteralPath $candidatePath) { $targetRepoPath = $candidatePath }
    }
} else {
    $targetRepoPath = $workspaceRoot
}

$repoName = Split-Path $targetRepoPath -Leaf
$reviewsDir = Join-Path $workspaceRoot "LCM_Inventory\data\reviews"
if (-not (Test-Path -LiteralPath $reviewsDir)) { New-Item -ItemType Directory -Path $reviewsDir -Force | Out-Null }
$stagedManifestFile = Join-Path $reviewsDir "staged_review_${repoName}.json"

$stagedManifest = $null
if (Test-Path -LiteralPath $stagedManifestFile) {
    try {
        $stagedManifest = Get-Content -LiteralPath $stagedManifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {}
}

if (-not $stagedManifest) {
    # Dynamically discover active review scratchpad in LCM_Inventory/scratch/BC_Review
    $reviewBase = Join-Path $workspaceRoot "LCM_Inventory\scratch\BC_Review"
    if (Test-Path -LiteralPath $reviewBase) {
        $candidateDirs = @(Get-ChildItem -LiteralPath $reviewBase -Directory | Where-Object { $_.Name -notlike 'ACTIVE_*' } | Sort-Object LastWriteTime -Descending)
        foreach ($cd in $candidateDirs) {
            $metaFile = Join-Path $cd.FullName ".lcm_review.json"
            if (Test-Path -LiteralPath $metaFile) {
                try {
                    $meta = Get-Content -LiteralPath $metaFile -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($meta.RepositoryName -eq $repoName) {
                        $baseDirs = @(Get-ChildItem -LiteralPath $cd.FullName -Directory | Where-Object { $_.Name -like "Baseline_${repoName}_*" })
                        if ($baseDirs.Count -gt 0) {
                            $activeReviewRoot = $baseDirs[0].FullName
                            $bcrScript = Join-Path $workspaceRoot "LCM_Inventory\tools\Invoke-BeyondCompareReview.ps1"
                            if (Test-Path -LiteralPath $bcrScript) {
                                & pwsh -NoProfile -ExecutionPolicy Bypass -Command "& {
                                    . `"$bcrScript`"
                                    Audit-BeyondCompareReviewStaging -TempReviewRoot `"$activeReviewRoot`" -RepoPath `"$targetRepoPath`" -RepoName `"$repoName`" -CommitSha `"$($meta.BaseCommit)`" -CRP `"$CRP`"
                                }" | Out-Null
                                if (Test-Path -LiteralPath $stagedManifestFile) {
                                    $stagedManifest = Get-Content -LiteralPath $stagedManifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
                                    break
                                }
                            }
                        }
                    }
                } catch {}
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Result)) {
    $Result = "Completed"
}

if ($Result -eq "Rejected") {
    if (Test-Path -LiteralPath $stagedManifestFile) { Remove-Item -LiteralPath $stagedManifestFile -Force }
    Write-Host "Review rejected. Staging manifest purged." -ForegroundColor Gray
    return
}

# A completion is valid only for the current repository and its current BCR baseline.
if (-not $stagedManifest) {
    throw "No current review staging manifest exists for '$repoName'. Open and complete its BCompare review before submitting completion."
}

$resolvedTargetPath = (Resolve-Path -LiteralPath $targetRepoPath).Path
$manifestPath = if ($stagedManifest.RepositoryPath) { (Resolve-Path -LiteralPath $stagedManifest.RepositoryPath -ErrorAction SilentlyContinue).Path } else { $null }
if ($stagedManifest.RepositoryName -ne $repoName -or -not $manifestPath -or $manifestPath -ne $resolvedTargetPath) {
    throw "Review staging manifest does not match repository '$repoName'. Completion was not performed."
}
if (-not $stagedManifest.PSObject.Properties['CRP'] -or $stagedManifest.CRP -ne $CRP) {
    throw "Review staging manifest does not match exact proposal '$CRP'. Completion was not performed."
}

$currentHead = (git -C $targetRepoPath rev-parse HEAD).Trim()
if ([string]::IsNullOrWhiteSpace($stagedManifest.BaselineCommit) -or -not $currentHead.StartsWith([string]$stagedManifest.BaselineCommit, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Review staging manifest baseline does not match current HEAD for '$repoName'. Completion was not performed."
}

# ------------------------------------------------------------------------------
# Record Accepted Review
# ------------------------------------------------------------------------------
$actionsExecuted = [System.Collections.Generic.List[string]]::new()
$actionsExecuted.Add("Accepted live worktree through BCR disposition '$Result'.")

# ------------------------------------------------------------------------------
# Git Staging & Commit
# ------------------------------------------------------------------------------
git -C $targetRepoPath add -A

$stagedPaths = @(git -C $targetRepoPath diff --cached --name-only)
$ruleChangePaths = @(Get-RuleChangePaths -Paths $stagedPaths)
if ($ruleChangePaths.Count -gt 0) {
    $reviewCrp = if ($stagedManifest -and $stagedManifest.PSObject.Properties['CRP']) { [string]$stagedManifest.CRP } else { '' }
    Assert-AdminModeForRuleChange -Paths $ruleChangePaths -CRP $reviewCrp -WorkspaceRoot $workspaceRoot
}

$commitCreated = $false
git -C $targetRepoPath diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    $commitMsg = if (-not [string]::IsNullOrWhiteSpace($Notes)) { $Notes } else { "feat(review): review completion by $env:USERNAME" }
    $authorizationFile = Join-Path $reviewsDir "pending_commit_${repoName}.json"
    $authorization = [ordered]@{
        RepositoryName      = $repoName
        RepositoryPath      = $resolvedTargetPath
        BaselineCommit      = $currentHead
        ReviewResult        = $Result
        Reviewer            = $env:USERNAME
        CreatedAt           = [DateTimeOffset]::UtcNow.ToString('O')
        ExpiresAt           = [DateTimeOffset]::UtcNow.AddHours(2).ToString('O')
        StagedDiffSha256    = Get-StagedDiffSha256 -Path $targetRepoPath
    }
    $authorization | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $authorizationFile -Encoding UTF8

    git -C $targetRepoPath commit -m "$commitMsg"
    if ($LASTEXITCODE -ne 0) {
        throw "Git commit failed for '$repoName'. The review authorization remains available only until its expiry."
    }

    Remove-Item -LiteralPath $authorizationFile -Force -ErrorAction Stop
    $newCommitSha = (git -C $targetRepoPath rev-parse --short HEAD).Trim()
    $commitCreated = $true

    # Save Permanent Review Record
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $testScopeVal = if ($MinimalTests) { "minimal" } else { "full" }
    $reviewRecord = [ordered]@{
        RepositoryName   = $repoName
        RepositoryPath   = $targetRepoPath
        CommitSha        = $newCommitSha
        ReviewResult     = $Result
        Reviewer         = $env:USERNAME
        Timestamp        = $timestamp
        Message          = $commitMsg
        ActionsExecuted  = $actionsExecuted
        TestScope        = $testScopeVal
    }
    $timeTag = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $finalReviewFile = Join-Path $reviewsDir "review_${repoName}_${timeTag}.json"
    $reviewRecord | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $finalReviewFile -Encoding UTF8

    # Append to active CM activity ledger
    $cmLogFile = Join-Path $workspaceRoot "LCM_Inventory\logs\cm_activity.log"
    if (Test-Path -LiteralPath (Split-Path $cmLogFile -Parent)) {
        $cmLogEntry = "[$timestamp] [REVIEW_SUBMITTED] [Target: $repoName] [Version: v8.3.0] [PushDate: $timestamp] [AffectedRepos: $repoName, LCM_Inventory] [TestScope: $testScopeVal] REVIEW_COMPLETED - Committed review completion ($newCommitSha): $commitMsg"
        Add-Content -LiteralPath $cmLogFile -Value $cmLogEntry -Encoding UTF8
    }

    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " REVIEW COMPLETED AND COMMITTED ($newCommitSha)" -ForegroundColor Green
    Write-Host " Repository : $repoName"
    Write-Host " Message    : $commitMsg"
    Write-Host " Receipt    : $finalReviewFile" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
} else {
    throw "The accepted review for '$repoName' has no live working-tree changes to commit."
}

# Cleanup staging manifest and temp baseline tree
if ($commitCreated -and (Test-Path -LiteralPath $stagedManifestFile)) { Remove-Item -LiteralPath $stagedManifestFile -Force -ErrorAction SilentlyContinue }
if ($commitCreated -and $stagedManifest -and $stagedManifest.TempReviewRoot) {
    $scratchBcReviewDir = Join-Path $workspaceRoot "LCM_Inventory\scratch\BC_Review"

    # Resolve the CRP identifier from the BCR session metadata before purging the baseline dir.
    # .lcm_review.json is written by BCR into the TempReviewRoot on every BCR invocation.
    $crpReviewDirToPurge = $null
    $lcmReviewMeta = Join-Path $stagedManifest.TempReviewRoot ".lcm_review.json"
    if (Test-Path -LiteralPath $lcmReviewMeta) {
        try {
            $meta = Get-Content -LiteralPath $lcmReviewMeta -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($meta -and -not [string]::IsNullOrWhiteSpace($meta.CRP)) {
                $crpReviewDirToPurge = Join-Path $scratchBcReviewDir $meta.CRP
            }
        } catch {}
    }

    # Remove root-level ACTIVE_BASELINE convenience junction if it still points to this baseline.
    $activeBaselineJunction = Join-Path $scratchBcReviewDir "ACTIVE_BASELINE"
    if (Test-Path -LiteralPath $activeBaselineJunction) {
        try {
            $jItem = Get-Item -LiteralPath $activeBaselineJunction -Force -ErrorAction SilentlyContinue
            if ($jItem -and $jItem.Target -eq $stagedManifest.TempReviewRoot) {
                [System.IO.Directory]::Delete($activeBaselineJunction, $false)
            }
        } catch {}
    }

    # Call Clear-BCReviewSession tool to clean dynamic BCSessions.xml entries (CRP-203)
    $cleanerScript = Join-Path $PSScriptRoot "Clear-BCReviewSession.ps1"
    if (Test-Path -LiteralPath $cleanerScript) {
        try {
            $targetCRP = if ($meta -and -not [string]::IsNullOrWhiteSpace($meta.CRP)) { $meta.CRP } else { $null }
            if ($targetCRP) {
                $cleanResult = & $cleanerScript -CRP $targetCRP -RepositoryName $repoName -WorkspaceRoot $workspaceRoot
                if ($cleanResult -and $cleanResult.SessionsRemoved.Count -gt 0) {
                    Write-Host ("  [CLEANED] Removed dynamic BC session(s): {0}" -f ($cleanResult.SessionsRemoved -join ', ')) -ForegroundColor DarkGray
                }
            }
        } catch {
            Write-Verbose "Could not clear dynamic BC review session via Clear-BCReviewSession: $($_.Exception.Message)"
        }
    }

    # Purge the CRP review directory post-commit only when Beyond Compare is NOT running.
    # If BCompare is actively open, defer purge to prevent 'Fast refresh / Path not found' errors.
    $bcRunning = @(Get-CimInstance Win32_Process -Filter "Name = 'BCompare.exe'" -ErrorAction SilentlyContinue).Count -gt 0
    if ($bcRunning) {
        Write-Host "  [PRESERVED] Beyond Compare session is active; preserving review scratchpad to prevent fast-refresh error." -ForegroundColor DarkGray
    } else {
        if ($crpReviewDirToPurge -and (Test-Path -LiteralPath $crpReviewDirToPurge)) {
            try {
                # Delete all junction nodes within the CRP dir before recursive removal
                $junctions = @(Get-ChildItem -LiteralPath $crpReviewDirToPurge -Directory -Force -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.LinkType -eq 'Junction' })
                foreach ($jn in $junctions) {
                    try { [System.IO.Directory]::Delete($jn.FullName, $false) } catch {}
                }
                Remove-Item -LiteralPath $crpReviewDirToPurge -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  [PURGED] BC review scratch directory: $crpReviewDirToPurge" -ForegroundColor DarkGray
            } catch {
                Write-Verbose "Could not fully purge CRP review directory '$crpReviewDirToPurge': $($_.Exception.Message)"
            }
        } elseif (Test-Path -LiteralPath $stagedManifest.TempReviewRoot) {
            # Fallback: CRP not resolvable — purge baseline dir only
            Remove-Item -LiteralPath $stagedManifest.TempReviewRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ------------------------------------------------------------------------------
# Auto-Synchronize Proposals Ledger (RULE-LCM-002: Dual-State Alignment)
# ------------------------------------------------------------------------------
try {
    $proposalModulePath = Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'
    Import-Module $proposalModulePath -Force
    $propStore = Get-ProposalStore
    $matchingProposals = @($propStore.proposals | Where-Object {
        $_.crp_id -eq $CRP -or $_.cr_id -eq $CRP -or ("CRP-$($_.id)" -eq $CRP)
    })
    if ($matchingProposals.Count -ne 1) {
        throw "Review result for $CRP must resolve to exactly one proposal; found $($matchingProposals.Count)."
    }
    if ($commitCreated) {
        $proposal = Move-LcmProposalLifecycleState -Id $matchingProposals[0].id -State 'completed' -Details "Review completed and committed ($newCommitSha)."
        if ($MinimalTests) {
            $propStore = Get-ProposalStore
            $proposal = @($propStore.proposals | Where-Object { $_.id -eq $proposal.id })[0]
            $proposal | Add-Member -NotePropertyName 'test_scope' -NotePropertyValue 'minimal' -Force
            $proposal | Add-Member -NotePropertyName 'minimal_tests' -NotePropertyValue $true -Force
            Set-ProposalStore -Store $propStore
        }
        Write-Host "Auto-synchronized proposals ledger to 'completed'." -ForegroundColor Green
    }
} catch {
    throw "Review result was committed, but the CRP lifecycle ledger could not be updated: $($_.Exception.Message)"
}
