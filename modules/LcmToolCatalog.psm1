<#
.SYNOPSIS
  LCM Tool Catalog & Viewer Generation Module
.DESCRIPTION
  Provides modular services for loading tool catalogs, measuring metric summaries,
  formatting terminal text output, and compiling the self-contained HTML Tool Explorer dashboard.
  Conforms to RULE-PS-001 (StrictMode), RULE-PS-002 (Approved Verbs), and RULE-PS-008.
.NOTES
  Module: LcmToolCatalog
  Purpose: Loads the governed tool catalog and generates the HTTP-backed Tool Explorer.
  Path: tools/modules/LcmToolCatalog.psm1
  Authors: Rolf, Copilot
  Version: 10.2.4
  Date: 2026-11-13 13:12:00
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'LcmDisplayVersion.psm1') -Force

function Get-LcmToolCatalogData {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string]$ToolsDir = 'D:\Git_Repositories\LCM_Inventory\tools'
  )

  $candidatePaths = @(
    'D:\Git_Repositories\LCM_Inventory\config\tool_catalog.json',
    'D:\Git_Repositories\LCM_Tools\tool_catalog.json'
  )
  $catalogPath = $null
  foreach ($c in $candidatePaths) {
    if (Test-Path -LiteralPath $c) {
      $catalogPath = $c
      break
    }
  }

  if (-not $catalogPath) {
    $updateCandidates = @(
      (Join-Path $ToolsDir 'Update-ToolCatalog.ps1'),
      'D:\Git_Repositories\LCM_Inventory\tools\Update-ToolCatalog.ps1',
      'D:\Git_Repositories\LCM_Tools\Update-ToolCatalog.ps1'
    )
    foreach ($u in $updateCandidates) {
      if (Test-Path -LiteralPath $u) {
        & $u -Silent
        break
      }
    }
    foreach ($c in $candidatePaths) {
      if (Test-Path -LiteralPath $c) {
        $catalogPath = $c
        break
      }
    }
  }

  if (-not $catalogPath) {
    throw "Catalog file not found in candidate paths: $($candidatePaths -join ', ')"
  }

  $rawJson = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8
  $catalog = $rawJson | ConvertFrom-Json
  return @{
    RawJson = $rawJson
    Catalog = $catalog
  }
}

