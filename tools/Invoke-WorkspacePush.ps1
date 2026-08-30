<#
.SYNOPSIS
  Multi-repository push and remote synchronization engine for LCM governed workspace.
.DESCRIPTION
  Module: tools/Invoke-WorkspacePush.ps1
  Purpose: Iterates across all governed and child repositories under D:\Git_Repositories, detects if a Git remote exists and if local branch is ahead of remote tracking branch, and executes git push with structured audit logging.
  Path: Workspace_Inventory/tools/Invoke-WorkspacePush.ps1
  Authors: Rolf, Workspace_AI Engine
  Version: 1.0.0
  Date: 2026-08-30
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Reason = "feat(cm): sync completed workspace proposals and governance updates",

    [Parameter(Mandatory = $false)]
    [string[]]$Repositories,

    [Parameter(Mandatory = $false)]
    [switch]$SkipGemini,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = 'D:\Git_Repositories'
$cmLogFile = Join-Path $workspaceRoot "Workspace_Inventory\logs\cm_activity.log"

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM MULTI-REPOSITORY PUSH & REMOTE SYNCHRONIZATION ENGINE" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Push Reason : $Reason"
Write-Host " Timestamp   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "==========================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 0. Synchronize Gemini AI & Knowledge Base Mirror (RULE-LCM-013)
# ------------------------------------------------------------------------------
if (-not $SkipGemini) {
    Write-Host "`n[Pre-Push Pipeline] Executing Update-Gemini Context & Knowledge Base Synchronization..." -ForegroundColor Yellow
    $updateGeminiScript = Join-Path $workspaceRoot "Workspace_AI\tools\Update-Gemini.ps1"
    if (Test-Path -LiteralPath $updateGeminiScript) {
        & pwsh -File $updateGeminiScript
        # If Workspace_AI updated export files, stage and commit them
        $aiStatus = git -C (Join-Path $workspaceRoot "Workspace_AI") status --porcelain
        if ($aiStatus) {
            git -C (Join-Path $workspaceRoot "Workspace_AI") add -A
            git -C (Join-Path $workspaceRoot "Workspace_AI") commit -m "chore(gemini): pre-push synchronization of rules export and knowledge base" | Out-Null
        }
    } else {
        Write-Warning "Update-Gemini.ps1 not found at $updateGeminiScript"
    }
}


$allRepos = @()
if ($Repositories -and $Repositories.Count -gt 0) {
    $allRepos = $Repositories
} else {
    $candidateDirs = Get-ChildItem -Path $workspaceRoot -Directory -ErrorAction SilentlyContinue
    $allRepos = @("Git_Repositories") + @($candidateDirs | Where-Object { Test-Path (Join-Path $_.FullName ".git") } | Select-Object -ExpandProperty Name)
}

$pushedRepos = @()
$skippedRepos = @()
$failedRepos = @()

foreach ($repoName in $allRepos) {
    $repoPath = if ($repoName -eq "Git_Repositories" -or $repoName -eq ".") { $workspaceRoot } else { Join-Path $workspaceRoot $repoName }
    if (-not (Test-Path -LiteralPath (Join-Path $repoPath ".git"))) {
        continue
    }

    # Check if remote exists
    $remotes = git -C $repoPath remote
    if (-not $remotes) {
        Write-Host "  [$repoName] SKIP (No Git remote configured)" -ForegroundColor DarkGray
        $skippedRepos += $repoName
        continue
    }

    # Check branch & ahead status
    $branch = (git -C $repoPath rev-parse --abbrev-ref HEAD).Trim()
    $statusSb = git -C $repoPath status -sb
    $isAhead = $statusSb -match 'ahead\s+(\d+)'

    if (-not $isAhead) {
        Write-Host "  [$repoName] UP-TO-DATE (Branch: $branch, 0 commits ahead)" -ForegroundColor DarkGray
        continue
    }

    $aheadCount = $Matches[1]
    Write-Host "  [$repoName] PUSHING $aheadCount commit(s) on branch '$branch' to remote 'origin'..." -ForegroundColor Cyan

    try {
        $pushOutput = git -C $repoPath push origin $branch 2>&1
        Write-Host "    -> $pushOutput" -ForegroundColor Green
        $pushedRepos += $repoName
    } catch {
        Write-Host "    -> ERROR: $_" -ForegroundColor Red
        $failedRepos += $repoName
    }
}

$pushTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
if ($pushedRepos.Count -gt 0) {
    $logEntry = "[$pushTimestamp] [SUCCESS] [Target: MULTI] [Version: v7.1.0] [PushDate: $pushTimestamp] [AffectedRepos: $($pushedRepos -join ', ')] PUSH_EXECUTED - Pushed $($pushedRepos.Count) repository/repositories to remote ($($pushedRepos -join ', ')). Reason: $Reason"
    Add-Content -LiteralPath $cmLogFile -Value $logEntry -Encoding UTF8
    Write-Host "`n  -> Appended PUSH_EXECUTED record to cm_activity.log" -ForegroundColor Green

    # Transition completed proposals to 'pushed' state in proposals.json
    $proposalsFile = Join-Path $workspaceRoot "Workspace_Inventory\data\proposals\proposals.json"
    if (Test-Path -LiteralPath $proposalsFile) {
        $ledgerJson = Get-Content -LiteralPath $proposalsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $transitionCount = 0
        foreach ($p in $ledgerJson.proposals) {
            $origin = if ($p.origin_repo) { $p.origin_repo } else { "" }
            $matchesPushed = $pushedRepos | Where-Object { $origin -like "*$_*" }
            if ($matchesPushed -or $pushedRepos -contains "Workspace_Inventory" -or $pushedRepos -contains "Git_Repositories") {
                if ($p.progress_state -eq "completed" -or $p.state -eq "completed") {
                    $p.state = "pushed"
                    $p.progress_state = "pushed"
                    $p | Add-Member -NotePropertyName "pushed_at" -NotePropertyValue $pushTimestamp -Force
                    $transitionCount++
                }
            }
        }
        if ($transitionCount -gt 0) {
            $ledgerJson | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $proposalsFile -Encoding UTF8
            Write-Host "  -> Transitioned $transitionCount proposal(s) from 'completed' to 'pushed' state in proposals.json." -ForegroundColor Green
        }
    }
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " [SUMMARY] Workspace Push Completed" -ForegroundColor Green
Write-Host " Pushed Repos  : $($pushedRepos.Count) ($($pushedRepos -join ', '))"
Write-Host " Skipped Repos : $($skippedRepos.Count)"
Write-Host " Failed Repos  : $($failedRepos.Count)"
Write-Host "==========================================================================" -ForegroundColor Cyan
