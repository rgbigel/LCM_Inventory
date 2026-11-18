<#
.SYNOPSIS
    Completes the review of one or more items or of one cohort: one commit per changed repository, lifecycle once.
.DESCRIPTION
    Module: tools/Complete-Review.ps1
    Purpose: Single review-completion entry point (CRP-357). Resolves the target items (CRP-nnn / BUG-nnn / numbers) or one
             cohort (COH-nnn), refuses before any change when a member is not ready, shows a read-only plan (-Plan),
             commits every changed governed repository once with a message naming all members (per-repository commit
             step: Submit-ReviewResult.ps1 -SkipLifecycleSynchronization), then moves every member to completed once.
             Items already completed only get their remaining repositories committed (CRP-346 R1).
    Path: LCM_Inventory/tools/Complete-Review.ps1
    Authors: Rolf, Claude
    Version: 10.7.5
    Date: 2026-11-18
    Implementation Choices (CRP-357): Invoke-ProposalAction.ps1 (accept / complete / proceed) and Complete-ReviewCohort.ps1
             forward here; the changed-repository scan is Get-LcmChangedGovernedRepositories in
             modules/LcmReviewCompletionAtoms.psm1. Before, each item of a shared worktree was completed separately and the
             first commit carried all changes under that item's message. Segment 2 (open): the per-repository commit body
             of Submit-ReviewResult.ps1 moves into the atoms module and the old scripts retire after one release.
.PARAMETER Target
    One or more item IDs (CRP-346, BUG-356, 346) or one cohort ID (COH-nnn).
.PARAMETER Details
    Commit message text (the member IDs are prefixed when there is more than one member).
.PARAMETER Plan
    Prints the resolved members and repositories and changes nothing.
.PARAMETER SubmitScriptPath
    Per-repository commit step (default: Submit-ReviewResult.ps1 next to this script; tests inject a stub).
.NOTES
    Caveats: commits only through the per-repository step, which enforces ADMINMODE for rule paths, line-ending
    normalization and the BCR exclusion rule; never pushes.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]]$Target,

    [string]$Details = '',

    [ValidateSet('Completed', 'CompleteWithEdits')]
    [string]$Result = 'Completed',

    [switch]$MinimalTests,

    [switch]$Force,

    [switch]$Plan,

    [string]$SubmitScriptPath = (Join-Path $PSScriptRoot 'Submit-ReviewResult.ps1'),

    [string]$WorkspaceRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help -or $null -eq $Target -or @($Target).Count -eq 0) {
    Write-Host '=========================================================================='
    Write-Host ' COMPLETE REVIEW (Complete-Review)'
    Write-Host '=========================================================================='
    Write-Host 'USAGE:'
    Write-Host '  pwsh LCM_Inventory/tools/Complete-Review.ps1 <CRP-nnn|BUG-nnn|nnn>... [-Details <text>] [-Plan] [-MinimalTests] [-h]'
    Write-Host '  pwsh LCM_Inventory/tools/Complete-Review.ps1 COH-nnn [-Details <text>] [-Plan]'
    Write-Host 'PARAMETERS:'
    Write-Host '  <targets>      : Items to complete together, or one cohort'
    Write-Host '  -Details       : Commit message text'
    Write-Host '  -Plan          : Show members and repositories only'
    Write-Host '  -MinimalTests  : Record test_scope minimal'
    Write-Host '  -Help          : Displays this help screen'
    Write-Host '=========================================================================='
    return
}

