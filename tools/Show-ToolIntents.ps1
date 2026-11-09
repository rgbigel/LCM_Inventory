<#
.SYNOPSIS
  Generates and opens the interactive HTML viewer for LCM Tool Intents (tool_intents.json).
.DESCRIPTION
  Module: Show-ToolIntents
  Purpose: Displays the comprehensive operational intent-to-command mappings defined in
  LCM_Inventory/config/tool_intents.json. Conforms to the standard display aesthetic (IBM Plex,
  light/dark mode, responsive filtering by intent keyword, goal, group, category, audience, privilege).
  Features frozen table headers, multi-column sorting, column dropdown filters, and one-click
  command line copying to Windows clipboard with toast notifications.
  Path: LCM_Inventory/tools/Show-ToolIntents.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.1.0
  Date: 2026-11-09 19:35:00
.PARAMETER Filter
  Initial search keyword to filter intents upon launch.
.PARAMETER NoLaunch
  Generates the HTML dashboard and writes to data/artifacts/SHOW_TOOL_INTENTS.html without opening browser.
.PARAMETER Cli
  Outputs the intent table directly to terminal without launching browser (Aliases: -Text, -Console).
.PARAMETER Help
  Displays this comprehensive parameter reference (Aliases: -h, -?).
#>
[CmdletBinding()]
param(
  [string]$Filter = '',

  [switch]$NoLaunch,

  [Alias('Text', 'Console')]
  [switch]$Cli,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.1.0"
$scriptName = "Show-ToolIntents"

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM TOOL INTENTS VIEWER (v$scriptVersion)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Interactive HTML dashboard for direct goal-to-command operational intents."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Show-ToolIntents.ps1 [-Filter <text>] [-NoLaunch] [-Cli] [-h]"
  Write-Host "  ShowToolIntents [-Filter <text>]"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$inventoryRoot = Split-Path $PSScriptRoot -Parent
$workspaceRoot = Split-Path $inventoryRoot -Parent
$intentsFile = Join-Path $inventoryRoot 'config\tool_intents.json'

if (-not (Test-Path -LiteralPath $intentsFile -PathType Leaf)) {
  throw "Tool intents store was not found: $intentsFile"
}

$intentsRaw = Get-Content -LiteralPath $intentsFile -Raw -Encoding UTF8
$intentsData = $intentsRaw | ConvertFrom-Json

# CLI / Terminal Mode
if ($Cli) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM TOOL INTENTS LEDGER ($($intentsData.total_intents) total intents)" -ForegroundColor Green
  Write-Host "==========================================================================" -ForegroundColor Cyan
  $rows = foreach ($prop in $intentsData.intents.PSObject.Properties) {
    $item = $prop.Value
    if (-not [string]::IsNullOrWhiteSpace($Filter)) {
      $match = $prop.Name -like "*$Filter*" -or $item.goal -like "*$Filter*" -or $item.script -like "*$Filter*" -or ($item.group -and $item.group -like "*$Filter*") -or ($item.category -and $item.category -like "*$Filter*")
      if (-not $match) { continue }
    }
    [pscustomobject]@{
      Intent     = $prop.Name
      Goal       = $item.goal
      Group      = if ($item.group) { $item.group } else { '-' }
      Category   = if ($item.category) { $item.category } else { '-' }
      Audience   = if ($item.audience) { $item.audience } else { '-' }
      Elevated   = if ($item.elevated) { 'YES' } else { 'no' }
      Executable = $item.executable
      Script     = $item.script
      Trampoline = if ($item.trampoline) { $item.trampoline } else { '-' }
    }
  }
  $rows | Format-Table -AutoSize
  return
}

# Generate Interactive HTML Dashboard
$artifactsDir = Join-Path $inventoryRoot 'data\artifacts'
if (-not (Test-Path -LiteralPath $artifactsDir)) {
  New-Item -Path $artifactsDir -ItemType Directory -Force | Out-Null
}
$outputHtmlPath = Join-Path $artifactsDir 'SHOW_TOOL_INTENTS.html'

