<#
Module: tools/Invoke-WorkspaceAudit.ps1
Purpose: Runs a complete multi-repository Configuration Management audit across D:\Git_Repositories.
Path: tools/Invoke-WorkspaceAudit.ps1
Authors: Rolf, Workspace_AI Engine
Version: 1.0.0
Date: 2026-08-15
Changelog:
- 2026-08-15: Initial versioned implementation of the multi-repo CM audit runner.
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
