<#
.SYNOPSIS
    Runs a complete multi-repository Configuration Management audit across D:\Git_Repositories.

.DESCRIPTION
    Scans all sibling directories, detects Git status, branch heads, dirty working copy state,
    LCM governance status, absorbed version, and current version. Updates data/inventory.json
    and docs/INVENTORY_DASHBOARD.md.

.EXAMPLE
    .\tools\Invoke-WorkspaceAudit.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\modules\WorkspaceCM.psm1'
Import-Module $modulePath -Force

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Workspace_Inventory: Configuration Management Audit Runner      " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$results = Update-WorkspaceInventory

$drift = Test-WorkspaceDrift
Write-Host "`nWorkspace Drift Assessment: " -NoNewline
if ($drift.Status -eq 'CLEAN') {
    Write-Host "CLEAN (No configuration drift detected)" -ForegroundColor Green
} else {
    Write-Host "DRIFT DETECTED" -ForegroundColor Yellow
    Write-Host "  Dirty Repositories ($($drift.DirtyRepoCount)): $($drift.DirtyRepositories -join ', ')" -ForegroundColor Yellow
    Write-Host "  Outdated LCM Repositories ($($drift.OutdatedRepoCount)): $($drift.OutdatedRepositories -join ', ')" -ForegroundColor Yellow
    if ($drift.UnpushedRepoCount -gt 0) {
        Write-Host "  Unpushed Repositories ($($drift.UnpushedRepoCount)): $($drift.UnpushedRepositories -join ', ')" -ForegroundColor Yellow
    }
}

Write-Host "`nAudit complete. Dashboard updated at docs/INVENTORY_DASHBOARD.md" -ForegroundColor Green