$intentsJsonEscaped = $intentsRaw.Replace('<', '\u003c')

$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LCM Tool Intents Explorer</title>
    <link rel="stylesheet" href="/assets/lcmtoolcatalog.css">
    <style>
        :root {
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --bg-tertiary: #21262d;
            --border: #30363d;
            --text-primary: #c9d1d9;
            --text-secondary: #8b949e;
            --text-muted: #6e7681;
            --accent: #58a6ff;
            --accent-green: #238636;
            --badge-elevated: #f85149;
            --badge-user: #2ea043;
            --badge-primary: #388bfd;
        }
        [data-theme="light"] {
            --bg-primary: #f6f8fa;
            --bg-secondary: #ffffff;
            --bg-tertiary: #eaeef2;
            --border: #d0d7de;
            --text-primary: #1f2328;
            --text-secondary: #656d76;
            --text-muted: #8c959f;
            --accent: #0969da;
            --accent-green: #1a7f37;
            --badge-elevated: #cf222e;
            --badge-user: #1a7f37;
            --badge-primary: #0969da;
        }
        * { box-sizing: border-box; }
        html, body {
            height: 100vh;
            margin: 0;
            padding: 0;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
            background-color: var(--bg-primary);
            color: var(--text-primary);
        }
        .container {
            height: 100vh;
            max-height: 100vh;
            display: flex;
            flex-direction: column;
            padding: 12px 18px;
            box-sizing: border-box;
            overflow: hidden;
        }
        .header-container {
            flex: 0 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
            padding-bottom: 8px;
            border-bottom: 1px solid var(--border);
        }
        .header-title {
            font-size: 20px;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .header-actions {
            display: flex;
            gap: 8px;
            align-items: center;
        }
        .filter-toolbar {
            flex: 0 0 auto;
            display: flex;
            gap: 10px;
            align-items: center;
            margin-bottom: 10px;
        }
        .search-box {
            flex: 1;
            padding: 7px 14px;
            border: 1px solid var(--border);
            background: var(--bg-secondary);
            color: var(--text-primary);
            border-radius: 6px;
            font-size: 13px;
            outline: none;
            transition: border-color 0.2s;
        }
        .search-box:focus {
            border-color: var(--accent);
        }
        .table-container {
            flex: 1 1 auto;
            min-height: 0;
            overflow-y: auto;
            overflow-x: auto;
            border: 1px solid var(--border);
            border-radius: 8px;
            background: var(--bg-secondary);
        }
        table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
            font-size: 12px;
        }
        thead {
            position: sticky;
            top: 0;
            z-index: 20;
            background: var(--bg-secondary);
        }
        th {
            position: sticky;
            top: 0;
            background: var(--bg-secondary);
            padding: 7px 8px;
            text-align: left;
            font-weight: 600;
            color: var(--text-secondary);
            border-bottom: 1px solid var(--border);
            user-select: none;
            white-space: nowrap;
        }
        th.sortable {
            cursor: pointer;
        }
        th.sortable:hover {
            color: var(--accent);
        }
        .sort-icon {
            font-size: 11px;
            margin-left: 3px;
            opacity: 0.6;
        }
        tr.col-filter-row th {
            top: 33px;
            background: var(--bg-secondary);
            padding: 4px 6px;
            border-bottom: 2px solid var(--border);
        }
        .col-filter-select, .col-filter-input {
            width: 100%;
            height: 25px;
            padding: 2px 6px;
            font-size: 11px;
            background: var(--bg-primary);
            color: var(--text-primary);
            border: 1px solid var(--border);
            border-radius: 4px;
            box-sizing: border-box;
            outline: none;
        }
        .col-filter-select:focus, .col-filter-input:focus {
            border-color: var(--accent);
        }
        td {
            padding: 6px 8px;
            border-bottom: 1px solid var(--border);
            vertical-align: middle;
        }
        tr:hover td {
            background-color: rgba(88,166,255,0.06);
        }
        .intent-key {
            font-family: "IBM Plex Mono", Consolas, monospace;
            font-weight: 700;
            color: var(--accent);
            font-size: 12.5px;
        }
        .badge {
            display: inline-block;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 10.5px;
            font-weight: 600;
            text-transform: uppercase;
        }
        .badge-elevated {
            background: rgba(248,81,73,0.15);
            color: var(--badge-elevated);
            border: 1px solid rgba(248,81,73,0.4);
        }
        .badge-user {
            background: rgba(46,160,67,0.15);
            color: var(--badge-user);
            border: 1px solid rgba(46,160,67,0.4);
        }
        .badge-primary {
            background: rgba(88,166,255,0.15);
            color: var(--accent);
            border: 1px solid rgba(88,166,255,0.4);
        }
        .badge-dev {
            background: rgba(188,140,255,0.15);
            color: #bc8cff;
            border: 1px solid rgba(188,140,255,0.4);
        }
        .code-snippet {
            font-family: "IBM Plex Mono", Consolas, monospace;
            background: rgba(127,127,127,0.12);
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 11px;
            word-break: break-all;
        }
        .btn {
            background: var(--bg-secondary);
            color: var(--text-primary);
            border: 1px solid var(--border);
            padding: 4px 10px;
            border-radius: 5px;
            cursor: pointer;
            transition: all 0.2s;
            display: inline-flex;
            align-items: center;
            gap: 5px;
            font-size: 11.5px;
            font-weight: 600;
        }
        .btn:hover {
            border-color: var(--accent);
            color: var(--accent);
        }
        .count-badge {
            font-size: 11px;
            background: rgba(88,166,255,0.15);
            color: var(--accent);
            padding: 2px 8px;
            border-radius: 10px;
        }
        .btn-copy {
            background: rgba(56,139,253,0.1);
            color: var(--accent);
            border: 1px solid rgba(56,139,253,0.3);
            font-weight: 700;
            padding: 2px 8px;
            font-size: 11px;
        }
        .btn-copy:hover {
            background: var(--accent);
            color: #ffffff;
        }
        /* Modal Overlay & Help Card */
        .modal-overlay {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.65);
            backdrop-filter: blur(2px);
            z-index: 1000;
            align-items: center;
            justify-content: center;
        }
        .modal-card {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.5);
            width: 640px;
            max-width: 90vw;
            max-height: 85vh;
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }
        .modal-header {
            padding: 12px 16px;
            background: var(--bg-tertiary);
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-weight: 700;
            font-size: 14px;
        }
        .modal-body {
            padding: 16px 20px;
            overflow-y: auto;
            font-size: 12.5px;
            line-height: 1.6;
        }
        .modal-body h4 {
            margin: 12px 0 4px 0;
            color: var(--accent);
            font-size: 13px;
        }
        .modal-close {
            background: none;
            border: none;
            color: var(--text-secondary);
            cursor: pointer;
            font-size: 16px;
            font-weight: bold;
        }
        .modal-close:hover {
            color: var(--text-primary);
        }
        .toast {
            position: fixed;
            bottom: 24px;
            right: 24px;
            background: #238636;
            color: #ffffff;
            padding: 8px 16px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 600;
            box-shadow: 0 4px 12px rgba(0,0,0,0.4);
            display: none;
            z-index: 9999;
            transition: opacity 0.3s;
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Top Bar -->
        <div class="header-container">
            <div class="header-title">
                <span>🎯</span>
                <span>LCM Tool Intents Explorer</span>
                <span class="count-badge" id="intent-count">0 Intents</span>
            </div>
            <div class="header-actions">
                <button class="btn" onclick="toggleTheme()" title="Toggle Light/Dark Theme">🌓 Theme</button>
                <button class="btn" onclick="openHelpModal()" title="Help, Documentation & Icon Legend">❓ Help & Legend</button>
                <button class="btn" onclick="goToTools()" title="Switch to Tool Explorer">🛠️ Show Tools</button>
                <button class="btn" onclick="goToHub()" title="Back to Control Hub">🏠 Hub</button>
            </div>
        </div>

        <!-- Toolbar Search & Quick Actions -->
        <div class="filter-toolbar">
            <input type="text" class="search-box" id="global-search" placeholder="🔍 Global Search across all intent keys, descriptions, groups, categories, commands, and trampolines..." oninput="applyFilters()">
            <button class="btn" onclick="resetAllFilters()" title="Reset all search queries and column dropdowns" style="flex-shrink: 0;">↺ Reset Filters</button>
        </div>

        <!-- Frozen Scrollable Table Container -->
        <div class="table-container">
            <table>
                <thead>
                    <!-- Titles Row (Sortable) -->
                    <tr>
                        <th class="sortable" onclick="sortTable('intent')" style="width: 140px;">Intent / Key <span class="sort-icon" id="sort-intent">⇅</span></th>
                        <th class="sortable" onclick="sortTable('goal')">Goal / Objective <span class="sort-icon" id="sort-goal">⇅</span></th>
                        <th class="sortable" onclick="sortTable('group')" style="width: 90px;">Group <span class="sort-icon" id="sort-group">⇅</span></th>
                        <th class="sortable" onclick="sortTable('category')" style="width: 130px;">Category <span class="sort-icon" id="sort-category">⇅</span></th>
                        <th class="sortable" onclick="sortTable('audience')" style="width: 80px;">Audience <span class="sort-icon" id="sort-audience">⇅</span></th>
                        <th class="sortable" onclick="sortTable('privilege')" style="width: 85px;">Privilege <span class="sort-icon" id="sort-privilege">⇅</span></th>
                        <th class="sortable" onclick="sortTable('script')">Target Script & Parameters <span class="sort-icon" id="sort-script">⇅</span></th>
                        <th class="sortable" onclick="sortTable('trampoline')" style="width: 130px;">Trampoline <span class="sort-icon" id="sort-trampoline">⇅</span></th>
                        <th style="width: 70px; text-align: center;">Action</th>
                    </tr>
                    <!-- Aligned Column Selectors Row -->
                    <tr class="col-filter-row">
                        <th><input type="text" class="col-filter-input" id="col-filter-intent" placeholder="Filter..." oninput="applyFilters()"></th>
                        <th><input type="text" class="col-filter-input" id="col-filter-goal" placeholder="Filter goals..." oninput="applyFilters()"></th>
                        <th>
                            <select class="col-filter-select" id="col-filter-group" onchange="applyFilters()">
                                <option value="">All Groups</option>
                            </select>
                        </th>
                        <th>
                            <select class="col-filter-select" id="col-filter-category" onchange="applyFilters()">
                                <option value="">All Categories</option>
                            </select>
                        </th>
                        <th>
                            <select class="col-filter-select" id="col-filter-audience" onchange="applyFilters()">
                                <option value="">All</option>
                                <option value="User">User</option>
                                <option value="Developer">Developer</option>
                            </select>
                        </th>
                        <th>
                            <select class="col-filter-select" id="col-filter-privilege" onchange="applyFilters()">
                                <option value="">All</option>
                                <option value="admin">🛡️ Admin</option>
                                <option value="user">👤 User</option>
                            </select>
                        </th>
                        <th><input type="text" class="col-filter-input" id="col-filter-script" placeholder="Filter target..." oninput="applyFilters()"></th>
                        <th><input type="text" class="col-filter-input" id="col-filter-trampoline" placeholder="Filter launcher..." oninput="applyFilters()"></th>
                        <th style="text-align: center;">
                            <button class="btn" onclick="resetAllFilters()" style="padding: 1px 6px; font-size: 10px;" title="Reset Filters">↺</button>
                        </th>
                    </tr>
                </thead>
                <tbody id="intents-tbody">
                </tbody>
            </table>
        </div>
    </div>

    <!-- Help & Documentation Modal -->
    <div class="modal-overlay" id="help-modal" onclick="closeHelpModal(event)">
        <div class="modal-card" onclick="event.stopPropagation()">
            <div class="modal-header">
                <span>🎯 LCM Tool Intents Explorer — Guide & Help</span>
                <button class="modal-close" onclick="closeHelpModal()">✕</button>
            </div>
            <div class="modal-body">
                <h4>What is the Tool Intents Explorer?</h4>
                <p>The <strong>Tool Intents Explorer</strong> provides a canonical, machine-readable operational ledger that maps operational objectives directly to their exact executable script, parameter contract, and trampoline batch file. It eliminates speculative code searches, linear file scanning, and accidental implementation reading (governed by <code>RULE-EFF-009: Anti-Code-Reading & Direct Goal Execution Invariant</code>).</p>

                <h4>What is the "📋 Copy" Action Button for?</h4>
                <p>Clicking <strong>📋 Copy</strong> places the <strong>exact, ready-to-run command line</strong> directly into your Windows Clipboard. If a short-name trampoline is available (e.g., <code>BCR.cmd</code> or <code>ShowTools.cmd</code>), it copies the quick batch launcher. If not, it copies the full <code>pwsh.exe -File &lt;path&gt;</code> invocation. You can immediately paste it into PowerShell, Windows Command Prompt, or terminal sessions.</p>

                <h4>Maintenance & Coupling: Who maintains this list?</h4>
                <p>This ledger is <strong>100% synchronized and automated</strong>. It is maintained directly by <code>LCM_Inventory/tools/Update-ToolCatalog.ps1</code>. Whenever tools are added, modified, or re-scanned in the workspace, <code>Update-ToolCatalog.ps1</code> automatically keeps both <code>tool_catalog.json</code> and <code>tool_intents.json</code> fully synchronized in lockstep.</p>

                <h4>Column Indicators & Badges</h4>
                <ul>
                    <li><span class="badge badge-primary">Primary Intent</span> Standardized semantic shortcut (e.g. <code>bcr</code>, <code>mount</code>, <code>push</code>, <code>showtools</code>, <code>rules</code>).</li>
                    <li><span class="badge badge-elevated">🛡️ Admin</span> Requires elevated Administrator privileges per <code>RULE-ELEV-001</code>.</li>
                    <li><span class="badge badge-user">👤 User</span> Standard non-elevated operator command.</li>
                    <li><strong>Audience (User vs. Developer):</strong> <code>User</code> identifies daily operator tools; <code>Developer</code> indicates internal plumbing and diagnostics.</li>
                </ul>

                <h4>Sorting & Frozen Headers</h4>
                <p>Click on any column header to sort ascending or descending. The table headers and filter dropdowns stay permanently frozen in place while scrolling through large intent datasets.</p>
            </div>
        </div>
    </div>

    <!-- Toast Notification Container -->
    <div class="toast" id="toast">✓ Copied command to clipboard!</div>

    <script id="lcm-intents-data" type="application/json">$intentsJsonEscaped</script>
    <script>
        const store = JSON.parse(document.getElementById('lcm-intents-data').textContent);
        const rawIntents = store.intents || {};
        const allItems = Object.keys(rawIntents).map(k => {
            const item = rawIntents[k];
            return {
                intent: k,
                goal: item.goal || '',
                group: item.group || '',
                category: item.category || '',
                audience: item.audience || 'User',
                privilege: item.elevated ? 'admin' : 'user',
                elevated: item.elevated === true,
                executable: item.executable || 'pwsh.exe',
                script: item.script || '',
                parameters: item.parameters || {},
                trampoline: item.trampoline || '',
                is_primary_intent: item.is_primary_intent === true
            };
        });

        let currentSortField = 'intent';
        let currentSortAsc = true;

        // Populate dynamic dropdowns (Group and Category)
        function initDropdowns() {
            const groupSelect = document.getElementById('col-filter-group');
            const catSelect = document.getElementById('col-filter-category');

            const groups = Array.from(new Set(allItems.map(i => i.group).filter(Boolean))).sort();
            groups.forEach(g => {
                const opt = document.createElement('option');
                opt.value = g;
                opt.textContent = g;
                groupSelect.appendChild(opt);
            });

            const categories = Array.from(new Set(allItems.map(i => i.category).filter(Boolean))).sort();
            categories.forEach(c => {
                const opt = document.createElement('option');
                opt.value = c;
                opt.textContent = c;
                catSelect.appendChild(opt);
            });
        }

        function sortTable(field) {
            if (currentSortField === field) {
                currentSortAsc = !currentSortAsc;
            } else {
                currentSortField = field;
                currentSortAsc = true;
            }
            updateSortIcons();
            renderTable();
        }

        function updateSortIcons() {
            const fields = ['intent', 'goal', 'group', 'category', 'audience', 'privilege', 'script', 'trampoline'];
            fields.forEach(f => {
                const el = document.getElementById('sort-' + f);
                if (el) {
                    if (currentSortField === f) {
                        el.textContent = currentSortAsc ? '▲' : '▼';
                        el.style.opacity = '1';
                        el.style.color = 'var(--accent)';
                    } else {
                        el.textContent = '⇅';
                        el.style.opacity = '0.6';
                        el.style.color = 'inherit';
                    }
                }
            });
        }

        function renderTable() {
            const globalQuery = (document.getElementById('global-search').value || '').toLowerCase().trim();
            const fIntent = (document.getElementById('col-filter-intent').value || '').toLowerCase().trim();
            const fGoal = (document.getElementById('col-filter-goal').value || '').toLowerCase().trim();
            const fGroup = (document.getElementById('col-filter-group').value || '').toLowerCase().trim();
            const fCategory = (document.getElementById('col-filter-category').value || '').toLowerCase().trim();
            const fAudience = (document.getElementById('col-filter-audience').value || '').toLowerCase().trim();
            const fPrivilege = (document.getElementById('col-filter-privilege').value || '').toLowerCase().trim();
            const fScript = (document.getElementById('col-filter-script').value || '').toLowerCase().trim();
            const fTrampoline = (document.getElementById('col-filter-trampoline').value || '').toLowerCase().trim();

            const tbody = document.getElementById('intents-tbody');
            tbody.innerHTML = '';

            const filtered = allItems.filter(item => {
                if (globalQuery) {
                    const haystack = (item.intent + ' ' + item.goal + ' ' + item.group + ' ' + item.category + ' ' + item.audience + ' ' + item.script + ' ' + item.trampoline).toLowerCase();
                    if (!haystack.includes(globalQuery)) return false;
                }
                if (fIntent && !item.intent.toLowerCase().includes(fIntent)) return false;
                if (fGoal && !item.goal.toLowerCase().includes(fGoal)) return false;
                if (fGroup && item.group.toLowerCase() !== fGroup) return false;
                if (fCategory && item.category.toLowerCase() !== fCategory) return false;
                if (fAudience && item.audience.toLowerCase() !== fAudience) return false;
                if (fPrivilege && item.privilege.toLowerCase() !== fPrivilege) return false;
                if (fScript && !item.script.toLowerCase().includes(fScript)) return false;
                if (fTrampoline && !item.trampoline.toLowerCase().includes(fTrampoline)) return false;
                return true;
            });

            // Sort
            filtered.sort((a, b) => {
                let valA = a[currentSortField] || '';
                let valB = b[currentSortField] || '';
                if (typeof valA === 'string') valA = valA.toLowerCase();
                if (typeof valB === 'string') valB = valB.toLowerCase();
                if (valA < valB) return currentSortAsc ? -1 : 1;
                if (valA > valB) return currentSortAsc ? 1 : -1;
                return 0;
            });

            filtered.forEach(item => {
                const tr = document.createElement('tr');

                // Param preview
                let paramsHtml = '';
                if (item.parameters) {
                    const pKeys = Object.keys(item.parameters);
                    if (pKeys.length > 0) {
                        paramsHtml = '<div style="margin-top: 3px; font-size: 10.5px; color: var(--text-secondary);">' +
                            pKeys.map(pk => '<span class="code-snippet">' + pk + '</span>').join(' ') +
                            '</div>';
                    }
                }

                tr.innerHTML =
                    '<td>' +
                        '<div class="intent-key">' + item.intent + '</div>' +
                        (item.is_primary_intent ? '<span class="badge badge-primary" style="margin-top: 3px;">Primary</span>' : '') +
                    '</td>' +
                    '<td>' + (item.goal || '<span style="color:var(--text-muted)">-</span>') + '</td>' +
                    '<td><span class="code-snippet">' + (item.group || '-') + '</span></td>' +
                    '<td>' + (item.category || '-') + '</td>' +
                    '<td><span class="badge ' + (item.audience === 'User' ? 'badge-user' : 'badge-dev') + '">' + item.audience + '</span></td>' +
                    '<td><span class="badge ' + (item.elevated ? 'badge-elevated">🛡️ Admin' : 'badge-user">👤 User') + '</span></td>' +
                    '<td>' +
                        '<div><span class="code-snippet">' + item.executable + ' ' + item.script + '</span></div>' +
                        paramsHtml +
                    '</td>' +
                    '<td>' + (item.trampoline ? '<span class="code-snippet">' + item.trampoline + '</span>' : '<span style="color:var(--text-muted)">-</span>') + '</td>' +
                    '<td style="text-align: center;"><button class="btn btn-copy" onclick="copyCmd(\'' + item.intent + '\')">📋 Copy</button></td>';

                tbody.appendChild(tr);
            });

            document.getElementById('intent-count').textContent = filtered.length + ' / ' + allItems.length + ' Intents';
        }

        function applyFilters() {
            renderTable();
        }

        function resetAllFilters() {
            document.getElementById('global-search').value = '';
            document.getElementById('col-filter-intent').value = '';
            document.getElementById('col-filter-goal').value = '';
            document.getElementById('col-filter-group').value = '';
            document.getElementById('col-filter-category').value = '';
            document.getElementById('col-filter-audience').value = '';
            document.getElementById('col-filter-privilege').value = '';
            document.getElementById('col-filter-script').value = '';
            document.getElementById('col-filter-trampoline').value = '';
            renderTable();
        }

        function copyCmd(key) {
            const item = rawIntents[key];
            if (!item) return;
            const cmd = item.trampoline ? item.trampoline : (item.executable + ' ' + item.script);
            navigator.clipboard.writeText(cmd).then(() => {
                showToast('✓ Copied: ' + cmd);
            }).catch(() => {
                // fallback
                prompt('Copy command:', cmd);
            });
        }

        function showToast(msg) {
            const toast = document.getElementById('toast');
            toast.textContent = msg;
            toast.style.display = 'block';
            toast.style.opacity = '1';
            setTimeout(() => {
                toast.style.opacity = '0';
                setTimeout(() => { toast.style.display = 'none'; }, 300);
            }, 2500);
        }

        function openHelpModal() {
            document.getElementById('help-modal').style.display = 'flex';
        }

        function closeHelpModal(e) {
            if (!e || e.target.id === 'help-modal' || e.target.classList.contains('modal-close')) {
                document.getElementById('help-modal').style.display = 'none';
            }
        }

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                closeHelpModal();
            }
        });

        function goToTools() {
            if (window.location.protocol === 'file:') {
                window.location.href = 'SHOW_TOOLS.html';
            } else {
                window.location.href = '/tools';
            }
        }

        function goToHub() {
            if (window.location.protocol === 'file:') {
                window.location.href = 'CM_CONTROL_HUB.html';
            } else {
                window.location.href = '/hub';
            }
        }

        function toggleTheme() {
            const current = document.documentElement.getAttribute('data-theme');
            const next = current === 'light' ? 'dark' : 'light';
            document.documentElement.setAttribute('data-theme', next);
            localStorage.setItem('lcm_theme', next);
        }

        const savedTheme = localStorage.getItem('lcm_theme') || 'dark';
        document.documentElement.setAttribute('data-theme', savedTheme);

        initDropdowns();
        updateSortIcons();
        renderTable();
    </script>
</body>
</html>
"@

[System.IO.File]::WriteAllText($outputHtmlPath, $htmlContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "Generated HTML Tool Intents Dashboard: $outputHtmlPath" -ForegroundColor Green

if (-not $NoLaunch) {
  Start-Process -FilePath $outputHtmlPath | Out-Null
  Write-Host "Opened Tool Intents Explorer in browser." -ForegroundColor Green
}
