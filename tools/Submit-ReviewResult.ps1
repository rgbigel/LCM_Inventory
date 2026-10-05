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

    [Parameter(Mandatory = $false, HelpMessage = 'Include all changes, including uncopied files, without interactive confirmation')]
    [switch]$All,

    [Parameter(Mandatory = $false, HelpMessage = 'Single-cycle minimal testing scope: fast syntax and AST validation only')]
    [switch]$MinimalTests,

    [Parameter(Mandatory = $false, HelpMessage = 'Force review commit and bypass safety checks')]
    [switch]$Force,

    [Alias('h', '?')]
    [switch]$Help
)

<#
.SYNOPSIS
    Interactive review response recorder and staging execution engine for Beyond Compare and LCM governance.
.DESCRIPTION
    Module: tools/Submit-ReviewResult.ps1
    Purpose: Consumes interactive review staging manifests, handles Delete/Rename directives, executes cleanups,
             prompts for uncopied file confirmations (bypassed with 'COMPLETE ALL' or -All), and performs review-gated commits per RULE-REV-001.
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
    Write-Host "  Interactive review response recorder and staging engine for Beyond Compare."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Submit-ReviewResult.ps1 [[-RepositoryPath] <str>] [-Result <str>] [-Notes <str>] [-All] [-MinimalTests] [-Force] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -RepositoryPath  : Name or path of the repository"
    Write-Host "  -Result          : Review disposition (Completed, CompleteAll, CompleteWithEdits, Rejected, Deferred)"
    Write-Host "  -Notes           : Review notes or rationale"
    Write-Host "  -All             : Include all uncopied files"
    Write-Host "  -MinimalTests    : Single-cycle minimal testing scope: fast syntax and AST validation only"
    Write-Host "  -Force           : Force commit"
    Write-Host "  -Help (-h, -?)   : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
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
                                    Audit-BeyondCompareReviewStaging -TempReviewRoot `"$activeReviewRoot`" -RepoPath `"$targetRepoPath`" -RepoName `"$repoName`" -CommitSha `"$($meta.BaseCommit)`"
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

# ------------------------------------------------------------------------------
# Check for Uncopied Files and Prompt Operator (Bypassed if COMPLETE ALL / -All is used)
# ------------------------------------------------------------------------------
$includeUncopied = $false
$isExplicitCompleteAll = ($All -or $Result -in @("CompleteAll", "ALL", "COMPLETE ALL"))

