<#
.SYNOPSIS
    Workspace AI Super-Controller - Unified Navigation Dispatcher for ToolsExplorer and ShowCM.
.DESCRIPTION
    Module: tools/Show-SuperController.ps1
    Purpose: Provides a single, unified entry point to dispatch ToolsExplorer and ShowCM
             scoped cleanly to a specific workspace subsystem.
    Path: tools/Show-SuperController.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 1.0.0
    Date: 2026-09-27
.PARAMETER Subsystem
    Workspace subsystem to scope tools and proposals to (e.g. LCM, LCM_Inventory, LCM_AI, HaSSD06, SystemConfiguration, LCM_Supervision, or ALL).
.PARAMETER Tool
    Which tool dashboard to launch: 'Tools' / 'ToolsExplorer', 'CM' / 'ShowCM', or 'All' (both). Default is 'All'.
.PARAMETER CliMode
    Outputs status summary directly to terminal without launching desktop browser.
.PARAMETER Help
    Displays parameter reference and usage examples.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false, HelpMessage = 'Workspace subsystem scope')]
    [Alias('Scope', 'Group')]
    [string]$Subsystem = 'ALL',

    [Parameter(Position = 1, Mandatory = $false, HelpMessage = 'Target tool dashboard to launch')]
    [ValidateSet('All', 'Tools', 'CM', 'ToolsExplorer', 'ShowCM')]
    [string]$Tool = 'All',

    [Parameter(Mandatory = $false, HelpMessage = 'Output summary to CLI without browser launch')]
    [Alias('Cli', 'Text', 'NoBrowser')]
    [switch]$CliMode,

    [Alias('h', '?')]
    [switch]$Help
)

$scriptVersion = "1.0.0"
$scriptName = "Show-SuperController"

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " WORKSPACE AI SUPER-CONTROLLER (v$scriptVersion)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Unified navigation dispatcher for ToolsExplorer and ShowCM scoped to subsystems."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Show-SuperController.ps1 [-Subsystem <name>] [-Tool <All|Tools|CM>] [-Cli] [-h]"
    Write-Host ""
    Write-Host "SUBSYSTEMS:" -ForegroundColor Yellow
    Write-Host "  ALL, LCM, LCM_Inventory, LCM_AI, HaSSD06, SystemConfiguration, LCM_Supervision"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  SuperController"
    Write-Host "  SuperController LCM"
    Write-Host "  SuperController HaSSD06 -Tool Tools"
    Write-Host "  SuperController LCM_Inventory -Tool CM"
    Write-Host "  SuperController -Cli"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
    $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$normSubsys = $Subsystem.Trim()
if ([string]::IsNullOrWhiteSpace($normSubsys) -or $normSubsys -eq '*' -or $normSubsys.ToUpper() -eq 'ALL') {
    $normSubsys = 'ALL'
}

$toolsExplorerScript = Join-Path $workspaceRoot '.lcm\tools\internal\Show-ToolsExplorer.ps1'
$showCmScript = Join-Path $workspaceRoot 'LCM_Inventory\tools\Show-LcmControl.ps1'

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " WORKSPACE AI SUPER-CONTROLLER v$scriptVersion" -ForegroundColor Green
Write-Host " Scope Target : $normSubsys" -ForegroundColor Yellow
Write-Host " Target View  : $Tool" -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($CliMode) {
    Write-Host " CLI Mode Active. Querying ledger and catalog..." -ForegroundColor DarkGray
    if ($Tool -in @('All', 'Tools', 'ToolsExplorer')) {
        Write-Host "`n--- Tools in Subsystem: $normSubsys ---" -ForegroundColor Cyan
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $toolsExplorerScript -Group $normSubsys -NoBrowser
    }
    if ($Tool -in @('All', 'CM', 'ShowCM')) {
        Write-Host "`n--- Proposals in Subsystem: $normSubsys ---" -ForegroundColor Cyan
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $showCmScript -Repo $(if ($normSubsys -ne 'ALL') { $normSubsys }) -CliMode
    }
    return
}

# Desktop Browser Dispatch
if ($Tool -in @('All', 'Tools', 'ToolsExplorer')) {
    Write-Host " [1/2] Dispatching ToolsExplorer (Subsystem: $normSubsys)..." -ForegroundColor Green
    $teArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$toolsExplorerScript`"")
    if ($normSubsys -ne 'ALL') {
        $teArgs += @("-Group", "`"$normSubsys`"")
    }
    Start-Process -FilePath "pwsh.exe" -ArgumentList $teArgs
    Start-Sleep -Milliseconds 400
}

if ($Tool -in @('All', 'CM', 'ShowCM')) {
    Write-Host " [2/2] Dispatching ShowCM Control Hub (Subsystem: $normSubsys)..." -ForegroundColor Green
    $cmArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$showCmScript`"")
    if ($normSubsys -ne 'ALL') {
        $cmArgs += @("-Repo", "`"$normSubsys`"")
    }
    Start-Process -FilePath "pwsh.exe" -ArgumentList $cmArgs
}

Write-Host " Dispatches initiated cleanly." -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
