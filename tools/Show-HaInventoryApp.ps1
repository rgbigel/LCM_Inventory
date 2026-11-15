<#
.SYNOPSIS
  Generates and displays the authoritative interactive HTML dashboard for Home Assistant Subsystem Inventory.
.DESCRIPTION
  Generates a modern, interactive, scrollable HTML dashboard from data/subsystem_inventory.json
  conforming to the LCM Standard Table Display specification (StandardTableDisplay.css & lcm-table-print-atom.js).
  Features:
  1. Standard LCM Header with navigation breadcrumbs [⬅️ Back to Subsystems], live timestamp, and status badges.
  2. Theme switcher (Dark/Light mode) with persistent localStorage synchronization.
  3. Universal top filter toolbar with negation search engine (!term / -term) and instant match counter.
  4. Top-level clickable metric cards with animated hover states and tab switching.
  5. Multi-tab navigation covering Live Entities, Devices, Brands, Clusters, Add-ons, Automations, Helpers, Domains, and Tools.
  6. Double-row sticky headers on tables with aligned column filter dropdowns/inputs and enlarged sort indicators (▲, ▼, ⇅).
  7. Interactive device accordions, secondary drill-down entity modals, and deep diagnostic brand/device scan modals.
  8. Enlarged inspect symbols (🔍), quick copy buttons (📋), and full LcmTablePrintAtom print/PDF export engine.
  Supports multi-instance selection via -Instance (Default: 'HaSSD06').
  Outputs to SHOW_HA_INVENTORY.html in docs/ and tools/.
  Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), RULE-PS-010 (CLI Help), and RULE-PS-011 (Interactive Desktop Dispatch).
  Path: HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 5.6.1
  Date: 2026-11-08 17:34:00
.PARAMETER Instance
  The target Home Assistant subsystem instance name (e.g. 'HaSSD06'). Defaults to 'HaSSD06' (Aliases: -Subsystem, -Name, -HaName).
.PARAMETER Refresh
  Queries live Home Assistant API to refresh data/subsystem_inventory.json before rendering. Defaults to false (instant local render).
.PARAMETER NoLaunch
  Generates the HTML dashboard file without automatically launching it in the web browser.
.PARAMETER Pane
  Opens the display inside an Antigravity IDE editor/side pane instead of an external browser window (Alias: -Panel).
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Show-HaInventoryApp.ps1 -h
.EXAMPLE
  pwsh tools/Show-HaInventoryApp.ps1
.EXAMPLE
  pwsh tools/Show-HaInventoryApp.ps1 -Instance HaSSD06 -Refresh
#>

[CmdletBinding()]
param(
    [Alias('Subsystem', 'Name', 'HaName')]
    [string]$Instance = 'HaSSD06',
    [switch]$Refresh,
    [switch]$NoLaunch,
    [Parameter(Mandatory = $false, HelpMessage = 'Opens the display inside an Antigravity IDE editor/side pane')]
    [Alias('Panel')]
    [switch]$Pane,
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " HOME ASSISTANT SUBSYSTEM INVENTORY VIEWER (v5.6.1)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Generates and displays the authoritative interactive HTML dashboard for Home Assistant Subsystem Inventory."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Show-HaInventoryApp.ps1 [-Instance <name>] [-Refresh] [-NoLaunch] [-Pane] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Instance : Target Home Assistant instance name (Default: 'HaSSD06')."
    Write-Host "  -Refresh  : Refreshes telemetry live from Home Assistant API before rendering."
    Write-Host "  -NoLaunch : Generates HTML dashboard without opening browser."
    Write-Host "  -Pane     : Opens the dashboard inside an Antigravity IDE editor/side pane (Alias: -Panel)."
    Write-Host "  -h, -Help : Displays this parameter reference."
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$workspaceRoot = 'D:\Git_Repositories'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$genTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$timestamp = $genTime

if ($Refresh) {
    $updateCandidates = @(
        (Join-Path $workspaceRoot "${Instance}_Inventory\tools\Update-HaInventory.ps1"),
        (Join-Path $workspaceRoot "$Instance\tools\Update-HaInventory.ps1"),
        (Join-Path $workspaceRoot 'HaSSD06_Inventory\tools\Update-HaInventory.ps1')
    )
    foreach ($uc in $updateCandidates) {
        if (Test-Path -LiteralPath $uc) {
            Write-Host "Executing live telemetry refresh for $Instance..." -ForegroundColor Yellow
            & pwsh -File $uc
            break
        }
    }
}

$candidates = @(
    (Join-Path $workspaceRoot "${Instance}_Inventory\data\subsystem_inventory.json"),
    (Join-Path $workspaceRoot "$Instance\data\subsystem_inventory.json"),
    (Join-Path $PSScriptRoot "..\..\${Instance}_Inventory\data\subsystem_inventory.json"),
    (Join-Path $PSScriptRoot '..\data\subsystem_inventory.json'),
    (Join-Path $PSScriptRoot '..\HaSSD06_Inventory\data\subsystem_inventory.json'),
    (Join-Path $PSScriptRoot 'data\subsystem_inventory.json')
)
$invPath = $null
foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) {
        $invPath = $c
        break
    }
}

if (-not $invPath) {
    throw "Inventory file for instance '$Instance' not found in candidate paths: $($candidates -join '; ')"
}

$inv = Get-Content -LiteralPath $invPath -Raw | ConvertFrom-Json
$embeddedJson = Get-Content -LiteralPath $invPath -Raw

# Load Canonical Standard Display CSS and Print Atom
$cssCandidates = @(
    (Join-Path $workspaceRoot 'LCM_Inventory\assets\StandardTableDisplay.css'),
    (Join-Path $workspaceRoot 'tools\assets\StandardTableDisplay.css'),
    (Join-Path $workspaceRoot 'LCM_Inventory\assets\lcm-dashboard-theme.css'),
    (Join-Path $PSScriptRoot 'assets\StandardTableDisplay.css')
)
$cssPath = $null
foreach ($cand in $cssCandidates) {
    if (Test-Path -LiteralPath $cand) {
        $cssPath = $cand
        break
    }
}
$themeCssContent = if ($cssPath) { Get-Content -LiteralPath $cssPath -Raw -Encoding UTF8 } else { "" }

$atomJsCandidates = @(
    (Join-Path $workspaceRoot 'LCM_Inventory\assets\lcm-table-print-atom.js'),
    (Join-Path $workspaceRoot 'tools\assets\lcm-table-print-atom.js'),
    (Join-Path $PSScriptRoot 'assets\lcm-table-print-atom.js')
)
$atomJsPath = $null
foreach ($cand in $atomJsCandidates) {
    if (Test-Path -LiteralPath $cand) {
        $atomJsPath = $cand
        break
    }
}
$atomJsContent = if ($atomJsPath) { Get-Content -LiteralPath $atomJsPath -Raw -Encoding UTF8 } else { "" }

$distinctDomains = if ($inv.PSObject.Properties['entities_catalog']) {
    @($inv.entities_catalog | ForEach-Object { $_.domain } | Select-Object -Unique | Sort-Object)
} else { @() }

$distinctAreas = if ($inv.PSObject.Properties['entities_catalog']) {
    @($inv.entities_catalog | Where-Object { $_.area -and $_.area -ne '-' } | ForEach-Object { $_.area } | Select-Object -Unique | Sort-Object)
} else { @() }

$distinctDevices = if ($inv.PSObject.Properties['devices_catalog']) {
    @($inv.devices_catalog | ForEach-Object { $_.name } | Select-Object -Unique | Sort-Object)
} else { @() }

$distinctManufacturers = if ($inv.PSObject.Properties['devices_catalog']) {
    @($inv.devices_catalog | Where-Object { $_.manufacturer -and $_.manufacturer -ne '-' } | ForEach-Object { $_.manufacturer } | Select-Object -Unique | Sort-Object)
} else { @() }

$distinctAddonCategories = if ($inv.PSObject.Properties['add_ons_and_packages']) {
    @($inv.add_ons_and_packages | Where-Object { $_.PSObject.Properties['category'] -and $_.category } | ForEach-Object { $_.category } | Select-Object -Unique | Sort-Object)
} else { @() }

$domainOptionsHtml = ($distinctDomains | ForEach-Object { "<option value='$([System.Web.HttpUtility]::HtmlEncode($_))'>$([System.Web.HttpUtility]::HtmlEncode($_))</option>" }) -join "`n"
$areaOptionsHtml = ($distinctAreas | ForEach-Object { "<option value='$([System.Web.HttpUtility]::HtmlEncode($_))'>$([System.Web.HttpUtility]::HtmlEncode($_))</option>" }) -join "`n"
$deviceOptionsHtml = ($distinctDevices | ForEach-Object { "<option value='$([System.Web.HttpUtility]::HtmlEncode($_))'>$([System.Web.HttpUtility]::HtmlEncode($_))</option>" }) -join "`n"
$manufacturerOptionsHtml = ($distinctManufacturers | ForEach-Object { "<option value='$([System.Web.HttpUtility]::HtmlEncode($_))'>$([System.Web.HttpUtility]::HtmlEncode($_))</option>" }) -join "`n"
$addonCategoryOptionsHtml = ($distinctAddonCategories | ForEach-Object { "<option value='$([System.Web.HttpUtility]::HtmlEncode($_))'>$([System.Web.HttpUtility]::HtmlEncode($_))</option>" }) -join "`n"

# Load Readiness Receipt (CRP-152)
$readinessCandidates = @(
    (Join-Path $workspaceRoot "${Instance}_Inventory\data\readiness\latest_readiness.json"),
    (Join-Path $PSScriptRoot "..\data\readiness\latest_readiness.json"),
    (Join-Path $PSScriptRoot 'data\readiness\latest_readiness.json')
)
$readinessPath = $null
foreach ($rc in $readinessCandidates) {
    if (Test-Path -LiteralPath $rc) {
        $readinessPath = $rc
        break
    }
}

$readinessData = if ($readinessPath) {
    try { Get-Content -LiteralPath $readinessPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null }
} else { $null }

$embeddedReadinessJson = if ($readinessPath) {
    Get-Content -LiteralPath $readinessPath -Raw -Encoding UTF8
} else { 'null' }

$readinessPassed = if ($readinessData -and $readinessData.overall_status -eq 'PASSED') { $true } else { $false }
$readinessPassedCount = if ($readinessData) { $readinessData.passed_count } else { 0 }
$readinessTotalCount = if ($readinessData) { $readinessData.total_count } else { 5 }
$readinessDurationText = if ($readinessData -and $readinessData.duration_ms) { "$($readinessData.duration_ms)ms" } else { "-" }
$readinessTimestampText = if ($readinessData -and $readinessData.timestamp) { "Verified: $($readinessData.timestamp)" } else { "No receipt recorded" }
$readinessStatusText = if ($readinessData) { $readinessData.overall_status } else { "UNKNOWN" }
$readinessBadgeClass = if ($readinessPassed) { 'badge-success' } elseif ($readinessData) { 'badge-danger' } else { 'badge-muted' }
$readinessIcon = if ($readinessPassed) { '🟢' } elseif ($readinessData) { '🔴' } else { '⚪' }

$readinessHeaderBadgeHtml = @"
                    <span class="badge $readinessBadgeClass" style="padding: 3px 10px; font-size: 11px; cursor: pointer; border: 1px solid var(--border);" onclick="openReadinessModal()" title="Click to inspect Quality Gate Readiness Receipt &amp; run live checks">
                        $readinessIcon Readiness: $readinessPassedCount/$readinessTotalCount $readinessStatusText
                    </span>
"@

$readinessGatesHtml = if ($readinessData -and $readinessData.gates) {
    ($readinessData.gates | ForEach-Object {
        $g = $_
        $gPassed = $g.status -eq 'PASSED'
        $gBadgeClass = if ($gPassed) { 'badge-success' } else { 'badge-danger' }
        $gIcon = if ($gPassed) { '✓' } else { '✗' }
        $gBorderColor = if ($gPassed) { 'rgba(46, 160, 67, 0.4)' } else { 'rgba(248, 81, 73, 0.4)' }
        $gBgColor = if ($gPassed) { 'rgba(46, 160, 67, 0.06)' } else { 'rgba(248, 81, 73, 0.06)' }
        $reasonHtml = if ($g.failure_reason) { "<div style='color: #ff7b72; font-size: 11px; margin-top: 4px;'><strong>Reason:</strong> $([System.Web.HttpUtility]::HtmlEncode($g.failure_reason))</div>" } else { "" }
        @"
        <div style="background: $gBgColor; border: 1px solid $gBorderColor; border-radius: 8px; padding: 10px 14px; margin-bottom: 8px;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div style="font-weight: 600; font-size: 13px; color: var(--text-primary); display: flex; align-items: center; gap: 8px;">
                    <span class="badge $gBadgeClass" style="font-size: 11px; padding: 2px 6px;">Gate $($g.id)</span>
                    <span>$([System.Web.HttpUtility]::HtmlEncode($g.name))</span>
                </div>
                <div style="display: flex; align-items: center; gap: 8px;">
                    <span style="font-size: 11px; color: var(--text-muted); font-family: monospace;">$($g.duration_ms)ms</span>
                    <span class="badge $gBadgeClass">$gIcon $($g.status)</span>
                </div>
            </div>
            <div style="font-size: 12px; color: var(--text-secondary); margin-top: 4px;">
                $([System.Web.HttpUtility]::HtmlEncode($g.details))
            </div>
            $reasonHtml
        </div>
"@
    }) -join "`n"
} else {
    '<div style="color: var(--text-muted); font-size: 12px; padding: 12px; text-align: center;">No readiness quality gate data recorded yet. Click "Run Live Check" below to execute.</div>'
}

$htmlFileName = if ($Instance -eq 'HaSSD06') { 'SHOW_HA_INVENTORY.html' } else { "SHOW_HA_INVENTORY_${Instance}.html" }
$legacyHtmlFileName = if ($Instance -eq 'HaSSD06') { 'HA_INVENTORY_VIEWER.html' } else { "HA_INVENTORY_VIEWER_${Instance}.html" }
$instanceArtifactsDir = Join-Path $workspaceRoot "${Instance}_Inventory\data\artifacts"
if (-not (Test-Path -LiteralPath $instanceArtifactsDir)) {
    New-Item -ItemType Directory -Path $instanceArtifactsDir -Force | Out-Null
}
$htmlPath = Join-Path $instanceArtifactsDir $htmlFileName
$toolsHtmlPath = Join-Path $workspaceRoot "tools\$htmlFileName"

$html = @"
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Instance Subsystem Inventory Explorer</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>⚡</text></svg>">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
/* ==============================================================================
   LCM STANDARD TABLE DISPLAY SYSTEM (Embedded Theme)
   ============================================================================== */
