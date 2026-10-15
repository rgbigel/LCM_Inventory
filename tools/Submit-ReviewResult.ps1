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

    [Parameter(Mandatory = $false, HelpMessage = 'Commits and records review evidence without independently changing the proposal lifecycle; reserved for atomic cohort completion')]
    [switch]$SkipLifecycleSynchronization,

    [Parameter(Mandatory = $false, HelpMessage = 'Explicitly include durable unreviewed paths disclosed by the current BCR staging manifest')]
    [switch]$IncludeUnreviewed,

    [Parameter(Mandatory = $false, HelpMessage = 'Commit only the existing staged review manifest; do not stage other live worktree paths')]
    [switch]$StagedOnly,

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
    Version: 10.0.0
    Date: 2026-10-13
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-StandardBcrExcludedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $normalizedPath = $RelativePath.Replace('/', '\').TrimStart('\')
    $lcmDirectory = [regex]::Escape('.' + 'lcm')
    return $normalizedPath -match "^(?i)(?:\.git|\.venv|venv|\.env|__pycache__|scratch|logs|work|data|node_modules|bin|obj)(?:\\|$)|(?:^|\\)$lcmDirectory\\(?:logs|scratch|archive|tools\\links)(?:\\|$)|(?i)\.(?:pyc|pyo|inventory|log|tmp|bak|swp|lock)$"
}

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
    Write-Host "  pwsh LCM_Inventory/tools/Submit-ReviewResult.ps1 -CRP <CRP-ID> [[-RepositoryPath] <str>] [-Result <str>] [-Notes <str>] [-All] [-StagedOnly] [-MinimalTests] [-Force] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -RepositoryPath  : Name or path of the repository"
    Write-Host "  -Result          : Review disposition (Completed, CompleteAll, CompleteWithEdits, Rejected, Deferred)"
    Write-Host "  -Notes           : Review notes or rationale"
    Write-Host "  -All             : Legacy compatibility switch; accepted reviews commit the live worktree"
    Write-Host "  -StagedOnly      : Preserve the reviewed staged manifest; do not add other live worktree paths"
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
if ([string]::IsNullOrWhiteSpace($Result)) {
    $Result = "Completed"
}

if ($Result -eq "Rejected") {
    Write-Host "Review rejected." -ForegroundColor Gray
    return
}

$resolvedTargetPath = (Resolve-Path -LiteralPath $targetRepoPath).Path
$currentHead = (git -C $targetRepoPath rev-parse HEAD).Trim()

$proposalModulePath = Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'
Import-Module $proposalModulePath -Force
$propStore = Get-ProposalStore
$matchingProposals = @($propStore.proposals | Where-Object {
    $proposalCrpId = if ($_.PSObject.Properties['crp_id']) { [string]$_.crp_id } else { '' }
    $proposalCrId = if ($_.PSObject.Properties['cr_id']) { [string]$_.cr_id } else { '' }
    $proposalCrpId -eq $CRP -or $proposalCrId -eq $CRP -or ("CRP-$($_.id)" -eq $CRP)
})
if ($matchingProposals.Count -ne 1) {
    throw "Review result for $CRP must resolve to exactly one proposal; found $($matchingProposals.Count)."
}
$crossRepositoryObligation = @(Get-LcmProposalReviewObligations -Proposal $matchingProposals[0] -UnresolvedOnly | Where-Object {
    ([string]$_.repository).Equals($repoName, [System.StringComparison]::OrdinalIgnoreCase)
}) | Select-Object -First 1
$unresolvedCrossRepositoryObligations = @(Get-LcmProposalReviewObligations -Proposal $matchingProposals[0] -UnresolvedOnly)
if ($matchingProposals[0].state -ne 'in_review' -and $null -eq $crossRepositoryObligation) {
    throw "Review result for $CRP requires lifecycle state 'in_review'; found '$($matchingProposals[0].state)'."
}
if ($null -eq $crossRepositoryObligation -and $unresolvedCrossRepositoryObligations.Count -gt 0) {
    $blockingComponents = @($unresolvedCrossRepositoryObligations | ForEach-Object {
        "COH-$($matchingProposals[0].id) — 1 - REVIEW ($($_.repository))"
    } | Sort-Object -Unique)
    throw "Review result for $CRP cannot be recorded in '$repoName' while blocking 1 - REVIEW component(s) remain: $($blockingComponents -join ', '). Review and accept those component(s) first; no commit or lifecycle state was changed."
}

# ------------------------------------------------------------------------------
# Record Accepted Review
# ------------------------------------------------------------------------------
$actionsExecuted = [System.Collections.Generic.List[string]]::new()
$actionsExecuted.Add("Accepted live worktree through BCR disposition '$Result'.")

# ------------------------------------------------------------------------------
# Git Staging & Commit
# ------------------------------------------------------------------------------
$existingStagedPaths = @(git -C $targetRepoPath diff --cached --name-only)
if ($existingStagedPaths.Count -gt 0) {
    Write-Host "Continuing reviewed manifest with $($existingStagedPaths.Count) existing staged path(s) in '$repoName'." -ForegroundColor DarkYellow
}

