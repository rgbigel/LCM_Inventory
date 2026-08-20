[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Name or path of the repository to review')]
    [string]$RepositoryName,

    [Parameter(Mandatory = $false, HelpMessage = 'Base Git commit or reference to compare against (e.g., HEAD~1, root, SHA, tag)')]
    [string]$BaseCommit,

    [Parameter(Mandatory = $false)]
    [string]$BeyondComparePath = 'D:\Tools\Beyond Compare 5\BCompare.exe'
)

<#
Module: Invoke-BeyondCompareReview.ps1
Purpose: Compares a repository's current state against any prior commit/baseline in Beyond Compare 5.
Path: tools/Invoke-BeyondCompareReview.ps1
Authors: Rolf, Workspace_AI Engine
Version: 1.3.0
Date: 2026-08-20
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$resolvedTarget = if (Test-Path -LiteralPath $RepositoryName) {
    $RepositoryName
} else {
    Join-Path $workspaceRoot $RepositoryName
}

if (-not (Test-Path -LiteralPath $resolvedTarget)) {
    throw "Repository path not found: $resolvedTarget"
}

# ALWAYS resolve to fully-qualified absolute path (guarantees correct resolution when launched via schtasks/explorer)
$repoPath = (Get-Item -LiteralPath $resolvedTarget).FullName

if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
    throw "Directory is not a Git repository: $repoPath"
}

# Validate Beyond Compare executable
if (-not (Test-Path -LiteralPath $BeyondComparePath)) {
    throw "Beyond Compare executable not found at: $BeyondComparePath. Please verify the tool path."
}

# If BaseCommit is not specified, default to HEAD to review uncommitted working tree changes
if ([string]::IsNullOrWhiteSpace($BaseCommit)) {
    $BaseCommit = 'HEAD'
}
elseif ($BaseCommit -eq 'root') {
    $logCommits = @(git -C $repoPath log --oneline | ForEach-Object { ($_ -split ' ')[0] })
    if ($logCommits.Count -gt 0) {
        $BaseCommit = $logCommits[-1]
    } else {
        $BaseCommit = 'HEAD'
    }
}

$commitSha = (git -C $repoPath rev-parse --short $BaseCommit 2>$null)
if (-not $commitSha) {
    throw "Invalid Git commit reference: $BaseCommit"
}

$commitMsg = (git -C $repoPath log -n 1 --pretty=format:"%s" $commitSha)
$repoName = Split-Path $repoPath -Leaf
$tempParent = Join-Path $env:TEMP "BC_Review"
if (-not (Test-Path -LiteralPath $tempParent)) {
    New-Item -ItemType Directory -Path $tempParent -Force | Out-Null
}

$tempReviewRoot = Join-Path $tempParent "$repoName-$commitSha"

if (Test-Path -LiteralPath $tempReviewRoot) {
    Remove-Item -LiteralPath $tempReviewRoot -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $tempReviewRoot -Force | Out-Null

Write-Host ("Exporting baseline commit [{0}: {1}] to temp review directory..." -f $commitSha, $commitMsg) -ForegroundColor Cyan

# Export git archive of the base commit
$tarPath = Join-Path $env:TEMP "BC_Review_$repoName-$commitSha.tar"
git -C $repoPath archive -o $tarPath $commitSha
tar -xf $tarPath -C $tempReviewRoot
Remove-Item -LiteralPath $tarPath -Force -ErrorAction SilentlyContinue

# Record immutable review session metadata
$sessionMeta = [ordered]@{
    RepositoryName   = $repoName
    RepositoryPath   = $repoPath
    BaseCommit       = $commitSha
    CommitMessage    = $commitMsg
    CommitDate       = (git -C $repoPath log -n 1 --pretty=format:"%cI" $commitSha)
    SessionStartedAt = (Get-Date).ToString("o")
}
$sessionMeta | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $tempReviewRoot ".lcm_review.json") -Encoding utf8

Write-Host "Launching Beyond Compare 5 on interactive desktop..." -ForegroundColor Green
Write-Host ("  Left (Baseline {0}): {1}" -f $commitSha, $tempReviewRoot)
Write-Host ("  Right (Current Live):       {0}" -f $repoPath)

$taskName = "LCM_BeyondCompare_Review"
$actionCmd = "`"$BeyondComparePath`" `"$tempReviewRoot`" `"$repoPath`""

try {
    # Method 1: Launch via interactive Windows Task Scheduler (forces GUI into active user Session 1)
    schtasks.exe /create /tn $taskName /tr $actionCmd /sc once /st "23:59" /it /f 2>&1 | Out-Null
    schtasks.exe /run /tn $taskName 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    schtasks.exe /delete /tn $taskName /f 2>&1 | Out-Null
}
catch {
    # Method 2: Standard Start-Process fallback
    Start-Process -FilePath $BeyondComparePath -ArgumentList @($tempReviewRoot, $repoPath)
}
