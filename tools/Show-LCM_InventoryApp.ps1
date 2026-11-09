<#
.SYNOPSIS
  Generates and opens the modern interactive HTML explorer for LCM Workspace Inventory.
.DESCRIPTION
  Module: Show-LCM_InventoryApp
  Purpose: Generates and opens the interactive HTML workspace dashboard conforming to the
           INVENTORY_VIEWER design standard. Features clickable metric cards, multi-tab navigation
           (Repositories Ledger, Workspace Tools, Governance Rules), live search filtering,
           interactive action suite (Open in Explorer, Onboard, Un-Git, Rename, Delete),
           single-instance tab lifecycle coordination, and live REST daemon integration.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: LCM_Inventory/tools/Show-LCM_InventoryApp.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.1
  Date: 2026-11-08 17:34:00
  ShortName: ShowLCMExplorer
.PARAMETER NoLaunch
Generates the HTML dashboard without opening the HTTP Standard Display.
.PARAMETER Pane
  Opens the display inside an Antigravity IDE editor/side pane instead of an external browser window (Alias: -Panel).
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  showinventory
.EXAMPLE
  pwsh tools/Show-LCM_InventoryApp.ps1 -NoLaunch
#>

[CmdletBinding()]
param(
  [switch]$NoLaunch,
  [Parameter(Mandatory = $false, HelpMessage = 'Opens the display inside an Antigravity IDE editor/side pane')]
  [Alias('Panel')]
  [switch]$Pane,
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmDisplayVersion.psm1') -Force
$scriptVersion = Get-LcmDisplaySourceVersion -Path $PSCommandPath

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
$templatePath = Join-Path $repoRoot 'assets\LCM_INVENTORY_VIEWER.html'
if (-not (Test-Path -LiteralPath $templatePath)) {
  $templatePath = Join-Path $repoRoot 'assets\WORKSPACE_INVENTORY_VIEWER.html'
}
$artifactsDir = Join-Path $repoRoot 'data\artifacts'
if (-not (Test-Path $artifactsDir)) {
  New-Item -Path $artifactsDir -ItemType Directory -Force | Out-Null
}
$renderedHtmlPath = Join-Path $artifactsDir 'LCM_INVENTORY_VIEWER.html'

if (-not (Test-Path -LiteralPath $invPath)) {
  throw "Workspace inventory file not found: $invPath"
}

if (-not (Test-Path -LiteralPath $templatePath)) {
  throw "Workspace inventory viewer template not found: $templatePath"
}
$invRaw = Get-Content -LiteralPath $invPath -Raw -Encoding UTF8
$htmlTemplate = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
$provenance = Get-LcmDisplayProvenance -ScriptPath $PSCommandPath -TemplatePath $templatePath
$htmlTemplate = $htmlTemplate.Replace('{{DISPLAY_VERSION}}', $provenance.Label)

# Load Repo Documentation for Universal Document Table
$docsCache = @{}
$governedRepos = @("LCM_Inventory", "LCM_Inventory", "Installation_LCD", "LCM_AI", "SystemConfiguration", "BackgroundModifier", "VolumeInventory", "HaSSD06", "HaSSD06_Inventory", "AuthorizeMasterUser", "LCM_Shared", "Git_Repositories")
$docNames = @("Architecture.md", "Requirements.md", "Implementation.md", "install/Installation.md", "Installation.md", "README.md", "docs/Architecture.md", "docs/Requirements.md", "docs/Implementation.md", "docs/CM_POLICIES.md")

foreach ($r in $governedRepos) {
    $repoDir = if ($r -eq "Git_Repositories") { $workspaceRoot } else { Join-Path $workspaceRoot $r }
    if (Test-Path -LiteralPath $repoDir) {
        foreach ($d in $docNames) {
            $fullDoc = Join-Path $repoDir $d.Replace('/', '\')
            if (Test-Path -LiteralPath $fullDoc) {
                $key = "$r/$d"
                $docsCache[$key] = Get-Content -LiteralPath $fullDoc -Raw -Encoding UTF8
            }
        }
    }
}

$injectedDataBlock = @"
{
  "inventory": $($invRaw | ConvertFrom-Json | ConvertTo-Json -Depth 12 -Compress),
  "docs": $($docsCache | ConvertTo-Json -Depth 8 -Compress)
}
"@
$injectedDataBlock = $injectedDataBlock.Replace('<', '\u003c')
$renderedHtml = $htmlTemplate.Replace('{"inventory":{"repositories":[]},"docs":{},"__lcm_unrendered_template__":true}', $injectedDataBlock)

$renderedHtml | Set-Content -LiteralPath $renderedHtmlPath -Encoding UTF8

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM WORKSPACE INVENTORY EXPLORER (v$scriptVersion)" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Dashboard: $renderedHtmlPath"
Write-Host " Inventory: $invPath"

if (-not $NoLaunch) {
  $standardDisplayModule = Join-Path $repoRoot 'modules\LcmStandardDisplay.psm1'
  if (-not (Test-Path -LiteralPath $standardDisplayModule -PathType Leaf)) {
    throw "Standard Display launcher module is missing: $standardDisplayModule"
  }
  Import-Module -Name $standardDisplayModule -Force
  Write-Host " Launching Workspace Inventory through port 9876 HTTP..." -ForegroundColor Green
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Open-LcmStandardDisplay -DisplayId inventory -Pane:$Pane
} else {
  Write-Host " Dashboard rendered cleanly (browser launch suppressed via -NoLaunch)." -ForegroundColor DarkGray
  Write-Host "==========================================================================" -ForegroundColor Cyan
}