$themeCssContent

        /* Custom Component Enhancements for Subsystem Inventory Explorer */
        .container {
            max-width: 1720px;
            margin: 0 auto;
            width: 100%;
        }

        /* Metric Cards Grid */
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-bottom: 20px;
        }

        .metric-card {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 16px 18px;
            box-shadow: var(--card-shadow);
            cursor: pointer;
            transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
            position: relative;
            overflow: hidden;
        }

        .metric-card:hover {
            transform: translateY(-3px);
            border-color: var(--accent);
            box-shadow: 0 10px 28px rgba(88, 166, 255, 0.18);
        }

        .metric-card::after {
            content: 'View tab →';
            position: absolute;
            bottom: 8px;
            right: 12px;
            font-size: 11px;
            font-weight: 600;
            color: var(--accent);
            opacity: 0;
            transition: opacity 0.2s;
        }

        .metric-card:hover::after { opacity: 1; }

        .metric-label {
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.6px;
            color: var(--text-secondary);
        }

        .metric-value {
            font-size: 28px;
            font-weight: 700;
            color: var(--text-primary);
            margin-top: 4px;
            font-family: 'JetBrains Mono', monospace;
            letter-spacing: -0.5px;
        }

        .metric-sub {
            font-size: 12px;
            color: var(--success);
            margin-top: 4px;
            font-weight: 500;
        }

        /* Tabs & Universal Toolbar */
        .tabs-container {
            display: flex;
            align-items: center;
            gap: 6px;
            overflow-x: auto;
            scrollbar-width: none;
            padding-bottom: 4px;
        }
        .tabs-container::-webkit-scrollbar { display: none; }

        .tab-btn {
            background: transparent;
            border: 1px solid transparent;
            color: var(--text-secondary);
            font-size: 13px;
            font-weight: 600;
            padding: 8px 14px;
            cursor: pointer;
            border-radius: 6px;
            transition: all 0.15s;
            white-space: nowrap;
        }
        .tab-btn:hover { color: var(--text-primary); background: var(--bg-tertiary); }
        .tab-btn.active {
            color: var(--accent);
            background: rgba(56, 139, 253, 0.15);
            border-color: rgba(56, 139, 253, 0.35);
        }

        /* Search & Filter Toolbar */
        .filter-panel-top {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 12px 16px;
            margin-bottom: 16px;
            display: flex;
            flex-direction: row;
            align-items: center;
            justify-content: space-between;
            gap: 14px;
            flex-wrap: wrap;
        }

        .search-wrapper {
            flex: 1;
            min-width: 280px;
            position: relative;
            display: flex;
            align-items: center;
        }

        .search-input {
            width: 100%;
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 9px 36px 9px 14px;
            color: var(--text-primary);
            font-size: 13px;
            outline: none;
            transition: border-color 0.2s;
        }
        .search-input:focus { border-color: var(--accent); }

        .search-clear-btn {
            position: absolute;
            right: 10px;
            background: none;
            border: none;
            color: var(--text-muted);
            font-size: 14px;
            cursor: pointer;
            padding: 4px;
            border-radius: 50%;
            display: none;
        }
        .search-clear-btn:hover { color: var(--text-primary); }

        .results-count-badge {
            font-size: 12px;
            font-family: 'JetBrains Mono', monospace;
            color: var(--text-secondary);
            background: var(--bg-primary);
            border: 1px solid var(--border);
            padding: 4px 10px;
            border-radius: 20px;
            white-space: nowrap;
        }

        /* Table Sizing & Sort Indicators */
        .sort-icon {
            font-size: 14px;
            font-weight: 700;
            color: var(--accent);
            margin-left: 5px;
            display: inline-block;
            vertical-align: middle;
            opacity: 0.85;
        }

        .action-btn-inspect {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: rgba(210, 153, 34, 0.15);
            color: #d29922;
            border: 1px solid rgba(210, 153, 34, 0.35);
            padding: 5px 12px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.15s ease;
        }
        .action-btn-inspect:hover {
            background: rgba(210, 153, 34, 0.25);
            border-color: #d29922;
            transform: scale(1.03);
        }
        .action-btn-inspect .icon {
            font-size: 15px;
            line-height: 1;
        }

        .btn-copy-eid {
            background: transparent;
            border: none;
            color: var(--text-muted);
            cursor: pointer;
            font-size: 13px;
            padding: 2px 4px;
            border-radius: 4px;
            transition: color 0.15s;
            margin-left: 4px;
            vertical-align: middle;
        }
        .btn-copy-eid:hover { color: var(--accent); background: rgba(56, 139, 253, 0.1); }

        .device-link {
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            transition: all 0.15s ease;
        }
        .device-link:hover .badge {
            transform: scale(1.05);
            border-color: var(--accent);
            color: var(--accent);
            box-shadow: 0 0 8px rgba(56, 139, 253, 0.3);
        }

        /* Code Cells & Labels */
        .code-cell {
            font-family: 'JetBrains Mono', monospace;
            font-size: 12.5px;
            color: #79c0ff;
        }
        body.light-theme .code-cell {
            color: #0550ae;
        }

        /* Device Accordion Container */
        .device-group {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 10px;
            margin-bottom: 12px;
            overflow: hidden;
            box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        }

        .device-group-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 13px 18px;
            background: var(--bg-tertiary);
            cursor: pointer;
            user-select: none;
            transition: background 0.2s;
        }
        .device-group-header:hover { background: #262c35; }
        body.light-theme .device-group-header:hover { background: #e1e7ed; }

        .device-group-title {
            font-weight: 600;
            font-size: 14.5px;
            display: flex;
            align-items: center;
            gap: 10px;
            flex-wrap: wrap;
        }

        .device-group-body { display: none; padding: 0; }
        .device-group.open .device-group-body { display: block; }
        .device-group.open .device-arrow { transform: rotate(90deg); }
        .device-arrow { transition: transform 0.2s; color: var(--accent); font-size: 13px; font-weight: bold; }

        /* Tab Visibility */
        .tab-content { display: none; }
        .tab-content.active { display: block; }

        /* Modals & Drill-Downs */
        .modal-overlay {
            display: none;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0, 0, 0, 0.75);
            backdrop-filter: blur(4px);
            z-index: 1000;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .modal-overlay.active { display: flex; }

        .modal-box {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 14px;
            width: 100%;
            max-width: 860px;
            max-height: 88vh;
            overflow-y: auto;
            box-shadow: 0 20px 48px rgba(0, 0, 0, 0.8);
            padding: 24px 28px;
            position: relative;
        }

        .modal-close {
            position: absolute;
            top: 18px;
            right: 18px;
            background: var(--bg-tertiary);
            border: 1px solid var(--border);
            color: var(--text-muted);
            font-size: 18px;
            width: 32px; height: 32px;
            border-radius: 50%;
            cursor: pointer;
            display: flex; align-items: center; justify-content: center;
            transition: all 0.15s;
        }
        .modal-close:hover { color: var(--text-primary); border-color: var(--accent); }

        .detail-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 12px;
            margin: 16px 0;
        }

        .detail-item {
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 10px 14px;
        }
        .detail-item-label {
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-secondary);
        }
        .detail-item-value {
            font-size: 13.5px;
            font-weight: 600;
            color: var(--text-primary);
            margin-top: 3px;
        }

        .attributes-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 12.5px;
        }
        .attributes-table th {
            background: var(--bg-primary);
            padding: 8px 12px;
            border: 1px solid var(--border);
            font-size: 11px;
            text-transform: uppercase;
            color: var(--text-secondary);
        }
        .attributes-table td {
            padding: 8px 12px;
            border: 1px solid var(--border);
            color: var(--text-primary);
        }

        /* Tool Parameter Form Controls */
        .param-field {
            margin-bottom: 12px;
        }
        .input-clear-wrapper {
            position: relative;
            display: flex;
            align-items: center;
        }
        .tool-param-input {
            width: 100%;
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 6px;
            padding: 7px 32px 7px 10px;
            color: var(--text-primary);
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            outline: none;
            transition: border-color 0.2s;
        }
        .tool-param-input:focus { border-color: var(--accent); }
        .btn-clear-param {
            position: absolute;
            right: 8px;
            background: none;
            border: none;
            color: var(--text-muted);
            font-size: 14px;
            cursor: pointer;
            padding: 2px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            width: 20px;
            height: 20px;
        }
        .btn-clear-param:hover { color: var(--danger); background: rgba(248, 81, 73, 0.15); }

        /* Toast Notifications */
        .toast {
            position: fixed;
            bottom: 24px;
            right: 24px;
            background: #1f242c;
            color: #58a6ff;
            border: 1px solid #388bfd;
            border-radius: 8px;
            padding: 12px 20px;
            font-size: 13px;
            font-weight: 600;
            box-shadow: 0 8px 24px rgba(0,0,0,0.6);
            display: none;
            z-index: 2000;
            transition: opacity 0.3s ease;
        }

        /* Action Log Drawer (CRP-151) */
        .action-drawer-overlay {
            display: none;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0, 0, 0, 0.5);
            backdrop-filter: blur(2px);
            z-index: 1400;
        }
        .action-drawer-overlay.active { display: block; }
        .action-drawer {
            position: fixed;
            top: 0; right: -460px;
            width: 440px; height: 100%;
            background: var(--bg-secondary);
            border-left: 1px solid var(--border);
            box-shadow: -8px 0 32px rgba(0, 0, 0, 0.6);
            z-index: 1500;
            display: flex;
            flex-direction: column;
            transition: right 0.25s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .action-drawer.active { right: 0; }
        .drawer-header {
            padding: 16px 20px;
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: var(--bg-tertiary);
        }
        .drawer-title { font-size: 15px; font-weight: 700; display: flex; align-items: center; gap: 8px; }
        .drawer-body {
            flex: 1;
            overflow-y: auto;
            padding: 14px 18px;
        }
        .action-card {
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 10px 12px;
            margin-bottom: 10px;
            font-size: 12px;
            transition: border-color 0.15s;
        }
        .action-card:hover { border-color: var(--accent); }
        .action-card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 4px;
        }
        .action-card-type { font-weight: 700; font-size: 11px; }
        .action-card-time { font-size: 10px; color: var(--text-muted); font-family: 'JetBrains Mono', monospace; }
        .action-card-target { font-family: 'JetBrains Mono', monospace; color: var(--accent); font-weight: 600; font-size: 11.5px; margin-bottom: 3px; word-break: break-all; }
        .action-card-details { color: var(--text-secondary); font-size: 11px; line-height: 1.4; }
        .action-card-cmd { background: var(--bg-secondary); border-radius: 4px; padding: 4px 6px; font-family: 'JetBrains Mono', monospace; font-size: 10px; color: #7ee787; margin-top: 6px; word-break: break-all; }

        /* Light Mode Specific Overrides */
        body.light-theme .metric-card {
            background: #ffffff;
            border-color: #d0d7de;
            box-shadow: 0 4px 14px rgba(0, 0, 0, 0.06);
        }
        body.light-theme .device-group {
            background: #ffffff;
            border-color: #d0d7de;
        }
        body.light-theme .device-group-header {
            background: #f1f4f8;
        }
        body.light-theme .scrollable-table thead tr:first-child th {
            background: #eaeef2;
            color: #424a53;
        }
        body.light-theme .scrollable-table thead tr.col-filter-row th {
            background: #f6f8fa;
        }
        body.light-theme .modal-box {
            background: #ffffff;
            border-color: #d0d7de;
        }
        body.light-theme .detail-item {
            background: #f6f8fa;
            border-color: #d0d7de;
        }
        body.light-theme .action-drawer {
            background: #ffffff;
            border-color: #d0d7de;
        }
        body.light-theme .drawer-header {
            background: #eaeef2;
        }
        body.light-theme .action-card {
            background: #f6f8fa;
            border-color: #d0d7de;
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- 1. Standard LCM Subsystem Display Header -->
        <header>
            <div class="header-title">
                <h1>⚡ $Instance Subsystem Inventory Explorer <span class="header-version-badge">v5.6.0</span></h1>
                <div class="header-meta">
                    <span>Host: <strong>$($inv.host_hardware)</strong> &bull; Core: <strong>$($inv.core_version)</strong></span>
                    <span>&bull;</span>
                    <span class="timestamp-badge">Generated: $($inv.generated_at) (<span id="generatedRelativeTime" style="color: var(--accent); font-weight: 600;">Just now</span>)</span>
                    <span class="badge badge-success" style="padding: 3px 10px; font-size: 11px;">🟢 Online &bull; 192.168.10.6</span>
$readinessHeaderBadgeHtml
                </div>
            </div>
            <div class="header-actions">
                <button class="btn-back-nav" onclick="navigateBackToSubsystems()" title="Return to master subsystem list">
                    ⬅️ Back to Subsystems
                </button>
                <button class="btn-help-nav" id="btn-theme-toggle" onclick="toggleTheme()" title="Switch between Dark and Light display modes">
                    <span id="theme-icon">☀️</span> <span id="theme-label">Light Mode</span>
                </button>
                <button class="btn-help-nav" id="btn-action-log" onclick="toggleActionLogDrawer()" title="View live subsystem action audit stream">
                    <span>📜</span> Action Log (<span id="actionLogBadgeCount">0</span>)
                </button>
                <button class="btn-refresh" onclick="LcmTablePrintAtom.openModal()" title="Configure layout, columns, and export to PDF or printer">
                    <span>🖨️</span> Print / PDF Export
                </button>
            </div>
        </header>
        <!-- 2. Interactive Metric Overview Cards -->
        <div class="metrics-grid">
            <div class="metric-card" onclick="showTab('tab-devices')">
                <div class="metric-label">Registered Devices</div>
                <div class="metric-value">$($inv.total_registered_devices)</div>
                <div class="metric-sub">$($inv.total_registered_devices) Hardware &amp; Virtual Nodes</div>
            </div>
            <div class="metric-card" onclick="showTab('tab-clusters')">
                <div class="metric-label">Active Integrations</div>
                <div class="metric-value">$($inv.total_config_integrations)</div>
                <div class="metric-sub">Config Entries &amp; Clusters</div>
            </div>
            <div class="metric-card" onclick="showTab('tab-entities')">
                <div class="metric-label">Total Entities</div>
                <div class="metric-value">$($inv.total_entities)</div>
                <div class="metric-sub">$($inv.total_entities) Tracked Live Entities</div>
            </div>
            <div class="metric-card" onclick="showTab('tab-automations')">
                <div class="metric-label">Automations &amp; Scripts</div>
                <div class="metric-value">$($inv.total_automations + $inv.total_scripts)</div>
                <div class="metric-sub">$($inv.total_automations) Automations &bull; $($inv.total_scripts) Scripts</div>
            </div>
            <div class="metric-card" onclick="showTab('tab-helpers')">
                <div class="metric-label">Configured Helpers</div>
                <div class="metric-value">$($inv.total_helpers)</div>
                <div class="metric-sub">Inputs, Lists &amp; Zones</div>
            </div>
        </div>

        <!-- 3. Universal Toolbar & Filter Panel -->
        <div class="filter-panel-top">
            <div class="search-wrapper">
                <input type="text" id="filterInput" class="search-input" placeholder="Type to filter across entities, devices, rooms, integrations (!exclude supported)..." oninput="handleSearchInput()">
                <button id="searchClearBtn" class="search-clear-btn" onclick="clearSearch()" title="Clear search">✕</button>
            </div>
            <div class="tabs-container">
                <button class="tab-btn active" id="btn-tab-entities" onclick="showTab('tab-entities')">Live Entities ($($inv.total_entities))</button>
                <button class="tab-btn" id="btn-tab-devices" onclick="showTab('tab-devices')">Devices Explorer ($($inv.devices_catalog.Count))</button>
                <button class="tab-btn" id="btn-tab-brands" onclick="showTab('tab-brands')">Hardware Brands</button>
                <button class="tab-btn" id="btn-tab-clusters" onclick="showTab('tab-clusters')">Ecosystem Clusters</button>
                <button class="tab-btn" id="btn-tab-addons" onclick="showTab('tab-addons')">Add-ons &amp; Packages ($($inv.add_ons_and_packages.Count))</button>
                <button class="tab-btn" id="btn-tab-automations" onclick="showTab('tab-automations')">Automations &amp; Scripts</button>
                <button class="tab-btn" id="btn-tab-helpers" onclick="showTab('tab-helpers')">Helpers &amp; Virtual</button>
                <button class="tab-btn" id="btn-tab-domains" onclick="showTab('tab-domains')">Domain Breakdown</button>
                <button class="tab-btn" id="btn-tab-tools" onclick="showTab('tab-tools')">🛠️ Tools &amp; Active Help</button>
            </div>
            <div class="toolbar-actions">
                <span class="results-count-badge" id="resultsCountBadge">Showing $($inv.total_entities) of $($inv.total_entities)</span>
                <button class="btn-reset" onclick="resetAllFilters()" title="Reset all global and column filters">✕ Reset Filters</button>
            </div>
        </div>

        <!-- TAB 0: LIVE ENTITIES (Double-Header Sortable & Aligned Column Filter) -->
        <div id="tab-entities" class="tab-content active">
            <div class="table-container">
                <table class="scrollable-table" id="table-entities">
                    <thead>
                        <tr>
                            <th onclick="sortTable('table-entities', 0)" style="width: 140px;">Domain <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-entities', 1)" style="min-width: 220px;" class="allow-wrap">Friendly Name <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-entities', 2)" style="min-width: 260px;">Entity ID <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-entities', 3)" style="width: 140px;">Current Status <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-entities', 4)" style="min-width: 200px;" class="allow-wrap">Associated Device <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-entities', 5)" style="width: 160px;">Area / Room <span class="sort-icon">⇅</span></th>
                            <th style="width: 175px; text-align: center;">Actions</th>
                        </tr>
                        <tr class="col-filter-row">
                            <th>
                                <select class="col-filter-select" id="ent-domain-select" onchange="filterEntitiesTable()">
                                    <option value="All">All Domains</option>
                                    $domainOptionsHtml
                                </select>
                            </th>
                            <th>
                                <input type="text" class="col-filter-input" id="ent-name-filter" placeholder="Filter Name..." oninput="filterEntitiesTable()">
                            </th>
                            <th>
                                <input type="text" class="col-filter-input" id="ent-id-filter" placeholder="Filter Entity ID..." oninput="filterEntitiesTable()">
                            </th>
                            <th>
                                <input type="text" class="col-filter-input" id="ent-state-filter" placeholder="Filter Status..." oninput="filterEntitiesTable()">
                            </th>
                            <th>
                                <input type="text" class="col-filter-input" id="ent-device-filter" placeholder="Filter Device..." oninput="filterEntitiesTable()">
                            </th>
                            <th>
                                <select class="col-filter-select" id="ent-area-select" onchange="filterEntitiesTable()">
                                    <option value="All">All Areas</option>
                                    $areaOptionsHtml
                                </select>
                            </th>
                            <th style="text-align: center;">
                                <button class="btn-reset" style="padding: 4px 8px; font-size: 11px;" onclick="resetEntityColumnFilters()" title="Reset column filters">✕</button>
                            </th>
                        </tr>
                    </thead>
                    <tbody>
"@

