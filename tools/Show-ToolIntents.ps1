<#
.SYNOPSIS
  Generates and opens the interactive HTML viewer for LCM Tool Intents (tool_intents.json).
.DESCRIPTION
  Module: Show-ToolIntents
  Purpose: Displays the comprehensive operational intent-to-command mappings defined in
  LCM_Inventory/config/tool_intents.json. Conforms to the standard display aesthetic (IBM Plex,
  light/dark mode, responsive filtering by intent keyword, goal, executable, or category).
  Provides copy-to-clipboard, parameter inspection, and click-to-run via LCM Desktop Daemon.
  Path: LCM_Inventory/tools/Show-ToolIntents.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.1
  Date: 2026-11-09 18:45:00
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

$scriptVersion = "10.0.1"
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
      $match = $prop.Name -like "*$Filter*" -or $item.goal -like "*$Filter*" -or $item.script -like "*$Filter*"
      if (-not $match) { continue }
    }
    [pscustomobject]@{
      Intent = $prop.Name
      Goal = $item.goal
      Executable = $item.executable
      Script = $item.script
      Elevated = if ($item.elevated) { 'YES' } else { 'no' }
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
            --border: #30363d;
            --text-primary: #c9d1d9;
            --text-secondary: #8b949e;
            --accent: #58a6ff;
            --accent-green: #238636;
            --badge-elevated: #f85149;
            --badge-user: #2ea043;
        }
        [data-theme="light"] {
            --bg-primary: #f6f8fa;
            --bg-secondary: #ffffff;
            --border: #d0d7de;
            --text-primary: #1f2328;
            --text-secondary: #656d76;
            --accent: #0969da;
            --accent-green: #1a7f37;
            --badge-elevated: #cf222e;
            --badge-user: #1a7f37;
        }
        body {
            margin: 0;
            padding: 20px;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
            background-color: var(--bg-primary);
            color: var(--text-primary);
        }
        .header-container {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border);
            padding-bottom: 16px;
            margin-bottom: 20px;
        }
        .header-title {
            font-size: 22px;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .header-actions {
            display: flex;
            gap: 10px;
        }
        .search-box {
            width: 100%;
            padding: 10px 14px;
            border: 1px solid var(--border);
            background: var(--bg-secondary);
            color: var(--text-primary);
            border-radius: 6px;
            font-size: 14px;
            margin-bottom: 16px;
            box-sizing: border-box;
        }
        .search-box:focus {
            outline: none;
            border-color: var(--accent);
            box-shadow: 0 0 0 3px rgba(88,166,255,0.2);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background: var(--bg-secondary);
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 1px 3px rgba(0,0,0,0.12);
        }
        th, td {
            padding: 12px 14px;
            text-align: left;
            border-bottom: 1px solid var(--border);
            font-size: 13px;
        }
        th {
            background: rgba(0,0,0,0.1);
            font-weight: 600;
            color: var(--text-secondary);
            text-transform: uppercase;
            font-size: 11px;
            letter-spacing: 0.5px;
        }
        tr:hover {
            background-color: rgba(88,166,255,0.06);
        }
        .badge {
            display: inline-block;
            padding: 2px 7px;
            font-size: 11px;
            font-weight: 600;
            border-radius: 12px;
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
        .intent-key {
            font-family: "IBM Plex Mono", Consolas, monospace;
            font-weight: 700;
            color: var(--accent);
            font-size: 13px;
        }
        .code-snippet {
            font-family: "IBM Plex Mono", Consolas, monospace;
            background: rgba(127,127,127,0.1);
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 11px;
        }
        .btn {
            background: var(--bg-secondary);
            color: var(--text-primary);
            border: 1px solid var(--border);
            border-radius: 6px;
            padding: 6px 12px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
        .btn:hover {
            border-color: var(--accent);
            color: var(--accent);
        }
        .count-badge {
            font-size: 12px;
            background: rgba(88,166,255,0.15);
            color: var(--accent);
            padding: 2px 8px;
            border-radius: 10px;
        }
    </style>
</head>
<body>
    <div class="header-container">
        <div class="header-title">
            <span>🎯</span>
            <span>LCM Tool Intents Explorer</span>
            <span class="count-badge" id="intent-count">0 Intents</span>
        </div>
        <div class="header-actions">
            <button class="btn" onclick="toggleTheme()" title="Toggle Light/Dark Theme">🌓 Theme</button>
            <button class="btn" onclick="goToTools()" title="Switch to Tool Explorer">🛠️ Show Tools</button>
            <button class="btn" onclick="goToHub()" title="Back to Control Hub">🏠 Hub</button>
        </div>
    </div>

    <input type="text" class="search-box" id="filter-input" placeholder="🔍 Filter intents by name, goal, command, parameter, or category (e.g. bcr, mount, readiness)..." oninput="renderTable()">

    <table>
        <thead>
            <tr>
                <th style="width: 160px;">Intent / Key</th>
                <th>Goal / Objective</th>
                <th style="width: 90px;">Privilege</th>
                <th>Target Script & Parameters</th>
                <th style="width: 140px;">Trampoline</th>
                <th style="width: 70px;">Action</th>
            </tr>
        </thead>
        <tbody id="intents-tbody">
        </tbody>
    </table>

    <script id="lcm-intents-data" type="application/json">$intentsJsonEscaped</script>
    <script>
        const store = JSON.parse(document.getElementById('lcm-intents-data').textContent);
        const intents = store.intents || {};
        const intentKeys = Object.keys(intents);

        function renderTable() {
            const query = (document.getElementById('filter-input').value || '').toLowerCase().trim();
            const tbody = document.getElementById('intents-tbody');
            tbody.innerHTML = '';
            let matched = 0;

            intentKeys.forEach(k => {
                const item = intents[k];
                const goal = item.goal || '';
                const script = item.script || '';
                const trampoline = item.trampoline || '';
                const elevated = item.elevated === true;
                const isPrimary = item.is_primary_intent === true;

                const textToMatch = (k + ' ' + goal + ' ' + script + ' ' + trampoline).toLowerCase();
                if (query && !textToMatch.includes(query)) return;

                matched++;
                const tr = document.createElement('tr');

                // Param preview
                let paramsHtml = '';
                if (item.parameters) {
                    const pKeys = Object.keys(item.parameters);
                    if (pKeys.length > 0) {
                        paramsHtml = '<div style="margin-top: 4px; font-size: 11px; color: var(--text-secondary);">' +
                            pKeys.map(pk => '<span class="code-snippet">' + pk + '</span>').join(' ') +
                            '</div>';
                    }
                }

                tr.innerHTML =
                    '<td>' +
                        '<div class="intent-key">' + k + '</div>' +
                        (isPrimary ? '<span class="badge badge-primary" style="margin-top: 4px;">Primary Intent</span>' : '') +
                    '</td>' +
                    '<td>' + (goal || '<span style="color:var(--text-secondary)">-</span>') + '</td>' +
                    '<td><span class="badge ' + (elevated ? 'badge-elevated">🛡️ Admin' : 'badge-user">👤 User') + '</span></td>' +
                    '<td>' +
                        '<div><span class="code-snippet">' + item.executable + ' ' + script + '</span></div>' +
                        paramsHtml +
                    '</td>' +
                    '<td>' + (trampoline ? '<span class="code-snippet">' + trampoline + '</span>' : '<span style="color:var(--text-secondary)">-</span>') + '</td>' +
                    '<td><button class="btn" style="padding: 2px 8px; font-size: 11px;" onclick="copyCmd(\'' + k + '\')">📋 Copy</button></td>';

                tbody.appendChild(tr);
            });

            document.getElementById('intent-count').textContent = matched + ' / ' + intentKeys.length + ' Intents';
        }

        function copyCmd(key) {
            const item = intents[key];
            if (!item) return;
            const cmd = item.trampoline ? item.trampoline : (item.executable + ' ' + item.script);
            navigator.clipboard.writeText(cmd).then(() => {
                alert('Copied command: ' + cmd);
            });
        }

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
