<#
.SYNOPSIS
  Scans, summarizes, and visualizes Quality Gate Readiness Receipts across all workspace repositories.
.DESCRIPTION
  Module: LCM_Inventory/tools/Show-LCM_Readiness.ps1
  Purpose: Summarize retained workspace readiness receipts and optionally publish an HTTP snapshot.
  Path: tools/Show-LCM_Readiness.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.1
  Date: 2026-11-08 17:34:00
  ShortName: ShowReadiness
  
  Features:
  1. Scans all child repositories under D:\Git_Repositories for standardized readiness receipts
     (data/readiness/latest_readiness.json and data/readiness/latest_rule_health.json).
  2. Detects available readiness test harnesses (tools/Test-RepoReadiness.ps1).
  3. Displays a rich, color-coded console matrix showing pass/fail status, gate counts, durations, and receipt ages.
  4. Generates a standalone interactive HTML dashboard when -Html switch is provided.
  5. Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), RULE-PS-010 (CLI Help),
     and RULE-PS-011 (Interactive Desktop Dispatch).

.PARAMETER WorkspaceRoot
  The root workspace directory containing repositories to inspect (Defaults to 'D:\Git_Repositories').
.PARAMETER Repository
  Optional filter to inspect a single repository (Aliases: -Repo, -TargetRepository).
.PARAMETER Html
  Generates and opens the interactive HTML Quality Gate Readiness matrix dashboard.
.PARAMETER RunMissing
  Automatically runs Test-RepoReadiness.ps1 for any repository that has the test harness but lacks an up-to-date receipt.
.PARAMETER NoLaunch
  When -Html is specified, generates the HTML report without launching the browser.
.PARAMETER Pane
  Opens the display inside an Antigravity IDE editor/side pane instead of an external browser window (Alias: -Panel).
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).

.EXAMPLE
  pwsh LCM_Inventory/tools/Show-LCM_Readiness.ps1 -h
.EXAMPLE
  pwsh LCM_Inventory/tools/Show-LCM_Readiness.ps1
.EXAMPLE
  pwsh LCM_Inventory/tools/Show-LCM_Readiness.ps1 -Html
.EXAMPLE
  pwsh LCM_Inventory/tools/Show-LCM_Readiness.ps1 -Repo HaSSD06_Inventory -Html
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [Alias('Repo', 'TargetRepository')]
    [string]$Repository,

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Parameter(Mandatory = $false)]
    [switch]$Html,

    [Parameter(Mandatory = $false)]
    [switch]$RunMissing,

    [Parameter(Mandatory = $false)]
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
$provenance = Get-LcmDisplayProvenance -ScriptPath $PSCommandPath -TemplatePath $PSCommandPath

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " WORKSPACE QUALITY GATE READINESS ROLLUP (v$scriptVersion)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Scans and reports Quality Gate Readiness across all repositories."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Show-LCM_Readiness.ps1 [[-Repository] <name>] [-Html] [-RunMissing] [-NoLaunch] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Repository : Target specific repository to inspect"
    Write-Host "  -Html       : Generate and display interactive HTML dashboard"
    Write-Host "  -RunMissing : Automatically run Test-RepoReadiness.ps1 if receipt is missing"
    Write-Host "  -NoLaunch   : Generate HTML report without auto-launching web browser"
    Write-Host "  -Help (-h)  : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

# Discover Repositories
$childDirs = @(Get-ChildItem -Path $WorkspaceRoot -Directory | Where-Object {
    $_.Name -notmatch '^\.' -and (Test-Path (Join-Path $_.FullName '.git'))
})

if (-not [string]::IsNullOrWhiteSpace($Repository)) {
    $childDirs = @($childDirs | Where-Object { $_.Name -like "*$Repository*" })
}

$now = Get-Date
$readinessRows = @()

# Workspace-level requisite check: external tools, Machine PATH and Everything content-index settings
$externalToolsCheck = Join-Path $PSScriptRoot 'Test-ExternalTools.ps1'
if (Test-Path -LiteralPath $externalToolsCheck) {
    Write-Host " [>] External tools and Everything index (LCM_AI\docs\Requisites)..." -ForegroundColor Yellow
    & pwsh -NoProfile -File $externalToolsCheck | Out-Host
}

