<#
Module: tools/Build-HaInventoryViewer.ps1
Purpose: Unified builder and launcher that automatically syncs live Home Assistant state and opens the interactive viewer.
Path: tools/Build-HaInventoryViewer.ps1
Authors: Rolf, LCM_AI Engine
Version: 5.2.0
Date: 2026-09-18
.SYNOPSIS
  Unified builder and launcher that automatically syncs live Home Assistant state and opens the interactive viewer.

.PARAMETER Instance
  Target Home Assistant instance or subsystem identifier (default: HaSSD06).

.PARAMETER NoLaunch
  Suppresses automatic browser launch after building inventory.

.PARAMETER SkipSync
  Skips fetching live telemetry from Home Assistant OS and uses cached inventory.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Target Home Assistant instance or subsystem identifier (default: HaSSD06).')]
    [Alias('Subsystem', 'Name', 'HaName')]
    [string]$Instance = 'HaSSD06',

    [Parameter(Mandatory = $false, HelpMessage = 'Suppresses automatic browser launch after building inventory.')]
    [switch]$NoLaunch,

    [Parameter(Mandatory = $false, HelpMessage = 'Skips fetching live telemetry from Home Assistant OS and uses cached inventory.')]
    [switch]$SkipSync,

    [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
    [Alias('h', '?')]
    [switch]$Help
)

if ($Help) {
    Write-Host "Build-HaInventoryViewer.ps1 - Unified Home Assistant inventory builder and dashboard launcher." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  pwsh -File Build-HaInventoryViewer.ps1 [-Instance <string>] [-NoLaunch] [-SkipSync] [-Help]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -Instance  Target Home Assistant instance name (default: HaSSD06)."
    Write-Host "  -NoLaunch  Build HTML inventory without launching web browser."
    Write-Host "  -SkipSync  Skip live API synchronization; render from cached data."
    Write-Host "  -Help      (-h, -?) Displays this help message."
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$htmlFileName = if ($Instance -eq 'HaSSD06') { 'SHOW_HA_INVENTORY.html' } else { "SHOW_HA_INVENTORY_${Instance}.html" }
$artifactsDir = Join-Path $repoRoot "data\artifacts"
if (-not (Test-Path -LiteralPath $artifactsDir)) {
    New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
}
$htmlPath = Join-Path $artifactsDir $htmlFileName
$updateScript = Join-Path $PSScriptRoot 'Update-HaInventory.ps1'
$appScript = Join-Path $PSScriptRoot 'Show-HaInventoryApp.ps1'

# 1. Sync live telemetry from Home Assistant OS if available
if (-not $SkipSync -and (Test-Path -LiteralPath $updateScript)) {
    Write-Host "Syncing latest live telemetry from Home Assistant ($Instance)..." -ForegroundColor Cyan
    try {
        & $updateScript
    } catch {
        Write-Warning "Live sync failed ($($_.Exception.Message)). Falling back to cached inventory."
        if (Test-Path -LiteralPath $appScript) {
            & $appScript -Instance $Instance -NoLaunch
        }
    }
} else {
    if (Test-Path -LiteralPath $appScript) {
        & $appScript -Instance $Instance -NoLaunch
    }
}

# 2. Launch browser with foreground focus
if (-not $NoLaunch -and (Test-Path -LiteralPath $htmlPath)) {
    Write-Host "Opening interactive Subsystem Dashboard on Desktop (Session 1)..." -ForegroundColor Green
    $dispatcher = Join-Path $workspaceRoot 'LCM_Inventory\tools\Invoke-InteractiveDesktop.ps1'
    if (-not (Test-Path -LiteralPath $dispatcher)) {
        $dispatcher = Join-Path $workspaceRoot 'tools\Invoke-InteractiveDesktop.ps1'
    }
    if (Test-Path -LiteralPath $dispatcher) {
        & pwsh -File $dispatcher -FilePath "explorer.exe" -ArgumentList "`"$htmlPath`"" | Out-Null
    } else {
        Start-Process "explorer.exe" -ArgumentList "`"$htmlPath`""
    }
}
