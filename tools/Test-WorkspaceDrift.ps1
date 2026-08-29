<#
Module: tools/Test-WorkspaceDrift.ps1
Purpose: Evaluates workspace repositories for configuration drift (dirty copies, unpushed commits, outdated LCM).
Path: tools/Test-WorkspaceDrift.ps1
Authors: Rolf, Workspace_AI Engine
Version: 1.0.0
Date: 2026-08-15
Changelog:
- 2026-08-15: Initial versioned implementation of configuration drift tester.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cmModule = Join-Path $PSScriptRoot '..\modules\WorkspaceCM.psm1'
if (-not (Test-Path $cmModule)) {
    $cmModule = Join-Path (Split-Path $PSScriptRoot -Parent) 'Workspace_Inventory\modules\WorkspaceCM.psm1'
}
if (-not (Test-Path $cmModule)) {
    $cmModule = Join-Path $PSScriptRoot '..\Workspace_Inventory\modules\WorkspaceCM.psm1'
}
Import-Module $cmModule -Force

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Workspace_Inventory: Configuration Drift Evaluator              " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$drift = Test-WorkspaceDrift

if ($drift.Status -eq 'CLEAN') {
    Write-Host "`nStatus: CLEAN" -ForegroundColor Green
    Write-Host "All repositories match active baseline (v$($drift.GlobalLCMVersion)) and are clean." -ForegroundColor Green
} else {
    Write-Host "`nStatus: DRIFT DETECTED" -ForegroundColor Yellow
    Write-Host "Global LCM Baseline: v$($drift.GlobalLCMVersion)" -ForegroundColor Cyan
    
    if ($drift.DirtyRepoCount -gt 0) {
        Write-Host "`nDirty Repositories ($($drift.DirtyRepoCount)):" -ForegroundColor Yellow
        foreach ($r in $drift.DirtyRepositories) {
            Write-Host "  - $r" -ForegroundColor Yellow
        }
    }
    
    if ($drift.OutdatedRepoCount -gt 0) {
        Write-Host "`nOutdated LCM Repositories ($($drift.OutdatedRepoCount)):" -ForegroundColor Yellow
        foreach ($r in $drift.OutdatedRepositories) {
            Write-Host "  - $r" -ForegroundColor Yellow
        }
    }
    
    if ($drift.UnpushedRepoCount -gt 0) {
        Write-Host "`nUnpushed Repositories ($($drift.UnpushedRepoCount)):" -ForegroundColor Yellow
        foreach ($r in $drift.UnpushedRepositories) {
            Write-Host "  - $r" -ForegroundColor Yellow
        }
    }
}