function Measure-LcmToolCatalogMetrics {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [array]$Catalog
  )

  $totalCount = $Catalog.Count
  $userCount = @($Catalog | Where-Object { $_.Audience -eq 'User' }).Count
  $devCount = @($Catalog | Where-Object { $_.Audience -eq 'Developer' }).Count
  $adminCount = @($Catalog | Where-Object { $_.Admin -eq $true }).Count
  $noExitCount = @($Catalog | Where-Object { $_.NoExit -eq $true }).Count
  $invariantsCount = @($Catalog | Where-Object { $_.Role -in @('Invariants', 'SystemInvariants') }).Count
  $customizationsCount = @($Catalog | Where-Object { $_.Role -in @('Customization', 'SystemCustomization') }).Count
  $repairCount = @($Catalog | Where-Object { $_.Role -in @('Repair', 'SystemRepair') }).Count
  $haCount = @($Catalog | Where-Object { $_.Group -eq 'HaSSD06' -or ($_.Domain -and $_.Domain -like 'HaSSD06*') }).Count

  $distinctToolsList = [System.Collections.Generic.List[string]]::new()
  foreach ($item in $Catalog) {
    if (-not [string]::IsNullOrWhiteSpace($item.Name) -and -not $distinctToolsList.Contains($item.Name)) {
      $distinctToolsList.Add($item.Name)
    }
  }
  $distinctToolsList.Sort([System.StringComparer]::OrdinalIgnoreCase)
  $distinctTools = @($distinctToolsList)
  $distinctSubsystems = @('HaSSD06', 'LCM', 'LCM_AI', 'LCM_Inventory', 'SystemConfiguration') + @($Catalog | ForEach-Object {
    if ($_.PSObject.Properties['SubSystem']) { $_.SubSystem }
    elseif ($_.PSObject.Properties['Subsystem']) { $_.Subsystem }
    elseif ($_.PSObject.Properties['Group']) { $_.Group }
    else { $null }
  } | Where-Object { $_ -ne 'LCD' -and -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique) | Where-Object { $_ -ne 'LCD' } | Sort-Object -Unique
  $distinctGroups = $distinctSubsystems
  $distinctRoles = @($Catalog | ForEach-Object { $_.Role } | Sort-Object -Unique)
  $distinctCategories = @($Catalog | Where-Object { $_.Category } | ForEach-Object { $_.Category } | Sort-Object -Unique)
  $distinctEnvs = @($Catalog | ForEach-Object { [System.IO.Path]::GetExtension($_.Name).ToUpper().TrimStart('.') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

  return [PSCustomObject]@{
    Total          = $totalCount
    User           = $userCount
    Dev            = $devCount
    Admin          = $adminCount
    NoExit         = $noExitCount
    Invariants     = $invariantsCount
    Customizations = $customizationsCount
    Repair         = $repairCount
    HaCount        = $haCount
    DistinctTools      = $distinctTools
    DistinctSubsystems = $distinctSubsystems
    DistinctGroups     = $distinctSubsystems
    DistinctRoles      = $distinctRoles
    DistinctCategories = $distinctCategories
    DistinctEnvs   = $distinctEnvs
  }
}

function Format-LcmToolCatalogCli {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [array]$Catalog,
    [string]$Audience = 'User',
    [Alias('Group')]
    [string]$SubSystem = 'All',
    [string]$Role = 'All',
    [string]$Tool = 'All',
    [string]$Env = 'All',
    [string]$Filter = '',
    [string]$Timestamp = ''
  )

  if ([string]::IsNullOrWhiteSpace($Timestamp)) {
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  }

  $metrics = Measure-LcmToolCatalogMetrics -Catalog $Catalog

  Write-Host "====================================================================================================" -ForegroundColor Cyan
  Write-Host "  AUTHORITATIVE TOOL CATALOG - LCM WORKSPACE & SUBSYSTEMS (Generated: $Timestamp)" -ForegroundColor Cyan
  Write-Host "====================================================================================================" -ForegroundColor Cyan
  Write-Host "   Total: $($metrics.Total) | User: $($metrics.User) | Dev: $($metrics.Dev) | Admin: $($metrics.Admin) | NoExit: $($metrics.NoExit) | Invariants: $($metrics.Invariants) | Customizations: $($metrics.Customizations) | Repair: $($metrics.Repair)" -ForegroundColor DarkGray
  Write-Host ""

  $filtered = @($Catalog | Where-Object {
    $itemExt = [System.IO.Path]::GetExtension($_.Name).ToUpper().TrimStart('.')
    $itemSub = if ($_.PSObject.Properties['SubSystem']) { $_.SubSystem } elseif ($_.PSObject.Properties['Subsystem']) { $_.Subsystem } elseif ($_.PSObject.Properties['Group']) { $_.Group } else { '' }
    ($Audience -eq 'All' -or ($Audience -eq 'User' -and $_.Audience -eq 'User') -or ($Audience -eq 'Dev' -and $_.Audience -eq 'Developer')) -and
    ($SubSystem -eq 'All' -or $itemSub -eq $SubSystem) -and
    ($Tool -eq 'All' -or $_.Name -eq $Tool) -and
    ($Env -eq 'All' -or $itemExt -eq $Env.ToUpper()) -and
    ($Role -eq 'All' -or [string]::IsNullOrWhiteSpace($Role) -or $_.Role -eq $Role) -and
    ([string]::IsNullOrWhiteSpace($Filter) -or $_.Name -like "*$Filter*" -or $_.Description -like "*$Filter*" -or $_.Category -like "*$Filter*")
  })

  foreach ($t in $filtered) {
    $audBadge = if ($t.Audience -eq 'User') { "[User]" } else { "[Dev]" }
    $admBadge = if ($t.Admin) { "[Admin:Yes]" } else { "[Admin:No]" }
    $noExitBadge = if ($t.NoExit) { "[NoExit:🔴]" } else { "[NoExit:🟢]" }
    $envTag = [System.IO.Path]::GetExtension($t.Name).ToUpper().TrimStart('.')
    $subSystemVal = if ($t.PSObject.Properties['SubSystem']) { $t.SubSystem } elseif ($t.PSObject.Properties['Subsystem']) { $t.Subsystem } elseif ($t.PSObject.Properties['Group']) { $t.Group } else { '' }
    Write-Host "  $($t.Name) [$envTag] $($audBadge) $($admBadge) $($noExitBadge) [$subSystemVal] - $($t.Category)" -ForegroundColor Cyan
    Write-Host "    $($t.Description)" -ForegroundColor Gray
    Write-Host "    Run: $($t.Example)" -ForegroundColor DarkYellow
    Write-Host ""
  }
}

function Build-LcmToolIndexHtml {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RawJson,
    [Parameter(Mandatory = $true)]
    [array]$Catalog,
    [string]$WorkspaceRoot = 'D:\Git_Repositories',
    [string]$ToolsDir = 'D:\Git_Repositories\LCM_Inventory\tools',
    [string]$Audience = 'User',
    [Alias('Group')]
    [string]$SubSystem = 'All',
    [string]$Role = 'All',
    [string]$Tool = 'All',
    [string]$Env = 'All',
    [string]$Filter = '',
    [ValidatePattern('^v?\d+\.\d+\.\d+$')]
    [string]$Version
  )

  $provenance = Get-LcmDisplayProvenance -ScriptPath (Join-Path $ToolsDir 'Show-ToolsExplorer.ps1') -TemplatePath $PSCommandPath
  if ($Version -and "v$($Version.TrimStart('v'))" -ne $provenance.ToolVersion) {
    throw "Tool Explorer version '$Version' disagrees with constructing-script metadata '$($provenance.ToolVersion)'."
  }
  $displayVersion = $provenance.Label
  $metrics = Measure-LcmToolCatalogMetrics -Catalog $Catalog
  $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $computerName = $env:COMPUTERNAME

  $inventoryRoot = Join-Path $WorkspaceRoot 'LCM_Inventory'

  $stdCssUri = '/assets/StandardTableDisplay.css'
  $toolCssUri = '/assets/LCMToolCatalog.css'
  $printAtomUri = '/assets/lcm-table-print-atom.js'
  $tableEngineUri = '/assets/lcm-table-engine.js'
  $jsAppUri = '/assets/lcm-tool-explorer.js'

  # Compile authoritative dropdown options from catalog and persist to LCM_Inventory/config/tool_explorer_options.json
  $optionsPath = Join-Path $inventoryRoot 'config\tool_explorer_options.json'
  $optionsObj = [PSCustomObject]@{
    Subsystems = @($metrics.DistinctSubsystems)
    Categories = @($metrics.DistinctCategories)
  }
  $optionsJson = $optionsObj | ConvertTo-Json -Depth 5
  try {
    [System.IO.File]::WriteAllText($optionsPath, $optionsJson, [System.Text.Encoding]::UTF8)
  } catch {}

  $toolOptionsHtml = ($metrics.DistinctTools | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n"
  $subsystemOptionsHtml = ($metrics.DistinctSubsystems | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n"
  $groupOptionsHtml = $subsystemOptionsHtml
  $roleOptionsHtml = ($metrics.DistinctRoles | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n"
  $categoryOptionsHtml = ($metrics.DistinctCategories | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n"
  $envOptionsHtml = ($metrics.DistinctEnvs | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n"

  $configJson = [PSCustomObject]@{
    Audience  = $Audience
    Group     = $SubSystem
    SubSystem = $SubSystem
    Tool      = $Tool
    Env       = $Env
    Filter    = $Filter
    Version   = $displayVersion
    ToolVersion = $provenance.ToolVersion
    TemplateVersion = $provenance.TemplateVersion
  } | ConvertTo-Json -Compress
  $displayPayload = [PSCustomObject]@{
    tools = $RawJson | ConvertFrom-Json
    config = $configJson | ConvertFrom-Json
    options = $optionsJson | ConvertFrom-Json
  } | ConvertTo-Json -Depth 12 -Compress
  $displayPayload = $displayPayload.Replace('<', '\u003c')

  $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LCM Tool Explorer $displayVersion</title>
    <link rel="stylesheet" href="$stdCssUri">
    <link rel="stylesheet" href="$toolCssUri">
    <meta name="lcm-display-id" content="tools">
    <script src="/assets/lcm-display-freshness.js" defer></script>
    <style id="dynamic-print-style"></style>
</head>
<body>
    <!-- Hidden frame for seamless lcm:// protocol execution -->
    <iframe id="lcm-runner-frame" style="display: none;"></iframe>

    <div class="container">
        <!-- Main Top Bar -->
        <header>
            <div class="header-title">
                <h1>🛠️ LCM Tool Explorer <span style="font-size: 0.6em; color: var(--text-muted); vertical-align: middle;">$displayVersion</span></h1>
                <div class="header-meta">
                    <span>Generated:</span>
                    <span class="timestamp-badge">$timestamp</span>
                    <span>• Host:</span>
                    <strong style="color: var(--text-primary);">$computerName</strong>
                    <span>• Subsystem:</span>
                    <select class="subsystem-highlight-badge" id="header-subsystem-select" onchange="window.LcmTools.filterBySubsystem(this.value)" style="cursor: pointer; border: none; background: rgba(88, 166, 255, 0.15); border-radius: 4px;">
                        <option value="All">All</option>
                        $groupOptionsHtml
                    </select>
                </div>
            </div>
            <div class="header-actions" style="margin-left: auto; display: flex; align-items: center; gap: 8px;">
                <button class="btn-help-nav" onclick="window.LcmTools.openHelpModal()" title="Open UI Feature Guide, Icon Legend & Parameter Explanations" style="padding: 4px 10px; font-size: 11px; border-radius: 5px;">
                    <span>❓</span> <span>Help & Legend</span>
                </button>
                <button class="btn-back-nav" onclick="window.LcmTools.goBack()" title="Return to originating view (Windows-style Back)" style="padding: 4px 10px; font-size: 11px; border-radius: 5px;">
                    <span>⬅️</span> <span>Back</span>
                </button>
            </div>
        </header>

        <!-- Top Metric Summary Cards (Interactive Filters) -->
        <div class="metrics-grid">
            <div class="metric-card active" id="card-all" onclick="window.LcmTools.filterByCard('all')">
                <div class="metric-label" id="card-all-label">Total / Selected Tools</div>
                <div class="metric-value" id="card-all-value">$($metrics.Total) / $($metrics.Total)</div>
                <div class="metric-sub" id="card-all-sub">Active Selection</div>
            </div>
            <div class="metric-card" id="card-user" onclick="window.LcmTools.filterByCard('user')">
                <div class="metric-label">User Operations</div>
                <div class="metric-value">$($metrics.User)</div>
                <div class="metric-sub">Operator Tools</div>
            </div>
            <div class="metric-card" id="card-admin" onclick="window.LcmTools.filterByCard('admin')">
                <div class="metric-label">Admin Required</div>
                <div class="metric-value">$($metrics.Admin)</div>
                <div class="metric-sub">🛡️ Elevated</div>
            </div>
            <div class="metric-card" id="card-subsystem" onclick="void(0)" style="cursor: default;" title="Statistics for currently selected Subsystem">
                <div class="metric-label" id="card-subsystem-label">HaSSD06 Subsystem</div>
                <div class="metric-value" id="card-subsystem-value">$($metrics.HaCount)</div>
                <div class="metric-sub" id="card-subsystem-sub">Selected Subsystem</div>
            </div>
            <div class="metric-card" id="card-invariants" onclick="window.LcmTools.filterByCard('invariants')">
                <div class="metric-label">System Invariants</div>
                <div class="metric-value">$($metrics.Invariants)</div>
                <div class="metric-sub">Hardened Settings</div>
            </div>
            <div class="metric-card" id="card-customizations" onclick="window.LcmTools.filterByCard('customizations')">
                <div class="metric-label">Customizations</div>
                <div class="metric-value">$($metrics.Customizations)</div>
                <div class="metric-sub">UI &amp; Setup Tweaks</div>
            </div>
        </div>

        <!-- Aligned Column Controls Toolbar & Search -->
        <!-- Universal Toolbar & Filters Panel (Split into Two Clean Lines to Prevent Overflow) -->
        <div class="filter-panel-top" style="display: flex; flex-direction: column; gap: 8px; padding: 8px 12px;">
            <!-- Line 3A: Global Search Bar and Quick Utility Switches (Theme, Tool Intents, Refresh, Reset) -->
            <div style="display: flex; align-items: center; justify-content: space-between; gap: 8px; width: 100%; flex-wrap: wrap;">
                <div class="search-wrapper" style="flex: 1; min-width: 280px;">
                    <input type="text" class="search-input" id="search-input" placeholder="🔍 Global Search across all fields (support !term and !Col:Val negation)..." oninput="window.LcmTools.applyFilters()" style="padding: 6px 12px; height: 32px; font-size: 12px;">
                </div>
                <div style="display: flex; align-items: center; gap: 6px; flex-shrink: 0;">
                    <button class="btn-export" id="btn-theme-toggle" onclick="window.LcmTools.toggleTheme()" title="Toggle Light/Dark Theme" style="cursor: pointer; display: inline-flex; align-items: center; gap: 4px; padding: 4px 8px; font-size: 11px; font-weight: 600; border-radius: 5px; border: 1px solid var(--border); background: var(--bg-secondary); color: var(--text-primary); transition: all 0.2s;">
                        <span>🌓</span> <span>Theme</span>
                    </button>
                    <button class="btn-export" id="btn-show-intents" onclick="window.LcmTools.openToolIntents()" title="Open LCM Tool Intents Explorer (🎯 Intents)" style="cursor: pointer; display: inline-flex; align-items: center; gap: 4px; padding: 4px 8px; font-size: 11px; font-weight: 600; border-radius: 5px; border: 1px solid var(--border); background: var(--bg-secondary); color: var(--text-primary); transition: all 0.2s;">
                        <span>🎯</span> <span>Tool Intents</span>
                    </button>
                    <button class="btn-refresh" onclick="window.LcmTools.refreshToolCatalog()" title="Re-scan tools and regenerate catalog (🔄 Refresh)" style="padding: 4px 10px; font-size: 11px; border-radius: 5px;">
                        <span>🔄</span> <span>Refresh</span>
                    </button>
                    <button class="btn-reset" onclick="window.LcmTools.resetFilters()" style="display: inline-flex; align-items: center; gap: 4px; padding: 4px 8px; font-size: 11px; font-weight: 600;" title="Reset all search queries and column selectors">
                        <span style="font-size: 14px; line-height: 1;">↺</span> Reset Filters
                    </button>
                </div>
            </div>

            <!-- Line 3B: View, Filter & Presets Switches -->
            <div class="toolbar-actions" style="display: flex; align-items: center; gap: 8px; width: 100%; flex-wrap: wrap;">
                <div class="preset-control-wrapper" style="display: flex; align-items: center; gap: 4px;">
                    <label for="filter-presets-select" style="font-size: 11px; font-weight: 700; color: var(--text-primary); text-transform: none !important;">Presets:</label>
                    <select id="filter-presets-select" class="col-filter-select" onchange="window.LcmTools.applyPreset(this.value)" style="min-width: 170px; height: 28px; background: var(--bg-secondary); border: 1px solid var(--border); border-radius: 6px; color: var(--text-primary); font-size: 12px; padding: 2px 8px;">
                        <option value="">-- Presets --</option>
                        <optgroup label="Standard Presets">
                            <option value="preset_default">⭐ Default View</option>
                            <option value="preset_lcm_core">🏛️ LCM Core</option>
                            <option value="preset_general">🔧 General Tools (Not LCM)</option>
                            <option value="preset_no_sub_cmd">🚫 Exclude Subsystems & CMD</option>
                            <option value="preset_show_tools">📊 ShowTools</option>
                            <option value="preset_none">⚪ None (Clear All)</option>
                        </optgroup>
                        <optgroup label="Custom Presets" id="custom-presets-group">
                        </optgroup>
                    </select>
                    <button class="btn-action" id="btn-add-preset" onclick="window.LcmTools.addCustomPreset()" title="Save current filter configuration as a new custom preset" style="padding: 3px 8px; font-size: 11px; font-weight: 600; display: inline-flex; align-items: center; gap: 4px;"><span style="font-size: 14px; line-height: 1;">💾</span> Save</button>
                    <button class="btn-action" id="btn-replace-preset" onclick="window.LcmTools.replaceCustomPreset()" title="Replace selected custom preset with current filters" style="padding: 3px 8px; font-size: 11px; font-weight: 600; display: inline-flex; align-items: center; gap: 4px;"><span style="font-size: 14px; line-height: 1;">🔄</span> Replace</button>
                    <button class="btn-action" id="btn-delete-preset" onclick="window.LcmTools.deleteCustomPreset()" title="Delete selected custom preset" style="padding: 3px 8px; font-size: 11px; font-weight: 600; color: var(--danger); border-color: rgba(248,81,73,0.4); display: inline-flex; align-items: center; gap: 4px;"><span style="font-size: 14px; line-height: 1;">🗑️</span> Delete</button>
                </div>
                <button class="tab-btn" id="tab-view-mode" onclick="window.LcmTools.toggleViewMode()" style="font-weight: 700; display: inline-flex; align-items: center; gap: 4px; font-size: 11px; padding: 3px 8px; white-space: nowrap;" title="Switch column display between Short-Names and Source Code"><span style="font-size: 14px; line-height: 1;">💬</span> Mode: Short</button>
                <button class="btn-export" onclick="LcmTablePrintAtom.openModal()" style="display: inline-flex; align-items: center; gap: 4px; font-size: 11px; font-weight: 600; padding: 3px 8px;" title="Open print and PDF document generator"><span style="font-size: 14px; line-height: 1;">🖨️</span> Print / PDF</button>
                <button class="tab-btn" id="btn-show-tools-filter" onclick="window.LcmTools.toggleShowFilter()" style="display: inline-flex; align-items: center; gap: 4px; font-size: 11px; font-weight: 700; padding: 3px 8px;" title="Filter to ShowTools standard displays"><span style="font-size: 14px; line-height: 1;">📊</span> ShowTools</button>
                <button class="tab-btn" id="btn-internal-filter" onclick="window.LcmTools.toggleInternalFilter()" style="display: inline-flex; align-items: center; gap: 4px; font-size: 11px; font-weight: 700; padding: 3px 8px;" title="Toggle Internal tools inclusion in view"><span style="font-size: 14px; line-height: 1;">🔒</span> Intern</button>
                <button class="btn-action" id="btn-mass-edit" onclick="window.LcmTools.openMassEditModal()" style="display: inline-flex; align-items: center; gap: 4px; padding: 3px 8px; font-size: 11px; font-weight: 600;" title="Mass assign / rename dropdown column values for currently visible filtered tools"><span style="font-size: 14px; line-height: 1;">⚡</span> Bulk Assign</button>
            </div>
        </div>

        <!-- Data Table with Column Filters Aligned Directly Above Columns -->
        <div class="table-container" style="flex: 1 1 auto; min-height: 0; overflow-y: auto !important; overflow-x: auto !important; width: 100%;">
            <!-- Dynamic Print Header for Paper & PDF Output -->
            <div class="print-header" id="print-header-block">
                <div style="display: grid; grid-template-columns: 1fr auto 1fr; align-items: baseline; border-bottom: 2px solid #222; padding-bottom: 5px; margin-bottom: 6px;">
                    <div style="font-size: 13pt; font-weight: 800; color: #000;" id="print-header-title">🛠️ LCM Tool Explorer</div>
                    <div style="font-size: 10pt; font-weight: 700; color: #333; text-align: center;" id="print-header-mode">User Tools</div>
                    <div style="font-size: 8.5pt; font-family: monospace; color: #444; text-align: right;" id="print-header-file">SHOW_TOOLS.html</div>
                </div>
            </div>

            <table style="min-width: 1280px; width: 100%;">
                <thead>
                    <!-- Titles Row -->
                    <tr>
                        <th onclick="window.LcmTools.sortTable('Index')" style="width: 45px; text-align: center;" title="Persistent sequential tool index (001-max)"># <span class="sort-icon">⇅</span></th>
                        <th onclick="window.LcmTools.sortTable('Name')" style="min-width: 220px;" id="th-tool-name">Tool Name <span class="sort-icon">⇅</span></th>
                        <th style="width: 160px; text-align: center;">Actions & Modes</th>
                        <th onclick="window.LcmTools.sortTable('SubSystem')" style="width: 80px; min-width: 80px;" id="th-col-subsystem">SubSystem <span class="sort-icon">⇅</span></th>
                        <th onclick="window.LcmTools.sortTable('Description')">Description <span class="sort-icon">⇅</span></th>
                        <th onclick="window.LcmTools.sortTable('Category')" style="width: 95px; min-width: 95px;" id="th-col-category">Category <span class="sort-icon">⇅</span></th>
                        <th onclick="window.LcmTools.sortTable('Audience')" style="width: 100px;" id="th-col-audience">Audience <span class="sort-icon">⇅</span></th>
                        <th onclick="window.LcmTools.sortTable('Env')" style="width: 75px; text-align: center;">Env. <span class="sort-icon">⇅</span></th>
                        <th onclick="window.LcmTools.sortTable('Admin')" style="width: 100px;">Admin <span class="sort-icon">⇅</span></th>
                        <th onclick="window.LcmTools.sortTable('NoExit')" style="width: 95px; text-align: center;" title="Keep console window open after completion (🔴 NoExit = stay open, 🟢 May Exit = auto-close)">NoExit <span class="sort-icon">⇅</span></th>
                    </tr>
                    <!-- Aligned Column Selectors Row -->
                    <tr class="col-filter-row">
                        <th style="text-align: center; font-size: 11px; font-weight: 700; color: var(--text-primary);">#</th>
                        <th>
                            <select class="col-filter-select" id="tool-select" onchange="window.LcmTools.applyFilters()">
                                <option value="All">All Tools</option>
                                $toolOptionsHtml
                            </select>
                        </th>
                        <th style="text-align: center;">
                            <div style="display: flex; gap: 4px; justify-content: center; align-items: center;">
                                <button class="col-filter-reset-btn" onclick="window.LcmTools.resetColumnFilters()" title="Reset All Column Selectors" style="background: #0d1117 !important; color: #f85149 !important; border: 1px solid rgba(248, 81, 73, 0.4) !important; font-size: 11px; padding: 2px 6px; font-weight: 700;">↺ Reset</button>
                                <button class="btn-action" id="btn-set-all" onclick="window.LcmTools.finalizeAllBlocked()" title="Finalize and unblock all pending tools across table" style="background: #0d1117 !important; color: #3fb950 !important; border: 1px solid rgba(63, 185, 80, 0.4) !important; font-size: 11px; padding: 2px 6px; font-weight: 700;">SetAll</button>
                            </div>
                        </th>
                        <th>
                            <select class="col-filter-select" id="subsystem-select" onchange="window.LcmTools.handleSelectFilterChange('Subsystems', this)">
                                <option value="All">All SubSystems</option>
                                $subsystemOptionsHtml
                                <option value="__NEW__" style="color: #58a6ff; font-weight: 700;">+ New...</option>
                            </select>
                        </th>
                        <th>
                            <input type="text" class="col-filter-input" id="desc-filter" placeholder="Filter descriptions..." oninput="window.LcmTools.applyFilters()" style="width: 100%; height: 26px; font-size: 11px; background: var(--bg-secondary); border: 1px solid var(--border); border-radius: 4px; padding: 2px 6px; color: var(--text-primary);">
                        </th>
                        <th>
                            <select class="col-filter-select" id="category-select" onchange="window.LcmTools.handleSelectFilterChange('Categories', this)">
                                <option value="All">All Categories</option>
                                $categoryOptionsHtml
                                <option value="__NEW__" style="color: #58a6ff; font-weight: 700;">+ New...</option>
                            </select>
                        </th>
                        <th>
                            <select class="col-filter-select" id="audience-select" onchange="window.LcmTools.applyFilters()">
                                <option value="All">All Audiences</option>
                                <option value="User">User</option>
                                <option value="Developer">Developer</option>
                                <option value="Internal">Internal</option>
                            </select>
                        </th>
                        <th>
                            <select class="col-filter-select" id="env-select" onchange="window.LcmTools.applyFilters()">
                                <option value="All">All Envs</option>
                                $envOptionsHtml
                            </select>
                        </th>
                        <th>
                            <select class="col-filter-select" id="admin-select" onchange="window.LcmTools.applyFilters()">
                                <option value="All">All Privileges</option>
                                <option value="true">Admin Required</option>
                                <option value="false">Standard User</option>
                            </select>
                        </th>
                        <th>
                            <select class="col-filter-select" id="noexit-select" onchange="window.LcmTools.applyFilters()">
                                <option value="All">All States</option>
                                <option value="true">🔴 NoExit</option>
                                <option value="false">🟢 May Exit</option>
                            </select>
                        </th>
                    </tr>
                </thead>
                <tbody id="tools-tbody">
                    <!-- Populated dynamically by JavaScript -->
                </tbody>
            </table>
            <!-- Dynamic Print Footer for Paper & PDF Output -->
            <div class="print-footer" id="print-footer-block">
                <div style="display: grid; grid-template-columns: 1fr auto 1fr; align-items: center; border-top: 1px solid #666; padding-top: 4px; margin-top: 8px; font-size: 8pt; color: #444;">
                    <div style="text-align: left;" id="print-footer-date">$timestamp</div>
                    <div style="text-align: center; font-weight: 600;" id="print-footer-subsystem">LCM</div>
                    <div style="text-align: right; font-family: monospace; font-weight: 600;" id="print-footer-page">1 / 1</div>
                </div>
            </div>
        </div>
    </div>

    <!-- Inline Cell Editor Popover -->
    <div class="editor-popover" id="cell-editor">
        <div id="editor-control-container"></div>
        <div class="editor-actions">
            <button class="btn-action" onclick="window.LcmTools.saveCellEdit()">✓ Save</button>
            <button class="btn-action" onclick="window.LcmTools.closeCellEditor()">&times; Cancel</button>
        </div>
    </div>

    <!-- Multi-Action Dropdown Menu (Floating singleton) -->
    <div class="action-dropdown-menu" id="action-dropdown-menu">
        <div class="menu-section-header">Standard Actions</div>
        <button class="menu-item" onclick="window.LcmTools.menuAction('tool_help')">❓ <strong>Tool Help</strong> (-h in Notepad)</button>
        <button class="menu-item" onclick="window.LcmTools.menuAction('copy')">📋 <strong>Copy</strong> CLI Command</button>
        <button class="menu-item" onclick="window.LcmTools.menuAction('inspect')">🔍 <strong>Inspect</strong> Details & Deps</button>
        <div class="menu-divider"></div>

        <div class="menu-section-header">Privileged (Admins Only)</div>
        <button class="menu-item" onclick="window.LcmTools.menuAction('edit')">💻 <strong>Show / Edit Code</strong> (IDE)</button>
        <button class="menu-item" onclick="window.LcmTools.menuAction('rename')">✏️ <strong>Rename</strong> Tool & Alias...</button>
        <button class="menu-item" onclick="window.LcmTools.menuAction('cleanup')">🧹 <strong>Cleanup</strong> Logs & History...</button>
        <button class="menu-item danger" onclick="window.LcmTools.menuAction('archive')">📦 <strong>Archive</strong> Tool</button>
        <button class="menu-item danger" onclick="window.LcmTools.menuAction('delete')">🗑️ <strong>Delete</strong> Tool</button>
    </div>

    <!-- Multi-Target Cleanup Modal -->
    <div class="modal-overlay" id="cleanup-modal-overlay" onclick="window.LcmTools.closeCleanupModal(event)">
        <div class="modal-card" onclick="event.stopPropagation()" style="max-width: 550px;">
            <div class="modal-header">
                <div class="modal-title" id="cleanup-modal-title">🧹 Cleanup Tool Artifacts</div>
                <button class="modal-close" onclick="window.LcmTools.closeCleanupModal()">&times;</button>
            </div>
            <div style="font-size: 13px; color: var(--text-secondary); margin-bottom: 14px;" id="cleanup-modal-subtitle">
                Select which artifact caches to purge:
            </div>
            <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px; margin-bottom: 16px;">
                <label style="display: flex; align-items: flex-start; gap: 10px; margin-bottom: 14px; cursor: pointer;">
                    <input type="checkbox" id="cleanup-chk-logs" checked style="margin-top: 3px; cursor: pointer;">
                    <div>
                        <strong style="color: var(--text-primary); font-size: 13px;">Tool Audit Logs</strong>
                        <div style="font-size: 11px; color: var(--text-secondary);" id="cleanup-logs-info">Querying tools/logs/...</div>
                    </div>
                </label>
                <label style="display: flex; align-items: flex-start; gap: 10px; cursor: pointer;">
                    <input type="checkbox" id="cleanup-chk-archive" checked style="margin-top: 3px; cursor: pointer;">
                    <div>
                        <strong style="color: var(--text-primary); font-size: 13px;">Archived Tool Snapshots</strong>
                        <div style="font-size: 11px; color: var(--text-secondary);" id="cleanup-archive-info">Querying retired tool snapshots...</div>
                    </div>
                </label>
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 10px;">
                <button class="btn-reset" onclick="window.LcmTools.closeCleanupModal()">Cancel</button>
                <button class="btn-action" style="background: var(--danger); border-color: var(--danger); color: white;" onclick="window.LcmTools.executeCleanup()">🗑️ Purge Selected</button>
            </div>
        </div>
    </div>

    <!-- Dual-Field Rename Modal -->
    <div class="modal-overlay" id="rename-modal-overlay" onclick="window.LcmTools.closeRenameModal(event)">
        <div class="modal-card" onclick="event.stopPropagation()" style="max-width: 600px;">
            <div class="modal-header">
                <div class="modal-title" id="rename-modal-title">✏️ Rename Tool & Command Alias</div>
                <button class="modal-close" onclick="window.LcmTools.closeRenameModal()">&times;</button>
            </div>
            <div style="font-size: 13px; color: var(--text-secondary); margin-bottom: 14px;">
                Update canonical source filename and/or short-name command launcher:
            </div>
            <div style="margin-bottom: 14px;">
                <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); display: block; margin-bottom: 4px;">1. Canonical Source File Name (.ps1 / .py)</label>
                <input type="text" id="rename-input-source" style="width: 100%; background: var(--bg-primary); border: 1px solid var(--border); border-radius: 6px; padding: 8px 12px; color: var(--text-primary); font-family: 'JetBrains Mono', monospace; font-size: 12px;">
            </div>
            <div style="margin-bottom: 14px;">
                <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--accent); display: block; margin-bottom: 4px;">2. Primary Short-Name Command (LCM_Inventory/DoT/&lt;ShortName&gt;.cmd)</label>
                <input type="text" id="rename-input-short" style="width: 100%; background: var(--bg-primary); border: 1px solid var(--border); border-radius: 6px; padding: 8px 12px; color: #7ee787; font-family: 'JetBrains Mono', monospace; font-size: 12px;">
            </div>
            <div style="margin-bottom: 16px; padding: 12px; background: var(--bg-secondary); border: 1px solid var(--border); border-radius: 6px;">
                <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); display: block; margin-bottom: 6px;">3. Additional Command Aliases</label>
                <div id="rename-aliases-tags" style="display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; min-height: 24px;"></div>
                <div style="display: flex; gap: 8px; align-items: center;">
                    <input type="text" id="rename-new-alias-input" placeholder="Add new alias (e.g. BCR)..." style="flex: 1; background: var(--bg-primary); border: 1px solid var(--border); border-radius: 4px; padding: 6px 10px; color: var(--text-primary); font-family: 'JetBrains Mono', monospace; font-size: 11px;" onkeydown="if(event.key==='Enter'){event.preventDefault();window.LcmTools.addModalAlias();}">
                    <button type="button" class="btn-action" onclick="window.LcmTools.addModalAlias()" style="padding: 4px 10px; font-size: 11px; font-weight: 600;">+ Add</button>
                </div>
                <div style="font-size: 10.5px; color: var(--text-muted); margin-top: 6px;">Each alias generates an active .cmd launcher. Click &times; to remove an alias.</div>
            </div>
            <div style="display: flex; justify-content: flex-end; align-items: center; gap: 10px;">
                <button class="btn-reset" onclick="window.LcmTools.closeRenameModal()">Cancel</button>
                <button class="btn-action btn-run-action" id="btn-save-rename" onclick="window.LcmTools.executeRename()">✓ Save & Rename</button>
            </div>
        </div>
    </div>

    <!-- Modal Drawer for Bulk Column Assignment / Mass Rename -->
    <div class="modal-overlay" id="mass-edit-modal-overlay" onclick="window.LcmTools.closeMassEditModal(event)">
        <div class="modal-card" onclick="event.stopPropagation()" style="max-width: 550px;">
            <div class="modal-header">
                <div class="modal-title">⚡ Bulk Column Assignment</div>
                <button class="modal-close" onclick="window.LcmTools.closeMassEditModal()">&times;</button>
            </div>
            <div style="font-size: 13px; color: var(--text-secondary); margin-bottom: 14px;">
                Apply column modifications to all <strong id="mass-edit-count" style="color: var(--accent);">0</strong> currently filtered/visible tools:
            </div>
            <div style="margin-bottom: 14px;">
                <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); display: block; margin-bottom: 4px;">Target Column</label>
                <select id="mass-edit-col" class="col-filter-select" style="width: 100%; height: 32px; font-size: 12px;" onchange="window.LcmTools.updateMassEditOptions()">
                    <option value="SubSystem">SubSystem</option>
                    <option value="Category">Category</option>
                    <option value="Audience">Audience</option>
                </select>
            </div>
            <div style="margin-bottom: 14px;">
                <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); display: block; margin-bottom: 4px;">Mode</label>
                <div style="display: flex; gap: 14px; font-size: 12px; color: var(--text-primary); margin-bottom: 8px;">
                    <label style="display: flex; align-items: center; gap: 6px; cursor: pointer;">
                        <input type="radio" name="mass-edit-mode" value="set" checked onchange="window.LcmTools.toggleMassEditMode()"> Set All to Value
                    </label>
                    <label style="display: flex; align-items: center; gap: 6px; cursor: pointer;">
                        <input type="radio" name="mass-edit-mode" value="replace" onchange="window.LcmTools.toggleMassEditMode()"> Find &amp; Replace (Pattern)
                    </label>
                </div>
            </div>
            <!-- Set Mode Container -->
            <div id="mass-edit-set-container" style="margin-bottom: 14px;">
                <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); display: block; margin-bottom: 4px;">New Value</label>
                <div style="display: flex; gap: 8px;">
                    <select id="mass-edit-val-select" class="col-filter-select" style="flex: 1; height: 32px; font-size: 12px;" onchange="window.LcmTools.handleMassEditSelectChange(this)"></select>
                    <input type="text" id="mass-edit-val-custom" placeholder="Or enter custom value..." style="flex: 1; display: none; background: var(--bg-primary); border: 1px solid var(--border); border-radius: 6px; padding: 6px 10px; color: var(--text-primary); font-size: 12px;">
                </div>
            </div>
            <!-- Replace Mode Container -->
            <div id="mass-edit-replace-container" style="margin-bottom: 14px; display: none;">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                    <div>
                        <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); display: block; margin-bottom: 4px;">Match Pattern</label>
                        <input type="text" id="mass-edit-find" placeholder="e.g. Workspace* or System Customization" style="width: 100%; background: var(--bg-primary); border: 1px solid var(--border); border-radius: 6px; padding: 6px 10px; color: var(--text-primary); font-size: 12px;">
                    </div>
                    <div>
                        <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); display: block; margin-bottom: 4px;">Replace With</label>
                        <input type="text" id="mass-edit-replace" placeholder="e.g. LCD or PC Cust." style="width: 100%; background: var(--bg-primary); border: 1px solid var(--border); border-radius: 6px; padding: 6px 10px; color: var(--text-primary); font-size: 12px;">
                    </div>
                </div>
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 18px;">
                <button class="btn-reset" onclick="window.LcmTools.closeMassEditModal()">Cancel</button>
                <button class="btn-action btn-run-action" onclick="window.LcmTools.executeMassEdit()" style="padding: 6px 16px; font-weight: 700;">✓ Apply Bulk Edit</button>
            </div>
        </div>
    </div>

    <!-- Modal Drawer for Run & Two-Column Parameter Help Panel -->
    <div class="modal-overlay" id="run-modal-overlay" onclick="window.LcmTools.closeRunModal(event)">
        <div class="modal-card" onclick="event.stopPropagation()" style="max-width: 1000px; width: 94%;">
            <div class="modal-header">
                <div class="modal-title" id="run-modal-title">▶ Run Tool & Configure Parameters</div>
                <button class="modal-close" onclick="window.LcmTools.closeRunModal()">&times;</button>
            </div>
            
            <div style="display: grid; grid-template-columns: 1.1fr 0.9fr; gap: 20px; margin-top: 10px;">
                <!-- Left Column: Interactive Parameters Form -->
                <div>
                    <div id="run-modal-desc" style="font-size: 13px; color: var(--text-secondary); margin-bottom: 14px;"></div>

                    <!-- Dynamic Parameter Inputs -->
                    <div id="run-param-container" style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px; margin-bottom: 14px; display: none;">
                        <div style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); margin-bottom: 10px;">Explicit Named Parameters</div>
                        <div id="run-param-fields-list"></div>
                    </div>

                    <!-- Command Line Preview Box -->
                    <div style="margin-bottom: 8px;">
                        <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary);">Command Line Preview / Custom Arguments</label>
                            <span id="run-char-count" style="font-size: 11px; color: var(--text-secondary);"></span>
                        </div>
                        <textarea id="run-cmd-input" style="width: 100%; background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 10px 12px; font-family: 'JetBrains Mono', monospace; font-size: 12px; color: #7ee787; outline: none; resize: vertical; min-height: 55px;" oninput="window.LcmTools.validateRunCommand()"></textarea>
                    </div>

                    <!-- Validation Error Alert -->
                    <div id="run-validation-error" style="color: var(--danger); background: rgba(248, 81, 73, 0.1); border: 1px solid rgba(248, 81, 73, 0.3); border-radius: 6px; padding: 8px 12px; font-size: 12px; margin-top: 10px; display: none;"></div>

                    <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 18px;">
                        <button class="btn-reset" onclick="window.LcmTools.closeRunModal()">Cancel</button>
                        <button class="btn-action btn-run-action" id="btn-run-execute" onclick="window.LcmTools.executeConfiguredTool()" style="padding: 8px 18px; font-weight: 700;">⚡ Dispatch Execution</button>
                    </div>
                </div>

                <!-- Right Column: Dedicated Parameter Documentation & Context Panel -->
                <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px; display: flex; flex-direction: column; max-height: 520px; overflow-y: auto;">
                    <div style="display: flex; align-items: center; gap: 6px; margin-bottom: 12px; border-bottom: 1px solid var(--border); padding-bottom: 8px;">
                        <span style="font-size: 16px;">📖</span>
                        <span style="font-size: 12px; font-weight: 700; text-transform: uppercase; color: var(--text-primary);">Parameter & Tool Documentation</span>
                    </div>

                    <div id="run-help-active-param" style="margin-bottom: 14px;">
                        <div style="font-size: 11px; font-weight: 600; color: var(--text-secondary); margin-bottom: 4px;">FOCUSED PARAMETER HELP</div>
                        <div id="run-help-param-body" style="font-size: 12px; line-height: 1.5; color: var(--text-primary); background: rgba(88, 166, 255, 0.08); border-left: 3px solid var(--accent); padding: 8px 12px; border-radius: 0 6px 6px 0;">
                            Focus or hover any parameter input on the left to inspect its complete description, expected type, and CLI flags.
                        </div>
                    </div>

                    <div style="font-size: 11px; font-weight: 600; color: var(--text-secondary); margin-bottom: 6px;">ALL PARAMETERS REFERENCE</div>
                    <div id="run-help-all-params-list" style="font-size: 12px; line-height: 1.4; color: var(--text-secondary);">
                        <!-- Rendered by JS -->
                    </div>

                    <div style="margin-top: auto; padding-top: 12px; border-top: 1px solid var(--border);">
                        <div style="font-size: 11px; font-weight: 600; color: var(--text-secondary); margin-bottom: 4px;">EXAMPLE EXECUTION SYNTAX</div>
                        <div id="run-help-example-box" style="font-family: 'JetBrains Mono', monospace; font-size: 11px; color: #7ee787; background: #0d1117; padding: 8px 10px; border-radius: 6px; word-break: break-all;"></div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Modal Drawer for Inspection -->
    <div class="modal-overlay" id="modal-overlay" onclick="window.LcmTools.closeModal(event)">
        <div class="modal-card" onclick="event.stopPropagation()">
            <div class="modal-header">
                <div class="modal-title" id="modal-title">Tool Inspection</div>
                <button class="modal-close" onclick="window.LcmTools.closeModal()">&times;</button>
            </div>
            <div class="modal-row">
                <div class="modal-label">Execution Command</div>
                <div class="code-block" id="modal-example"></div>
            </div>
            <div class="modal-row">
                <div class="modal-label">Interactive Dispatcher Command (Session 1)</div>
                <div class="code-block" id="modal-dispatch-cmd"></div>
            </div>
            <div class="modal-row">
                <div class="modal-label">Relative Path & Group</div>
                <div class="modal-val" id="modal-path"></div>
            </div>
            <div class="modal-row">
                <div class="modal-label">Category, Audience & Privilege</div>
                <div class="modal-val" id="modal-role-cat"></div>
            </div>
            <div class="modal-row">
                <div class="modal-label">Prerequisites & AST Dependencies</div>
                <div class="modal-val" id="modal-deps"></div>
            </div>
            <div class="modal-row">
                <div class="modal-label">Description</div>
                <div class="modal-val" id="modal-desc"></div>
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
                <button class="btn-refresh" onclick="window.LcmTools.runModalTool()">⚡ Run Tool Now</button>
                <button class="btn-export" onclick="window.LcmTools.copyModalCommand()">📋 Copy Command</button>
            </div>
        </div>
    </div>

    <!-- Global Help & Legend Modal (Draggable & Non-Blocking) -->
    <div class="modal-overlay" id="help-modal-overlay" style="background: rgba(0, 0, 0, 0.35); backdrop-filter: blur(2px);" onclick="window.LcmTools.closeHelpModal(event)">
        <div class="modal-card" id="help-modal-card" onclick="event.stopPropagation()" style="max-width: 920px; width: 92%; max-height: 85vh; overflow-y: auto; box-shadow: 0 16px 48px rgba(0,0,0,0.7); border: 1px solid var(--border);">
            <div class="modal-header" id="help-modal-header" style="cursor: grab; user-select: none;" title="Click and drag to move this window">
                <div class="modal-title" style="display: flex; align-items: center; gap: 8px;">
                    <span>❓ LCM Tool Explorer: Feature Guide & Icon Legend</span>
                    <span style="font-size: 11px; font-weight: normal; color: var(--text-muted);">(🖐️ Drag header to move)</span>
                </div>
                <button class="modal-close" onclick="window.LcmTools.closeHelpModal()">&times;</button>
            </div>

            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-top: 12px;">
                <!-- Section 1: Badges & Status Icons -->
                <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px;">
                    <div style="font-size: 12px; font-weight: 700; color: var(--accent); margin-bottom: 10px; text-transform: uppercase;">🏷️ Status Badges & Execution Modes</div>
                    <div style="display: flex; flex-direction: column; gap: 10px; font-size: 12px;">
                        <div>
                            <span class="badge badge-noexit-true" style="margin-right: 6px;">🔴 NoExit</span>
                            <strong>Keep Console Open:</strong> Window remains open after script completes so you can review diagnostic output, logs, or error codes.
                        </div>
                        <div>
                            <span class="badge badge-noexit-false" style="margin-right: 6px;">🟢 May Exit</span>
                            <strong>Auto-Close:</strong> Console window closes automatically upon successful completion (ideal for silent background tasks).
                        </div>
                        <div>
                            <span class="badge badge-admin" style="margin-right: 6px;">🛡️ Elevated Admin</span>
                            <strong>Administrator Required:</strong> Requires elevated Windows privileges (UAC prompt / RunAs Administrator).
                        </div>
                        <div>
                            <span class="badge badge-user" style="margin-right: 6px;">👤 User Operation</span>
                            <strong>Standard Operator Tool:</strong> Safe for direct human operator execution in standard user context.
                        </div>
                        <div>
                            <span class="badge badge-dev" style="margin-right: 6px;">⚙️ Developer / Plumbing</span>
                            <strong>Subsystem Developer Tool:</strong> Automation building blocks, AST linters, and governance modules.
                        </div>
                        <div>
                            <span class="badge badge-internal" style="background: #8957e5; color: #fff; font-weight: 600; padding: 2px 6px; border-radius: 4px; margin-right: 6px;">🔒 Internal</span>
                            <strong>Diagnostic / Subsystem Internal:</strong> Diagnostic tools toggled via the <code>Int.</code> toolbar button.
                        </div>
                    </div>
                </div>

                <!-- Section 2: Actions & Buttons -->
                <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px;">
                    <div style="font-size: 12px; font-weight: 700; color: var(--accent); margin-bottom: 10px; text-transform: uppercase;">⚡ Actions & Interactive Controls</div>
                    <div style="display: flex; flex-direction: column; gap: 10px; font-size: 12px;">
                        <div>
                            <span class="btn-action btn-run-action" style="padding: 2px 8px; margin-right: 6px; display: inline-block;">⚡ Run</span>
                            <strong>Instant Desktop Launch:</strong> Dispatches execution to your physical desktop (Session 1) via the local Port 9876 REST daemon in &lt;5ms.
                        </div>
                        <div>
                            <span class="btn-action" style="padding: 2px 8px; margin-right: 6px; display: inline-block;">⚡ Bulk Assign</span>
                            <strong>Mass Column Assignment:</strong> Mass assign or pattern-replace values (Group, Role, Category, Audience) across filtered tools.
                        </div>
                        <div>
                            <span class="btn-action btn-inspect" style="padding: 2px 8px; margin-right: 6px; display: inline-block;">🔍 Inspect</span>
                            <strong>Deep Inspection Drawer:</strong> Opens detailed view with parameters, script paths, and direct launcher commands.
                        </div>
                        <div>
                            <span class="tab-btn" style="padding: 2px 8px; margin-right: 6px; display: inline-block;">💬 Chat Short-Names</span>
                            <strong>Aliases &amp; ShortNames:</strong> Displays clean conversational names with multiple stacked command aliases.
                        </div>
                    </div>
                </div>

                <!-- Section 3: Search, Filters & Sorting -->
                <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px;">
                    <div style="font-size: 12px; font-weight: 700; color: var(--accent); margin-bottom: 10px; text-transform: uppercase;">🔍 Search, Negation & Multi-Sorting</div>
                    <div style="display: flex; flex-direction: column; gap: 8px; font-size: 12px;">
                        <div><strong>Global Filter:</strong> Searches across tool names, descriptions, groups, roles, and categories simultaneously.</div>
                        <div><strong>Negation Filtering:</strong> Type <code>!term</code> (e.g. <code>!hass</code> or <code>!python</code>) to invert search and exclude specific matches.</div>
                        <div><strong>Column Sorting:</strong> Click any table header with <span class="sort-icon">⇅</span> to toggle Ascending / Descending sort order.</div>
                        <div><strong>Dropdown Selectors:</strong> Dedicated dropdown filters aligned directly above every table column.</div>
                    </div>
                </div>

                <!-- Section 4: Live Editing & Auto-Sync Defeat Switch -->
                <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px;">
                    <div style="font-size: 12px; font-weight: 700; color: var(--accent); margin-bottom: 10px; text-transform: uppercase;">⚙️ Inline Editing & Auto-Sync Defeat Switch</div>
                    <div style="display: flex; flex-direction: column; gap: 8px; font-size: 12px;">
                        <div><strong>Live Cell Editing:</strong> Click directly on any <em>Role</em>, <em>Audience</em>, <em>Admin</em>, <em>Category</em>, or <em>Description</em> cell in the table to modify its value inline.</div>
                        <div><strong>NoExit One-Click Toggle:</strong> Click the 🔴/🟢 NoExit badge to instantly flip keep-open state across all environment variants.</div>
                        <div><strong>Auto-Sync Edits (Defeat Switch):</strong> When checked, closing the browser tab automatically sends all edited metadata back to the workspace on Port 9876 with an atomic backup. Uncheck to run 100% sandboxed in browser memory.</div>
                    </div>
                </div>

                <!-- Section 5: Export Overrides & LocalStorage Cache (CRM 5) -->
                <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px; grid-column: span 2;">
                    <div style="font-size: 12px; font-weight: 700; color: var(--accent); margin-bottom: 8px; text-transform: uppercase;">💾 Export Overrides & Persistence Engine</div>
                    <div style="display: flex; flex-direction: column; gap: 8px; font-size: 12px; line-height: 1.5;">
                        <div><strong>Client-Side Override Cache:</strong> Any edits made to tool properties (NoExit 🔴/🟢, Role badges, Audience, Categories, Descriptions) are immediately saved in your browser's persistent <code>localStorage</code> cache so they survive page reloads.</div>
                        <div><strong>💾 Export Overrides Button:</strong> Generates and copies the full JSON dictionary of your custom client-side overrides directly to the Windows Clipboard so you can inspect, back up, or incorporate them into <code>tool_catalog.json</code>.</div>
                    </div>
                </div>
            </div>

            <div style="display: flex; justify-content: flex-start; align-items: center; margin-top: 16px;">
                <span style="font-size: 11px; color: var(--text-muted);">Tip: Drag this dialog by the header to position it anywhere while inspecting the table. Press Esc to exit.</span>
            </div>
        </div>
    </div>

    <!-- Execution Feedback Drawer (CRP-309 WP4) -->
    <div class="execution-feedback-drawer collapsed" id="executionFeedbackDrawer">
        <div class="execution-feedback-header" onclick="window.LcmTools.toggleExecutionDrawer(event)">
            <span class="drawer-title">⚡ Execution Output</span>
            <div class="drawer-badges">
                <span id="drawerExitBadge" class="drawer-badge badge-neutral">Ready</span>
                <span id="drawerTargetBadge" class="drawer-target"></span>
                <span id="drawerDurationBadge" class="drawer-duration"></span>
            </div>
            <div class="drawer-actions" onclick="event.stopPropagation()">
                <button class="drawer-btn" onclick="window.LcmTools.copyDrawerOutput()" title="Copy output to clipboard">📋 Copy</button>
                <button class="drawer-btn" onclick="window.LcmTools.clearDrawerOutput()" title="Clear terminal output">🧹 Clear</button>
                <button class="drawer-btn" id="drawerToggleBtn" onclick="window.LcmTools.toggleExecutionDrawer(event)">▲ Expand</button>
            </div>
        </div>
        <pre class="execution-feedback-body" id="executionFeedbackBody">Ready. Executed actions, tests, and tool commands stream output here.</pre>
    </div>

    <!-- Toast Notification -->
    <div class="toast" id="toast">✓ Action completed!</div>

    <script id="lcm-display-data" type="application/json">$displayPayload</script>
    <script src="$printAtomUri"></script>
    <script src="$tableEngineUri"></script>
    <script src="$jsAppUri"></script>
