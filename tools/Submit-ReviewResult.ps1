[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Name or path of the repository')]
    [Alias('RepositoryName', 'Repo', 'Name')]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Accepted", "AcceptedWithEdits", "Rejected", "Deferred")]
    [string]$Result,

    [Parameter(Mandatory = $false)]
    [string]$Notes,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

<#
.SYNOPSIS
    Interactive review response recorder for Beyond Compare 5 and LCM CM audit trail.
.DESCRIPTION
    Module: tools/Submit-ReviewResult.ps1
    Purpose: Interactive review response recorder for Beyond Compare 5 and LCM CM audit trail with automatic review window closure upon acceptance.
    Path: Workspace_Inventory/tools/Submit-ReviewResult.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.1.0
    Date: 2026-08-21
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Close-BeyondCompareReviewWindow {
    [CmdletBinding()]
    param(
        [string]$TargetRepoName,
        [string]$TargetRepoPath
    )

    try {
        $csharpCode = @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class BCWindowCloser {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public const uint WM_CLOSE = 0x0010;

    public static int CloseMatchingWindows(string targetName, string targetPath) {
        int closedCount = 0;
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                StringBuilder sb = new StringBuilder(512);
                GetWindowText(hWnd, sb, 512);
                string title = sb.ToString();
                if (!string.IsNullOrEmpty(title) && title.Contains("Beyond Compare")) {
                    bool match = false;
                    if (!string.IsNullOrEmpty(targetName) && title.IndexOf(targetName, StringComparison.OrdinalIgnoreCase) >= 0) {
                        match = true;
                    }
                    if (!match && !string.IsNullOrEmpty(targetPath) && title.IndexOf(targetPath, StringComparison.OrdinalIgnoreCase) >= 0) {
                        match = true;
                    }
                    if (!match && (title.IndexOf("BC_Review", StringComparison.OrdinalIgnoreCase) >= 0 || title.IndexOf("LCM_Review", StringComparison.OrdinalIgnoreCase) >= 0)) {
                        match = true;
                    }

                    if (match) {
                        PostMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                        closedCount++;
                    }
                }
            }
            return true;
        }, IntPtr.Zero);
        return closedCount;
    }
}
'@
        if (-not ('BCWindowCloser' -as [type])) {
            Add-Type -TypeDefinition $csharpCode -ErrorAction SilentlyContinue
        }
        
        if ('BCWindowCloser' -as [type]) {
            $closed = [BCWindowCloser]::CloseMatchingWindows($TargetRepoName, $TargetRepoPath)
            if ($closed -gt 0) {
                Write-Host "Closed $closed Beyond Compare review window(s) for '$TargetRepoName'." -ForegroundColor Green
                return
            }
        }

        # Fallback: Process MainWindowTitle match
        $bcProcs = @(Get-Process -Name BCompare -ErrorAction SilentlyContinue)
        foreach ($p in $bcProcs) {
            if ($p.MainWindowTitle -like "*$TargetRepoName*" -or $p.MainWindowTitle -like "*BC_Review*" -or $p.MainWindowTitle -like "*LCM_Review*") {
                $null = $p.CloseMainWindow()
                Write-Host "Closed Beyond Compare window: $($p.MainWindowTitle)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Verbose "Could not automatically close Beyond Compare window: $($_.Exception.Message)"
    }
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
    $workspaceRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
}

# If path is passed from BC (%p or %f), resolve to repository root
$targetRepoPath = $null
if (-not [string]::IsNullOrWhiteSpace($RepositoryPath)) {
    $resolvedPath = $RepositoryPath.Trim('"', "'")
    if ($resolvedPath -in @('.', 'root', 'Git_Repositories', (Split-Path $workspaceRoot -Leaf))) {
        $targetRepoPath = $workspaceRoot
    } elseif (Test-Path -LiteralPath $resolvedPath) {
        # Check if this path is within a repository
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
        if (Test-Path -LiteralPath $candidatePath) {
            $targetRepoPath = $candidatePath
        }
    }
} else {
    # If not passed, prompt user to select active repository
    Write-Host "Select Repository for Review Submission:" -ForegroundColor Cyan
    $repos = @(Get-ChildItem -Path $workspaceRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName '.git') })
    for ($i = 0; $i -lt $repos.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $repos[$i].Name)
    }
    $sel = Read-Host "`nEnter selection (1-$($repos.Count))"
    $idx = [int]$sel - 1
    if ($idx -ge 0 -and $idx -lt $repos.Count) {
        $targetRepoPath = $repos[$idx].FullName
    } else {
        throw "Invalid repository selection."
    }
}

$repoName = Split-Path $targetRepoPath -Leaf
if (-not (Test-Path -LiteralPath $targetRepoPath)) {
    throw "Target repository path not found: $targetRepoPath"
}