Import-Module -Name (Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1') -Force
Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmReviewCompletionAtoms.psm1') -Force

$targets = @($Target | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# ----------------------------------------------------------------------------- cohort
if ($targets.Count -eq 1 -and $targets[0] -match '^COH-\d+$') {
    $cohortId = $targets[0]
    $cohortPlan = Get-LcmReviewCohortCompletionPlan -CohortId $cohortId
    foreach ($repositoryPlan in $cohortPlan.Repositories) {
        $repoPath = if ($repositoryPlan.Repository -eq 'Git_Repositories') { $WorkspaceRoot } else { Join-Path $WorkspaceRoot $repositoryPlan.Repository }
        if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) { throw "Cohort repository '$($repositoryPlan.Repository)' is not a Git repository." }
    }
    if ($Plan) {
        Write-Host "Cohort $cohortId : repositories $(@($cohortPlan.Repositories.Repository) -join ', ')" -ForegroundColor Cyan
        return $cohortPlan
    }
    $reviewReceiptPaths = @{}
    foreach ($repositoryPlan in $cohortPlan.Repositories) {
        $members = @($repositoryPlan.Members)
        $primary = @($members | Where-Object { $_.Id -eq [int]$cohortId.Substring(4) })
        $submissionMember = if ($primary.Count -gt 0) { $primary[0] } else { $members[0] }
        if ($null -eq $submissionMember) { throw "Cohort '$cohortId' has no review member in repository '$($repositoryPlan.Repository)'." }
        $submission = @(& $SubmitScriptPath -RepositoryPath $repositoryPlan.Repository -CRP $submissionMember.Identity -Result Completed -Notes $Details -SkipLifecycleSynchronization)
        $receipt = @($submission | Where-Object { $_ -is [psobject] -and $_.PSObject.Properties['ReviewReceiptPath'] })[-1]
        if ($null -eq $receipt -or [string]::IsNullOrWhiteSpace([string]$receipt.ReviewReceiptPath)) {
            throw "Accepted review commit for '$($repositoryPlan.Repository)' did not produce a review receipt."
        }
        $reviewReceiptPaths[[string]$repositoryPlan.Repository] = [string]$receipt.ReviewReceiptPath
    }
    $updated = Complete-LcmReviewCohortAcceptance -CohortId $cohortId -ResolutionReceiptPath $cohortPlan.ReceiptPath -ReviewReceiptPaths $reviewReceiptPaths -Details $Details
    Write-Host "Completed accepted review cohort $cohortId atomically: $(@($updated).Count) member(s)." -ForegroundColor Green
    return $updated
}

# ----------------------------------------------------------------------------- items
$store = Get-ProposalStore
$members = foreach ($t in $targets) {
    $match = @($store.proposals | Where-Object {
            $tag = if ($_.PSObject.Properties['crp_id'] -and $_.crp_id) { [string]$_.crp_id } else { '' }
            $tag -eq $t -or [string]$_.id -eq $t -or ($t -match '^\d+$' -and [int]$_.id -eq [int]$t)
        })
    if ($match.Count -ne 1) { throw "Target '$t' must resolve to exactly one proposal; found $($match.Count)." }
    $match[0]
}
$members = @($members | Sort-Object { [int]$_.id } -Unique)
$notReady = @($members | Where-Object { [string]$_.state -notin @('in_progress', 'verified', 'in_review', 'completed') })
if ($notReady.Count -gt 0) {
    throw ("Not ready for completion (no change made): {0}." -f (@($notReady | ForEach-Object { '{0} is {1}' -f $_.crp_id, $_.state }) -join '; '))
}
$open = @($members | Where-Object { [string]$_.state -ne 'completed' })
$identities = @($members | ForEach-Object { [string]$_.crp_id })

$changed = @(Get-LcmChangedGovernedRepositories -WorkspaceRoot $WorkspaceRoot)
$obligationRepos = @($members | ForEach-Object { Get-LcmProposalReviewObligations -Proposal $_ -UnresolvedOnly } | ForEach-Object { [string]$_.repository })
$repositories = @(@($obligationRepos) + @($changed) | Where-Object { $_ } | Select-Object -Unique)

Write-Host ("Completion plan: members {0}; repositories {1}." -f ($identities -join ', '), $(if ($repositories.Count) { $repositories -join ', ' } else { 'none (lifecycle only)' })) -ForegroundColor Cyan
if ($Plan) {
    return [pscustomobject]@{ Members = $identities; Repositories = $repositories }
}

foreach ($m in $open) {
    if ([string]$m.state -eq 'in_progress') { $null = Move-LcmProposalLifecycleState -Id $m.id -State 'verified' -Details 'Auto-transitioned to verified for review completion (CRP-357)' }
    if ([string]$m.state -in @('in_progress', 'verified')) { $null = Move-LcmProposalLifecycleState -Id $m.id -State 'in_review' -Details 'Auto-transitioned to in_review for review completion (CRP-357)' }
}

$message = if ($identities.Count -gt 1) { '[{0}] {1}' -f ($identities -join ', '), $Details } else { $Details }
if ([string]::IsNullOrWhiteSpace($message)) { $message = "Review completion: $($identities -join ', ')" }
$commits = [ordered]@{}
$receipts = @{}
foreach ($repository in $repositories) {
    $submitArgs = @{ RepositoryPath = $repository; Result = $Result; Notes = $message }
    if ($MinimalTests) { $submitArgs.MinimalTests = $true }
    if ($Force) { $submitArgs.Force = $true }
    if ($open.Count -gt 0) {
        $submitArgs.CRP = [string]$open[0].crp_id
        $submitArgs.SkipLifecycleSynchronization = $true
    } else {
        # all members completed: the remaining repository is recorded as an obligation of the first member (CRP-346 R1)
        $submitArgs.CRP = [string]$members[0].crp_id
        $null = Register-LcmCrossRepositoryReviewObligation -Id $members[0].id -Repository $repository -Reason 'Remaining repository of a completed item (CRP-346 R1, CRP-357).'
    }
    $out = @(& $SubmitScriptPath @submitArgs)
    $receipt = @($out | Where-Object { $_ -is [psobject] -and $_.PSObject.Properties['CommitSha'] })
    $commits[$repository] = if ($receipt.Count) { [string]$receipt[-1].CommitSha } else { '' }
    $receipts[$repository] = if ($receipt.Count -and $receipt[-1].PSObject.Properties['ReviewReceiptPath']) { [string]$receipt[-1].ReviewReceiptPath } else { 'none (no receipt returned)' }
}

$shaText = @($commits.Keys | ForEach-Object { if ($commits[$_]) { '{0} {1}' -f $_, $commits[$_] } else { $_ } }) -join ', '
foreach ($m in $open) {
    $s = Get-ProposalStore
    $p = @($s.proposals | Where-Object { [int]$_.id -eq [int]$m.id })[0]
    $p | Add-Member -NotePropertyName 'bcr_disposition' -NotePropertyValue $Result -Force
    $p | Add-Member -NotePropertyName 'bcr_disposition_at' -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
    $p | Add-Member -NotePropertyName 'bcr_disposition_notes' -NotePropertyValue $message -Force
    if ($MinimalTests) {
        $p | Add-Member -NotePropertyName 'test_scope' -NotePropertyValue 'minimal' -Force
        $p | Add-Member -NotePropertyName 'minimal_tests' -NotePropertyValue $true -Force
    }
    Set-ProposalStore -Store $s
    foreach ($ob in @(Get-LcmProposalReviewObligations -Proposal $p -UnresolvedOnly)) {
        if ($commits.Contains([string]$ob.repository)) {
            $null = Complete-LcmCrossRepositoryReviewObligation -Id $p.id -Repository ([string]$ob.repository) -ReviewReceiptPath $receipts[[string]$ob.repository] -CommitSha $commits[[string]$ob.repository]
        }
    }
    $null = Move-LcmProposalLifecycleState -Id $m.id -State 'completed' -Details ("Review completed together with {0} ({1})." -f ($identities -join ', '), $(if ($shaText) { $shaText } else { 'no repository change' }))
}
Write-Host ("Completed {0}; commits: {1}." -f ($identities -join ', '), $(if ($shaText) { $shaText } else { 'none' })) -ForegroundColor Green
return [pscustomobject]@{ Members = $identities; Commits = $commits }