if ($stagedManifest -and $stagedManifest.Uncopied -and $stagedManifest.Uncopied.Count -gt 0) {
    if ($isExplicitCompleteAll) {
        $includeUncopied = $true
        $Result = "CompleteAll"
        Write-Host "[COMPLETE ALL] Confirmed: Automatically including all $($stagedManifest.Uncopied.Count) uncopied/modified file(s) without prompt." -ForegroundColor Green
    } elseif ($Result -eq "CompleteStaged") {
        $includeUncopied = $false
    } elseif (-not $Force -and ($null -eq $Result -or $Result -in @("Complete", "CompleteWithEdits"))) {
        Write-Host ""
        Write-Host "==========================================================================" -ForegroundColor Yellow
        Write-Host " NOTICE: UNCOPIED FILES DETECTED IN REVIEW" -ForegroundColor Yellow
        Write-Host "==========================================================================" -ForegroundColor Yellow
        Write-Host " You have $($stagedManifest.Uncopied.Count) modified/new file(s) that were NOT copied to the Left pane:"
        foreach ($uf in $stagedManifest.Uncopied) {
            Write-Host "   ? $($uf.RelativePath)" -ForegroundColor Yellow
        }
        Write-Host "--------------------------------------------------------------------------"
        Write-Host " Did you forget to copy them, or do you want to include them in this commit?" -ForegroundColor Cyan
        Write-Host "   [1] Yes, Include All    - Complete staged files PLUS these uncopied files" -ForegroundColor Green
        Write-Host "   [2] No, Staged Only     - Commit ONLY explicitly copied files (leave these uncommitted)" -ForegroundColor Gray
        Write-Host "   [q] Cancel Review"
        $resp = Read-Host " Enter choice [1-2, q]"
        if ($resp -eq "1" -or $resp -eq "y" -or $resp -eq "yes") {
            $includeUncopied = $true
            $Result = "Complete"
        } elseif ($resp -eq "2" -or $resp -eq "n" -or $resp -eq "no") {
            $includeUncopied = $false
            $Result = "Complete"
        } else {
            Write-Host "Review submission cancelled." -ForegroundColor Gray
            return
        }
    }
} elseif ($isExplicitCompleteAll) {
    $includeUncopied = $true
    $Result = "CompleteAll"
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

$currentHead = (git -C $targetRepoPath rev-parse HEAD).Trim()
if ([string]::IsNullOrWhiteSpace($stagedManifest.BaselineCommit) -or -not $currentHead.StartsWith([string]$stagedManifest.BaselineCommit, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Review staging manifest baseline does not match current HEAD for '$repoName'. Completion was not performed."
}

$approvedActionCount = @($stagedManifest.Completed).Count + @($stagedManifest.Renames).Count + @($stagedManifest.Deletions).Count
if (-not $includeUncopied -and $approvedActionCount -eq 0) {
    throw "Review staging manifest for '$repoName' contains no approved actions. Completion was not performed."
}

# ------------------------------------------------------------------------------
# Execute Staging Actions: Deletions, Renames & Cleanups
# ------------------------------------------------------------------------------
$actionsExecuted = [System.Collections.Generic.List[string]]::new()

if ($stagedManifest) {
    # 1. Execute Deletions
    if ($stagedManifest.Deletions) {
        foreach ($df in $stagedManifest.Deletions) {
            $liveFile = Join-Path $targetRepoPath $df.RelativePath
            if (Test-Path -LiteralPath $liveFile) {
                Remove-Item -LiteralPath $liveFile -Force -ErrorAction SilentlyContinue
                git -C $targetRepoPath rm -f --ignore-unmatch $df.RelativePath 2>$null | Out-Null
                $actionsExecuted.Add("Deleted: $($df.RelativePath)")
                Write-Host "  [PURGED] Deleted file and Git tracking: $($df.RelativePath)" -ForegroundColor Red
            }
        }
    }

    # 2. Execute Renames
    if ($stagedManifest.Renames) {
        foreach ($rf in $stagedManifest.Renames) {
            $oldLive = Join-Path $targetRepoPath $rf.OldRelativePath
            $newLive = Join-Path $targetRepoPath $rf.NewRelativePath
            if (Test-Path -LiteralPath $oldLive) {
                $newDir = Split-Path $newLive -Parent
                if (-not (Test-Path -LiteralPath $newDir)) { New-Item -ItemType Directory -Path $newDir -Force | Out-Null }
                git -C $targetRepoPath mv -f $rf.OldRelativePath $rf.NewRelativePath 2>$null | Out-Null
                if (Test-Path -LiteralPath $oldLive) { Remove-Item -LiteralPath $oldLive -Force -ErrorAction SilentlyContinue }
                $actionsExecuted.Add("Renamed: $($rf.OldRelativePath) => $($rf.NewRelativePath)")
                Write-Host "  [RENAMED] $($rf.OldRelativePath) => $($rf.NewRelativePath)" -ForegroundColor Yellow
            }
        }
    }
}

# ------------------------------------------------------------------------------
# Git Staging & Commit
# ------------------------------------------------------------------------------
if ($includeUncopied -or ($null -eq $stagedManifest)) {
    git -C $targetRepoPath add -A
} else {
    # Stage reviewed files
    if ($stagedManifest.Completed) {
        foreach ($af in $stagedManifest.Completed) {
            git -C $targetRepoPath add $af.RelativePath 2>$null | Out-Null
        }
    }
    if ($stagedManifest.Renames) {
        foreach ($rf in $stagedManifest.Renames) {
            git -C $targetRepoPath add $rf.NewRelativePath 2>$null | Out-Null
        }
    }
}

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
    throw "No approved staged changes are available for '$repoName'. Completion was not performed."
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
    $propJsonFile = Join-Path $workspaceRoot "LCM_Inventory\data\proposals\proposals.json"
    if (Test-Path -LiteralPath $propJsonFile) {
        $propStore = Get-Content -LiteralPath $propJsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $matchedProposal = $false
        foreach ($p in $propStore.proposals) {
            $isRepoMatch = ($p.origin_repo -and $p.origin_repo.StartsWith($repoName))
            $isOpenState = ($p.progress_state -in @('verification', 'committed', 'in_progress', 'review') -or $p.state -in @('approved', 'suggested', 'in_progress', 'review'))
            if ($isRepoMatch -and $isOpenState) {
                $p.progress_state = 'completed'
                $p.state = if ($MinimalTests) { 'completed [minimal-tests]' } else { 'completed' }
                if ($MinimalTests) {
                    $p | Add-Member -NotePropertyName "test_scope" -NotePropertyValue "minimal" -Force
                }
                if (-not $p.dates) { $p | Add-Member -NotePropertyName "dates" -NotePropertyValue ([ordered]@{}) -Force }
                $p.dates | Add-Member -NotePropertyName "completed" -NotePropertyValue (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") -Force
                $matchedProposal = $true
            }
        }
        if ($commitCreated -and $matchedProposal) {
            $propStore.updated_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
            $propStore | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $propJsonFile -Encoding UTF8
            Write-Host "Auto-synchronized proposals ledger to '$((if ($MinimalTests) { 'completed [minimal-tests]' } else { 'completed' }))'." -ForegroundColor Green
        }
    }
} catch {
    Write-Verbose "Could not auto-update proposals.json: $($_.Exception.Message)"
}