if ($StagedOnly) {
    if ($existingStagedPaths.Count -eq 0) {
        throw "Staged-only review completion for '$repoName' requires an existing staged review manifest."
    }
    $excludedStagedPaths = @(
        $existingStagedPaths | Where-Object {
            $_ -ne 'data/proposals/proposals.json' -and
            (Test-StandardBcrExcludedPath -RelativePath $_)
        }
    )
    if ($excludedStagedPaths.Count -gt 0) {
        throw "Staged-only review manifest contains excluded path(s): $($excludedStagedPaths -join ', ')."
    }
    $actionsExecuted.Add("Preserved the existing staged review manifest with $($existingStagedPaths.Count) path(s).")
} else {
    $rhsPaths = @(
        git -C $targetRepoPath diff --name-only
        git -C $targetRepoPath ls-files --others --exclude-standard
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
    $committablePaths = @($rhsPaths | Where-Object { -not (Test-StandardBcrExcludedPath -RelativePath $_) })
    if ($committablePaths.Count -eq 0 -and $null -eq $crossRepositoryObligation) {
        throw "The accepted review for '$repoName' has no committable RHS worktree changes."
    }
    foreach ($relativePath in $committablePaths) {
        git -C $targetRepoPath add -A -- $relativePath
        if ($LASTEXITCODE -ne 0) { throw "Unable to stage reviewed RHS path '$relativePath'." }
    }
}

$stagedPaths = @(git -C $targetRepoPath diff --cached --name-only)
$ruleChangePaths = @(
    if ($stagedPaths.Count -gt 0) {
        Get-RuleChangePaths -Paths $stagedPaths
    }
)
if ($ruleChangePaths.Count -gt 0) {
    Assert-AdminModeForRuleChange -Paths $ruleChangePaths -CRP $CRP -WorkspaceRoot $workspaceRoot
}

$commitCreated = $false
$reviewAccepted = $false
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
    $reviewAccepted = $true

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
        $cmLogEntry = "[$timestamp] [REVIEW_SUBMITTED] [Target: $repoName] [Version: 10.0.0] [PushDate: $timestamp] [AffectedRepos: $repoName, LCM_Inventory] [TestScope: $testScopeVal] REVIEW_COMPLETED - Committed review completion ($newCommitSha): $commitMsg"
        Add-Content -LiteralPath $cmLogFile -Value $cmLogEntry -Encoding UTF8
    }

    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " REVIEW COMPLETED AND COMMITTED ($newCommitSha)" -ForegroundColor Green
    Write-Host " Repository : $repoName"
    Write-Host " Message    : $commitMsg"
    Write-Host " Receipt    : $finalReviewFile" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
} else {
    if ($null -eq $crossRepositoryObligation) {
        throw "The accepted review for '$repoName' has no live working-tree changes to commit."
    }

    $newCommitSha = $currentHead
    $reviewAccepted = $true
    $actionsExecuted.Add("Accepted the cross-repository BCR obligation without a new commit; reviewed content is already at $newCommitSha.")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $testScopeVal = if ($MinimalTests) { "minimal" } else { "full" }
    $reviewRecord = [ordered]@{
        RepositoryName  = $repoName
        RepositoryPath  = $targetRepoPath
        CommitSha       = $newCommitSha
        ReviewResult    = $Result
        Reviewer        = $env:USERNAME
        Timestamp       = $timestamp
        Message         = $Notes
        ActionsExecuted = $actionsExecuted
        TestScope       = $testScopeVal
    }
    $timeTag = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $finalReviewFile = Join-Path $reviewsDir "review_${repoName}_${timeTag}.json"
    $reviewRecord | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $finalReviewFile -Encoding UTF8

    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " REVIEW ACCEPTED WITHOUT NEW COMMIT ($($newCommitSha.Substring(0, 7)))" -ForegroundColor Green
    Write-Host " Repository : $repoName"
    Write-Host " Reason     : Reviewed content is already committed; no duplicate commit was created."
    Write-Host " Receipt    : $finalReviewFile" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# Auto-Synchronize Proposals Ledger (RULE-LCM-002: Dual-State Alignment)
# ------------------------------------------------------------------------------
try {
    if ($reviewAccepted -and -not $SkipLifecycleSynchronization) {
        if ($crossRepositoryObligation) {
            $completedObligation = Complete-LcmCrossRepositoryReviewObligation -Id $matchingProposals[0].id `
                -Repository $repoName -ReviewReceiptPath $finalReviewFile -CommitSha $newCommitSha
            Write-Host "Resolved cross-repository BCR obligation '$($completedObligation.id)'. Primary proposal remains in '$($matchingProposals[0].state)'." -ForegroundColor Green
        } else {
            $propStore = Get-ProposalStore
            $reviewedProposal = @($propStore.proposals | Where-Object { $_.id -eq $matchingProposals[0].id })[0]
            $reviewedProposal | Add-Member -NotePropertyName 'bcr_disposition' -NotePropertyValue $Result -Force
            $reviewedProposal | Add-Member -NotePropertyName 'bcr_disposition_at' -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
            $reviewedProposal | Add-Member -NotePropertyName 'bcr_disposition_notes' -NotePropertyValue $Notes -Force
            Set-ProposalStore -Store $propStore
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
    }
} catch {
    throw "Review result was committed, but the CRP lifecycle ledger could not be updated: $($_.Exception.Message)"
}

if ($commitCreated -and $SkipLifecycleSynchronization) {
    [PSCustomObject]@{
        RepositoryName = $repoName
        ReviewReceiptPath = $finalReviewFile
        CommitSha = $newCommitSha
    }
}
