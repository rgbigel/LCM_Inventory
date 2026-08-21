<#
Module: tools/Invoke-LCMOnboardBatch.ps1
Purpose: Interactively enumerates un-governed repositories in alphabetical order, prompting for disposition (Onboard, Ignore, Retire, Delete) or auto-skipping pre-dispositioned items.
Path: tools/Invoke-LCMOnboardBatch.ps1
Authors: Rolf, Workspace_AI Engine
Version: 1.0.0
Date: 2026-08-21
#>

[CmdletBinding()]
param(
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\modules\WorkspaceCM.psm1'
Import-Module (Resolve-Path $modulePath) -Force

$workspaceRoot = Get-WorkspaceRoot

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " LCM Multi-Repository Batch Onboarding & Disposition Manager     " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. Update and refresh inventory state
Update-WorkspaceInventory -WorkspaceRoot $workspaceRoot | Out-Null

# 2. Retrieve un-governed repositories sorted alphabetically
$candidates = Get-UngovernedRepositories -WorkspaceRoot $workspaceRoot

if ($candidates.Count -eq 0) {
    Write-Host "`nAll repositories in the workspace are governed or have active dispositions." -ForegroundColor Green
    return
}

Write-Host "`nFound $($candidates.Count) candidate repository(ies) awaiting disposition/onboarding:" -ForegroundColor Yellow
$candidates | Format-Table RepositoryName, Classification, ElevationRequired, Path -AutoSize

foreach ($repo in $candidates) {
    Write-Host "`n-----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Processing Repository: $($repo.RepositoryName)" -ForegroundColor Cyan
    Write-Host " Path: $($repo.Path)"
    Write-Host " Classification: $($repo.Classification)"
    Write-Host " Elevation Required: $($repo.ElevationRequired)"
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Cyan

    if ($NonInteractive) {
        Write-Host "NonInteractive mode enabled. Skipping prompt for $($repo.RepositoryName)." -ForegroundColor Gray
        continue
    }

    Write-Host "Choose Disposition for '$($repo.RepositoryName)':" -ForegroundColor White
    Write-Host "  [1] Onboard into LCM v5.0.1" -ForegroundColor Green
    Write-Host "  [2] Ignore (Keep on disk, do not onboard)" -ForegroundColor Yellow
    Write-Host "  [3] Retire (Mark as obsolete / deprecated)" -ForegroundColor Yellow
    Write-Host "  [4] Delete (Permanently remove from disk)" -ForegroundColor Red
    Write-Host "  [5] Defer / Skip for now" -ForegroundColor Gray

    $choice = Read-Host "Enter selection (1-5)"
    
    switch ($choice) {
        '1' {
            Write-Host "`nProceeding with LCM onboarding for $($repo.RepositoryName)..." -ForegroundColor Green
            # Dispatch to Onboarding Runner
            $onboardScript = Join-Path $workspaceRoot "Workspace_AI\tools\Invoke-LCMOnboardRepo.ps1"
            if (Test-Path -LiteralPath $onboardScript) {
                & $onboardScript -TargetRepo $repo.RepositoryName
                Set-RepoDisposition -RepositoryName $repo.RepositoryName -State 'governed' -Reason 'Onboarded into LCM v5.0.1' -WorkspaceRoot $workspaceRoot
            } else {
                Write-Warning "Onboarding script not found at: $onboardScript"
            }
        }
        '2' {
            $reason = Read-Host "Enter reason for ignoring '$($repo.RepositoryName)'"
            Set-RepoDisposition -RepositoryName $repo.RepositoryName -State 'ignored' -Reason $reason -WorkspaceRoot $workspaceRoot
        }
        '3' {
            $reason = Read-Host "Enter reason for retiring '$($repo.RepositoryName)'"
            Set-RepoDisposition -RepositoryName $repo.RepositoryName -State 'retired' -Reason $reason -WorkspaceRoot $workspaceRoot
        }
        '4' {
            $confirm = Read-Host "Are you sure you want to PERMANENTLY DELETE '$($repo.Path)'? Type 'DELETE' to confirm"
            if ($confirm -eq 'DELETE') {
                Remove-Item -Path $repo.Path -Recurse -Force
                Write-Host "Deleted directory: $($repo.Path)" -ForegroundColor Red
                Set-RepoDisposition -RepositoryName $repo.RepositoryName -State 'deleted' -Reason 'Deleted from disk by operator' -WorkspaceRoot $workspaceRoot
            } else {
                Write-Host "Deletion cancelled." -ForegroundColor Yellow
            }
        }
        Default {
            Write-Host "Skipped for now." -ForegroundColor Gray
        }
    }
}

# 3. Final refresh
Write-Host "`nBatch disposition pass complete. Refreshing workspace inventory..." -ForegroundColor Cyan
Update-WorkspaceInventory -WorkspaceRoot $workspaceRoot | Out-Null