</body>
</html>
"@

  # Persist the generated revision inside this repository; browsers use only the daemon route.
  $artifactsDir = Join-Path $inventoryRoot 'data\artifacts'
  if (-not (Test-Path -LiteralPath $artifactsDir)) { New-Item -ItemType Directory -Force -Path $artifactsDir | Out-Null }
  $htmlPath = Join-Path $artifactsDir 'SHOW_TOOLS.html'
  [System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.UTF8Encoding]::new($false))

  # Purge all obsolete / legacy alias HTML files
  $obsoleteNames = @(
    'User_Tools_Explorer_LCM.html',
    'Developer_Tools_Explorer_LCM.html',
    'Dev_Tools_Explorer_LCM.html',
    'Tools_Explorer_LCM.html'
  )
  foreach ($dir in @($artifactsDir)) {
    if (Test-Path -LiteralPath $dir) {
      foreach ($obs in $obsoleteNames) {
        $p = Join-Path $dir $obs
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
      }
    }
  }

  # Clean up legacy root html files if present
  $legacyRootHtml = Join-Path $ToolsDir 'SHOW_TOOLS.html'
  $legacyViewerHtml = Join-Path $ToolsDir 'TOOLS_VIEWER.html'
  if (Test-Path -LiteralPath $legacyRootHtml) { Remove-Item -LiteralPath $legacyRootHtml -Force -ErrorAction SilentlyContinue }
  if (Test-Path -LiteralPath $legacyViewerHtml) { Remove-Item -LiteralPath $legacyViewerHtml -Force -ErrorAction SilentlyContinue }

  return $htmlPath
}