if ($inv.PSObject.Properties['entities_catalog']) {
    foreach ($ent in $inv.entities_catalog) {
        $badgeClass = switch -Regex ($ent.domain) {
            'sensor|binary_sensor' { 'badge-info' }
            'switch|light|cover'   { 'badge-success' }
            'update'               { 'badge-warning' }
            default                { 'badge-muted' }
        }
        $entId = $ent.entity_id
        $devName = if ($ent.device_name -and $ent.device_name -ne '-') { $ent.device_name } else { '-' }
        $area = if ($ent.area -and $ent.area -ne '-') { $ent.area } else { '-' }

        $stateLower = if ($ent.state) { $ent.state.Trim().ToLower() } else { '' }
        $statusBadge = switch -Regex ($stateLower) {
            '^(on|home|online|connected|active|running|playing|open|ok|unlocked)$' { 'badge-success' }
            '^(off|not_home|offline|disconnected|closed|standby|stopped)$'         { 'badge-danger' }
            '^(unavailable|unknown|error|problem)$'                                { 'badge-warning' }
            '^[0-9]+(\.[0-9]+)?'                                                   { 'badge-info' }
            default                                                                { 'badge-secondary' }
        }
        $stateText = if ($ent.state) { [System.Web.HttpUtility]::HtmlEncode($ent.state) } else { '-' }

        $devLinkHtml = if ($devName -ne '-') {
            $devJsArg = [System.Web.HttpUtility]::JavaScriptStringEncode($devName)
            $devEnc = [System.Web.HttpUtility]::HtmlEncode($devName)
            "<a href='javascript:void(0)' onclick='event.stopPropagation(); jumpToDevice(`"$devJsArg`")' class='device-link' title='Click to view device details in Devices Explorer'><span class='badge badge-role' style='font-size: 11px; cursor: pointer;'>📱 $devEnc</span></a>"
        } else {
            "<span class='badge badge-muted'>-</span>"
        }

        $html += @"
                        <tr class="clickable-row" onclick="openEntityModal('$entId')">
                            <td><span class="badge $badgeClass">$($ent.domain)</span></td>
                            <td class="allow-wrap"><strong>$([System.Web.HttpUtility]::HtmlEncode($ent.name))</strong></td>
                            <td class="code-cell">$entId <button class="btn-copy-eid" onclick="event.stopPropagation(); copyToClipboard('$entId', this)" title="Copy Entity ID">📋</button></td>
                            <td><span class="badge $statusBadge">$stateText</span></td>
                            <td class="allow-wrap">$devLinkHtml</td>
                            <td><span class="badge badge-muted">$([System.Web.HttpUtility]::HtmlEncode($area))</span></td>
                            <td style="text-align: center; white-space: nowrap;">
                                <button class="action-btn-inspect" onclick="event.stopPropagation(); openEntityModal('$entId')" title="Inspect entity attributes & details"><span class="icon">🔍</span> Inspect</button>
                                <button class="action-btn-inspect" style="background: rgba(235, 148, 56, 0.15); color: #f0883e; border-color: rgba(235, 148, 56, 0.35);" onclick="event.stopPropagation(); openEntityRenameModal('$entId')" title="Rename entity, pattern preview & cascade references"><span class="icon">✏️</span> Rename</button>
                            </td>
                        </tr>
"@
    }
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 1: DEDICATED DEVICES EXPLORER PAGE -->
        <div id="tab-devices" class="tab-content">
            <div class="table-container">
                <table class="scrollable-table" id="table-devices">
                    <thead>
                        <tr>
                            <th onclick="sortTable('table-devices', 0)" style="min-width: 240px;" class="allow-wrap">Device Name <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-devices', 1)" style="min-width: 160px;">Manufacturer <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-devices', 2)" style="min-width: 180px;">Model / Hardware <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-devices', 3)" style="width: 140px;">Area / Room <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-devices', 4)" style="width: 140px;">Labels / Tags <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-devices', 5)" style="width: 130px; text-align: center;">Entities <span class="sort-icon">⇅</span></th>
                            <th style="width: 225px; text-align: center;">Actions</th>
                        </tr>
                        <tr class="col-filter-row">
                            <th>
                                <select class="col-filter-select" id="dev-name-select" onchange="filterDevicesTable()">
                                    <option value="All">All Devices ($($inv.devices_catalog.Count))</option>
                                    $deviceOptionsHtml
                                </select>
                            </th>
                            <th>
                                <select class="col-filter-select" id="dev-mfg-select" onchange="filterDevicesTable()">
                                    <option value="All">All Manufacturers</option>
                                    $manufacturerOptionsHtml
                                </select>
                            </th>
                            <th>
                                <input type="text" class="col-filter-input" id="dev-model-filter" placeholder="Filter Model..." oninput="filterDevicesTable()">
                            </th>
                            <th>
                                <select class="col-filter-select" id="dev-area-select" onchange="filterDevicesTable()">
                                    <option value="All">All Areas</option>
                                    $areaOptionsHtml
                                </select>
                            </th>
                            <th>
                                <input type="text" class="col-filter-input" id="dev-label-filter" placeholder="Filter Label..." oninput="filterDevicesTable()">
                            </th>
                            <th>
                                <input type="text" class="col-filter-input" id="dev-count-filter" placeholder="Min count..." oninput="filterDevicesTable()" style="text-align: center;">
                            </th>
                            <th style="text-align: center;">
                                <button class="btn-reset" style="padding: 4px 8px; font-size: 11px;" onclick="resetDeviceColumnFilters()" title="Reset device filters">✕</button>
                            </th>
                        </tr>
                    </thead>
                    <tbody>
"@

if ($inv.PSObject.Properties['devices_catalog']) {
    foreach ($dev in $inv.devices_catalog) {
        $devId = $dev.id
        $devName = [System.Web.HttpUtility]::HtmlEncode($dev.name)
        $devJsArg = [System.Web.HttpUtility]::JavaScriptStringEncode($dev.name)
        $mfg = if ($dev.manufacturer -and $dev.manufacturer -ne '-') { [System.Web.HttpUtility]::HtmlEncode($dev.manufacturer) } else { '-' }
        $model = if ($dev.model -and $dev.model -ne '-') { [System.Web.HttpUtility]::HtmlEncode($dev.model) } else { '-' }
        $area = if ($dev.area -and $dev.area -ne '-') { [System.Web.HttpUtility]::HtmlEncode($dev.area) } else { '-' }
        $areaBadge = if ($area -ne '-') { "<span class='badge badge-info'>$area</span>" } else { "<span class='badge badge-muted'>-</span>" }
        
        $labelsBadge = if ($dev.PSObject.Properties['labels'] -and $dev.labels.Count -gt 0) {
            ($dev.labels | ForEach-Object { "<span class='badge badge-purple'>$([System.Web.HttpUtility]::HtmlEncode($_))</span>" }) -join " "
        } else {
            "<span class='badge badge-muted'>-</span>"
        }

        $html += @"
                        <tr class="clickable-row" onclick="jumpToEntities('$devJsArg')">
                            <td class="allow-wrap">
                                <strong>$devName</strong>
                                <div style="font-size: 11px; color: var(--text-muted); font-family: monospace;">ID: $devId</div>
                            </td>
                            <td><span class="badge badge-muted">$mfg</span></td>
                            <td class="allow-wrap"><span class="badge badge-secondary">$model</span></td>
                            <td>$areaBadge</td>
                            <td>$labelsBadge</td>
                            <td style="text-align: center;">
                                <a href="javascript:void(0)" onclick="event.stopPropagation(); jumpToEntities('$devJsArg')" class="badge badge-success" style="font-size: 12px; text-decoration: none;" title="Click to view all $($dev.entity_count) entities in Live Entities tab">🔗 $($dev.entity_count) Entities</a>
                            </td>
                            <td style="text-align: center; white-space: nowrap;">
                                <button class="action-btn-inspect" onclick="event.stopPropagation(); jumpToEntities('$devJsArg')" title="Jump to Live Entities filtered to this device"><span class="icon">🔗</span> Entities</button>
                                <button class="action-btn-inspect" style="background: rgba(56, 139, 253, 0.15); color: var(--accent); border-color: rgba(56, 139, 253, 0.35);" onclick="event.stopPropagation(); openDeviceScanModal('$devId')" title="Deep Scan device attributes"><span class="icon">🔍</span> Scan</button>
                                <button class="action-btn-inspect" style="background: rgba(235, 148, 56, 0.15); color: #f0883e; border-color: rgba(235, 148, 56, 0.35);" onclick="event.stopPropagation(); openDeviceRenameModal('$devId')" title="Rename device, set patterns, and cascade child entities"><span class="icon">✏️</span> Rename</button>
                            </td>
                        </tr>
"@
    }
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 2: BRANDS -->
        <div id="tab-brands" class="tab-content">
            <div class="table-container">
                <table class="scrollable-table" id="table-brands">
                    <thead>
                        <tr>
                            <th onclick="sortTable('table-brands', 0)">Manufacturer / Brand <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-brands', 1)">Registered Devices <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-brands', 2)">Category / Ecosystem Role <span class="sort-icon">⇅</span></th>
                            <th style="text-align: center;">Diagnostic Action</th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($m in $inv.registered_devices_by_brand.PSObject.Properties) {
    $role = if ($m.Name -match 'AVM|FRITZ') { 'Network Gateway, Repeaters, DECT Plugs & Clients' } elseif ($m.Name -eq 'Tuya') { 'Smart Plugs, Power Relays & Lighting' } elseif ($m.Name -eq 'Shelly') { 'Local Wi-Fi Relays (Plus 1PM, 2PM, Plug S)' } elseif ($m.Name -eq 'Amazon') { 'Echo & Alexa Voice Media Endpoints' } elseif ($m.Name -eq 'coolkit') { 'Sonoff & eWeLink Zigbee/Wi-Fi Relays' } elseif ($m.Name -match 'Nuki') { 'Smart Door Lock & Nuki Bridge' } elseif ($m.Name -eq 'Sonos') { 'Network Audio Players' } elseif ($m.Name -eq 'LG') { 'webOS Smart Televisions (OLED/NANO)' } elseif ($m.Name -eq 'Govee') { 'BLE Hygrometer / Thermometer Sensors' } elseif ($m.Name -match 'Eufy') { 'Security Camera P2P Base & Video Streams' } elseif ($m.Name -eq 'Aqara') { 'mmWave Presence & Motion Radar Sensors' } else { 'Integration Device / Virtual Node' }
    $bName = $m.Name
    $html += @"
                        <tr>
                            <td><strong>$bName</strong></td>
                            <td class="code-cell">$($m.Value)</td>
                            <td>$role</td>
                            <td style="text-align: center;"><button class="action-btn-inspect" onclick="openBrandScanModal('$bName')"><span class="icon">🔍</span> Scan $bName Devices</button></td>
                        </tr>
"@
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 3: CLUSTERS -->
        <div id="tab-clusters" class="tab-content">
            <div class="table-container">
                <table class="scrollable-table" id="table-clusters">
                    <thead>
                        <tr>
                            <th onclick="sortTable('table-clusters', 0)">Ecosystem Cluster <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-clusters', 1)">Tracked Devices <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-clusters', 2)">Tracked Entities <span class="sort-icon">⇅</span></th>
                            <th>Communication Protocol</th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($c in $inv.hardware_device_clusters) {
    $html += @"
                        <tr>
                            <td><strong>$($c.ecosystem)</strong></td>
                            <td class="code-cell">$($c.tracked_devices)</td>
                            <td class="code-cell">$($c.tracked_entities)</td>
                            <td><span class="badge badge-info">$($c.protocol)</span></td>
                        </tr>
"@
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 4: ADDONS -->
        <div id="tab-addons" class="tab-content">
            <div class="table-container">
                <table class="scrollable-table" id="table-addons">
                    <thead>
                        <tr>
                            <th onclick="sortTable('table-addons', 0)">Component / Package <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-addons', 1)">Category <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-addons', 2)">Tracking Entity / Slug <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-addons', 3)">Installed Version <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-addons', 4)">Latest Version <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-addons', 5)">Operational Status <span class="sort-icon">⇅</span></th>
                        </tr>
                        <tr class="col-filter-row">
                            <th><input type="text" class="col-filter-input" placeholder="Filter component..." onkeyup="filterTable('table-addons', 0, this.value)"></th>
                            <th>
                                <select class="col-filter-select" onchange="filterTable('table-addons', 1, this.value)">
                                    <option value="">All Categories</option>
                                    $addonCategoryOptionsHtml
                                </select>
                            </th>
                            <th><input type="text" class="col-filter-input" placeholder="Filter entity..." onkeyup="filterTable('table-addons', 2, this.value)"></th>
                            <th><input type="text" class="col-filter-input" placeholder="Filter installed..." onkeyup="filterTable('table-addons', 3, this.value)"></th>
                            <th><input type="text" class="col-filter-input" placeholder="Filter latest..." onkeyup="filterTable('table-addons', 4, this.value)"></th>
                            <th>
                                <select class="col-filter-select" onchange="filterTable('table-addons', 5, this.value)">
                                    <option value="">All Statuses</option>
                                    <option value="Up to date">Up to date</option>
                                    <option value="Running">Running</option>
                                    <option value="Update Available">Update Available</option>
                                    <option value="Installing">Installing</option>
                                    <option value="Stopped">Stopped</option>
                                    <option value="Unavailable">Unavailable</option>
                                </select>
                            </th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($a in $inv.add_ons_and_packages) {
    $cat = if ($a.PSObject.Properties['category'] -and $a.category) { $a.category } else { 'Supervisor Add-on' }
    $catBadge = switch ($cat) {
        'Core Subsystem'              { 'badge-primary' }
        'Supervisor Subsystem'        { 'badge-info' }
        'Operating System'            { 'badge-info' }
        'Supervisor Add-on'           { 'badge-success' }
        'HACS / Custom Integration'   { 'badge-warning' }
        'Lovelace Card'               { 'badge-muted' }
        'Device Firmware'             { 'badge-secondary' }
        default                       { 'badge-info' }
    }

    $latestVer = if ($a.PSObject.Properties['latest_version'] -and $a.latest_version) { $a.latest_version } else { $a.version }
    
    $statusBadge = switch ($a.state) {
        'up_to_date'        { '<span class="badge badge-success">🟢 Up to date</span>' }
        'running'           { '<span class="badge badge-success">🟢 Running</span>' }
        'update_available'  { "<span class=`"badge badge-warning`">🟡 Update ($latestVer)</span>" }
        'installing'        { '<span class="badge badge-info">🔵 Installing</span>' }
        'stopped'           { '<span class="badge badge-danger">🔴 Stopped</span>' }
        'unavailable'       { '<span class="badge badge-muted">⚪ Unavailable</span>' }
        'off'               { '<span class="badge badge-success">🟢 Up to date</span>' }
        'on'                { "<span class=`"badge badge-warning`">🟡 Update ($latestVer)</span>" }
        default             { "<span class=`"badge badge-muted`">$($a.state)</span>" }
    }

    $nameHtml = if ($a.PSObject.Properties['release_url'] -and $a.release_url) {
        "<strong>$($a.name)</strong> <a href=`"$($a.release_url)`" target=`"_blank`" title=`"View Release Notes`" style=`"font-size: 11px; text-decoration: none; opacity: 0.8;`">↗️</a>"
    } else {
        "<strong>$($a.name)</strong>"
    }

    $html += @"
                        <tr>
                            <td>$nameHtml</td>
                            <td><span class="badge $catBadge">$cat</span></td>
                            <td class="code-cell">$($a.entity)</td>
                            <td class="code-cell">$($a.version)</td>
                            <td class="code-cell">$latestVer</td>
                            <td>$statusBadge</td>
                        </tr>
"@
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 5: AUTOMATIONS & SCRIPTS -->
        <div id="tab-automations" class="tab-content">
            <div class="table-container">
                <table class="scrollable-table" id="table-automations">
                    <thead>
                        <tr>
                            <th onclick="sortTable('table-automations', 0)">Type <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-automations', 1)">Name <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-automations', 2)">Entity ID <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-automations', 3)">Mode <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-automations', 4)">Current State <span class="sort-icon">⇅</span></th>
                            <th style="text-align: center; width: 280px;">Actions</th>
                        </tr>
                        <tr class="col-filter-row">
                            <th>
                                <select class="col-filter-select" onchange="filterTable('table-automations', 0, this.value)">
                                    <option value="">All Types</option>
                                    <option value="Automation">Automation</option>
                                    <option value="Script">Script</option>
                                </select>
                            </th>
                            <th><input type="text" class="col-filter-input" placeholder="Filter name..." onkeyup="filterTable('table-automations', 1, this.value)"></th>
                            <th><input type="text" class="col-filter-input" placeholder="Filter entity..." onkeyup="filterTable('table-automations', 2, this.value)"></th>
                            <th><input type="text" class="col-filter-input" placeholder="Filter mode..." onkeyup="filterTable('table-automations', 3, this.value)"></th>
                            <th>
                                <select class="col-filter-select" onchange="filterTable('table-automations', 4, this.value)">
                                    <option value="">All States</option>
                                    <option value="on">On / Active</option>
                                    <option value="off">Off / Standby</option>
                                    <option value="unavailable">Unavailable</option>
                                </select>
                            </th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($au in $inv.automations_catalog) {
    $auBadge = switch ($au.state) {
        'on'          { 'badge-success' }
        'off'         { 'badge-danger' }
        'unavailable' { 'badge-warning' }
        default       { 'badge-muted' }
    }
    $modeStr = if ($au.PSObject.Properties['mode'] -and $au.mode) { $au.mode } else { 'single' }
    $toggleActionLabel = if ($au.state -eq 'on') { '⏸️ Turn Off' } else { '▶️ Turn On' }
    $toggleTargetState = if ($au.state -eq 'on') { 'off' } else { 'on' }

    $html += @"
                        <tr id="row-$($au.entity.Replace('.', '-'))">
                            <td><span class="badge badge-info">Automation</span></td>
                            <td><strong>$($au.name)</strong></td>
                            <td class="code-cell">$($au.entity)</td>
                            <td><span class="badge badge-muted">$modeStr</span></td>
                            <td><span class="badge $auBadge" id="state-$($au.entity.Replace('.', '-'))">$($au.state)</span></td>
                            <td style="text-align: center; white-space: nowrap;">
                                <button class="action-btn-inspect" style="font-size: 11px; padding: 3px 8px; background: rgba(56, 139, 253, 0.15); color: var(--accent); border-color: rgba(56, 139, 253, 0.35);" onclick="toggleAutomationState('$($au.entity)', '$toggleTargetState')" title="Toggle automation state on/off">
                                    <span class="icon">⚡</span> $toggleActionLabel
                                </button>
                                <button class="action-btn-inspect" style="font-size: 11px; padding: 3px 8px; background: rgba(163, 113, 247, 0.15); color: #d2a8ff; border-color: rgba(163, 113, 247, 0.35);" onclick="openAutomationYamlModal('$($au.entity)', 'Automation', '$([System.Web.HttpUtility]::JavaScriptStringEncode($au.name))')" title="View/Edit Automation YAML &amp; HA Deep Link">
                                    <span class="icon">📝</span> YAML
                                </button>
                                <button class="action-btn-inspect" style="font-size: 11px; padding: 3px 8px;" onclick="openEntityRenameModal('$($au.entity)')" title="Rename Automation and cascade references">
                                    <span class="icon">✏️</span> Rename
                                </button>
                                <button class="action-btn-inspect" style="font-size: 11px; padding: 3px 8px; background: rgba(248, 81, 73, 0.15); color: #ff7b72; border-color: rgba(248, 81, 73, 0.35);" onclick="openAutomationDeleteModal('$($au.entity)', 'Automation', '$([System.Web.HttpUtility]::JavaScriptStringEncode($au.name))')" title="Delete Automation">
                                    <span class="icon">🗑️</span> Delete
                                </button>
                            </td>
                        </tr>
"@
}
foreach ($sc in $inv.scripts_catalog) {
    $scBadge = switch ($sc.state) {
        'on'          { 'badge-success' }
        'off'         { 'badge-danger' }
        'unavailable' { 'badge-warning' }
        default       { 'badge-muted' }
    }
    $modeStr = if ($sc.PSObject.Properties['mode'] -and $sc.mode) { $sc.mode } else { 'single' }

    $html += @"
                        <tr id="row-$($sc.entity.Replace('.', '-'))">
                            <td><span class="badge badge-muted">Script</span></td>
                            <td><strong>$($sc.name)</strong></td>
                            <td class="code-cell">$($sc.entity)</td>
                            <td><span class="badge badge-muted">$modeStr</span></td>
                            <td><span class="badge $scBadge" id="state-$($sc.entity.Replace('.', '-'))">$($sc.state)</span></td>
                            <td style="text-align: center; white-space: nowrap;">
                                <button class="action-btn-inspect" style="font-size: 11px; padding: 3px 8px; background: rgba(35, 134, 54, 0.15); color: #7ee787; border-color: rgba(46, 160, 67, 0.35);" onclick="executeScriptAction('$($sc.entity)')" title="Run / Execute Script">
                                    <span class="icon">▶️</span> Run
                                </button>
                                <button class="action-btn-inspect" style="font-size: 11px; padding: 3px 8px; background: rgba(163, 113, 247, 0.15); color: #d2a8ff; border-color: rgba(163, 113, 247, 0.35);" onclick="openAutomationYamlModal('$($sc.entity)', 'Script', '$([System.Web.HttpUtility]::JavaScriptStringEncode($sc.name))')" title="View/Edit Script YAML &amp; HA Deep Link">
                                    <span class="icon">📝</span> YAML
                                </button>
                                <button class="action-btn-inspect" style="font-size: 11px; padding: 3px 8px;" onclick="openEntityRenameModal('$($sc.entity)')" title="Rename Script and cascade references">
                                    <span class="icon">✏️</span> Rename
                                </button>
                                <button class="action-btn-inspect" style="font-size: 11px; padding: 3px 8px; background: rgba(248, 81, 73, 0.15); color: #ff7b72; border-color: rgba(248, 81, 73, 0.35);" onclick="openAutomationDeleteModal('$($sc.entity)', 'Script', '$([System.Web.HttpUtility]::JavaScriptStringEncode($sc.name))')" title="Delete Script">
                                    <span class="icon">🗑️</span> Delete
                                </button>
                            </td>
                        </tr>
"@
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 6: HELPERS -->
        <div id="tab-helpers" class="tab-content">
            <div class="table-container">
                <table class="scrollable-table" id="table-helpers">
                    <thead>
                        <tr>
                            <th onclick="sortTable('table-helpers', 0)">Helper / Primitive Name <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-helpers', 1)">Entity ID <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-helpers', 2)">Primitive Type <span class="sort-icon">⇅</span></th>
                            <th>Value / State</th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($hl in $inv.helpers_and_virtual) {
    $html += @"
                        <tr>
                            <td><strong>$($hl.name)</strong></td>
                            <td class="code-cell">$($hl.entity)</td>
                            <td><span class="badge badge-info">$($hl.type)</span></td>
                            <td>$($hl.state)</td>
                        </tr>
"@
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 7: DOMAINS -->
        <div id="tab-domains" class="tab-content">
            <div class="table-container">
                <table class="scrollable-table" id="table-domains">
                    <thead>
                        <tr>
                            <th onclick="sortTable('table-domains', 0)">Domain <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-domains', 1)">Total Entity Count <span class="sort-icon">⇅</span></th>
                            <th>Role Description</th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($dom in $inv.domain_distribution.PSObject.Properties) {
    $html += @"
                        <tr>
                            <td><strong class="code-cell">$($dom.Name)</strong></td>
                            <td class="code-cell"><strong>$($dom.Value)</strong></td>
                            <td>Domain partition</td>
                        </tr>
"@
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 8: TOOLS & ACTIVE HELP -->
        <div id="tab-tools" class="tab-content">
            <div style="display: flex; gap: 10px; margin-bottom: 14px; align-items: center;">
                <span style="font-size: 13px; font-weight: 600; color: var(--text-secondary);">Filter by Role:</span>
                <button class="badge badge-info" style="cursor: pointer; padding: 6px 14px; font-size: 12px;" id="btn-filter-tool-all" onclick="filterToolRole('all', this)">All Tools</button>
                <button class="badge badge-muted" style="cursor: pointer; padding: 6px 14px; font-size: 12px;" id="btn-filter-tool-op" onclick="filterToolRole('Operator', this)">Operator Tools</button>
                <button class="badge badge-muted" style="cursor: pointer; padding: 6px 14px; font-size: 12px;" id="btn-filter-tool-dev" onclick="filterToolRole('Developer', this)">Developer Tools</button>
            </div>
            <div class="table-container">
                <table class="scrollable-table" id="table-tools">
                    <thead>
                        <tr>
                            <th onclick="sortTable('table-tools', 0)" style="width: 100px;">Role <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-tools', 1)" style="min-width: 190px;">Recognized Chat Command <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-tools', 2)" style="min-width: 210px;">Tool Script Name <span class="sort-icon">⇅</span></th>
                            <th onclick="sortTable('table-tools', 3)" style="min-width: 160px;">Category / Scope <span class="sort-icon">⇅</span></th>
                            <th>Purpose &amp; Active Guidance</th>
                            <th>CLI Syntax</th>
                            <th style="min-width: 220px; text-align: center;">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
"@

if ($inv.PSObject.Properties['tools_catalog']) {
    $toolIndex = 0
    foreach ($t in $inv.tools_catalog) {
        $roleBadge = if ($t.role -eq 'Operator') { 'badge-success' } else { 'badge-info' }
        $tRole = $t.role
        $cmdText = $t.chat_command
        $tJsName = [System.Web.HttpUtility]::JavaScriptStringEncode($t.name)
        $tIdx = $toolIndex
        $toolIndex++
        $receiptBtnHtml = if ($t.name -eq 'Test-RepoReadiness.ps1') {
            "<button class=`"action-btn-inspect`" style=`"background: rgba(46, 160, 67, 0.15); color: #7ee787; border-color: rgba(46, 160, 67, 0.35);`" onclick=`"openReadinessModal()`" title=`"Inspect Quality Gate Readiness Receipt`"><span class=`"icon`">🛡️</span> Receipt</button>"
        } else { "" }
        $html += @"
                        <tr class="tool-row clickable-row" data-role="$tRole" onclick="openToolHelpModal($tIdx)">
                            <td><span class="badge $roleBadge">$tRole</span></td>
                            <td><span class="badge badge-warning" style="font-family: monospace; font-size: 12px; letter-spacing: 0.2px;">"$cmdText"</span></td>
                            <td><strong>$($t.name)</strong></td>
                            <td><span class="badge badge-muted">$($t.category)</span></td>
                            <td class="allow-wrap">$([System.Web.HttpUtility]::HtmlEncode($t.description))</td>
                            <td class="code-cell">$($t.script_path)</td>
                            <td style="text-align: center; white-space: nowrap;" onclick="event.stopPropagation()">
                                <button class="action-btn-inspect" style="background: rgba(35, 134, 54, 0.2); color: #7ee787; border-color: rgba(46, 160, 67, 0.4);" onclick="openToolRunModal($tIdx)" title="Configure parameters and execute tool"><span class="icon">▶️</span> Run</button>
                                $receiptBtnHtml
                                <button class="action-btn-inspect" style="background: rgba(56, 139, 253, 0.15); color: var(--accent); border-color: rgba(56, 139, 253, 0.35);" onclick="openToolHelpModal($tIdx)" title="View synopsis & CLI parameter help"><span class="icon">❓</span> Help</button>
                                <button class="action-btn-inspect" style="background: rgba(163, 113, 247, 0.15); color: #d2a8ff; border-color: rgba(163, 113, 247, 0.35);" onclick="openToolLastLog('$tJsName')" title="Open latest execution log in text editor"><span class="icon">📜</span> Logs</button>
                            </td>
                        </tr>
"@
    }
} else {
    $html += @"
                        <tr><td colspan="7" style="color: var(--text-muted);">No tools catalog embedded. Run Update-HaInventory.ps1 to refresh.</td></tr>
"@
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

    </div>

    <!-- Secondary Drill-Down Modal -->
    <div id="entityModal" class="modal-overlay" onclick="closeModalOnOverlay(event)">
        <div class="modal-box">
            <button class="modal-close" onclick="closeEntityModal()">&times;</button>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span class="badge badge-info" id="modalEntityDomainBadge">Entity Details</span>
            </div>
            <div class="modal-title" id="modalEntityName" style="margin-top: 6px; font-size: 20px; font-weight: 700; color: var(--text-primary);">Entity Friendly Name</div>
            <div class="modal-subtitle" id="modalEntityId" style="font-size: 13px; color: var(--accent); font-family: 'JetBrains Mono', monospace; margin-bottom: 16px;">sensor.example_entity_id</div>

            <div class="detail-grid">
                <div class="detail-item">
                    <div class="detail-item-label">Current State / Value</div>
                    <div class="detail-item-value" id="modalEntityState">-</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Device Class</div>
                    <div class="detail-item-value" id="modalEntityClass">-</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Associated Physical Device</div>
                    <div class="detail-item-value" id="modalEntityDevice">-</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Manufacturer &amp; Model</div>
                    <div class="detail-item-value" id="modalEntityMfg">-</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Room / Area</div>
                    <div class="detail-item-value" id="modalEntityArea">-</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Domain Partition</div>
                    <div class="detail-item-value" id="modalEntityDomain">-</div>
                </div>
            </div>

            <h4 style="margin-top: 15px; margin-bottom: 8px; color: var(--text-secondary); font-size: 13px; text-transform: uppercase;">Raw Custom Attributes &amp; Telemetry</h4>
            <div style="max-height: 220px; overflow-y: auto; border: 1px solid var(--border); border-radius: 8px;">
                <table class="attributes-table">
                    <thead>
                        <tr>
                            <th style="width: 35%;">Attribute Key</th>
                            <th>Value</th>
                        </tr>
                    </thead>
                    <tbody id="modalAttributesBody">
                    </tbody>
                </table>
            </div>

            <div style="margin-top: 18px; display: flex; justify-content: flex-end; gap: 10px;">
                <button class="action-btn-inspect" id="modalScanParentBtn" onclick="scanDeviceFromModal()"><span class="icon">🔍</span> Deep Scan Parent Device</button>
                <button class="action-btn-inspect" id="modalRenameEntityBtn" style="background: rgba(235, 148, 56, 0.15); color: #f0883e; border-color: rgba(235, 148, 56, 0.35);" onclick="renameEntityFromModal()"><span class="icon">✏️</span> Rename Entity</button>
            </div>
        </div>
    </div>

    <!-- Deep Diagnostic Scan Modal -->
    <div id="scanModal" class="modal-overlay" onclick="closeScanModalOnOverlay(event)">
        <div class="modal-box" style="max-width: 950px;">
            <button class="modal-close" onclick="closeScanModal()">&times;</button>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span class="badge badge-warning">Diagnostic Deep Scan</span>
                <span id="scanChatBadge" class="badge badge-info" style="font-family: monospace; font-size: 12px;">Chat: "Scan Shelly Devices"</span>
            </div>
            <div class="modal-title" id="scanModalTitle" style="margin-top: 8px; font-size: 20px; font-weight: 700; color: var(--text-primary);">Device Deep Diagnostic</div>
            <div class="modal-subtitle" id="scanModalSubtitle" style="font-size: 13px; color: var(--accent); font-family: 'JetBrains Mono', monospace; margin-bottom: 16px;">Child entities, parameters, and telemetry</div>

            <div id="scanModalHardwareInfo" class="detail-grid">
            </div>

            <h4 style="margin-top: 18px; margin-bottom: 8px; color: var(--text-secondary); font-size: 13px; text-transform: uppercase;">Child Entities &amp; Live Telemetry Probes</h4>
            <div style="max-height: 320px; overflow-y: auto; border: 1px solid var(--border); border-radius: 8px;">
                <table class="scrollable-table">
                    <thead>
                        <tr>
                            <th style="width: 140px;">Domain</th>
                            <th>Entity Name</th>
                            <th>Entity ID</th>
                            <th>Current State</th>
                            <th>Device Class</th>
                            <th style="width: 90px; text-align: center;">Action</th>
                        </tr>
                    </thead>
                    <tbody id="scanEntitiesBody">
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- Device Renaming & Cascading Subpanel Modal (CRP-146) -->
    <div id="deviceRenameModal" class="modal-overlay" onclick="closeDeviceRenameModalOnOverlay(event)">
        <div class="modal-box" style="max-width: 1050px;">
            <button class="modal-close" onclick="closeDeviceRenameModal()">&times;</button>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span class="badge badge-warning">Device Renaming Action Subpanel</span>
                <span class="badge badge-purple" id="devRenameModeBadge">Pattern-Based Propagation</span>
                <span class="badge badge-info" id="devRenameIdBadge" style="font-family: monospace; font-size: 11px;">ID: -</span>
            </div>
            <div class="modal-title" id="devRenameModalTitle" style="margin-top: 8px; font-size: 20px; font-weight: 700; color: var(--text-primary);">✏️ Rename Device: ...</div>
            <div class="modal-subtitle" id="devRenameModalSubtitle" style="font-size: 13px; color: var(--text-secondary); margin-bottom: 16px;">Configure standardized naming pattern and cascade changes to child entities &amp; references.</div>

            <!-- Configuration Grid -->
            <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px; margin-bottom: 16px;">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 12px;">
                    <div>
                        <label style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">Naming Pattern Preset</label>
                        <select id="devPatternSelect" class="col-filter-select" style="width: 100%; margin-top: 4px; padding: 8px;" onchange="applyDevicePattern()">
                            <option value="area_device">&lt;Area&gt; &lt;Device&gt; (e.g. "Kueche SH1")</option>
                            <option value="area_mfg_model">&lt;Area&gt; &lt;Manufacturer&gt; &lt;Model&gt; (e.g. "Kueche Shelly Plus 1PM")</option>
                            <option value="area_custom">&lt;Area&gt; &lt;Custom Name&gt;</option>
                            <option value="custom">Freeform Custom Name</option>
                        </select>
                    </div>
                    <div>
                        <label style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">Target Area / Room</label>
                        <select id="devTargetAreaSelect" class="col-filter-select" style="width: 100%; margin-top: 4px; padding: 8px;" onchange="applyDevicePattern()">
                            $areaOptionsHtml
                        </select>
                    </div>
                </div>

                <div style="display: grid; grid-template-columns: 2fr 1fr; gap: 14px;">
                    <div>
                        <label style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">Proposed Device Name</label>
                        <input type="text" id="devProposedNameInput" class="tool-param-input" style="width: 100%; margin-top: 4px; font-size: 14px; font-weight: 600;" oninput="updateDeviceChildPreviews()">
                    </div>
                    <div>
                        <label style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">Labels / Tags (comma-separated)</label>
                        <input type="text" id="devProposedLabelsInput" class="tool-param-input" style="width: 100%; margin-top: 4px;" placeholder="Smart, Lighting, Relay...">
                    </div>
                </div>

                <div style="margin-top: 12px; display: flex; align-items: center; justify-content: space-between; border-top: 1px solid var(--border); padding-top: 10px;">
                    <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-weight: 600; color: var(--accent);">
                        <input type="checkbox" id="devCascadeChildrenCheck" checked onchange="toggleCascadeChildren()" style="width: 16px; height: 16px; cursor: pointer;">
                        <span>Cascade rename to all child entities (Standard HA format)</span>
                    </label>
                    <span id="devChildEntitiesCountBadge" class="badge badge-info">0 Child Entities</span>
                </div>
            </div>

            <!-- Reverse Dependency & Impact Scanner -->
            <div id="devImpactBox" style="background: rgba(235, 148, 56, 0.08); border: 1px solid rgba(235, 148, 56, 0.3); border-radius: 8px; padding: 12px; margin-bottom: 16px;">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-size: 12px; font-weight: 700; color: #f0883e;">⚠️ Reverse-Dependency Reference Scanner</span>
                    <span id="devImpactSummaryBadge" class="badge badge-warning">Scanning...</span>
                </div>
                <div id="devImpactDetailsList" style="font-size: 11px; color: var(--text-primary); margin-top: 6px; max-height: 80px; overflow-y: auto;">
                    No breaking automation or script dependencies detected.
                </div>
            </div>

            <!-- Child Entities Diff & Impact Table -->
            <div id="devChildrenDiffContainer" style="margin-bottom: 16px;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                    <span style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary); letter-spacing: 0.5px;">Visual Impact &amp; Entity ID Diff Preview</span>
                    <span style="font-size: 11px; color: var(--text-muted);">Double-check proposed entity IDs before staging</span>
                </div>
                <div style="max-height: 220px; overflow-y: auto; border: 1px solid var(--border); border-radius: 8px;">
                    <table class="scrollable-table" id="devChildrenDiffTable">
                        <thead>
                            <tr>
                                <th style="width: 100px;">Domain</th>
                                <th>Current Friendly Name</th>
                                <th>Proposed Friendly Name</th>
                                <th>Current Entity ID</th>
                                <th>Proposed Entity ID</th>
                                <th style="width: 80px; text-align: center;">Refs</th>
                            </tr>
                        </thead>
                        <tbody id="devChildrenDiffBody">
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Pre-Change Safety & Deep Links -->
            <div style="background: var(--bg-secondary); border: 1px solid var(--border); border-radius: 8px; padding: 12px; margin-bottom: 16px;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                    <span style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">🔒 Pre-Change Home Assistant Safety Gate</span>
                    <div style="display: flex; gap: 8px;">
                        <a id="devHaDeepLinkBtn" href="http://192.168.10.6:8123/config/devices/dashboard" target="_blank" class="action-btn-inspect" style="font-size: 11px; padding: 4px 10px; background: rgba(56, 139, 253, 0.15); color: var(--accent); border-color: rgba(56, 139, 253, 0.35); text-decoration: none;">🌐 Open Device in HA</a>
                        <a href="http://192.168.10.6:8123/config/backup" target="_blank" class="action-btn-inspect" style="font-size: 11px; padding: 4px 10px; background: rgba(35, 134, 54, 0.15); color: #7ee787; border-color: rgba(46, 160, 67, 0.35); text-decoration: none;">🛡️ HA Backup Settings</a>
                    </div>
                </div>
                <div style="display: flex; gap: 16px; font-size: 12px; color: var(--text-secondary);">
                    <label style="display: flex; align-items: center; gap: 6px; cursor: pointer;">
                        <input type="radio" name="devBackupOption" value="verified" checked>
                        <span>Manual Backup Verified</span>
                    </label>
                    <label style="display: flex; align-items: center; gap: 6px; cursor: pointer;">
                        <input type="radio" name="devBackupOption" value="staging">
                        <span>Local Dry Run / Staging Only</span>
                    </label>
                </div>
            </div>

            <!-- Actions Footer -->
            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 18px;">
                <button class="action-btn-inspect" style="background: rgba(163, 113, 247, 0.15); color: #d2a8ff; border-color: rgba(163, 113, 247, 0.35);" onclick="copyDeviceHaPayload()"><span class="icon">📋</span> Copy HA Payload &amp; Deep Link</button>
                <div style="display: flex; gap: 10px;">
                    <button class="btn-reset" onclick="closeDeviceRenameModal()">Cancel</button>
                    <button class="action-btn-inspect" style="background: rgba(56, 139, 253, 0.2); color: var(--accent); border-color: rgba(56, 139, 253, 0.4);" onclick="stageDeviceRenameTx(true)"><span class="icon">💾</span> Stage Transaction</button>
                    <button class="action-btn-inspect" style="background: rgba(35, 134, 54, 0.25); color: #7ee787; border-color: rgba(46, 160, 67, 0.5); font-weight: 700; padding: 8px 18px;" onclick="executeDeviceRenameTx()"><span class="icon">⚡</span> Execute Cascade</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Entity Renaming & Cascading Subpanel Modal (CRP-146) -->
    <div id="entityRenameModal" class="modal-overlay" onclick="closeEntityRenameModalOnOverlay(event)">
        <div class="modal-box" style="max-width: 880px;">
            <button class="modal-close" onclick="closeEntityRenameModal()">&times;</button>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span class="badge badge-warning">Entity Renaming Action Subpanel</span>
                <span class="badge badge-info" id="entRenameDomainBadge">DOMAIN</span>
            </div>
            <div class="modal-title" id="entRenameModalTitle" style="margin-top: 8px; font-size: 20px; font-weight: 700; color: var(--text-primary);">✏️ Rename Entity: ...</div>
            <div class="modal-subtitle" id="entRenameModalSubtitle" style="font-size: 13px; color: var(--accent); font-family: 'JetBrains Mono', monospace; margin-bottom: 16px;">sensor.example</div>

            <!-- Configuration Grid -->
            <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px; margin-bottom: 16px;">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 12px;">
                    <div>
                        <label style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">Naming Pattern Preset</label>
                        <select id="entPatternSelect" class="col-filter-select" style="width: 100%; margin-top: 4px; padding: 8px;" onchange="applyEntityPattern()">
                            <option value="domain_area_dev_name">&lt;Domain&gt;.&lt;Area&gt;_&lt;Device&gt;_&lt;Name&gt;</option>
                            <option value="domain_area_name">&lt;Domain&gt;.&lt;Area&gt;_&lt;Name&gt;</option>
                            <option value="domain_dev_name">&lt;Domain&gt;.&lt;Device&gt;_&lt;Name&gt;</option>
                            <option value="custom">Freeform Custom</option>
                        </select>
                    </div>
                    <div>
                        <label style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">Associated Device / Area</label>
                        <div id="entRenameParentInfo" style="margin-top: 6px; font-size: 12px; color: var(--text-primary); font-weight: 600;">-</div>
                    </div>
                </div>

                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
                    <div>
                        <label style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">Proposed Friendly Name</label>
                        <input type="text" id="entProposedNameInput" class="tool-param-input" style="width: 100%; margin-top: 4px; font-size: 14px; font-weight: 600;" oninput="updateEntityIdFromFriendlyName()">
                    </div>
                    <div>
                        <label style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">Proposed Entity ID</label>
                        <input type="text" id="entProposedIdInput" class="tool-param-input" style="width: 100%; margin-top: 4px; font-family: monospace; color: #7ee787; font-size: 13px;">
                    </div>
                </div>
            </div>

            <!-- Reverse Dependency & Impact Scanner -->
            <div id="entImpactBox" style="background: rgba(235, 148, 56, 0.08); border: 1px solid rgba(235, 148, 56, 0.3); border-radius: 8px; padding: 12px; margin-bottom: 16px;">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-size: 12px; font-weight: 700; color: #f0883e;">⚠️ Reverse-Dependency Reference Scanner</span>
                    <span id="entImpactSummaryBadge" class="badge badge-warning">Scanning...</span>
                </div>
                <div id="entImpactDetailsList" style="font-size: 11px; color: var(--text-primary); margin-top: 6px; max-height: 80px; overflow-y: auto;">
                    No references detected in automations or scripts.
                </div>
            </div>

            <!-- Pre-Change Safety & Deep Links -->
            <div style="background: var(--bg-secondary); border: 1px solid var(--border); border-radius: 8px; padding: 12px; margin-bottom: 16px;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                    <span style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">🔒 Pre-Change Home Assistant Safety Gate</span>
                    <div style="display: flex; gap: 8px;">
                        <a id="entHaDeepLinkBtn" href="http://192.168.10.6:8123/config/entities" target="_blank" class="action-btn-inspect" style="font-size: 11px; padding: 4px 10px; background: rgba(56, 139, 253, 0.15); color: var(--accent); border-color: rgba(56, 139, 253, 0.35); text-decoration: none;">🌐 Open Entity in HA</a>
                        <a href="http://192.168.10.6:8123/config/backup" target="_blank" class="action-btn-inspect" style="font-size: 11px; padding: 4px 10px; background: rgba(35, 134, 54, 0.15); color: #7ee787; border-color: rgba(46, 160, 67, 0.35); text-decoration: none;">🛡️ HA Backup Settings</a>
                    </div>
                </div>
                <div style="font-size: 11px; color: var(--text-muted);">Ensure Home Assistant backup is taken or verified prior to updating live entity IDs.</div>
            </div>

            <!-- Actions Footer -->
            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 18px;">
                <button class="action-btn-inspect" style="background: rgba(163, 113, 247, 0.15); color: #d2a8ff; border-color: rgba(163, 113, 247, 0.35);" onclick="copyEntityHaPayload()"><span class="icon">📋</span> Copy HA Payload &amp; Deep Link</button>
                <div style="display: flex; gap: 10px;">
                    <button class="btn-reset" onclick="closeEntityRenameModal()">Cancel</button>
                    <button class="action-btn-inspect" style="background: rgba(56, 139, 253, 0.2); color: var(--accent); border-color: rgba(56, 139, 253, 0.4);" onclick="stageEntityRenameTx(true)"><span class="icon">💾</span> Stage Transaction</button>
                    <button class="action-btn-inspect" style="background: rgba(35, 134, 54, 0.25); color: #7ee787; border-color: rgba(46, 160, 67, 0.5); font-weight: 700; padding: 8px 18px;" onclick="executeEntityRenameTx()"><span class="icon">⚡</span> Execute Cascade</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Automation & Script YAML Inspection / Editor Modal (CRP-150) -->
    <div id="automationYamlModal" class="modal-overlay" onclick="closeAutomationYamlModalOnOverlay(event)">
        <div class="modal-box" style="max-width: 820px;">
            <button class="modal-close" onclick="closeAutomationYamlModal()">&times;</button>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span class="badge badge-info" id="autoYamlTypeBadge">Automation</span>
                <span class="badge badge-success" id="autoYamlStateBadge">Active</span>
            </div>
            <div class="modal-title" id="autoYamlModalTitle" style="margin-top: 8px; font-size: 20px; font-weight: 700; color: var(--text-primary);">📝 Edit YAML: ...</div>
            <div class="modal-subtitle" id="autoYamlModalSubtitle" style="font-size: 13px; color: var(--accent); font-family: 'JetBrains Mono', monospace; margin-bottom: 14px;">automation.example</div>

            <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 12px; margin-bottom: 14px;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                    <span style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary);">YAML Definition &amp; Config Schema</span>
                    <span style="font-size: 11px; color: var(--text-muted);">Home Assistant OS Core Registry</span>
                </div>
                <textarea id="autoYamlContentArea" class="tool-param-input" style="width: 100%; height: 260px; font-family: 'JetBrains Mono', monospace; font-size: 12px; line-height: 1.4; resize: vertical; box-sizing: border-box; background: var(--bg-secondary); color: var(--text-primary); border: 1px solid var(--border); border-radius: 6px; padding: 10px;" spellcheck="false"></textarea>
            </div>

            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 14px;">
                <button class="action-btn-inspect" style="background: rgba(163, 113, 247, 0.15); color: #d2a8ff; border-color: rgba(163, 113, 247, 0.35);" onclick="copyAutomationYaml()"><span class="icon">📋</span> Copy YAML</button>
                <div style="display: flex; gap: 10px;">
                    <button class="btn-reset" onclick="closeAutomationYamlModal()">Close</button>
                    <a id="autoYamlHaDeepLinkBtn" href="#" target="_blank" class="action-btn-inspect" style="background: rgba(56, 139, 253, 0.2); color: var(--accent); border-color: rgba(56, 139, 253, 0.4); text-decoration: none;"><span class="icon">🌐</span> Open in Home Assistant UI</a>
                </div>
            </div>
        </div>
    </div>

    <!-- Automation & Script Safe Deletion Modal (CRP-150) -->
    <div id="automationDeleteModal" class="modal-overlay" onclick="closeAutomationDeleteModalOnOverlay(event)">
        <div class="modal-box" style="max-width: 680px;">
            <button class="modal-close" onclick="closeAutomationDeleteModal()">&times;</button>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span class="badge badge-danger">Confirm Deletion</span>
                <span class="badge badge-info" id="autoDeleteTypeBadge">Automation</span>
            </div>
            <div class="modal-title" id="autoDeleteModalTitle" style="margin-top: 8px; font-size: 20px; font-weight: 700; color: #ff7b72;">🗑️ Delete Item: ...</div>
            <div class="modal-subtitle" id="autoDeleteModalSubtitle" style="font-size: 13px; color: var(--text-secondary); font-family: 'JetBrains Mono', monospace; margin-bottom: 14px;">automation.example</div>

            <div style="background: rgba(248, 81, 73, 0.08); border: 1px solid rgba(248, 81, 73, 0.3); border-radius: 8px; padding: 12px; margin-bottom: 14px;">
                <div style="font-size: 12px; font-weight: 700; color: #ff7b72; margin-bottom: 6px;">⚠️ Reverse-Dependency Reference Scan</div>
                <div id="autoDeleteImpactSummary" style="font-size: 12px; color: var(--text-primary); line-height: 1.4;">Scanning references...</div>
            </div>

            <div style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 12px; margin-bottom: 16px;">
                <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 12px; color: var(--text-primary); font-weight: 600;">
                    <input type="checkbox" id="autoDeleteConfirmCheckbox" onchange="toggleAutoDeleteConfirmBtn()">
                    <span>I confirm deletion of this component from Home Assistant.</span>
                </label>
            </div>

            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 14px;">
                <button class="btn-reset" onclick="closeAutomationDeleteModal()">Cancel</button>
                <div style="display: flex; gap: 10px;">
                    <a id="autoDeleteHaDeepLinkBtn" href="#" target="_blank" class="action-btn-inspect" style="background: rgba(56, 139, 253, 0.2); color: var(--accent); border-color: rgba(56, 139, 253, 0.4); text-decoration: none;"><span class="icon">🌐</span> Delete in HA Settings</a>
                    <button id="autoDeleteExecuteBtn" class="action-btn-inspect" style="background: rgba(248, 81, 73, 0.25); color: #ff7b72; border-color: rgba(248, 81, 73, 0.5); font-weight: 700; opacity: 0.5; pointer-events: none;" onclick="executeAutomationDelete()"><span class="icon">🗑️</span> Execute Deletion</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Tool Run Modal Dialog -->
    <div id="toolRunModal" class="modal-overlay" onclick="closeToolRunModalOnOverlay(event)">
        <div class="modal-box" style="max-width: 860px;">
            <button class="modal-close" onclick="closeToolRunModal()">&times;</button>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span class="badge badge-success" id="toolRunRoleBadge">Operator Tool</span>
                <span class="badge badge-warning" id="toolRunScopeBadge">HaSSD06_Inventory</span>
            </div>
            <div class="modal-title" id="toolRunTitle" style="margin-top: 8px; font-size: 20px; font-weight: 700; color: var(--text-primary);">▶ Run Tool: Update-HaInventory.ps1</div>
            <div class="modal-subtitle" id="toolRunDesc" style="font-size: 13px; color: var(--text-secondary); margin-bottom: 16px;">Description</div>

            <!-- Parameters Container -->
            <div id="toolRunParamsContainer" style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px; margin-bottom: 16px;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                    <span style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary); letter-spacing: 0.5px;">Configurable Parameters</span>
                    <button class="btn-reset" onclick="clearAllToolParams()" style="font-size: 11px; padding: 3px 8px; color: var(--danger);">✕ Clear All Parameters</button>
                </div>
                <div id="toolRunParamsList"></div>
            </div>

            <!-- Command Line Preview -->
            <div style="margin-bottom: 14px;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                    <label style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary); letter-spacing: 0.5px;">Command Line Preview &amp; Custom Arguments</label>
                    <button class="btn-copy-eid" onclick="copyToolCommandPreview()" style="font-size: 11px; padding: 2px 6px;">📋 Copy</button>
                </div>
                <textarea id="toolRunCmdPreview" style="width: 100%; background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 10px 12px; font-family: 'JetBrains Mono', monospace; font-size: 12px; color: #7ee787; outline: none; resize: vertical; min-height: 55px;" oninput="syncCustomCommandInput()"></textarea>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 18px;">
                <button class="btn-reset" onclick="closeToolRunModal()">Cancel</button>
                <button class="action-btn-inspect" style="background: rgba(35, 134, 54, 0.25); color: #7ee787; border-color: rgba(46, 160, 67, 0.5); font-weight: 700; padding: 8px 18px; font-size: 13px;" onclick="executeToolRun()"><span class="icon">⚡</span> Dispatch Execution</button>
            </div>
        </div>
    </div>

    <!-- Tool Help Modal Dialog -->
    <div id="toolHelpModal" class="modal-overlay" onclick="closeToolHelpModalOnOverlay(event)">
        <div class="modal-box" style="max-width: 860px;">
            <button class="modal-close" onclick="closeToolHelpModal()">&times;</button>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span class="badge badge-info" id="toolHelpRoleBadge">Tool Synopsis</span>
                <span class="badge badge-warning" id="toolHelpScopeBadge">HaSSD06</span>
            </div>
            <div class="modal-title" id="toolHelpTitle" style="margin-top: 8px; font-size: 20px; font-weight: 700; color: var(--text-primary);">❓ Tool Help: Update-HaInventory.ps1</div>
            <div class="modal-subtitle" id="toolHelpChatCmd" style="font-size: 13px; color: var(--accent); font-family: 'JetBrains Mono', monospace; margin-bottom: 16px;">Chat Command: "Update Inventory"</div>

            <div class="detail-grid">
                <div class="detail-item">
                    <div class="detail-item-label">Functional Role</div>
                    <div class="detail-item-value" id="toolHelpRole">-</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Category / Area</div>
                    <div class="detail-item-value" id="toolHelpCategory">-</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Risk Level / Safety</div>
                    <div class="detail-item-value" id="toolHelpRisk">-</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Script Path</div>
                    <div class="detail-item-value code-cell" id="toolHelpPath">-</div>
                </div>
            </div>

            <div style="margin-top: 14px; background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 14px;">
                <div style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary); margin-bottom: 6px;">Purpose &amp; Active Guidance</div>
                <div id="toolHelpDesc" style="font-size: 13px; line-height: 1.5; color: var(--text-primary);"></div>
            </div>

            <div style="margin-top: 14px;">
                <div style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary); margin-bottom: 6px;">CLI Execution Syntax</div>
                <div id="toolHelpSyntaxBox" class="code-cell" style="background: var(--bg-primary); border: 1px solid var(--border); border-radius: 8px; padding: 10px 14px; font-size: 12px; color: #7ee787; word-break: break-all;"></div>
            </div>

            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 20px;">
                <button class="action-btn-inspect" style="background: rgba(163, 113, 247, 0.15); color: #d2a8ff; border-color: rgba(163, 113, 247, 0.35);" id="toolHelpLogBtn" onclick="openToolLastLogFromHelp()"><span class="icon">📜</span> View Last Log</button>
                <div style="display: flex; gap: 10px;">
                    <button class="btn-reset" onclick="closeToolHelpModal()">Close</button>
                    <button class="action-btn-inspect" style="background: rgba(35, 134, 54, 0.25); color: #7ee787; border-color: rgba(46, 160, 67, 0.5); font-weight: 700;" id="toolHelpRunBtn" onclick="runToolFromHelp()"><span class="icon">▶️</span> Run Tool</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Quality Gate Readiness Modal Dialog (CRP-152) -->
    <div id="readinessModal" class="modal-overlay" onclick="closeReadinessModalOnOverlay(event)">
        <div class="modal-box" style="max-width: 860px;">
            <button class="modal-close" onclick="closeReadinessModal()">&times;</button>
            <div style="display: flex; align-items: center; gap: 10px;">
                <span class="badge $readinessBadgeClass">$readinessIcon $readinessStatusText</span>
                <span class="badge badge-info">$Instance Quality Gates</span>
            </div>
            <div class="modal-title" style="margin-top: 8px; font-size: 20px; font-weight: 700; color: var(--text-primary);">🛡️ Quality Gate Readiness Inspection</div>
            <div class="modal-subtitle" style="font-size: 13px; color: var(--text-secondary); margin-bottom: 16px;">Verified against authoritative LCM Quality Gates &bull; $readinessTimestampText &bull; Duration: $readinessDurationText</div>

            <div class="detail-grid">
                <div class="detail-item">
                    <div class="detail-item-label">Repository / Scope</div>
                    <div class="detail-item-value">${Instance}_Inventory</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Passed Gates</div>
                    <div class="detail-item-value" style="font-weight: 700; color: $(if ($readinessPassed) { '#7ee787' } else { '#ff7b72' });">$readinessPassedCount / $readinessTotalCount Quality Gates</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Verification Duration</div>
                    <div class="detail-item-value">$readinessDurationText</div>
                </div>
                <div class="detail-item">
                    <div class="detail-item-label">Receipt Schema File</div>
                    <div class="detail-item-value code-cell" style="font-size: 11px;">data/readiness/latest_readiness.json</div>
                </div>
            </div>

            <div style="margin-top: 14px;">
                <div style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-secondary); margin-bottom: 8px; letter-spacing: 0.5px;">Gate Execution Breakdown</div>
                <div style="max-height: 280px; overflow-y: auto; padding-right: 4px;">
                    $readinessGatesHtml
                </div>
            </div>

            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 20px; border-top: 1px solid var(--border); padding-top: 14px;">
                <button class="action-btn-inspect" style="background: rgba(56, 139, 253, 0.15); color: var(--accent); border-color: rgba(56, 139, 253, 0.35);" onclick="copyReadinessJson()"><span class="icon">📋</span> Copy Receipt JSON</button>
                <div style="display: flex; gap: 10px;">
                    <button class="btn-reset" onclick="closeReadinessModal()">Close</button>
                    <button class="action-btn-inspect" style="background: rgba(163, 113, 247, 0.15); color: #d2a8ff; border-color: rgba(163, 113, 247, 0.35);" onclick="openToolLastLog('Test-RepoReadiness.ps1')"><span class="icon">📜</span> View Log</button>
                    <button class="action-btn-inspect" style="background: rgba(35, 134, 54, 0.25); color: #7ee787; border-color: rgba(46, 160, 67, 0.5); font-weight: 700;" onclick="runReadinessLiveCheck()"><span class="icon">▶️</span> Run Live Check</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Action Log Drawer & Overlay (CRP-151) -->
    <div id="actionDrawerOverlay" class="action-drawer-overlay" onclick="closeActionLogDrawer()"></div>
    <div id="actionLogDrawer" class="action-drawer">
        <div class="drawer-header">
            <div>
                <div class="drawer-title"><span>📜</span> Subsystem Action Log</div>
                <div style="font-size: 11px; color: var(--text-secondary); margin-top: 2px;">Chronological audit &amp; execution stream &bull; <span id="drawerActionCount">0</span> entries</div>
            </div>
            <button class="modal-close" style="position: static; width: 28px; height: 28px;" onclick="closeActionLogDrawer()">&times;</button>
        </div>
        <div style="padding: 10px 16px; background: var(--bg-primary); border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; gap: 8px;">
            <div style="display: flex; gap: 6px; overflow-x: auto; padding-bottom: 2px;">
                <button class="badge badge-info" style="cursor: pointer; padding: 3px 8px; font-size: 11px;" id="filter-act-all" onclick="filterActionType('ALL', this)">All</button>
                <button class="badge badge-muted" style="cursor: pointer; padding: 3px 8px; font-size: 11px;" id="filter-act-rename" onclick="filterActionType('CASCADE_RENAME', this)">Renames</button>
                <button class="badge badge-muted" style="cursor: pointer; padding: 3px 8px; font-size: 11px;" id="filter-act-service" onclick="filterActionType('SERVICE', this)">Services</button>
                <button class="badge badge-muted" style="cursor: pointer; padding: 3px 8px; font-size: 11px;" id="filter-act-tools" onclick="filterActionType('TOOL', this)">Tools</button>
            </div>
            <div style="display: flex; gap: 6px;">
                <button class="action-btn-inspect" style="padding: 3px 8px; font-size: 11px;" onclick="copyActionLogsJson()" title="Copy all actions as JSON"><span class="icon">📋</span></button>
                <button class="action-btn-inspect" style="padding: 3px 8px; font-size: 11px;" onclick="fetchDaemonActionLogs()" title="Refresh actions from REST daemon"><span class="icon">🔄</span></button>
            </div>
        </div>
        <div class="drawer-body" id="actionLogContainer">
            <div style="color: var(--text-muted); text-align: center; padding: 30px 10px; font-size: 12px;">
                No actions logged in this session yet. Actions triggered in the dashboard or via tools will appear here in real time.
            </div>
        </div>
    </div>

    <!-- Hidden Runner Frame & Toast Notification -->
    <iframe id="lcm-runner-frame" style="display: none;"></iframe>
    <div class="toast" id="toast"></div>

    <script>
        const INVENTORY_DATA = $embeddedJson;
        const READINESS_DATA = $embeddedReadinessJson;
        let currentModalDeviceId = null;

        function showTab(tabId) {
            document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
            document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
            const target = document.getElementById(tabId);
            if (target) { target.classList.add('active'); }
            const btn = document.getElementById('btn-' + tabId);
            if (btn) { btn.classList.add('active'); }
            updateItemCount();
        }

        function matchQuery(text, query) {
            if (!query || query === 'All') return true;
            const target = (text || '').toLowerCase();
            const q = query.toLowerCase().trim();
            if (!q) return true;

            const tokens = q.split(/\s+/);
            for (const token of tokens) {
                if (token.startsWith('!') || token.startsWith('-')) {
                    const exclude = token.slice(1);
                    if (exclude && target.includes(exclude)) return false;
                } else {
                    if (!target.includes(token)) return false;
                }
            }
            return true;
        }

        function handleSearchInput() {
            const val = document.getElementById('filterInput') ? document.getElementById('filterInput').value : '';
            const clearBtn = document.getElementById('searchClearBtn');
            if (clearBtn) { clearBtn.style.display = val ? 'block' : 'none'; }
            filterTables();
        }

        function clearSearch() {
            const input = document.getElementById('filterInput');
            if (input) {
                input.value = '';
                handleSearchInput();
            }
        }

        function filterTables() {
            const query = (document.getElementById('filterInput') ? document.getElementById('filterInput').value : '').trim();
            const activeTab = document.querySelector('.tab-content.active');
            if (!activeTab) return;

            if (activeTab.id === 'tab-entities') {
                filterEntitiesTable();
                return;
            }
            if (activeTab.id === 'tab-devices') {
                filterDevicesTable();
                return;
            }

            const rows = activeTab.querySelectorAll('tbody tr');
            let visibleCount = 0;
            rows.forEach(row => {
                const text = row.textContent;
                const match = matchQuery(text, query);
                row.style.display = match ? '' : 'none';
                if (match) visibleCount++;
            });

            updateBadge(visibleCount, rows.length);
        }

        function filterEntitiesTable() {
            const globalQuery = (document.getElementById('filterInput') ? document.getElementById('filterInput').value : '').trim();
            const domVal = document.getElementById('ent-domain-select') ? document.getElementById('ent-domain-select').value : 'All';
            const nameVal = (document.getElementById('ent-name-filter') ? document.getElementById('ent-name-filter').value : '').trim();
            const idVal = (document.getElementById('ent-id-filter') ? document.getElementById('ent-id-filter').value : '').trim();
            const stateVal = (document.getElementById('ent-state-filter') ? document.getElementById('ent-state-filter').value : '').trim();
            const devVal = (document.getElementById('ent-device-filter') ? document.getElementById('ent-device-filter').value : '').trim();
            const areaVal = document.getElementById('ent-area-select') ? document.getElementById('ent-area-select').value : 'All';

            const rows = document.querySelectorAll('#table-entities tbody tr');
            let visibleCount = 0;
            rows.forEach(row => {
                const cells = row.children;
                const rowDom = cells[0] ? cells[0].textContent.trim().toLowerCase() : '';
                const rowName = cells[1] ? cells[1].textContent.trim() : '';
                const rowId = cells[2] ? cells[2].textContent.trim() : '';
                const rowState = cells[3] ? cells[3].textContent.trim() : '';
                const rowDev = cells[4] ? cells[4].textContent.trim() : '';
                const rowArea = cells[5] ? cells[5].textContent.trim().toLowerCase() : '';
                const rowFull = row.textContent;

                const matchGlobal = matchQuery(rowFull, globalQuery);
                const matchDom = (domVal === 'All') || (rowDom === domVal.toLowerCase());
                const matchName = matchQuery(rowName, nameVal);
                const matchId = matchQuery(rowId, idVal);
                const matchState = matchQuery(rowState, stateVal);
                const matchDev = matchQuery(rowDev, devVal);
                const matchArea = (areaVal === 'All') || (rowArea === areaVal.toLowerCase());

                const isVisible = (matchGlobal && matchDom && matchName && matchId && matchState && matchDev && matchArea);
                row.style.display = isVisible ? '' : 'none';
                if (isVisible) visibleCount++;
            });

            updateBadge(visibleCount, rows.length);
        }

        function resetEntityColumnFilters() {
            if (document.getElementById('ent-domain-select')) document.getElementById('ent-domain-select').value = 'All';
            if (document.getElementById('ent-name-filter')) document.getElementById('ent-name-filter').value = '';
            if (document.getElementById('ent-id-filter')) document.getElementById('ent-id-filter').value = '';
            if (document.getElementById('ent-state-filter')) document.getElementById('ent-state-filter').value = '';
            if (document.getElementById('ent-device-filter')) document.getElementById('ent-device-filter').value = '';
            if (document.getElementById('ent-area-select')) document.getElementById('ent-area-select').value = 'All';
            filterEntitiesTable();
        }

        function filterDevicesTable() {
            const globalQuery = (document.getElementById('filterInput') ? document.getElementById('filterInput').value : '').trim();
            const nameSelect = document.getElementById('dev-name-select') ? document.getElementById('dev-name-select').value : 'All';
            const mfgSelect = document.getElementById('dev-mfg-select') ? document.getElementById('dev-mfg-select').value : 'All';
            const modelFilter = (document.getElementById('dev-model-filter') ? document.getElementById('dev-model-filter').value : '').trim();
            const areaSelect = document.getElementById('dev-area-select') ? document.getElementById('dev-area-select').value : 'All';
            const labelFilter = (document.getElementById('dev-label-filter') ? document.getElementById('dev-label-filter').value : '').trim();
            const countFilter = (document.getElementById('dev-count-filter') ? document.getElementById('dev-count-filter').value : '').trim();
            const minCount = countFilter ? parseInt(countFilter, 10) : 0;

            const rows = document.querySelectorAll('#table-devices tbody tr');
            let visibleCount = 0;
            rows.forEach(row => {
                const cells = row.children;
                const rowName = cells[0] ? cells[0].textContent.trim() : '';
                const rowMfg = cells[1] ? cells[1].textContent.trim() : '';
                const rowModel = cells[2] ? cells[2].textContent.trim() : '';
                const rowArea = cells[3] ? cells[3].textContent.trim().toLowerCase() : '';
                const rowLabel = cells[4] ? cells[4].textContent.trim() : '';
                const rowCountText = cells[5] ? cells[5].textContent.trim() : '';
                const rowCount = parseInt(rowCountText.replace(/[^0-9]/g, ''), 10) || 0;
                const rowFull = row.textContent;

                const matchGlobal = matchQuery(rowFull, globalQuery);
                const matchName = (nameSelect === 'All') || rowName.includes(nameSelect);
                const matchMfg = (mfgSelect === 'All') || (rowMfg.toLowerCase() === mfgSelect.toLowerCase());
                const matchModel = matchQuery(rowModel, modelFilter);
                const matchArea = (areaSelect === 'All') || (rowArea === areaSelect.toLowerCase());
                const matchLabel = matchQuery(rowLabel, labelFilter);
                const matchCount = isNaN(minCount) || (rowCount >= minCount);

                const isVisible = (matchGlobal && matchName && matchMfg && matchModel && matchArea && matchLabel && matchCount);
                row.style.display = isVisible ? '' : 'none';
                if (isVisible) visibleCount++;
            });

            updateBadge(visibleCount, rows.length);
        }

        function resetDeviceColumnFilters() {
            if (document.getElementById('dev-name-select')) document.getElementById('dev-name-select').value = 'All';
            if (document.getElementById('dev-mfg-select')) document.getElementById('dev-mfg-select').value = 'All';
            if (document.getElementById('dev-model-filter')) document.getElementById('dev-model-filter').value = '';
            if (document.getElementById('dev-area-select')) document.getElementById('dev-area-select').value = 'All';
            if (document.getElementById('dev-label-filter')) document.getElementById('dev-label-filter').value = '';
            if (document.getElementById('dev-count-filter')) document.getElementById('dev-count-filter').value = '';
            filterDevicesTable();
        }

        function jumpToDevice(deviceName) {
            if (!deviceName || deviceName === '-') return;
            showTab('tab-devices');
            const devSelect = document.getElementById('dev-name-select');
            if (devSelect) {
                let found = false;
                for (let i = 0; i < devSelect.options.length; i++) {
                    if (devSelect.options[i].value === deviceName) {
                        devSelect.selectedIndex = i;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    devSelect.value = 'All';
                    const modelFilter = document.getElementById('dev-model-filter');
                    if (modelFilter) modelFilter.value = deviceName;
                }
            }
            filterDevicesTable();
            const rows = Array.from(document.querySelectorAll('#table-devices tbody tr'));
            const targetRow = rows.find(r => r.children[0] && r.children[0].textContent.includes(deviceName));
            if (targetRow) {
                targetRow.scrollIntoView({ behavior: 'smooth', block: 'center' });
                targetRow.style.boxShadow = '0 0 12px var(--accent)';
                targetRow.style.outline = '2px solid var(--accent)';
                setTimeout(() => {
                    targetRow.style.boxShadow = '';
                    targetRow.style.outline = '';
                }, 3000);
            }
        }

        function jumpToEntities(deviceName) {
            if (!deviceName || deviceName === '-') return;
            showTab('tab-entities');
            const devFilter = document.getElementById('ent-device-filter');
            if (devFilter) {
                devFilter.value = deviceName;
            }
            filterEntitiesTable();
        }

        function resetAllFilters() {
            clearSearch();
            resetEntityColumnFilters();
            resetDeviceColumnFilters();
            filterTables();
        }

        function updateBadge(visible, total) {
            const badge = document.getElementById('resultsCountBadge');
            if (badge) {
                badge.textContent = 'Showing ' + visible + ' of ' + total;
            }
        }

        function updateItemCount() {
            const activeTab = document.querySelector('.tab-content.active');
            if (!activeTab) return;
            if (activeTab.id === 'tab-entities') {
                filterEntitiesTable();
                return;
            }
            if (activeTab.id === 'tab-devices') {
                filterDevicesTable();
                return;
            }
            const rows = activeTab.querySelectorAll('tbody tr');
            let vis = 0;
            rows.forEach(r => { if (r.style.display !== 'none') vis++; });
            updateBadge(vis, rows.length);
        }

        function toggleDeviceGroup(headerEl) {
            const group = headerEl.parentElement;
            group.classList.toggle('open');
        }

        let sortDirections = {};
        function sortTable(tableId, colIndex) {
            const table = document.getElementById(tableId);
            if (!table) return;
            const tbody = table.querySelector('tbody');
            const rows = Array.from(tbody.querySelectorAll('tr'));
            const headers = table.querySelectorAll('thead tr:first-child th');

            const currentDir = sortDirections[tableId + '_' + colIndex] || 'desc';
            const newDir = currentDir === 'asc' ? 'desc' : 'asc';
            sortDirections[tableId + '_' + colIndex] = newDir;

            headers.forEach(h => {
                const icon = h.querySelector('.sort-icon');
                if (icon) icon.textContent = '⇅';
            });
            if (headers[colIndex]) {
                const icon = headers[colIndex].querySelector('.sort-icon');
                if (icon) icon.textContent = newDir === 'asc' ? '▲' : '▼';
            }

            rows.sort((a, b) => {
                const aCell = a.children[colIndex] ? a.children[colIndex].textContent.trim() : '';
                const bCell = b.children[colIndex] ? b.children[colIndex].textContent.trim() : '';
                const aNum = parseFloat(aCell.replace(/[^0-9.-]+/g, ''));
                const bNum = parseFloat(bCell.replace(/[^0-9.-]+/g, ''));

                if (!isNaN(aNum) && !isNaN(bNum)) {
                    return newDir === 'asc' ? aNum - bNum : bNum - aNum;
                }
                return newDir === 'asc' ? aCell.localeCompare(bCell) : bCell.localeCompare(aCell);
            });

            rows.forEach(row => tbody.appendChild(row));
        }

        function copyToClipboard(text, btn) {
            navigator.clipboard.writeText(text).then(() => {
                const originalText = btn.textContent;
                btn.textContent = '✓';
                btn.style.color = 'var(--success)';
                setTimeout(() => {
                    btn.textContent = originalText;
                    btn.style.color = '';
                }, 1200);
            }).catch(() => {
                prompt('Copy to clipboard:', text);
            });
        }

        function openEntityModal(entityId) {
            const entities = INVENTORY_DATA.entities_catalog || [];
            const ent = entities.find(e => e.entity_id === entityId);
            if (!ent) return;

            currentModalDeviceId = ent.device_id || null;

            document.getElementById('modalEntityName').textContent = ent.name || ent.entity_id;
            document.getElementById('modalEntityId').textContent = ent.entity_id;
            document.getElementById('modalEntityState').textContent = ent.state || '-';
            document.getElementById('modalEntityClass').textContent = ent.device_class || '-';
            document.getElementById('modalEntityDevice').textContent = ent.device_name || '-';
            document.getElementById('modalEntityMfg').textContent = (ent.manufacturer && ent.manufacturer !== '-') ? (ent.manufacturer + ' ' + (ent.model !== '-' ? ent.model : '')) : '-';
            document.getElementById('modalEntityArea').textContent = ent.area || '-';
            document.getElementById('modalEntityDomain').textContent = ent.domain || '-';

            const badge = document.getElementById('modalEntityDomainBadge');
            if (badge) badge.textContent = (ent.domain || 'Entity').toUpperCase();

            const scanBtn = document.getElementById('modalScanParentBtn');
            if (scanBtn) {
                scanBtn.style.display = currentModalDeviceId ? 'inline-flex' : 'none';
            }

            const attrsBody = document.getElementById('modalAttributesBody');
            attrsBody.innerHTML = '';

            if (ent.attributes && Object.keys(ent.attributes).length > 0) {
                for (const [key, val] of Object.entries(ent.attributes)) {
                    const tr = document.createElement('tr');
                    tr.innerHTML = '<td><strong class=\"code-cell\">' + key + '</strong></td><td>' + val + '</td>';
                    attrsBody.appendChild(tr);
                }
            } else {
                attrsBody.innerHTML = '<tr><td colspan=\"2\" style=\"color: var(--text-muted);\">No additional attributes available.</td></tr>';
            }

            document.getElementById('entityModal').classList.add('active');
        }

        function closeEntityModal() {
            document.getElementById('entityModal').classList.remove('active');
        }

        function closeModalOnOverlay(event) {
            if (event.target.id === 'entityModal') {
                closeEntityModal();
            }
        }

        function scanDeviceFromModal() {
            if (currentModalDeviceId) {
                closeEntityModal();
                openDeviceScanModal(currentModalDeviceId);
            }
        }

        function renameEntityFromModal() {
            const eid = document.getElementById('modalEntityId').textContent.trim();
            if (eid) {
                closeEntityModal();
                openEntityRenameModal(eid);
            }
        }

        function openDeviceScanModal(devId) {
            const devices = INVENTORY_DATA.devices_catalog || [];
            const dev = devices.find(d => d.id === devId);
            if (!dev) return;

            document.getElementById('scanModalTitle').textContent = '🔍 Device Deep Scan: ' + (dev.name || dev.id);
            document.getElementById('scanModalSubtitle').textContent = 'Device ID: ' + dev.id + ' • ' + (dev.child_entities ? dev.child_entities.length : 0) + ' Entities';
            document.getElementById('scanChatBadge').textContent = 'Chat: "Scan ' + dev.name + '"';

            const hwGrid = document.getElementById('scanModalHardwareInfo');
            hwGrid.innerHTML = '<div class="detail-item"><div class="detail-item-label">Device Name</div><div class="detail-item-value">' + (dev.name || '-') + '</div></div>' +
                '<div class="detail-item"><div class="detail-item-label">Manufacturer / Brand</div><div class="detail-item-value">' + (dev.manufacturer || 'Unknown') + '</div></div>' +
                '<div class="detail-item"><div class="detail-item-label">Hardware Model</div><div class="detail-item-value">' + (dev.model || '-') + '</div></div>' +
                '<div class="detail-item"><div class="detail-item-label">Room / Area</div><div class="detail-item-value">' + (dev.area || 'Unassigned') + '</div></div>';

            const tbody = document.getElementById('scanEntitiesBody');
            tbody.innerHTML = '';
            (dev.child_entities || []).forEach(child => {
                const tr = document.createElement('tr');
                tr.className = 'clickable-row';
                tr.onclick = function() { closeScanModal(); openEntityModal(child.entity_id); };
                tr.innerHTML = '<td><span class="badge badge-info">' + child.domain + '</span></td>' +
                    '<td><strong>' + child.name + '</strong></td>' +
                    '<td class="code-cell">' + child.entity_id + '</td>' +
                    '<td><strong>' + child.state + '</strong></td>' +
                    '<td>' + (child.device_class || '-') + '</td>' +
                    '<td style="text-align: center;"><button class="action-btn-inspect" onclick="event.stopPropagation(); closeScanModal(); openEntityModal(\'' + child.entity_id + '\')"><span class="icon">🔍</span> Inspect</button></td>';
                tbody.appendChild(tr);
            });

            document.getElementById('scanModal').classList.add('active');
        }

        function openBrandScanModal(brandName) {
            const devices = (INVENTORY_DATA.devices_catalog || []).filter(d => (d.manufacturer || '').toLowerCase() === brandName.toLowerCase() || (d.name || '').toLowerCase().includes(brandName.toLowerCase()));
            const allEntities = (INVENTORY_DATA.entities_catalog || []).filter(e => (e.manufacturer || '').toLowerCase() === brandName.toLowerCase() || (e.entity_id || '').toLowerCase().includes(brandName.toLowerCase()));

            document.getElementById('scanModalTitle').textContent = '🔍 Brand Deep Scan: ' + brandName;
            document.getElementById('scanModalSubtitle').textContent = devices.length + ' Registered Devices • ' + allEntities.length + ' Total Entities';
            document.getElementById('scanChatBadge').textContent = 'Chat: "Scan ' + brandName + ' Devices"';

            const hwGrid = document.getElementById('scanModalHardwareInfo');
            hwGrid.innerHTML = '<div class="detail-item"><div class="detail-item-label">Ecosystem Brand</div><div class="detail-item-value">' + brandName + '</div></div>' +
                '<div class="detail-item"><div class="detail-item-label">Registered Physical Devices</div><div class="detail-item-value">' + devices.length + ' Devices</div></div>' +
                '<div class="detail-item"><div class="detail-item-label">Tracked Live Entities</div><div class="detail-item-value">' + allEntities.length + ' Entities</div></div>' +
                '<div class="detail-item"><div class="detail-item-label">CLI Deep Scan Command</div><div class="detail-item-value" style="font-family: monospace; font-size: 12px; color: var(--accent);">python HaSSD06/deep_device_scan.py "' + brandName + '"</div></div>';

            const tbody = document.getElementById('scanEntitiesBody');
            tbody.innerHTML = '';
            allEntities.slice(0, 100).forEach(child => {
                const tr = document.createElement('tr');
                tr.className = 'clickable-row';
                tr.onclick = function() { closeScanModal(); openEntityModal(child.entity_id); };
                tr.innerHTML = '<td><span class="badge badge-info">' + child.domain + '</span></td>' +
                    '<td><strong>' + child.name + '</strong></td>' +
                    '<td class="code-cell">' + child.entity_id + '</td>' +
                    '<td><strong>' + child.state + '</strong></td>' +
                    '<td>' + (child.device_class || '-') + '</td>' +
                    '<td style="text-align: center;"><button class="action-btn-inspect" onclick="event.stopPropagation(); closeScanModal(); openEntityModal(\'' + child.entity_id + '\')"><span class="icon">🔍</span> Inspect</button></td>';
                tbody.appendChild(tr);
            });

            document.getElementById('scanModal').classList.add('active');
        }

        function closeScanModal() {
            document.getElementById('scanModal').classList.remove('active');
        }

        function closeScanModalOnOverlay(event) {
            if (event.target.id === 'scanModal') {
                closeScanModal();
            }
        }

        function filterToolRole(role, btn) {
            document.querySelectorAll('#tab-tools .badge').forEach(b => {
                if (b.id && b.id.startsWith('btn-filter-tool-')) {
                    b.className = 'badge badge-muted';
                    b.style.cursor = 'pointer';
                    b.style.padding = '6px 14px';
                    b.style.fontSize = '12px';
                }
            });
            btn.className = 'badge badge-info';
            btn.style.cursor = 'pointer';
            btn.style.padding = '6px 14px';
            btn.style.fontSize = '12px';

            const rows = document.querySelectorAll('#table-tools tbody tr.tool-row');
            rows.forEach(r => {
                if (role === 'all' || r.getAttribute('data-role') === role) {
                    r.style.display = '';
                } else {
                    r.style.display = 'none';
                }
            });
        }

        // ==============================================================================
        // Device & Entity Renaming Subpanel & Cascading Engine (CRP-146)
        // ==============================================================================
        let currentRenameDeviceId = null;
        let currentRenameEntityId = null;
        let stagedChildDiffs = [];

        function slugify(text) {
            if (!text) return '';
            return text.toString().toLowerCase().trim()
                .replace(/ä/g, 'ae')
                .replace(/ö/g, 'oe')
                .replace(/ü/g, 'ue')
                .replace(/ß/g, 'ss')
                .replace(/[^a-z0-9_]+/g, '_')
                .replace(/^_+|_+$/g, '')
                .replace(/_+/g, '_');
        }

        function openDeviceRenameModal(deviceId) {
            const devices = INVENTORY_DATA.devices_catalog || [];
            const dev = devices.find(d => d.id === deviceId);
            if (!dev) return;

            currentRenameDeviceId = dev.id;
            document.getElementById('devRenameIdBadge').textContent = 'ID: ' + dev.id;
            document.getElementById('devRenameModalTitle').textContent = '✏️ Rename Device: ' + dev.name;
            document.getElementById('devProposedNameInput').value = dev.name || '';
            document.getElementById('devProposedLabelsInput').value = (dev.labels || []).join(', ');

            // Set Area dropdown
            const areaSelect = document.getElementById('devTargetAreaSelect');
            if (areaSelect) {
                let matched = false;
                for (let i = 0; i < areaSelect.options.length; i++) {
                    if (areaSelect.options[i].value.toLowerCase() === (dev.area || '').toLowerCase()) {
                        areaSelect.selectedIndex = i;
                        matched = true;
                        break;
                    }
                }
                if (!matched && dev.area && dev.area !== '-') {
                    const opt = document.createElement('option');
                    opt.value = dev.area;
                    opt.textContent = dev.area;
                    opt.selected = true;
                    areaSelect.appendChild(opt);
                }
            }

            // Set Deep Link
            const deepLinkBtn = document.getElementById('devHaDeepLinkBtn');
            if (deepLinkBtn) {
                deepLinkBtn.href = 'http://192.168.10.6:8123/config/devices/device/' + dev.id;
            }

            const children = dev.child_entities || [];
            document.getElementById('devChildEntitiesCountBadge').textContent = children.length + ' Child Entities';

            // Scan Reverse Dependencies
            const childEids = children.map(c => c.entity_id);
            scanDeviceReverseDependencies(dev.name, childEids);

            // Compute Initial Diffs
            updateDeviceChildPreviews();

            document.getElementById('deviceRenameModal').classList.add('active');
        }

        function closeDeviceRenameModal() {
            document.getElementById('deviceRenameModal').classList.remove('active');
            currentRenameDeviceId = null;
        }

        function closeDeviceRenameModalOnOverlay(event) {
            if (event.target.id === 'deviceRenameModal') {
                closeDeviceRenameModal();
            }
        }

        function applyDevicePattern() {
            const devices = INVENTORY_DATA.devices_catalog || [];
            const dev = devices.find(d => d.id === currentRenameDeviceId);
            if (!dev) return;

            const pattern = document.getElementById('devPatternSelect').value;
            const area = document.getElementById('devTargetAreaSelect').value;
            const areaStr = (area && area !== 'All') ? area : (dev.area || '');

            let newName = dev.name;
            if (pattern === 'area_device') {
                let cleanDev = dev.name;
                if (areaStr && cleanDev.toLowerCase().startsWith(areaStr.toLowerCase())) {
                    cleanDev = cleanDev.substring(areaStr.length).trim();
                }
                newName = (areaStr ? (areaStr + ' ') : '') + cleanDev;
            } else if (pattern === 'area_mfg_model') {
                const mfg = (dev.manufacturer && dev.manufacturer !== '-') ? dev.manufacturer : '';
                const model = (dev.model && dev.model !== '-') ? dev.model : 'Device';
                newName = (areaStr ? (areaStr + ' ') : '') + (mfg ? (mfg + ' ') : '') + model;
            } else if (pattern === 'area_custom') {
                const baseName = dev.name.replace(/^[\d_-]+\s*/, '');
                newName = (areaStr ? (areaStr + ' ') : '') + baseName;
            }

            document.getElementById('devProposedNameInput').value = newName.trim();
            updateDeviceChildPreviews();
        }

        function toggleCascadeChildren() {
            const cascade = document.getElementById('devCascadeChildrenCheck').checked;
            const diffContainer = document.getElementById('devChildrenDiffContainer');
            if (diffContainer) {
                diffContainer.style.display = cascade ? 'block' : 'none';
            }
        }

        function updateDeviceChildPreviews() {
            const devices = INVENTORY_DATA.devices_catalog || [];
            const dev = devices.find(d => d.id === currentRenameDeviceId);
            if (!dev) return;

            const proposedDevName = document.getElementById('devProposedNameInput').value.trim() || dev.name;
            const area = document.getElementById('devTargetAreaSelect').value;
            const areaStr = (area && area !== 'All') ? area : (dev.area || '');
            const areaSlug = slugify(areaStr);
            const devSlug = slugify(proposedDevName);

            const tbody = document.getElementById('devChildrenDiffBody');
            tbody.innerHTML = '';
            stagedChildDiffs = [];

            const children = dev.child_entities || [];
            children.forEach(child => {
                const dom = child.domain || 'sensor';
                const oldEid = child.entity_id;
                const oldName = child.name || oldEid;

                let suffix = oldEid.replace(new RegExp('^' + dom + '\\.'), '');
                suffix = suffix.replace(/^(0[0-9]+|sh[0-9]+|esp|tuya)_?/, '');
                if (!suffix) suffix = slugify(oldName);
                if (!suffix) suffix = 'entity';

                const proposedEid = (areaSlug ? (dom + '.' + areaSlug + '_' + devSlug + '_' + suffix) : (dom + '.' + devSlug + '_' + suffix)).replace(/_+/g, '_');
                const proposedChildName = proposedDevName + (oldName !== dev.name ? (' ' + oldName) : (' ' + suffix));

                const refCount = countEntityReferences(oldEid);

                stagedChildDiffs.push({
                    domain: dom,
                    old_entity_id: oldEid,
                    new_entity_id: proposedEid,
                    old_name: oldName,
                    new_name: proposedChildName,
                    device_id: dev.id,
                    ref_count: refCount
                });

                const tr = document.createElement('tr');
                tr.innerHTML = '<td><span class="badge badge-info">' + dom + '</span></td>' +
                    '<td class="allow-wrap">' + oldName + '</td>' +
                    '<td class="allow-wrap" style="color: #7ee787; font-weight: 600;">' + proposedChildName + '</td>' +
                    '<td class="code-cell" style="font-size: 11px;">' + oldEid + '</td>' +
                    '<td class="code-cell" style="font-size: 11px; color: #7ee787;">' + proposedEid + '</td>' +
                    '<td style="text-align: center;"><span class="badge ' + (refCount > 0 ? 'badge-warning' : 'badge-muted') + '">' + refCount + '</span></td>';
                tbody.appendChild(tr);
            });
        }

        function countEntityReferences(entityId) {
            if (!entityId) return 0;
            let count = 0;
            const automations = INVENTORY_DATA.automations_catalog || [];
            const scripts = INVENTORY_DATA.scripts_catalog || [];
            const helpers = INVENTORY_DATA.helpers_and_virtual || [];

            automations.forEach(a => {
                if (a.entity === entityId) return;
                if ((a.entity && a.entity.includes(entityId)) || (a.name && a.name.includes(entityId))) count++;
            });
            scripts.forEach(s => {
                if (s.entity === entityId) return;
                if ((s.entity && s.entity.includes(entityId)) || (s.name && s.name.includes(entityId))) count++;
            });
            helpers.forEach(h => {
                if (h.entity === entityId) return;
                if ((h.entity && h.entity.includes(entityId)) || (h.name && h.name.includes(entityId))) count++;
            });
            return count;
        }

        function scanDeviceReverseDependencies(devName, childEids) {
            let matches = [];
            const automations = INVENTORY_DATA.automations_catalog || [];
            const scripts = INVENTORY_DATA.scripts_catalog || [];
            const helpers = INVENTORY_DATA.helpers_and_virtual || [];

            childEids.forEach(eid => {
                automations.forEach(a => {
                    if (a.entity === eid) return;
                    if ((a.entity && a.entity.includes(eid)) || (a.name && a.name.includes(eid))) {
                        matches.push({ type: 'Automation', name: a.name || a.entity, target: eid });
                    }
                });
                scripts.forEach(s => {
                    if (s.entity === eid) return;
                    if ((s.entity && s.entity.includes(eid)) || (s.name && s.name.includes(eid))) {
                        matches.push({ type: 'Script', name: s.name || s.entity, target: eid });
                    }
                });
                helpers.forEach(h => {
                    if (h.entity === eid) return;
                    if ((h.entity && h.entity.includes(eid)) || (h.name && h.name.includes(eid))) {
                        matches.push({ type: 'Helper', name: h.name || h.entity, target: eid });
                    }
                });
            });

            const summaryBadge = document.getElementById('devImpactSummaryBadge');
            const detailsList = document.getElementById('devImpactDetailsList');

            if (matches.length > 0) {
                summaryBadge.textContent = matches.length + ' Impacted Reference(s)';
                summaryBadge.className = 'badge badge-danger';
                detailsList.innerHTML = matches.map(m => '<div style="margin-bottom: 2px;">• <strong class="badge badge-warning">' + m.type + '</strong> ' + m.name + ' <span style="color: var(--text-muted);">[' + m.target + ']</span></div>').join('');
            } else {
                summaryBadge.textContent = '0 Dependencies (Clean)';
                summaryBadge.className = 'badge badge-success';
                detailsList.innerHTML = '<span style="color: #7ee787;">✓ No breaking reverse references found in automations, scripts, or helpers.</span>';
            }
        }

        function copyDeviceHaPayload() {
            const devices = INVENTORY_DATA.devices_catalog || [];
            const dev = devices.find(d => d.id === currentRenameDeviceId);
            if (!dev) return;

            const proposedName = document.getElementById('devProposedNameInput').value.trim();
            const area = document.getElementById('devTargetAreaSelect').value;

            const payload = {
                device_id: dev.id,
                current_name: dev.name,
                proposed_name: proposedName,
                area: area,
                entities: stagedChildDiffs.map(d => ({ old_id: d.old_entity_id, new_id: d.new_entity_id, new_name: d.new_name }))
            };

            const text = JSON.stringify(payload, null, 2);
            navigator.clipboard.writeText(text).then(() => {
                showToast('✓ Copied HA rename payload to clipboard!');
                window.open('http://192.168.10.6:8123/config/devices/device/' + dev.id, '_blank');
            }).catch(() => {
                prompt('Copy HA Payload:', text);
            });
        }

        function stageDeviceRenameTx(showNotification) {
            const devices = INVENTORY_DATA.devices_catalog || [];
            const dev = devices.find(d => d.id === currentRenameDeviceId);
            if (!dev) return null;

            const proposedName = document.getElementById('devProposedNameInput').value.trim();
            const area = document.getElementById('devTargetAreaSelect').value;
            const cascade = document.getElementById('devCascadeChildrenCheck').checked;

            const txId = 'tx_' + new Date().toISOString().replace(/[-:T]/g, '').slice(0, 15);
            const txRecord = {
                transaction_id: txId,
                created_at: new Date().toISOString(),
                instance: '$Instance',
                state: 'staged',
                device_updates: [{
                    id: dev.id,
                    old_name: dev.name,
                    new_name: proposedName,
                    area: area,
                    manufacturer: dev.manufacturer,
                    model: dev.model
                }],
                entity_updates: cascade ? stagedChildDiffs : []
            };

            localStorage.setItem('lcm_last_rename_tx', JSON.stringify(txRecord));
            if (showNotification) {
                showToast('💾 Staged transaction: ' + txId);
            }
            return txRecord;
        }

        function executeDeviceRenameTx() {
            const tx = stageDeviceRenameTx(false);
            if (!tx) return;

            const dev = tx.device_updates[0];
            const cascade = document.getElementById('devCascadeChildrenCheck').checked;
            const isDryRun = document.querySelector('input[name="devBackupOption"]:checked').value === 'staging';

            const cmd = 'pwsh -File "D:\\Git_Repositories\\HaSSD06_Inventory\\tools\\Invoke-HaRenameCascade.ps1" -DeviceId "' + dev.id + '" -NewName "' + dev.new_name.replace(/"/g, '`"') + '"' + (cascade ? ' -CascadeChildren' : '') + (isDryRun ? ' -DryRun' : '');
            showToast('⚡ Dispatching Rename Cascade Engine...');
            dispatchCommand(cmd, false, { type: 'CASCADE_RENAME_DEVICE', target: dev.id, details: 'Cascaded rename to ' + dev.new_name + (cascade ? (' (' + stagedChildDiffs.length + ' child entities)') : '') });
            closeDeviceRenameModal();
        }

        function openEntityRenameModal(entityId) {
            const entities = INVENTORY_DATA.entities_catalog || [];
            let ent = entities.find(e => e.entity_id === entityId);
            if (!ent) {
                const autos = INVENTORY_DATA.automations_catalog || [];
                const auto = autos.find(a => a.entity === entityId);
                if (auto) {
                    ent = { entity_id: auto.entity, name: auto.name, domain: 'automation', device_name: '-', area: '-' };
                } else {
                    const scripts = INVENTORY_DATA.scripts_catalog || [];
                    const scr = scripts.find(s => s.entity === entityId);
                    if (scr) {
                        ent = { entity_id: scr.entity, name: scr.name, domain: 'script', device_name: '-', area: '-' };
                    } else {
                        const helpers = INVENTORY_DATA.helpers_and_virtual || [];
                        const hlp = helpers.find(h => h.entity === entityId);
                        if (hlp) {
                            ent = { entity_id: hlp.entity, name: hlp.name, domain: 'helper', device_name: '-', area: '-' };
                        }
                    }
                }
            }
            if (!ent) return;

            currentRenameEntityId = ent.entity_id;
            document.getElementById('entRenameDomainBadge').textContent = (ent.domain || 'entity').toUpperCase();
            document.getElementById('entRenameModalTitle').textContent = '✏️ Rename Entity: ' + (ent.name || ent.entity_id);
            document.getElementById('entRenameModalSubtitle').textContent = ent.entity_id;
            document.getElementById('entProposedNameInput').value = ent.name || ent.entity_id;
            document.getElementById('entProposedIdInput').value = ent.entity_id;

            const parentInfo = (ent.device_name && ent.device_name !== '-' ? ('📱 ' + ent.device_name) : 'No Device') + ' • Area: ' + (ent.area || 'Unassigned');
            document.getElementById('entRenameParentInfo').textContent = parentInfo;

            const deepLinkBtn = document.getElementById('entHaDeepLinkBtn');
            if (deepLinkBtn) {
                if (ent.domain === 'automation' || ent.entity_id.startsWith('automation.')) {
                    deepLinkBtn.href = 'http://192.168.10.6:8123/config/automation/dashboard';
                } else if (ent.domain === 'script' || ent.entity_id.startsWith('script.')) {
                    deepLinkBtn.href = 'http://192.168.10.6:8123/config/script/dashboard';
                } else {
                    deepLinkBtn.href = 'http://192.168.10.6:8123/config/entities/entity/' + ent.entity_id;
                }
            }

            scanEntityReverseDependencies(ent.entity_id);
            document.getElementById('entityRenameModal').classList.add('active');
        }

        function closeEntityRenameModal() {
            document.getElementById('entityRenameModal').classList.remove('active');
            currentRenameEntityId = null;
        }

        function closeEntityRenameModalOnOverlay(event) {
            if (event.target.id === 'entityRenameModal') {
                closeEntityRenameModal();
            }
        }

        function applyEntityPattern() {
            const entities = INVENTORY_DATA.entities_catalog || [];
            const ent = entities.find(e => e.entity_id === currentRenameEntityId);
            if (!ent) return;

            const pattern = document.getElementById('entPatternSelect').value;
            const dom = ent.domain || 'sensor';
            const areaSlug = slugify(ent.area);
            const devSlug = slugify(ent.device_name);
            const nameSlug = slugify(ent.name || ent.entity_id.replace(new RegExp('^' + dom + '\\.'), ''));

            let newId = ent.entity_id;
            if (pattern === 'domain_area_dev_name') {
                newId = dom + '.' + (areaSlug ? (areaSlug + '_') : '') + (devSlug ? (devSlug + '_') : '') + nameSlug;
            } else if (pattern === 'domain_area_name') {
                newId = dom + '.' + (areaSlug ? (areaSlug + '_') : '') + nameSlug;
            } else if (pattern === 'domain_dev_name') {
                newId = dom + '.' + (devSlug ? (devSlug + '_') : '') + nameSlug;
            }
            newId = newId.replace(/_+/g, '_');

            document.getElementById('entProposedIdInput').value = newId;
        }

        function updateEntityIdFromFriendlyName() {
            const pattern = document.getElementById('entPatternSelect').value;
            if (pattern === 'custom') return;
            const entities = INVENTORY_DATA.entities_catalog || [];
            const ent = entities.find(e => e.entity_id === currentRenameEntityId);
            if (!ent) return;

            const friendlyName = document.getElementById('entProposedNameInput').value.trim();
            const dom = ent.domain || 'sensor';
            const slug = slugify(friendlyName);
            if (slug) {
                document.getElementById('entProposedIdInput').value = dom + '.' + slug;
            }
        }

        function scanEntityReverseDependencies(entityId) {
            let matches = [];
            const automations = INVENTORY_DATA.automations_catalog || [];
            const scripts = INVENTORY_DATA.scripts_catalog || [];
            const helpers = INVENTORY_DATA.helpers_and_virtual || [];

            automations.forEach(a => {
                if (a.entity === entityId) return;
                if ((a.entity && a.entity.includes(entityId)) || (a.name && a.name.includes(entityId))) {
                    matches.push({ type: 'Automation', name: a.name || a.entity });
                }
            });
            scripts.forEach(s => {
                if (s.entity === entityId) return;
                if ((s.entity && s.entity.includes(entityId)) || (s.name && s.name.includes(entityId))) {
                    matches.push({ type: 'Script', name: s.name || s.entity });
                }
            });
            helpers.forEach(h => {
                if (h.entity === entityId) return;
                if ((h.entity && h.entity.includes(entityId)) || (h.name && h.name.includes(entityId))) {
                    matches.push({ type: 'Helper', name: h.name || h.entity });
                }
            });

            const summaryBadge = document.getElementById('entImpactSummaryBadge');
            const detailsList = document.getElementById('entImpactDetailsList');

            if (matches.length > 0) {
                summaryBadge.textContent = matches.length + ' Impacted Reference(s)';
                summaryBadge.className = 'badge badge-danger';
                detailsList.innerHTML = matches.map(m => '<div style="margin-bottom: 2px;">• <strong class="badge badge-warning">' + m.type + '</strong> ' + m.name + '</div>').join('');
            } else {
                summaryBadge.textContent = '0 Dependencies (Clean)';
                summaryBadge.className = 'badge badge-success';
                detailsList.innerHTML = '<span style="color: #7ee787;">✓ No breaking reverse references found in automations, scripts, or helpers.</span>';
            }
        }

        function copyEntityHaPayload() {
            const entities = INVENTORY_DATA.entities_catalog || [];
            const ent = entities.find(e => e.entity_id === currentRenameEntityId);
            if (!ent) return;

            const proposedName = document.getElementById('entProposedNameInput').value.trim();
            const proposedId = document.getElementById('entProposedIdInput').value.trim();

            const payload = {
                current_entity_id: ent.entity_id,
                proposed_entity_id: proposedId,
                current_name: ent.name,
                proposed_name: proposedName
            };

            const text = JSON.stringify(payload, null, 2);
            navigator.clipboard.writeText(text).then(() => {
                showToast('✓ Copied HA entity rename payload to clipboard!');
                window.open('http://192.168.10.6:8123/config/entities/entity/' + ent.entity_id, '_blank');
            }).catch(() => {
                prompt('Copy HA Entity Payload:', text);
            });
        }

        function stageEntityRenameTx(showNotification) {
            const entities = INVENTORY_DATA.entities_catalog || [];
            const ent = entities.find(e => e.entity_id === currentRenameEntityId);
            if (!ent) return null;

            const proposedName = document.getElementById('entProposedNameInput').value.trim();
            const proposedId = document.getElementById('entProposedIdInput').value.trim();

            const txId = 'tx_' + new Date().toISOString().replace(/[-:T]/g, '').slice(0, 15);
            const txRecord = {
                transaction_id: txId,
                created_at: new Date().toISOString(),
                instance: '$Instance',
                state: 'staged',
                device_updates: [],
                entity_updates: [{
                    old_entity_id: ent.entity_id,
                    new_entity_id: proposedId,
                    old_name: ent.name,
                    new_name: proposedName,
                    domain: ent.domain,
                    device_id: ent.device_id
                }]
            };

            localStorage.setItem('lcm_last_rename_tx', JSON.stringify(txRecord));
            if (showNotification) {
                showToast('💾 Staged entity transaction: ' + txId);
            }
            return txRecord;
        }

        function executeEntityRenameTx() {
            const tx = stageEntityRenameTx(false);
            if (!tx) return;

            const eu = tx.entity_updates[0];
            const cmd = 'pwsh -File "D:\\Git_Repositories\\HaSSD06_Inventory\\tools\\Invoke-HaRenameCascade.ps1" -EntityId "' + eu.old_entity_id + '" -NewEntityId "' + eu.new_entity_id + '" -NewName "' + eu.new_name.replace(/"/g, '`"') + '"';
            showToast('⚡ Dispatching Entity Rename Cascade...');
            dispatchCommand(cmd, false, { type: 'CASCADE_RENAME_ENTITY', target: eu.old_entity_id, details: 'Renamed ' + eu.old_entity_id + ' -> ' + eu.new_entity_id });
            closeEntityRenameModal();
        }

        function initTheme() {
            const savedTheme = localStorage.getItem('lcm_theme') || 'dark';
            applyTheme(savedTheme);
        }

        function applyTheme(theme) {
            const icon = document.getElementById('theme-icon');
            const label = document.getElementById('theme-label');
            if (theme === 'light') {
                document.body.classList.add('light-theme');
                document.documentElement.setAttribute('data-theme', 'light');
                if (icon) icon.innerText = '🌙';
                if (label) label.innerText = 'Dark Mode';
            } else {
                document.body.classList.remove('light-theme');
                document.documentElement.setAttribute('data-theme', 'dark');
                if (icon) icon.innerText = '☀️';
                if (label) label.innerText = 'Light Mode';
            }
            localStorage.setItem('lcm_theme', theme);
        }

        function toggleTheme() {
            const isLight = document.body.classList.contains('light-theme');
            applyTheme(isLight ? 'dark' : 'light');
        }
        initTheme();

        function updateRelativeTime() {
            if (!INVENTORY_DATA.generated_at) return;
            const genTime = new Date(INVENTORY_DATA.generated_at);
            const now = new Date();
            const diffSec = Math.floor((now - genTime) / 1000);
            let timeStr = 'Just now';
            if (diffSec >= 60 && diffSec < 3600) {
                timeStr = Math.floor(diffSec / 60) + ' min ago';
            } else if (diffSec >= 3600 && diffSec < 86400) {
                timeStr = Math.floor(diffSec / 3600) + ' hr ago';
            } else if (diffSec >= 86400) {
                timeStr = Math.floor(diffSec / 86400) + ' days ago';
            }
            const timeEl = document.getElementById('generatedRelativeTime');
            if (timeEl) { timeEl.textContent = timeStr; }
        }
        updateRelativeTime();
        setInterval(updateRelativeTime, 30000);

        // Inlined LcmTablePrintAtom Engine
        $atomJsContent

        if (typeof LcmTablePrintAtom !== 'undefined') {
            LcmTablePrintAtom.init({
                documentTitle: '$Instance Subsystem Inventory',
                subsystem: '$Instance',
                tableSelector: '#table-entities',
                tbodySelector: '#table-entities tbody',
                getViewMode: () => {
                    const activeTab = document.querySelector('.tab-btn.active');
                    return activeTab ? activeTab.innerText.trim() : 'Entities View';
                },
                getFileName: () => {
                    const activeTab = document.querySelector('.tab-btn.active');
                    const tabName = activeTab ? activeTab.innerText.trim().replace(/\s+/g, '_') : 'Entities';
                    return tabName + '_Inventory_${Instance}.html';
                },
                getDate: () => {
                    return '$genTime';
                },
                getFilterSummary: () => {
                    const search = document.getElementById('filterInput') ? document.getElementById('filterInput').value.trim() : '';
                    const domain = document.getElementById('ent-domain-select') ? document.getElementById('ent-domain-select').value : 'All';
                    const area = document.getElementById('ent-area-select') ? document.getElementById('ent-area-select').value : 'All';
                    let parts = [];
                    if (search) parts.push('Search: "' + search + '"');
                    if (domain !== 'All') parts.push('Domain: ' + domain);
                    if (area !== 'All') parts.push('Area: ' + area);
                    return parts.length > 0 ? parts.join(' • ') : 'All Entities in View';
                }
            });
        }

        // ==============================================================================
        // Active Help & Tool Execution Subsystem (CRP-143)
        // ==============================================================================
        const HA_TOOLS_CONFIG = {
            "Update-HaInventory.ps1": {
                defaultCmd: 'pwsh HaSSD06_Inventory/tools/Update-HaInventory.ps1',
                elevated: false,
                params: [
                    { name: "Instance", type: "string", default: "$Instance", description: "Target Home Assistant instance name." },
                    { name: "NoHtml", type: "switch", default: false, description: "Suppresses generating HTML dashboard." },
                    { name: "SkipDeviceScan", type: "switch", default: false, description: "Skips deep hardware brand telemetry scan." }
                ]
            },
            "Show-HaInventory.ps1": {
                defaultCmd: 'pwsh HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1',
                elevated: false,
                params: [
                    { name: "Instance", type: "string", default: "$Instance", description: "Target Home Assistant instance name." },
                    { name: "Refresh", type: "switch", default: false, description: "Queries live HA API before rendering." },
                    { name: "NoLaunch", type: "switch", default: false, description: "Generates HTML dashboard without opening browser." }
                ]
            },
            "Show-HaInventoryApp.ps1": {
                defaultCmd: 'pwsh HaSSD06_Inventory/tools/Show-HaInventoryApp.ps1',
                elevated: false,
                params: [
                    { name: "Instance", type: "string", default: "$Instance", description: "Target Home Assistant instance name." },
                    { name: "Refresh", type: "switch", default: false, description: "Queries live HA API before rendering." },
                    { name: "NoLaunch", type: "switch", default: false, description: "Generates HTML dashboard without opening browser." }
                ]
            },
            "Test-RepoReadiness.ps1": {
                defaultCmd: 'pwsh HaSSD06_Inventory/tools/Test-RepoReadiness.ps1',
                elevated: false,
                params: [
                    { name: "Fast", type: "switch", default: false, description: "Runs fast quality gate checks." },
                    { name: "SkipSchema", type: "switch", default: false, description: "Skips JSON schema validation." }
                ]
            },
            "Invoke-HaUpdateGate.ps1": {
                defaultCmd: 'pwsh HaSSD06_Inventory/tools/Invoke-HaUpdateGate.ps1',
                elevated: true,
                params: [
                    { name: "TargetVersion", type: "string", default: "latest", description: "Target Home Assistant release version." },
                    { name: "DryRun", type: "switch", default: false, description: "Simulates update and checks without applying." },
                    { name: "SkipBackup", type: "switch", default: false, description: "Skips pre-update backup snapshot creation." }
                ]
            },
            "Invoke-HaRenameCascade.ps1": {
                defaultCmd: 'pwsh HaSSD06_Inventory/tools/Invoke-HaRenameCascade.ps1',
                elevated: false,
                params: [
                    { name: "DeviceId", type: "string", default: "", description: "Target physical device ID." },
                    { name: "EntityId", type: "string", default: "", description: "Target entity ID." },
                    { name: "NewName", type: "string", default: "", description: "New friendly display name." },
                    { name: "NewEntityId", type: "string", default: "", description: "New entity ID (e.g. domain.new_name)." },
                    { name: "CascadeChildren", type: "switch", default: true, description: "Cascade renames to child entities." },
                    { name: "DryRun", type: "switch", default: true, description: "Simulates cascade diff without mutating files." }
                ]
            },
            "Invoke-HaService.ps1": {
                defaultCmd: 'pwsh HaSSD06_Inventory/tools/Invoke-HaService.ps1',
                elevated: false,
                params: [
                    { name: "Domain", type: "string", default: "automation", description: "Target service domain (automation, script, switch, light)." },
                    { name: "Service", type: "string", default: "toggle", description: "Target service action (turn_on, turn_off, toggle, reload)." },
                    { name: "EntityId", type: "string", default: "automation.bewegungsalarm_wz", description: "Target entity ID." }
                ]
            },
            "deep_device_scan.py": {
                defaultCmd: 'python HaSSD06/deep_device_scan.py',
                elevated: false,
                params: [
                    { name: "Brand", type: "string", default: "Tuya", description: "Brand name or keyword (Tuya, Shelly, FRITZ!, Aqara, Sonos, Nuki, BLE)." },
                    { name: "Detailed", type: "switch", default: false, description: "Include all raw entity attributes in dump." }
                ]
            },
            "inspect_ha_logs.py": {
                defaultCmd: 'python HaSSD06/inspect_ha_logs.py',
                elevated: false,
                params: [
                    { name: "Filter", type: "string", default: "error", description: "Search keyword filter (error, warning, tuya, zigbee)." },
                    { name: "Lines", type: "string", default: "100", description: "Number of trailing log lines to inspect." }
                ]
            },
            "scan_community_issues.py": {
                defaultCmd: 'python HaSSD06/scan_community_issues.py',
                elevated: false,
                params: [
                    { name: "Integration", type: "string", default: "all", description: "Filter to specific integration or 'all'." },
                    { name: "Limit", type: "string", default: "20", description: "Maximum issue count to retrieve." }
                ]
            },
            "compare_tuya_integrations.py": {
                defaultCmd: 'python HaSSD06/compare_tuya_integrations.py',
                elevated: false,
                params: [
                    { name: "Device", type: "string", default: "", description: "Optional device name or ID to filter comparison." }
                ]
            },
            "search_sys_sensors.py": {
                defaultCmd: 'python HaSSD06/search_sys_sensors.py',
                elevated: false,
                params: [
                    { name: "SensorType", type: "string", default: "all", description: "Sensor class filter (temperature, load, memory, ssd, all)." }
                ]
            },
            "extract_ha_central_registry.py": {
                defaultCmd: 'python HaSSD06_Inventory/tools/extract_ha_central_registry.py',
                elevated: false,
                params: [
                    { name: "OutputFile", type: "string", default: "data/central_registry.json", description: "Target JSON dump path." }
                ]
            },
            "Invoke-LCM_Audit.ps1": {
                defaultCmd: 'pwsh LCM_Inventory/tools/Invoke-LCM_Audit.ps1',
                elevated: false,
                params: [
                    { name: "Fast", type: "switch", default: false, description: "Fast repository check mode." },
                    { name: "VerboseAudit", type: "switch", default: false, description: "Detailed repository status output." }
                ]
            },
            "Show-LCM_InventoryApp.ps1": {
                defaultCmd: 'pwsh LCM_Inventory/tools/Show-LCM_InventoryApp.ps1',
                elevated: false,
                params: [
                    { name: "NoLaunch", type: "switch", default: false, description: "Generates HTML without browser launch." }
                ]
            },
            "build_offline_docs.py": {
                defaultCmd: 'python LCM_Inventory/tools/build_offline_docs.py',
                elevated: false,
                params: [
                    { name: "Scope", type: "string", default: "all", description: "Documentation export scope (all, hassd06, lcm)." }
                ]
            },
            "Show-LcmActiveLauncher.ps1": {
                defaultCmd: 'pwsh LCM_Inventory/tools/Show-LcmActiveLauncher.ps1',
                elevated: false,
                params: [
                    { name: "Group", type: "string", default: "HaSSD06", description: "Subsystem group filter." }
                ]
            }
        };

        let currentActiveTool = null;
        let currentHelpTool = null;

        function getToolParamKey(toolName, paramName) {
            const baseStem = (toolName || '').replace(/\.[^/.]+$/, "").toLowerCase();
            return 'lcm_hatool_param_' + baseStem + '_' + (paramName || '').toLowerCase();
        }

        function openToolRunModal(idx) {
            const catalog = INVENTORY_DATA.tools_catalog || [];
            const tool = catalog[idx];
            if (!tool) return;
            currentActiveTool = tool;

            document.getElementById('toolRunTitle').textContent = '▶ Run Tool: ' + tool.name;
            document.getElementById('toolRunDesc').textContent = tool.description || '';
            document.getElementById('toolRunRoleBadge').textContent = (tool.role || 'Operator') + ' Tool';
            document.getElementById('toolRunRoleBadge').className = tool.role === 'Operator' ? 'badge badge-success' : 'badge badge-info';
            document.getElementById('toolRunScopeBadge').textContent = tool.scope || tool.category || '$Instance';

            const config = HA_TOOLS_CONFIG[tool.name] || {
                defaultCmd: tool.script_path.endsWith('.py') ? ('python ' + tool.script_path) : ('pwsh ' + tool.script_path),
                elevated: false,
                params: [
                    { name: "Arguments", type: "string", default: "", description: "Custom command line arguments." }
                ]
            };

            const paramsList = document.getElementById('toolRunParamsList');
            paramsList.innerHTML = '';

            config.params.forEach(p => {
                const storageKey = getToolParamKey(tool.name, p.name);
                const savedVal = localStorage.getItem(storageKey);
                const isSwitch = p.type === 'switch';

                const fieldDiv = document.createElement('div');
                fieldDiv.className = 'param-field';

                if (isSwitch) {
                    const isChecked = savedVal !== null ? (savedVal === 'true') : Boolean(p.default);
                    fieldDiv.innerHTML = '<div style="display: flex; justify-content: space-between; align-items: center; background: rgba(255,255,255,0.03); padding: 8px 12px; border-radius: 6px; border: 1px solid var(--border);">' +
                        '<label style="display: flex; align-items: center; gap: 8px; cursor: pointer; margin: 0;">' +
                            '<input type="checkbox" id="param-input-' + p.name + '" ' + (isChecked ? 'checked' : '') + ' onchange="updateToolRunCommand()" style="cursor: pointer; width: 16px; height: 16px;">' +
                            '<span style="font-weight: 600; color: var(--accent);">-' + p.name + '</span>' +
                            '<span style="font-size: 11px; color: var(--text-secondary);">(Switch Flag)</span>' +
                        '</label>' +
                        '<span style="font-size: 11px; color: var(--text-secondary);">' + (p.description || '') + '</span>' +
                    '</div>';
                } else {
                    const val = savedVal !== null ? savedVal : (p.default || '');
                    fieldDiv.innerHTML = '<div style="display: flex; justify-content: space-between; margin-bottom: 4px;">' +
                        '<div><span style="font-weight: 600; color: var(--accent);">-' + p.name + '</span> <span style="font-size: 11px; color: var(--text-secondary);">(' + p.type + ')</span></div>' +
                        '<span style="font-size: 11px; color: var(--text-secondary);">' + (p.description || '') + '</span>' +
                    '</div>' +
                    '<div class="input-clear-wrapper">' +
                        '<input type="text" class="tool-param-input" id="param-input-' + p.name + '" value="' + val + '" placeholder="Enter value for -' + p.name + '..." oninput="updateToolRunCommand()">' +
                        '<button class="btn-clear-param" onclick="clearToolParam(\'' + p.name + '\')" title="Clear this parameter">&times;</button>' +
                    '</div>';
                }
                paramsList.appendChild(fieldDiv);
            });

            updateToolRunCommand();
            document.getElementById('toolRunModal').classList.add('active');
        }

        function closeToolRunModal() {
            document.getElementById('toolRunModal').classList.remove('active');
            currentActiveTool = null;
        }

        function closeToolRunModalOnOverlay(event) {
            if (event.target.id === 'toolRunModal') {
                closeToolRunModal();
            }
        }

        function clearToolParam(paramName) {
            if (!currentActiveTool) return;
            const storageKey = getToolParamKey(currentActiveTool.name, paramName);
            localStorage.removeItem(storageKey);
            const input = document.getElementById('param-input-' + paramName);
            if (input) {
                if (input.type === 'checkbox') input.checked = false;
                else input.value = '';
            }
            updateToolRunCommand();
        }

        function clearAllToolParams() {
            if (!currentActiveTool) return;
            const config = HA_TOOLS_CONFIG[currentActiveTool.name];
            if (config && config.params) {
                config.params.forEach(p => {
                    const storageKey = getToolParamKey(currentActiveTool.name, p.name);
                    localStorage.removeItem(storageKey);
                    const input = document.getElementById('param-input-' + p.name);
                    if (input) {
                        if (input.type === 'checkbox') input.checked = false;
                        else input.value = '';
                    }
                });
            }
            updateToolRunCommand();
            showToast('Cleared parameter history for ' + currentActiveTool.name);
        }

        function updateToolRunCommand() {
            if (!currentActiveTool) return;
            const config = HA_TOOLS_CONFIG[currentActiveTool.name] || {
                defaultCmd: currentActiveTool.script_path.endsWith('.py') ? ('python ' + currentActiveTool.script_path) : ('pwsh ' + currentActiveTool.script_path),
                params: []
            };

            let baseCmd = config.defaultCmd;
            let argParts = [];

            if (config.params) {
                config.params.forEach(p => {
                    const input = document.getElementById('param-input-' + p.name);
                    if (input) {
                        const storageKey = getToolParamKey(currentActiveTool.name, p.name);
                        if (p.type === 'switch') {
                            if (input.checked) {
                                localStorage.setItem(storageKey, 'true');
                                argParts.push('-' + p.name);
                            } else {
                                localStorage.setItem(storageKey, 'false');
                            }
                        } else {
                            const val = input.value.trim();
                            if (val) {
                                localStorage.setItem(storageKey, val);
                                if (currentActiveTool.script_path.endsWith('.py')) {
                                    argParts.push('"' + val.replace(/"/g, '\\"') + '"');
                                } else {
                                    argParts.push('-' + p.name + ' "' + val.replace(/"/g, '`"') + '"');
                                }
                            } else {
                                localStorage.removeItem(storageKey);
                            }
                        }
                    }
                });
            }

            let fullCmd = baseCmd;
            if (argParts.length > 0) {
                fullCmd += ' ' + argParts.join(' ');
            }

            const preview = document.getElementById('toolRunCmdPreview');
            if (preview) {
                preview.value = fullCmd;
            }
        }

        function syncCustomCommandInput() {
            // allows freeform edits in preview textarea
        }

        function copyToolCommandPreview() {
            const preview = document.getElementById('toolRunCmdPreview');
            if (preview && preview.value) {
                navigator.clipboard.writeText(preview.value).then(() => {
                    showToast('✓ Command copied to clipboard!');
                }).catch(() => {
                    prompt('Copy command:', preview.value);
                });
            }
        }

        function executeToolRun() {
            if (!currentActiveTool) return;
            const preview = document.getElementById('toolRunCmdPreview');
            const cmd = preview ? preview.value.trim() : '';
            if (!cmd) return;

            const config = HA_TOOLS_CONFIG[currentActiveTool.name] || {};
            const isElevated = Boolean(config.elevated);

            showToast('⚡ Dispatching ' + currentActiveTool.name + '...');
            dispatchCommand(cmd, isElevated, { type: 'TOOL_RUN', target: currentActiveTool.name, details: 'Executed from Tools tab' });
            closeToolRunModal();
        }

        function openToolHelpModal(idx) {
            const catalog = INVENTORY_DATA.tools_catalog || [];
            const tool = catalog[idx];
            if (!tool) return;
            currentHelpTool = tool;

            document.getElementById('toolHelpTitle').textContent = '❓ ' + tool.name;
            document.getElementById('toolHelpChatCmd').textContent = 'Chat Command: "' + (tool.chat_command || '') + '"';
            document.getElementById('toolHelpRoleBadge').textContent = (tool.role || 'Operator') + ' Tool';
            document.getElementById('toolHelpRoleBadge').className = tool.role === 'Operator' ? 'badge badge-success' : 'badge badge-info';
            document.getElementById('toolHelpScopeBadge').textContent = tool.scope || tool.category || '$Instance';

            document.getElementById('toolHelpRole').textContent = tool.role || 'Operator';
            document.getElementById('toolHelpCategory').textContent = tool.category || '-';
            document.getElementById('toolHelpRisk').textContent = tool.risk_level || 'Safe (Standard)';
            document.getElementById('toolHelpPath').textContent = tool.script_path || '-';
            document.getElementById('toolHelpDesc').textContent = tool.description || 'No additional guidance provided.';

            const config = HA_TOOLS_CONFIG[tool.name] || {
                defaultCmd: tool.script_path.endsWith('.py') ? ('python ' + tool.script_path) : ('pwsh ' + tool.script_path)
            };
            document.getElementById('toolHelpSyntaxBox').textContent = config.defaultCmd;

            document.getElementById('toolHelpModal').classList.add('active');
        }

        function closeToolHelpModal() {
            document.getElementById('toolHelpModal').classList.remove('active');
            currentHelpTool = null;
        }

        function closeToolHelpModalOnOverlay(event) {
            if (event.target.id === 'toolHelpModal') {
                closeToolHelpModal();
            }
        }

        function runToolFromHelp() {
            if (!currentHelpTool) return;
            const catalog = INVENTORY_DATA.tools_catalog || [];
            const idx = catalog.findIndex(t => t.name === currentHelpTool.name);
            closeToolHelpModal();
            if (idx >= 0) {
                openToolRunModal(idx);
            }
        }

        function openToolLastLogFromHelp() {
            if (!currentHelpTool) return;
            openToolLastLog(currentHelpTool.name);
        }

        function openToolLastLog(toolName) {
            if (!toolName) return;
            const baseName = toolName.replace(/\.[^/.]+$/, "");
            showToast('📜 Querying latest log for ' + toolName + '...');
            const cmd = 'pwsh LCM_Inventory/tools/Show-LastLog.ps1 -ToolName "' + baseName + '" -Subsystem "$Instance"';
            dispatchCommand(cmd, false);
        }

        function dispatchCommand(cmd, elevated, actionMeta) {
            const DAEMON_URL = 'http://127.0.0.1:9876';
            if (actionMeta) {
                logDashboardAction(actionMeta.type, actionMeta.target, actionMeta.details, cmd, 'DISPATCHED');
            }
            fetch(DAEMON_URL + '/api/action', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'DO',
                    target: cmd,
                    command: cmd,
                    elevated: Boolean(elevated),
                    caller: 'HaSSD06_Inventory'
                })
            }).then(r => r.json()).then(data => {
                if (data.status === 'ERROR' || data.error) {
                    showToast('⚠️ Dispatch failed: ' + (data.message || data.error || 'Unknown error'));
                } else {
                    showToast('✓ Dispatched: ' + cmd.split(' ')[0]);
                }
            }).catch(err => {
                showToast('⚠️ LCM Daemon offline on Port 9876. Run LCM_Inventory/tools/Start-LcmDaemon.ps1');
            });
        }

        function fallbackDispatch(cmd, elevated) {
            showToast('⚠️ LCM Daemon unreachable. Ensure Start-LcmDaemon.ps1 is running on Port 9876.');
        }

        function navigateBackToSubsystems() {
            if (window.history.length > 1 && document.referrer && (
                document.referrer.includes('SHOW_SUBSYSTEMS') || 
                document.referrer.includes('SHOW_LCM') || 
                document.referrer.includes('WORKSPACE_INVENTORY_VIEWER') ||
                document.referrer.includes('Git_Repositories') ||
                document.referrer.startsWith('file://')
            )) {
                window.history.back();
                return;
            }

            // Fallback relative target: Subsystems overview in LCM_Inventory
            window.location.href = 'http://127.0.0.1:9876/inventory';
        }

        // --------------------------------------------------------------------------
        // AUTOMATION & SCRIPT INTERACTIVE ACTIONS (CRP-150)
        // --------------------------------------------------------------------------
        let currentActionEntity = null;

        function toggleAutomationState(entityId, targetState) {
            const domain = entityId.split('.')[0];
            const service = targetState === 'on' ? 'turn_on' : 'turn_off';
            showToast('⚡ Setting ' + entityId + ' to ' + targetState + '...');

            // Optimistic UI state update
            const stateBadge = document.getElementById('state-' + entityId.replace('.', '-'));
            if (stateBadge) {
                stateBadge.className = targetState === 'on' ? 'badge badge-success' : 'badge badge-danger';
                stateBadge.textContent = targetState;
            }

            const cmd = 'pwsh -File "D:\\Git_Repositories\\HaSSD06_Inventory\\tools\\Invoke-HaService.ps1" -Domain "' + domain + '" -Service "' + service + '" -EntityId "' + entityId + '"';
            dispatchCommand(cmd, false, { type: 'TOGGLE_STATE', target: entityId, details: 'State toggled to ' + targetState });
        }

        function executeScriptAction(entityId) {
            showToast('▶️ Running script ' + entityId + '...');
            const cmd = 'pwsh -File "D:\\Git_Repositories\\HaSSD06_Inventory\\tools\\Invoke-HaService.ps1" -Domain "script" -Service "turn_on" -EntityId "' + entityId + '"';
            dispatchCommand(cmd, false, { type: 'SERVICE_CALL', target: entityId, details: 'Triggered script execution' });
        }

        function openAutomationYamlModal(entityId, type, name) {
            currentActionEntity = { entityId: entityId, type: type, name: name };
            logDashboardAction('YAML_INSPECT', entityId, 'Inspected YAML definition for ' + (name || entityId));
            document.getElementById('autoYamlTypeBadge').textContent = type || 'Automation';
            document.getElementById('autoYamlModalTitle').textContent = '📝 ' + (type || 'Automation') + ': ' + (name || entityId);
            document.getElementById('autoYamlModalSubtitle').textContent = entityId;

            const isAuto = entityId.startsWith('automation.');
            const catalog = isAuto ? (INVENTORY_DATA.automations_catalog || []) : (INVENTORY_DATA.scripts_catalog || []);
            const entItem = catalog.find(x => x.entity === entityId) || {};
            const entInLive = (INVENTORY_DATA.entities_catalog || []).find(x => x.entity_id === entityId) || {};

            const uniqueId = entItem.unique_id || (entInLive.attributes ? entInLive.attributes.id : '') || entityId.replace('script.', '').replace('automation.', '');
            const mode = entItem.mode || (entInLive.attributes ? entInLive.attributes.mode : 'single') || 'single';

            let yamlText = '# Home Assistant ' + type + ' Definition\n';
            yamlText += 'id: \'' + uniqueId + '\'\n';
            yamlText += 'alias: \'' + (name || entItem.name || entityId) + '\'\n';
            yamlText += 'mode: ' + mode + '\n';
            if (entInLive.attributes && entInLive.attributes.last_triggered) {
                yamlText += '# last_triggered: ' + entInLive.attributes.last_triggered + '\n';
            }
            yamlText += 'description: \'Governed ' + type + ' extracted from Subsystem Inventory\'\n';
            yamlText += 'trigger: []\n';
            yamlText += 'condition: []\n';
            yamlText += 'action: []\n';

            document.getElementById('autoYamlContentArea').value = yamlText;

            const haBase = 'http://192.168.10.6:8123';
            const deepLink = isAuto ? 
                (haBase + '/config/automation/edit/' + (uniqueId || '')) :
                (haBase + '/config/script/edit/' + (uniqueId || entityId.replace('script.', '')));
            document.getElementById('autoYamlHaDeepLinkBtn').href = deepLink;

            document.getElementById('automationYamlModal').classList.add('active');
        }

        function closeAutomationYamlModal() {
            document.getElementById('automationYamlModal').classList.remove('active');
            currentActionEntity = null;
        }

        function closeAutomationYamlModalOnOverlay(event) {
            if (event.target.id === 'automationYamlModal') {
                closeAutomationYamlModal();
            }
        }

        function copyAutomationYaml() {
            const area = document.getElementById('autoYamlContentArea');
            if (area) {
                if (navigator.clipboard) {
                    navigator.clipboard.writeText(area.value).then(() => {
                        showToast('✓ YAML copied to clipboard!');
                    });
                } else {
                    prompt('Copy YAML:', area.value);
                }
            }
        }

        function openAutomationDeleteModal(entityId, type, name) {
            currentActionEntity = { entityId: entityId, type: type, name: name };
            document.getElementById('autoDeleteTypeBadge').textContent = type || 'Automation';
            document.getElementById('autoDeleteModalTitle').textContent = '🗑️ Delete ' + (type || 'Automation') + ': ' + (name || entityId);
            document.getElementById('autoDeleteModalSubtitle').textContent = entityId;

            const refsCount = countEntityReferences(entityId);
            const summaryDiv = document.getElementById('autoDeleteImpactSummary');
            if (refsCount === 0) {
                summaryDiv.innerHTML = '<span style="color: #7ee787;">🟢 <strong>No breaking dependencies found.</strong> No other automations, scripts, or dashboards reference <code>' + entityId + '</code>.</span>';
            } else {
                summaryDiv.innerHTML = '<span style="color: #f0883e;">⚠️ <strong>' + refsCount + ' active reference(s) found!</strong> Please verify before deleting.</span>';
            }

            const checkbox = document.getElementById('autoDeleteConfirmCheckbox');
            if (checkbox) checkbox.checked = false;
            toggleAutoDeleteConfirmBtn();

            const haBase = 'http://192.168.10.6:8123';
            const deepLink = entityId.startsWith('automation.') ? 
                (haBase + '/config/automation/dashboard') : 
                (haBase + '/config/script/dashboard');
            document.getElementById('autoDeleteHaDeepLinkBtn').href = deepLink;

            document.getElementById('automationDeleteModal').classList.add('active');
        }

        function closeAutomationDeleteModal() {
            document.getElementById('automationDeleteModal').classList.remove('active');
            currentActionEntity = null;
        }

        function closeAutomationDeleteModalOnOverlay(event) {
            if (event.target.id === 'automationDeleteModal') {
                closeAutomationDeleteModal();
            }
        }

        function toggleAutoDeleteConfirmBtn() {
            const cb = document.getElementById('autoDeleteConfirmCheckbox');
            const btn = document.getElementById('autoDeleteExecuteBtn');
            if (cb && btn) {
                if (cb.checked) {
                    btn.style.opacity = '1';
                    btn.style.pointerEvents = 'auto';
                } else {
                    btn.style.opacity = '0.5';
                    btn.style.pointerEvents = 'none';
                }
            }
        }

        function executeAutomationDelete() {
            if (!currentActionEntity) return;
            const entityId = currentActionEntity.entityId;
            showToast('🗑️ Requesting deletion for ' + entityId + '...');

            logDashboardAction('DELETE_REQUEST', entityId, 'Requested deletion via dashboard and cascade scanner');

            const row = document.getElementById('row-' + entityId.replace('.', '-'));
            if (row) {
                row.style.opacity = '0.4';
                row.style.textDecoration = 'line-through';
            }

            closeAutomationDeleteModal();
            showToast('✓ Deletion requested. Complete deletion in HA Settings or via Cascade engine.');
        }

        let toastTimeout = null;
        function showToast(msg) {
            const t = document.getElementById('toast');
            if (!t) return;
            t.textContent = msg;
            t.style.display = 'block';
            t.style.opacity = '1';
            if (toastTimeout) clearTimeout(toastTimeout);
            toastTimeout = setTimeout(() => {
                t.style.opacity = '0';
                setTimeout(() => { t.style.display = 'none'; }, 300);
            }, 3000);
        }

        function openReadinessModal() {
            const m = document.getElementById('readinessModal');
            if (m) {
                m.classList.add('active');
            }
        }

        function closeReadinessModal() {
            const m = document.getElementById('readinessModal');
            if (m) {
                m.classList.remove('active');
            }
        }

        function closeReadinessModalOnOverlay(event) {
            if (event.target && event.target.id === 'readinessModal') {
                closeReadinessModal();
            }
        }

        function copyReadinessJson() {
            if (READINESS_DATA) {
                navigator.clipboard.writeText(JSON.stringify(READINESS_DATA, null, 2)).then(() => {
                    showToast('✓ Readiness receipt JSON copied to clipboard!');
                }).catch(() => {
                    showToast('Failed to copy to clipboard');
                });
            } else {
                showToast('No readiness receipt data available');
            }
        }

        function runReadinessLiveCheck() {
            showToast('⚡ Dispatching Test-RepoReadiness.ps1 live check...');
            const frame = document.getElementById('lcm-runner-frame');
            const scriptPath = 'D:\\Git_Repositories\\HaSSD06_Inventory\\tools\\Test-RepoReadiness.ps1';
            const logPath = 'D:\\Git_Repositories\\HaSSD06_Inventory\\logs\\Test-RepoReadiness.log';
            const cmd = 'pwsh -File "' + scriptPath + '"';
            const url = 'lcm-action:run-ps?cmd=' + encodeURIComponent(cmd) + '&log=' + encodeURIComponent(logPath);
            if (frame) {
                frame.src = url;
            }
            logDashboardAction('READINESS_CHECK', 'Test-RepoReadiness.ps1', 'Live quality gate verification dispatched', cmd);
            setTimeout(() => {
                showToast('✓ Readiness check initiated! Refresh page in 2s to view updated results.');
            }, 800);
        }

        // --------------------------------------------------------------------------
        // UNIVERSAL ACTION LOGGING ENGINE (CRP-151)
        // --------------------------------------------------------------------------
        let SESSION_ACTIONS = [];
        let currentActionFilter = 'ALL';

        function logDashboardAction(actionType, target, details, command, status) {
            const now = new Date();
            const timeStr = now.toLocaleTimeString();
            const record = {
                timestamp: now.toISOString().replace('T', ' ').slice(0, 19),
                time_display: timeStr,
                source: 'SHOW_HA_INVENTORY',
                subsystem: '$Instance',
                action_type: actionType || 'ACTION',
                target: target || '-',
                details: details || '',
                command: command || '',
                status: status || 'SUCCESS',
                user: 'Operator'
            };

            SESSION_ACTIONS.unshift(record);
            updateActionBadgeCount();
            renderActionCards();

            // Background async emission to REST daemon (:9876/log)
            fetch('http://127.0.0.1:9876/log', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(record)
            }).catch(() => {});
        }

        function updateActionBadgeCount() {
            const b = document.getElementById('actionLogBadgeCount');
            if (b) b.textContent = SESSION_ACTIONS.length;
            const db = document.getElementById('drawerActionCount');
            if (db) db.textContent = SESSION_ACTIONS.length;
        }

        function renderActionCards() {
            const container = document.getElementById('actionLogContainer');
            if (!container) return;

            const filtered = currentActionFilter === 'ALL' ? SESSION_ACTIONS : 
                SESSION_ACTIONS.filter(a => (a.action_type || '').includes(currentActionFilter));

            if (filtered.length === 0) {
                container.innerHTML = '<div style="color: var(--text-muted); text-align: center; padding: 30px 10px; font-size: 12px;">No matching actions recorded.</div>';
                return;
            }

            container.innerHTML = '';
            filtered.forEach(act => {
                const card = document.createElement('div');
                card.className = 'action-card';

                const typeBadgeClass = (act.action_type || '').includes('RENAME') ? 'badge-warning' :
                    ((act.action_type || '').includes('SERVICE') || (act.action_type || '').includes('TOGGLE')) ? 'badge-success' :
                    (act.action_type || '').includes('DELETE') ? 'badge-danger' : 'badge-info';

                const statusBadgeClass = act.status === 'SUCCESS' ? 'badge-success' : (act.status === 'FAILED' ? 'badge-danger' : 'badge-warning');

                let cmdHtml = '';
                if (act.command) {
                    cmdHtml = '<div class="action-card-cmd">' + act.command + '</div>';
                }

                card.innerHTML = '<div class="action-card-header">' +
                    '<span class="badge ' + typeBadgeClass + ' action-card-type">' + (act.action_type || 'ACTION') + '</span>' +
                    '<div style="display: flex; align-items: center; gap: 6px;">' +
                    '<span class="badge ' + statusBadgeClass + '" style="font-size: 10px; padding: 1px 5px;">' + (act.status || 'OK') + '</span>' +
                    '<span class="action-card-time">' + (act.time_display || act.timestamp || '') + '</span>' +
                    '</div>' +
                    '</div>' +
                    '<div class="action-card-target">' + act.target + '</div>' +
                    '<div class="action-card-details">' + act.details + '</div>' +
                    cmdHtml;

                container.appendChild(card);
            });
        }

        function toggleActionLogDrawer() {
            const drawer = document.getElementById('actionLogDrawer');
            const overlay = document.getElementById('actionDrawerOverlay');
            if (drawer && overlay) {
                const isOpen = drawer.classList.contains('active');
                if (isOpen) {
                    closeActionLogDrawer();
                } else {
                    openActionLogDrawer();
                }
            }
        }

        function openActionLogDrawer() {
            const drawer = document.getElementById('actionLogDrawer');
            const overlay = document.getElementById('actionDrawerOverlay');
            if (drawer && overlay) {
                drawer.classList.add('active');
                overlay.classList.add('active');
                fetchDaemonActionLogs();
            }
        }

        function closeActionLogDrawer() {
            const drawer = document.getElementById('actionLogDrawer');
            const overlay = document.getElementById('actionDrawerOverlay');
            if (drawer && overlay) {
                drawer.classList.remove('active');
                overlay.classList.remove('active');
            }
        }

        function filterActionType(type, btnEl) {
            currentActionFilter = type;
            document.querySelectorAll('[id^="filter-act-"]').forEach(b => {
                b.className = 'badge badge-muted';
            });
            if (btnEl) btnEl.className = 'badge badge-info';
            renderActionCards();
        }

        function copyActionLogsJson() {
            if (SESSION_ACTIONS.length > 0) {
                navigator.clipboard.writeText(JSON.stringify(SESSION_ACTIONS, null, 2)).then(() => {
                    showToast('✓ Action log JSON copied to clipboard (' + SESSION_ACTIONS.length + ' entries)');
                }).catch(() => {
                    showToast('Failed to copy action logs');
                });
            } else {
                showToast('No actions logged yet');
            }
        }

        function fetchDaemonActionLogs() {
            fetch('http://127.0.0.1:9876/logs?subsystem=$Instance&count=50')
                .then(r => r.json())
                .then(data => {
                    if (data && data.actions && data.actions.length > 0) {
                        const existingKeys = new Set(SESSION_ACTIONS.map(a => (a.timestamp || '') + '_' + (a.action_type || '') + '_' + (a.target || '')));
                        data.actions.forEach(a => {
                            const key = (a.timestamp || '') + '_' + (a.action_type || '') + '_' + (a.target || '');
                            if (!existingKeys.has(key)) {
                                existingKeys.add(key);
                                SESSION_ACTIONS.push(a);
                            }
                        });
                        SESSION_ACTIONS.sort((a, b) => (b.timestamp || '').localeCompare(a.timestamp || ''));
                        updateActionBadgeCount();
                        renderActionCards();
                    }
                }).catch(() => {});
        }

        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                closeEntityModal();
                closeScanModal();
                closeToolRunModal();
                closeToolHelpModal();
                closeReadinessModal();
                closeActionLogDrawer();
                closeDeviceRenameModal();
                closeEntityRenameModal();
                closeAutomationYamlModal();
                closeAutomationDeleteModal();
            }
        });

        // Initialize background action logs fetch
        fetchDaemonActionLogs();
    </script>
</body>
</html>
"@

[System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.UTF8Encoding]::new($false))
Write-Host "Generated Standard LCM Inventory Viewer: $htmlPath" -ForegroundColor Green


if (-not $NoLaunch) {
    Write-Host "Opening interactive Subsystem Inventory Dashboard on Desktop (Session 1)..." -ForegroundColor Cyan
    $dispatcher = Join-Path $workspaceRoot 'LCM_Inventory\tools\Invoke-InteractiveDesktop.ps1'
    if (-not (Test-Path -LiteralPath $dispatcher)) {
        $dispatcher = Join-Path $workspaceRoot 'tools\Invoke-InteractiveDesktop.ps1'
    }
    if (Test-Path -LiteralPath $dispatcher) {
        & pwsh -File $dispatcher -FilePath $htmlPath -Pane:$Pane | Out-Null
    } else {
        Start-Process "explorer.exe" -ArgumentList "`"$htmlPath`""
    }

    try {
        Start-Sleep -Milliseconds 350
        $wsh = New-Object -ComObject WScript.Shell
        $null = $wsh.AppActivate("$Instance Subsystem Inventory")
    } catch {}
}