foreach ($dir in $childDirs) {
    $repoName = $dir.Name
    $repoPath = $dir.FullName
    
    $readinessScript = Join-Path $repoPath 'tools\Test-RepoReadiness.ps1'
    $hasTestScript = Test-Path -LiteralPath $readinessScript
    
    $receiptPath = Join-Path $repoPath 'data\readiness\latest_readiness.json'
    $hasReceipt = Test-Path -LiteralPath $receiptPath
    
    if (-not $hasReceipt -and $hasTestScript -and $RunMissing) {
        Write-Host " [>] Running Test-RepoReadiness.ps1 for $repoName..." -ForegroundColor Yellow
        try {
            & pwsh -File $readinessScript | Out-Null
            $hasReceipt = Test-Path -LiteralPath $receiptPath
        } catch {
            Write-Host " [!] Failed to run Test-RepoReadiness.ps1 for $repoName : $_" -ForegroundColor Red
        }
    }
    
    $receiptData = $null
    $rawReceiptJson = $null
    if ($hasReceipt) {
        try {
            $rawReceiptJson = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8
            $receiptData = $rawReceiptJson | ConvertFrom-Json
        } catch {
            $receiptData = $null
        }
    }
    
    $ruleHealthReceiptPath = Join-Path $repoPath 'data\readiness\latest_rule_health.json'
    $ruleHealthData = $null
    if (Test-Path -LiteralPath $ruleHealthReceiptPath) {
        try {
            $ruleHealthData = Get-Content -LiteralPath $ruleHealthReceiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {}
    }
    
    $status = 'NO RECEIPT'
    $passedGates = 0
    $totalGates = 0
    $durationMs = 0
    $timestampStr = '-'
    $ageStr = '-'
    $gates = @()
    
    if ($receiptData) {
        $status = if ($receiptData.PSObject.Properties['overall_status']) { [string]$receiptData.overall_status } else { 'UNKNOWN' }
        $passedGates = if ($receiptData.PSObject.Properties['passed_count']) { [int]$receiptData.passed_count } else { 0 }
        $totalGates = if ($receiptData.PSObject.Properties['total_count']) { [int]$receiptData.total_count } else { 0 }
        $durationMs = if ($receiptData.PSObject.Properties['duration_ms']) { [int]$receiptData.duration_ms } else { 0 }
        
        if ($receiptData.PSObject.Properties['timestamp']) {
            $timestampStr = [string]$receiptData.timestamp
            try {
                $dt = [datetime]$timestampStr
                $diff = $now - $dt
                if ($diff.TotalMinutes -lt 60) {
                    $ageStr = "$([int]$diff.TotalMinutes)m ago"
                } elseif ($diff.TotalHours -lt 24) {
                    $ageStr = "$([int]$diff.TotalHours)h ago"
                } else {
                    $ageStr = "$([int]$diff.TotalDays)d ago"
                }
            } catch {
                $ageStr = '-'
            }
        }
        if ($receiptData.PSObject.Properties['gates']) {
            $gates = $receiptData.gates
        }
    } elseif ($hasTestScript) {
        $status = 'HARNESS AVAILABLE (NO RUN)'
    } else {
        $status = 'NO HARNESS'
    }
    
    $readinessRows += [PSCustomObject]@{
        Repository     = $repoName
        Path           = $repoPath
        Status         = $status
        PassedGates    = $passedGates
        TotalGates     = $totalGates
        GatesRatio     = if ($totalGates -gt 0) { "$passedGates/$totalGates" } else { "-" }
        DurationMs     = $durationMs
        Timestamp      = $timestampStr
        Age            = $ageStr
        HasScript      = $hasTestScript
        ScriptPath     = if ($hasTestScript) { $readinessScript } else { '-' }
        ReceiptPath    = if ($hasReceipt) { $receiptPath } else { '-' }
        RawReceipt     = $rawReceiptJson
        Gates          = $gates
        RuleHealth     = $ruleHealthData
    }
}

# Console Report Rendering
Write-Host "`n========================================================================================================" -ForegroundColor Cyan
Write-Host " LCM Quality Gate Readiness Rollup Report" -ForegroundColor Cyan
Write-Host "========================================================================================================" -ForegroundColor Cyan
Write-Host (" {0,-24} | {1,-18} | {2,-10} | {3,-10} | {4,-12} | {5}" -f 'Repository', 'Readiness Status', 'Gates', 'Duration', 'Receipt Age', 'Harness Script') -ForegroundColor Yellow
Write-Host "-------------------------+--------------------+------------+------------+--------------+----------------" -ForegroundColor DarkGray

$passedCount = 0
$failedCount = 0
$missingCount = 0
$noHarnessCount = 0

foreach ($r in $readinessRows) {
    $color = [ConsoleColor]::Gray
    $icon = "⚪"
    if ($r.Status -eq 'PASSED') {
        $color = [ConsoleColor]::Green
        $icon = "🟢"
        $passedCount++
    } elseif ($r.Status -eq 'FAILED') {
        $color = [ConsoleColor]::Red
        $icon = "🔴"
        $failedCount++
    } elseif ($r.Status -like '*HARNESS*') {
        $color = [ConsoleColor]::Yellow
        $icon = "🟡"
        $missingCount++
    } else {
        $color = [ConsoleColor]::DarkGray
        $icon = "⚪"
        $noHarnessCount++
    }

    $durText = if ($r.DurationMs -gt 0) { "$($r.DurationMs) ms" } else { "-" }
    $harnessText = if ($r.HasScript) { "Test-RepoReadiness.ps1" } else { "-" }

    Write-Host (" {0,-24} | {1,-18} | {2,-10} | {3,-10} | {4,-12} | {5}" -f $r.Repository, "$icon $($r.Status)", $r.GatesRatio, $durText, $r.Age, $harnessText) -ForegroundColor $color
}

Write-Host "========================================================================================================" -ForegroundColor Cyan
Write-Host (" Summary: Total Repos: {0} | Passed: {1} | Failed: {2} | Pending Receipts: {3} | No Harness: {4}" -f $readinessRows.Count, $passedCount, $failedCount, $missingCount, $noHarnessCount) -ForegroundColor Cyan
Write-Host "========================================================================================================`n" -ForegroundColor Cyan

# HTML Dashboard Generation
if ($Html) {
    $artifactsDir = Join-Path $WorkspaceRoot 'LCM_Inventory\data\artifacts'
    if (-not (Test-Path -LiteralPath $artifactsDir)) {
        New-Item -Path $artifactsDir -ItemType Directory -Force | Out-Null
    }
    $scratchDir = Join-Path $WorkspaceRoot 'LCM_Inventory\scratch'
    if (-not (Test-Path -LiteralPath $scratchDir)) {
        New-Item -Path $scratchDir -ItemType Directory -Force | Out-Null
    }
    $htmlPath = Join-Path $artifactsDir 'LCM_READINESS.html'
    
    $genTimestamp = $now.ToString('yyyy-MM-dd HH:mm:ss')
    $embeddedRowsJson = ($readinessRows | ConvertTo-Json -Depth 6)
    
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LCM Workspace Quality Gate Readiness Explorer $($provenance.Label)</title>
    <style>
        :root {
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --bg-tertiary: #21262d;
            --text-primary: #c9d1d9;
            --text-secondary: #8b949e;
            --text-muted: #6e7681;
            --accent: #58a6ff;
            --accent-hover: #79c0ff;
            --success: #238636;
            --success-border: #2ea043;
            --danger: #da3633;
            --warning: #d29922;
            --border: #30363d;
            --card-bg: #161b22;
        }

        body.light-theme {
            --bg-primary: #f6f8fa;
            --bg-secondary: #ffffff;
            --bg-tertiary: #eaeef2;
            --text-primary: #1f2328;
            --text-secondary: #59636e;
            --text-muted: #8c959f;
            --accent: #0969da;
            --accent-hover: #0550ae;
            --border: #d0d7de;
            --card-bg: #ffffff;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background-color: var(--bg-primary);
            color: var(--text-primary);
            padding: 20px 24px;
            font-size: 13px;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border);
            padding-bottom: 16px;
            margin-bottom: 20px;
        }

        .header-title-row { display: flex; align-items: center; gap: 12px; }
        .header-title { font-size: 20px; font-weight: 700; }
        .header-meta { font-size: 12px; color: var(--text-secondary); margin-top: 4px; }

        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 14px;
            margin-bottom: 20px;
        }

        .metric-card {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 14px 16px;
        }
        .metric-label { font-size: 11px; text-transform: uppercase; font-weight: 700; color: var(--text-secondary); }
        .metric-value { font-size: 24px; font-weight: 700; margin: 4px 0; color: var(--text-primary); }
        .metric-sub { font-size: 11px; color: var(--text-muted); }

        .filter-panel {
            display: flex;
            gap: 12px;
            margin-bottom: 16px;
            align-items: center;
        }
        .search-input {
            flex: 1;
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 6px;
            padding: 8px 12px;
            color: var(--text-primary);
            font-size: 13px;
            outline: none;
        }
        .search-input:focus { border-color: var(--accent); }

        .btn-theme {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 6px;
            padding: 8px 14px;
            color: var(--text-primary);
            cursor: pointer;
            font-weight: 600;
        }
        .btn-theme:hover { background: var(--bg-tertiary); }

        .table-container {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 8px;
            overflow-x: auto;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }
        th, td {
            padding: 10px 14px;
            border-bottom: 1px solid var(--border);
            text-align: left;
        }
        th {
            background: var(--bg-tertiary);
            font-weight: 600;
            color: var(--text-secondary);
            font-size: 12px;
            text-transform: uppercase;
        }
        tr:hover { background: rgba(255, 255, 255, 0.02); }

        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
        }
        .badge-success { background: rgba(46, 160, 67, 0.15); color: #7ee787; border: 1px solid rgba(46, 160, 67, 0.3); }
        .badge-danger { background: rgba(248, 81, 73, 0.15); color: #ff7b72; border: 1px solid rgba(248, 81, 73, 0.3); }
        .badge-warning { background: rgba(210, 153, 34, 0.15); color: #d29922; border: 1px solid rgba(210, 153, 34, 0.3); }
        .badge-muted { background: rgba(110, 118, 129, 0.15); color: #8b949e; border: 1px solid rgba(110, 118, 129, 0.3); }
        .badge-info { background: rgba(56, 139, 253, 0.15); color: var(--accent); border: 1px solid rgba(56, 139, 253, 0.3); }

        .code-cell { font-family: 'JetBrains Mono', monospace; font-size: 12px; }

        .action-btn {
            background: rgba(56, 139, 253, 0.1);
            border: 1px solid rgba(56, 139, 253, 0.3);
            color: var(--accent);
            border-radius: 6px;
            padding: 4px 10px;
            font-size: 11px;
            font-weight: 600;
            cursor: pointer;
        }
        .action-btn:hover { background: rgba(56, 139, 253, 0.25); }

        /* Modal */
        .modal-overlay {
            display: none;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.75);
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
            border-radius: 12px;
            max-width: 800px;
            width: 100%;
            max-height: 85vh;
            overflow-y: auto;
            padding: 24px;
            position: relative;
        }
        .modal-close {
            position: absolute;
            top: 16px; right: 16px;
            background: none; border: none;
            color: var(--text-muted);
            font-size: 20px; cursor: pointer;
        }
        .modal-close:hover { color: var(--text-primary); }

        .toast {
            position: fixed; bottom: 20px; right: 20px;
            background: #1f242c; color: #58a6ff; border: 1px solid #388bfd;
            border-radius: 8px; padding: 10px 18px; font-size: 12px; font-weight: 600;
            display: none; z-index: 2000;
        }
    </style>
</head>
<body>
    <div class="header">
        <div>
            <div class="header-title-row">
                <span style="font-size: 24px;">🛡️</span>
                <span class="header-title">LCM Workspace Quality Gate Readiness Explorer</span>
                <span class="badge badge-info">$($provenance.Label)</span>
            </div>
            <div class="header-meta">Generated: $genTimestamp &bull; Workspace Root: $WorkspaceRoot</div>
        </div>
        <div style="display: flex; gap: 10px;">
            <button class="btn-theme" id="themeBtn" onclick="toggleTheme()">☀️ Light Mode</button>
        </div>
    </div>

    <div class="metrics-grid">
        <div class="metric-card">
            <div class="metric-label">Total Repositories</div>
            <div class="metric-value">$($readinessRows.Count)</div>
            <div class="metric-sub">Governed Workspace Repos</div>
        </div>
        <div class="metric-card">
            <div class="metric-label">Readiness Passed</div>
            <div class="metric-value" style="color: #7ee787;">$passedCount</div>
            <div class="metric-sub">Full Quality Gate Pass</div>
        </div>
        <div class="metric-card">
            <div class="metric-label">Readiness Drift / Failed</div>
            <div class="metric-value" style="color: #ff7b72;">$failedCount</div>
            <div class="metric-sub">Broken Quality Gates</div>
        </div>
        <div class="metric-card">
            <div class="metric-label">Pending Receipts</div>
            <div class="metric-value" style="color: #d29922;">$missingCount</div>
            <div class="metric-sub">Harness Present &bull; No Run</div>
        </div>
    </div>

    <div class="filter-panel">
        <input type="text" id="searchInput" class="search-input" placeholder="Filter repositories, statuses, or receipts..." oninput="filterTable()">
        <span id="matchCounter" style="font-size: 12px; color: var(--text-secondary); white-space: nowrap;">$($readinessRows.Count) repositories</span>
    </div>

    <div class="table-container">
        <table id="readinessTable">
            <thead>
                <tr>
                    <th>Repository</th>
                    <th>Readiness Status</th>
                    <th>Quality Gates</th>
                    <th>Duration</th>
                    <th>Receipt Age</th>
                    <th>Harness Script</th>
                    <th style="text-align: center;">Actions</th>
                </tr>
            </thead>
            <tbody id="readinessTableBody">
            </tbody>
        </table>
    </div>

    <!-- Drill-Down Gate Modal -->
    <div id="gateModal" class="modal-overlay" onclick="closeGateModalOnOverlay(event)">
        <div class="modal-box">
            <button class="modal-close" onclick="closeGateModal()">&times;</button>
            <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 8px;">
                <span id="modalStatusBadge" class="badge badge-success">PASSED</span>
                <span id="modalRepoName" style="font-size: 18px; font-weight: 700;">Repo Name</span>
            </div>
            <div id="modalSubtitle" style="font-size: 12px; color: var(--text-secondary); margin-bottom: 16px;">Verified: 2026-10-13 &bull; Duration: 341ms</div>

            <div id="modalGatesList" style="margin-top: 14px;">
            </div>

            <div style="display: flex; justify-content: space-between; margin-top: 20px; border-top: 1px solid var(--border); padding-top: 14px;">
                <button class="action-btn" onclick="copyCurrentReceiptJson()">📋 Copy JSON Receipt</button>
                <button class="btn-theme" onclick="closeGateModal()">Close</button>
            </div>
        </div>
    </div>

    <div class="toast" id="toast"></div>

    <script>
        const ROWS_DATA = $embeddedRowsJson;
        let currentModalRow = null;

        function renderTable(rows) {
            const tbody = document.getElementById('readinessTableBody');
            tbody.innerHTML = '';
            rows.forEach((r, idx) => {
                const tr = document.createElement('tr');
                const badgeClass = r.Status === 'PASSED' ? 'badge-success' : (r.Status === 'FAILED' ? 'badge-danger' : (r.Status.includes('HARNESS') ? 'badge-warning' : 'badge-muted'));
                const icon = r.Status === 'PASSED' ? '🟢' : (r.Status === 'FAILED' ? '🔴' : (r.Status.includes('HARNESS') ? '🟡' : '⚪'));
                const durText = r.DurationMs > 0 ? (r.DurationMs + ' ms') : '-';
                const harnessName = r.HasScript ? 'Test-RepoReadiness.ps1' : '-';

                const inspectBtn = r.Gates && r.Gates.length > 0 ? 
                    '<button class="action-btn" onclick="openGateModal(' + idx + ')">🔍 Inspect Gates</button>' : 
                    '<span style="color: var(--text-muted); font-size: 11px;">No Gates</span>';

                tr.innerHTML = '<td><strong>' + r.Repository + '</strong></td>' +
                    '<td><span class="badge ' + badgeClass + '">' + icon + ' ' + r.Status + '</span></td>' +
                    '<td class="code-cell">' + r.GatesRatio + '</td>' +
                    '<td class="code-cell">' + durText + '</td>' +
                    '<td>' + r.Age + '</td>' +
                    '<td class="code-cell" style="font-size: 11px;">' + harnessName + '</td>' +
                    '<td style="text-align: center;">' + inspectBtn + '</td>';
                tbody.appendChild(tr);
            });
            document.getElementById('matchCounter').textContent = rows.length + ' repositories';
        }

        function filterTable() {
            const q = document.getElementById('searchInput').value.toLowerCase().trim();
            if (!q) {
                renderTable(ROWS_DATA);
                return;
            }
            const filtered = ROWS_DATA.filter(r => {
                const target = (r.Repository + ' ' + r.Status + ' ' + r.ScriptPath + ' ' + r.Age).toLowerCase();
                return target.includes(q);
            });
            renderTable(filtered);
        }

        function openGateModal(idx) {
            const r = ROWS_DATA[idx];
            if (!r) return;
            currentModalRow = r;
            document.getElementById('modalRepoName').textContent = r.Repository;
            const badge = document.getElementById('modalStatusBadge');
            badge.className = 'badge ' + (r.Status === 'PASSED' ? 'badge-success' : 'badge-danger');
            badge.textContent = r.Status;
            document.getElementById('modalSubtitle').textContent = 'Verified: ' + r.Timestamp + ' • Duration: ' + r.DurationMs + 'ms';

            const list = document.getElementById('modalGatesList');
            list.innerHTML = '';
            if (r.Gates && r.Gates.length > 0) {
                r.Gates.forEach(g => {
                    const isPass = g.status === 'PASSED';
                    const gDiv = document.createElement('div');
                    gDiv.style.background = isPass ? 'rgba(46, 160, 67, 0.08)' : 'rgba(248, 81, 73, 0.08)';
                    gDiv.style.border = '1px solid ' + (isPass ? 'rgba(46, 160, 67, 0.3)' : 'rgba(248, 81, 73, 0.3)');
                    gDiv.style.borderRadius = '8px';
                    gDiv.style.padding = '10px 14px';
                    gDiv.style.marginBottom = '8px';

                    gDiv.innerHTML = '<div style="display: flex; justify-content: space-between; align-items: center;">' +
                        '<div><strong>Gate ' + g.id + ': ' + g.name + '</strong></div>' +
                        '<div><span class="badge ' + (isPass ? 'badge-success' : 'badge-danger') + '">' + g.status + ' (' + g.duration_ms + 'ms)</span></div>' +
                        '</div>' +
                        '<div style="font-size: 12px; color: var(--text-secondary); margin-top: 4px;">' + g.details + '</div>' +
                        (g.failure_reason ? ('<div style="color: #ff7b72; font-size: 11px; margin-top: 4px;">Reason: ' + g.failure_reason + '</div>') : '');
                    list.appendChild(gDiv);
                });
            } else {
                list.innerHTML = '<div style="color: var(--text-muted); text-align: center; padding: 20px;">No gate breakdown available in receipt.</div>';
            }

            document.getElementById('gateModal').classList.add('active');
        }

        function closeGateModal() {
            document.getElementById('gateModal').classList.remove('active');
            currentModalRow = null;
        }

        function closeGateModalOnOverlay(e) {
            if (e.target.id === 'gateModal') {
                closeGateModal();
            }
        }

        function copyCurrentReceiptJson() {
            if (currentModalRow && currentModalRow.RawReceipt) {
                navigator.clipboard.writeText(currentModalRow.RawReceipt).then(() => {
                    showToast('✓ Quality Gate Receipt JSON copied!');
                }).catch(() => {
                    showToast('Failed to copy');
                });
            } else {
                showToast('No receipt data');
            }
        }

        let toastTimeout = null;
        function showToast(msg) {
            const t = document.getElementById('toast');
            if (!t) return;
            t.textContent = msg;
            t.style.display = 'block';
            if (toastTimeout) clearTimeout(toastTimeout);
            toastTimeout = setTimeout(() => { t.style.display = 'none'; }, 3000);
        }

        function toggleTheme() {
            const current = document.documentElement.getAttribute('data-theme');
            const target = current === 'light' ? 'dark' : 'light';
            document.documentElement.setAttribute('data-theme', target);
            document.body.classList.toggle('light-theme', target === 'light');
            document.getElementById('themeBtn').textContent = target === 'light' ? '🌙 Dark Mode' : '☀️ Light Mode';
        }

        // Init
        renderTable(ROWS_DATA);
    </script>
</body>
</html>
"@

    $htmlContent = $htmlContent.Replace('<body>', '<body><aside role="status">Retained readiness snapshot. Receipt ages describe collected evidence, not current workspace readiness. Reloading does not run tests.</aside>')
    $htmlContent | Set-Content -LiteralPath $htmlPath -Encoding UTF8
    $htmlContent | Set-Content -LiteralPath (Join-Path $scratchDir 'LCM_READINESS.html') -Encoding UTF8
    Write-Host "Generated HTML Readiness Dashboard: $htmlPath" -ForegroundColor Green

    if (-not $NoLaunch) {
        Write-Host "Opening interactive Quality Gate Readiness Dashboard in browser..." -ForegroundColor Cyan
        Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmStandardDisplay.psm1') -Force
        $snapshotId = Publish-LcmEvidenceSnapshot -Path $htmlPath
        Open-LcmStandardDisplay -DisplayId snapshot -SnapshotId $snapshotId -Pane:$Pane
    }
}

return $readinessRows