# Interactive Menu if Result not supplied via CLI
if ([string]::IsNullOrWhiteSpace($Result)) {
    Clear-Host
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host " LCM Review Result (RR) Recorder" -ForegroundColor Cyan
    Write-Host " Target Repository: $repoName" -ForegroundColor Yellow
    Write-Host " Path:              $targetRepoPath"
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host "  [1] Accepted            - Baseline verified, no further edits needed" -ForegroundColor Green
    Write-Host "  [2] Accepted with Edits  - Edits made during review, run quality gates & commit" -ForegroundColor Yellow
    Write-Host "  [3] Rejected            - Significant issues found, request revision" -ForegroundColor Red
    Write-Host "  [4] Deferred            - Review paused / in progress" -ForegroundColor Gray
    Write-Host "  [q] Cancel / Exit"
    Write-Host "-------------------------------------------------------------"
    
    $choice = Read-Host "Select review outcome [1-4, q]"
    switch ($choice) {
        "1" { $Result = "Accepted" }
        "2" { $Result = "AcceptedWithEdits" }
        "3" { $Result = "Rejected" }
        "4" { $Result = "Deferred" }
        default {
            Write-Host "Review recording cancelled." -ForegroundColor Gray
            return
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Notes)) {
    $Notes = Read-Host "Enter optional review notes/comments (Press Enter to skip)"
}

$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$reviewRecord = [ordered]@{
    RepositoryName   = $repoName
    RepositoryPath   = $targetRepoPath
    ReviewResult     = $Result
    Reviewer         = $env:USERNAME
    Timestamp        = $timestamp
    HeadCommit       = (git -C $targetRepoPath rev-parse --short HEAD 2>$null)
    Notes            = $Notes
}

# Save review record to Workspace_Inventory/data/reviews/
$reviewsDir = Join-Path $workspaceRoot "Workspace_Inventory\data\reviews"
if (-not (Test-Path -LiteralPath $reviewsDir)) {
    $null = New-Item -ItemType Directory -Path $reviewsDir -Force
}
$reviewFile = Join-Path $reviewsDir ("REVIEW-{0}-{1}.json" -f $repoName, (Get-Date).ToString('yyyyMMdd_HHmmss'))
$reviewRecord | ConvertTo-Json -Depth 3 | Set-Content -Path $reviewFile -Encoding UTF8

# Log CM Activity
$cmLog = Join-Path $workspaceRoot "Workspace_Inventory\logs\cm_activity.log"
$cmLogDir = Split-Path $cmLog -Parent
if (-not (Test-Path -LiteralPath $cmLogDir)) {
    $null = New-Item -ItemType Directory -Path $cmLogDir -Force
}
$logLine = ("[{0}] [REVIEW_SUBMITTED] Target: {1} | Outcome: {2} | Reviewer: {3} | Notes: {4}" -f $timestamp, $repoName, $Result, $env:USERNAME, $Notes)
$logLine | Out-File -FilePath $cmLog -Append -Encoding UTF8

Write-Host "`n-------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ("Review Result Recorded: {0}" -f $Result) -ForegroundColor Green
Write-Host ("Evidence Saved:        {0}" -f $reviewFile)

# Automatically close the Beyond Compare review window upon Acceptance
if ($Result -in @("Accepted", "AcceptedWithEdits")) {
    Close-BeyondCompareReviewWindow -TargetRepoName $repoName -TargetRepoPath $targetRepoPath
}

# If Accepted with Edits: run readiness test and auto-commit
if ($Result -eq "AcceptedWithEdits") {
    $dirty = @(git -C $targetRepoPath status --short)
    if ($dirty.Count -gt 0) {
        Write-Host "`nRunning Quality Gates on modified repository..." -ForegroundColor Cyan
        $readinessScript = Join-Path $targetRepoPath "tools\Test-RepoReadiness.ps1"
        if (Test-Path -LiteralPath $readinessScript) {
            & $readinessScript -ForceInProcess
        }
        
        Write-Host "Creating Git commit for review edits..." -ForegroundColor Cyan
        git -C $targetRepoPath add -A
        $commitMsg = "review(acceptance): accepted with review edits by $env:USERNAME"
        if ($Notes) { $commitMsg += " - $Notes" }
        git -C $targetRepoPath commit -m $commitMsg
        
        # Push if origin is configured
        $hasRemote = git -C $targetRepoPath remote 2>$null
        if ($hasRemote) {
            Write-Host "Pushing review commit to remote..." -ForegroundColor Cyan
            git -C $targetRepoPath push origin main
        }
    } else {
        Write-Host "No uncommitted edits detected in working directory." -ForegroundColor Gray
    }
}

Write-Host "=============================================================" -ForegroundColor Cyan
