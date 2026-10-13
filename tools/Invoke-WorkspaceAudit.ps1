<#
Module: tools/Invoke-WorkspaceAudit.ps1
Purpose: Runs a complete multi-repository Configuration Management audit across D:\Git_Repositories.
Path: tools/Invoke-WorkspaceAudit.ps1
Authors: Rolf, LCM_AI Engine
Version: 10.0.0
Date: 2026-10-13
Changelog:
- 2026-10-13: Added -h / -Help parameter per RULE-PS-010.
- 2026-10-13: Initial versioned implementation of the multi-repo CM audit runner.
#>

[CmdletBinding()]
param(
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " CONFIGURATION MANAGEMENT AUDIT RUNNER (Invoke-WorkspaceAudit)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Runs a complete multi-repository Configuration Management audit across workspace."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Invoke-WorkspaceAudit.ps1 [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Help (-h, -?) : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$modulePath = Join-Path $PSScriptRoot '..\modules\WorkspaceCM.psm1'
Import-Module $modulePath -Force

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " LCM_Inventory: Configuration Management Audit Runner      " -ForegroundColor Cyan
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