function Send-LcmIncidentTelemetry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [ValidateSet("WARNINGS", "FAILED", "INFO")]
    [string]$Status = "WARNINGS",
    [psobject[]]$Warnings = @(),
    [psobject[]]$Errors = @(),
    [string]$MasterLog = ""
  )

  $payload = @{
    source    = $Source
    status    = $Status
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    masterLog = $MasterLog
    warnings  = $Warnings
    errors    = $Errors
  } | ConvertTo-Json -Depth 5

  $daemonUri = "http://127.0.0.1:9876/report_incident"
  try {
    $res = Invoke-RestMethod -Uri $daemonUri -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "  -> [Incident Telemetry] Dispatched to Daemon (Occurrences: $($res.occurrenceCount), Priority: $($res.priority))" -ForegroundColor DarkCyan
    return $res
  } catch {
    # Fallback to local file
    $wsRoot = "D:\Git_Repositories"
    $incidentsDir = Join-Path $wsRoot 'LCM_Inventory\data\incidents'
    if (-not (Test-Path $incidentsDir)) { New-Item -ItemType Directory -Path $incidentsDir -Force | Out-Null }
    $sourceStem = [System.IO.Path]::GetFileNameWithoutExtension($Source)
    $fallbackFile = Join-Path $incidentsDir "incident_${sourceStem}_$((Get-Date).ToString('yyyyMMdd_HHmmss')).json"
    $payload | Set-Content -LiteralPath $fallbackFile -Encoding UTF8
    Write-Host "  -> [Incident Telemetry] Saved local snapshot: $fallbackFile" -ForegroundColor DarkCyan
    return @{ status = "FALLBACK_SAVED"; incidentFile = $fallbackFile }
  }
}

