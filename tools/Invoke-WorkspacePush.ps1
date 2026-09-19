<#
.SYNOPSIS
  Multi-repository push and remote synchronization engine for LCM governed workspace.
.DESCRIPTION
  Module: tools/Invoke-WorkspacePush.ps1
  Purpose: Iterates across all governed and child repositories under D:\Git_Repositories, detects if a Git remote exists and if local branch is ahead of remote tracking branch, and executes git push with structured audit logging.
  Path: Workspace_Inventory/tools/Invoke-WorkspacePush.ps1
  Authors: Rolf, Workspace_AI Engine
  Version: 1.1.0
  Date: 2026-09-10
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Commit reason and audit message for the push operation')]
    [string]$Reason = "feat(cm): sync completed workspace proposals and governance updates",

    [Parameter(Mandatory = $false, HelpMessage = 'Specific repositories to push (defaults to all ahead repositories)')]
    [string[]]$Repositories,

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

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM MULTI-REPOSITORY PUSH & SYNC ENGINE (Invoke-WorkspacePush)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Pushes all ahead workspace repositories to remote Git repositories in lockstep."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh Workspace_Inventory/tools/Invoke-WorkspacePush.ps1 [[-Reason] <str>] [-Repositories <str[]>] [-SkipGemini] [-Force] [-DryRun] [-h]"
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

# ------------------------------------------------------------------------------
# 0.1 Synchronize Tool Catalog & CM Metadata Snapshot for Root Container
# ------------------------------------------------------------------------------
$updateCatalogScript = Join-Path $workspaceRoot ".lcm\tools\internal\Update-ToolCatalog.ps1"
if (Test-Path -LiteralPath $updateCatalogScript) {
    Write-Host "`n[Pre-Push Pipeline] Synchronizing Tool Catalog snapshot..." -ForegroundColor Yellow
    & pwsh -File $updateCatalogScript -Silent
    $rootDirty = git -C $workspaceRoot status --porcelain
    if ($rootDirty -match '\.lcm/config/tool_catalog\.json') {
        git -C $workspaceRoot add .lcm/config/tool_catalog.json
        git -C $workspaceRoot commit -m "chore(lcm): pre-push snapshot synchronization of tool_catalog.json" | Out-Null
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
    $statusSb = (git -C $repoPath status -sb) -join "`n"

    if ($statusSb -match 'ahead\s+(\d+)') {
        $aheadCount = $Matches[1]
    } else {
        Write-Host "  [$repoName] UP-TO-DATE (Branch: $branch, 0 commits ahead)" -ForegroundColor DarkGray
        continue
    }

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

$pushTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
if ($pushedRepos.Count -gt 0) {
    if ($DryRun) {
        Write-Host "`n  -> [DRY RUN] Would append PUSH_EXECUTED record to cm_activity.log for: $($pushedRepos -join ', ')" -ForegroundColor Yellow
        $proposalsFile = Join-Path $workspaceRoot "Workspace_Inventory\data\proposals\proposals.json"
        if (Test-Path -LiteralPath $proposalsFile) {
            $ledgerJson = Get-Content -LiteralPath $proposalsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $transitionCount = 0
            foreach ($p in $ledgerJson.proposals) {
                if ($p.progress_state -eq "completed" -or $p.state -eq "completed") {
                    $transitionCount++
                    Write-Host "      * [DRY RUN] Would transition Proposal $($p.id) ($($p.title)) to 'pushed'" -ForegroundColor Gray
                }
            }
            Write-Host "  -> [DRY RUN] Total $transitionCount completed proposal(s) would transition to 'pushed'." -ForegroundColor Yellow
        }
    } else {
        $lcmVersion = "v7.0.0"
        $invFile = Join-Path $workspaceRoot "Workspace_Inventory\data\inventory.json"
        if (Test-Path -LiteralPath $invFile) {
            try {
                $invData = Get-Content -LiteralPath $invFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($invData.GlobalLCMVersion) { $lcmVersion = "v$($invData.GlobalLCMVersion.TrimStart('v'))" }
            } catch { }
        }
        $logEntry = "[$pushTimestamp] [SUCCESS] [Target: MULTI] [Version: $lcmVersion] [PushDate: $pushTimestamp] [AffectedRepos: $($pushedRepos -join ', ')] PUSH_EXECUTED - Pushed $($pushedRepos.Count) repository/repositories to remote ($($pushedRepos -join ', ')). Reason: $Reason"
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
                        if ($p.PSObject.Properties['dates'] -and $p.dates) {
                            $p.dates | Add-Member -NotePropertyName "pushed" -NotePropertyValue $pushTimestamp -Force
                        }
                        if ($p.PSObject.Properties['state_history'] -and $p.state_history) {
                            $newHist = [System.Collections.Generic.List[object]]::new(@($p.state_history))
                            $newHist.Add([PSCustomObject]@{
                                state = "pushed"
                                timestamp = $pushTimestamp
                                user = $env:USERNAME
                                note = "Pushed to remote ($($pushedRepos -join ', '))"
                            })
                            $p.state_history = @($newHist)
                        }
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
}


Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " [SUMMARY] Workspace Push Completed" -ForegroundColor Green
Write-Host " Pushed Repos  : $($pushedRepos.Count) ($($pushedRepos -join ', '))"
Write-Host " Skipped Repos : $($skippedRepos.Count)"
Write-Host " Failed Repos  : $($failedRepos.Count)"
Write-Host "==========================================================================" -ForegroundColor Cyan
