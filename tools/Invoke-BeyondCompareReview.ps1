[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Name or path of the repository to review')]
    [string]$RepositoryName,

    [Parameter(Mandatory = $false, HelpMessage = 'Base Git commit or reference to compare against (e.g., HEAD~1, root, SHA, tag)')]
    [string]$BaseCommit,

    [Parameter(Mandatory = $false)]
    [string]$BeyondComparePath = 'C:\Program Files\Beyond Compare 5\BCompare.exe'
)

<#
Module: Invoke-BeyondCompareReview.ps1
Purpose: Compares a repository's current state against any prior commit/baseline in Beyond Compare 5.
Path: tools/Invoke-BeyondCompareReview.ps1
Authors: Rolf, Workspace_AI Engine
Version: 1.0.0
Date: 2026-08-16
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$repoPath = if (Test-Path -LiteralPath $RepositoryName) {
    $RepositoryName
} else {
    Join-Path $workspaceRoot $RepositoryName
}

if (-not (Test-Path -LiteralPath $repoPath)) {
    throw "Repository path not found: $repoPath"
}

if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
    throw "Directory is not a Git repository: $repoPath"
}

# Resolve Beyond Compare executable
if (-not (Test-Path -LiteralPath $BeyondComparePath)) {
    $candidates = @(
        'C:\Program Files\Beyond Compare 5\BCompare.exe',
        'C:\Program Files\Beyond Compare 4\BCompare.exe',
        'C:\Program Files (x86)\Beyond Compare 4\BCompare.exe'
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) {
            $BeyondComparePath = $c
            break
        }
    }
}

if (-not (Test-Path -LiteralPath $BeyondComparePath)) {
    throw "Beyond Compare executable not found at: $BeyondComparePath"
}

# If BaseCommit is not specified, find the root commit or morning baseline
if ([string]::IsNullOrWhiteSpace($BaseCommit)) {
    $logCommits = @(git -C $repoPath log --oneline | ForEach-Object { ($_ -split ' ')[0] })
    if ($logCommits.Count -gt 1) {
        # Default to root/earliest commit for visual whole-history review
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
$tempReviewRoot = Join-Path $env:TEMP "BC_Review\$repoName-$commitSha"

if (Test-Path -LiteralPath $tempReviewRoot) {
    Remove-Item -LiteralPath $tempReviewRoot -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $tempReviewRoot -Force | Out-Null

Write-Host "Exporting baseline commit [$commitSha: $commitMsg] to temp review directory..." -ForegroundColor Cyan

# Export git archive of the base commit
$tarPath = Join-Path $env:TEMP "BC_Review_$repoName-$commitSha.tar"
git -C $repoPath archive -o $tarPath $commitSha
tar -xf $tarPath -C $tempReviewRoot
Remove-Item -LiteralPath $tarPath -Force -ErrorAction SilentlyContinue

Write-Host "Launching Beyond Compare 5..." -ForegroundColor Green
Write-Host "  Left (Baseline $commitSha): $tempReviewRoot"
Write-Host "  Right (Current Live):       $repoPath"

Start-Process -FilePath $BeyondComparePath -ArgumentList "`"$tempReviewRoot`"", "`"$repoPath`"" -NoNewWindow
