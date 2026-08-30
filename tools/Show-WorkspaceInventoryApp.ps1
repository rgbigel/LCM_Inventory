<#
.SYNOPSIS
  Generates and opens the modern interactive HTML explorer for LCM Workspace Inventory.
.DESCRIPTION
  Module: Show-WorkspaceInventoryApp
  Purpose: Generates and opens the interactive HTML workspace dashboard conforming to the
           INVENTORY_VIEWER design standard. Features clickable metric cards, multi-tab navigation
           (Repositories Ledger, Workspace Tools, Governance Rules), live search filtering,
           interactive action suite (Open in Explorer, Onboard, Un-Git, Rename, Delete),
           single-instance tab lifecycle coordination, and live REST daemon integration.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: Workspace_Inventory/tools/Show-WorkspaceInventoryApp.ps1
  Authors: Rolf, Workspace_AI Engine
  Version: 6.0.0
  Date: 2026-08-30
.PARAMETER NoLaunch
  Generates the HTML dashboard file without automatically launching it in the web browser.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  showinventory
.EXAMPLE
  pwsh tools/Show-WorkspaceInventoryApp.ps1 -NoLaunch
#>

[CmdletBinding()]
param(
  [switch]$NoLaunch,
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "6.0.0"
$scriptName = "Show-WorkspaceInventoryApp"

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM WORKSPACE INVENTORY VIEWER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Generates and displays the interactive HTML dashboard for LCM Workspace Inventory."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  showinventory [-NoLaunch] [-h]"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$workspaceRoot = Split-Path $repoRoot -Parent
$invPath = Join-Path $repoRoot 'data\inventory.json'
$templatePath = Join-Path $repoRoot 'docs\WORKSPACE_INVENTORY_VIEWER.html'
$scratchDir = Join-Path $repoRoot 'scratch'
if (-not (Test-Path $scratchDir)) {
  New-Item -Path $scratchDir -ItemType Directory -Force | Out-Null
}
$renderedHtmlPath = Join-Path $scratchDir 'WORKSPACE_INVENTORY_VIEWER.html'

if (-not (Test-Path -LiteralPath $invPath)) {
  throw "Workspace inventory file not found: $invPath"
}

if (-not (Test-Path -LiteralPath $templatePath)) {
  throw "Workspace inventory viewer template not found: $templatePath"
}

$invRaw = Get-Content -LiteralPath $invPath -Raw -Encoding UTF8
$htmlTemplate = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8

$injectedDataBlock = "const INVENTORY_DATA = $invRaw;"
$renderedHtml = $htmlTemplate.Replace('/*__INJECTED_INVENTORY_DATA__*/', $injectedDataBlock)

$renderedHtml | Set-Content -LiteralPath $renderedHtmlPath -Encoding UTF8

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM WORKSPACE INVENTORY EXPLORER (v$scriptVersion)" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Dashboard: $renderedHtmlPath"
Write-Host " Inventory: $invPath"

if (-not $NoLaunch) {
  Write-Host " Launching interactive desktop browser..." -ForegroundColor Green
  Write-Host "==========================================================================" -ForegroundColor Cyan
  $dispatcher = Join-Path $workspaceRoot ".lcm\tools\internal\Invoke-InteractiveDesktop.ps1"
  if (-not (Test-Path -LiteralPath $dispatcher)) {
    $dispatcher = Join-Path $workspaceRoot "tools\Invoke-InteractiveDesktop.ps1"
  }
  if (Test-Path -LiteralPath $dispatcher) {
    & pwsh -File $dispatcher -FilePath $renderedHtmlPath | Out-Null
  } else {
    Start-Process $renderedHtmlPath
  }
} else {
  Write-Host " Dashboard rendered cleanly (browser launch suppressed via -NoLaunch)." -ForegroundColor DarkGray
  Write-Host "==========================================================================" -ForegroundColor Cyan
}
