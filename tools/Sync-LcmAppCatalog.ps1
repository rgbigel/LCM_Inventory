<#
.SYNOPSIS
    Compiles and synchronizes the machine-readable LCM App Catalog (data/catalog/apps.json) across repositories.
.DESCRIPTION
    Module: tools/Sync-LcmAppCatalog.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 10.2.0
    Date: 2026-10-13
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Target repository to sync (defaults to all workspace repos)')]
    [string]$Repo = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Workspace root directory')]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " SYNC LCM APP CATALOG (Sync-LcmAppCatalog)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Scans tripartite documentation (Architecture, Requirements, Implementation) and DOX"
    Write-Host "  headers across repositories to compile a zero-drift machine-readable catalog (apps.json)."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Sync-LcmAppCatalog.ps1 [[-Repo] <str>] [-WorkspaceRoot <str>] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Repo          : Target repository to scan (optional, scans all if omitted)"
    Write-Host "  -WorkspaceRoot : Workspace root directory (default: D:\Git_Repositories)"
    Write-Host "  -Help (-h, -?) : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
Import-Module $modulePath -Force

$catalog = Sync-LcmAppCatalog -Repo $Repo -WorkspaceRoot $WorkspaceRoot
Format-LcmAppsTable -WorkspaceRoot $WorkspaceRoot