function Update-LcmToolIntentCall {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$CommandOrPath,
    [double]$DurationMs = 0.0,
    [datetime]$Timestamp = [System.DateTime]::Now
  )

  try {
    $wsRoot = 'D:\Git_Repositories'
    $intentsPath = Join-Path $wsRoot 'LCM_Inventory\config\tool_intents.json'
    if (-not (Test-Path -LiteralPath $intentsPath)) { return }

    $jsonRaw = [System.IO.File]::ReadAllText($intentsPath)
    $data = $jsonRaw | ConvertFrom-Json
    if ($null -eq $data -or $null -eq $data.intents) { return }

    $cleanTarget = $CommandOrPath.Trim()
    $targetName = [System.IO.Path]::GetFileName($cleanTarget)
    if ($cleanTarget -match '(?i)([A-Za-z0-9_\-\.]+\.(?:ps1|cmd|bat|py))') {
      $targetName = $Matches[1]
    }

    $timeStr = $Timestamp.ToString("yyyy-MM-dd HH:mm:ss.fff")
    $matched = $false

    foreach ($prop in $data.intents.PSObject.Properties) {
      $item = $prop.Value
      $isMatch = $false
      if ($prop.Name -ieq $cleanTarget -or $prop.Name -ieq $targetName) {
        $isMatch = $true
      } elseif ($item.script -and ($item.script -like "*$targetName*" -or $item.script -like "*$cleanTarget*")) {
        $isMatch = $true
      } elseif ($item.trampoline -and ($item.trampoline -ieq $targetName -or $item.trampoline -ieq $cleanTarget)) {
        $isMatch = $true
      }

      if ($isMatch) {
        $matched = $true
        $curCount = if ($null -ne $item.call_count) { [int]$item.call_count } else { 0 }
        $curTotal = if ($null -ne $item.total_duration_ms) { [double]$item.total_duration_ms } else { 0.0 }

        $item | Add-Member -NotePropertyName 'call_count' -NotePropertyValue ($curCount + 1) -Force
        $item | Add-Member -NotePropertyName 'last_called_at' -NotePropertyValue $timeStr -Force
        $item | Add-Member -NotePropertyName 'last_duration_ms' -NotePropertyValue ([Math]::Round($DurationMs, 2)) -Force
        $item | Add-Member -NotePropertyName 'total_duration_ms' -NotePropertyValue ([Math]::Round($curTotal + $DurationMs, 2)) -Force
      }
    }

    if ($matched) {
      $data.updated_at = $timeStr
      $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
      $newJson = $data | ConvertTo-Json -Depth 6
      [System.IO.File]::WriteAllText($intentsPath, $newJson, $utf8NoBom)
    }
  } catch {
    # Logging failure in telemetry tracking must never break the caller
  }
}

Export-ModuleMember -Function Get-LcmToolCatalogData, Measure-LcmToolCatalogMetrics, Format-LcmToolCatalogCli, Build-LcmToolIndexHtml, Send-LcmIncidentTelemetry, Update-LcmToolIntentCall
