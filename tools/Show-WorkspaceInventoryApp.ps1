<#
.SYNOPSIS
  Generates and opens the modern interactive HTML explorer for LCM Workspace Inventory.
.DESCRIPTION
  Module: Show-WorkspaceInventoryApp
  Purpose: Generates and opens the interactive HTML workspace dashboard conforming to the
           INVENTORY_VIEWER design standard. Features clickable metric cards, multi-tab navigation
           (Repositories Ledger, Workspace Tools, Governance Rules), live search filtering,
           generation timestamp, and refresh action button.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: Workspace_Inventory/tools/Show-WorkspaceInventoryApp.ps1
  Authors: Rolf, Workspace_AI Engine
  Version: 5.1.0
  Date: 2026-08-25
.PARAMETER NoLaunch
  Generates the HTML dashboard file without automatically launching it in the web browser.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Show-WorkspaceInventoryApp.ps1 -h
.EXAMPLE
  pwsh tools/Show-WorkspaceInventoryApp.ps1
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

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM WORKSPACE INVENTORY VIEWER (v5.1.0)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Generates and displays the interactive HTML dashboard for LCM Workspace Inventory."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Show-WorkspaceInventoryApp.ps1 [-NoLaunch] [-h]"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$invPath = Join-Path $repoRoot 'data\inventory.json'
$htmlPath = Join-Path $repoRoot 'docs\WORKSPACE_INVENTORY_VIEWER.html'

if (-not (Test-Path -LiteralPath $invPath)) {
  throw "Workspace inventory file not found: $invPath"
}

$inv = Get-Content -LiteralPath $invPath -Raw | ConvertFrom-Json

$totalRepos = $inv.repositories.Count
$governedRepos = ($inv.repositories | Where-Object { $_.LCMStatus -match 'governed' }).Count
$dirtyRepos = ($inv.repositories | Where-Object { $_.DirtyState -ne 'clean' -and $_.DirtyState -ne $null }).Count
$lcm5Repos = ($inv.repositories | Where-Object { $_.CurrentLCMVersion -eq '5.0.2' -or $_.AbsorbedLCMVersion -eq '5.0.2' }).Count
$schemaVer = if ($inv.PSObject.Properties['workspace_ai_baseline']) { $inv.workspace_ai_baseline.GlobalLCMVersion } else { '5.0.2' }
$genTime = if ($inv.generated_at) { $inv.generated_at } else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LCM Workspace Inventory Explorer</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --bg-tertiary: #21262d;
            --accent: #58a6ff;
            --accent-gradient: linear-gradient(135deg, #388bfd, #1f6feb);
            --text-primary: #f0f6fc;
            --text-secondary: #8b949e;
            --text-muted: #6e7681;
            --border: #30363d;
            --success: #3fb950;
            --warning: #d29922;
            --danger: #f85149;
            --badge-bg: rgba(56, 139, 253, 0.15);
            --card-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.5;
            padding: 24px;
        }

        .container { max-width: 1560px; margin: 0 auto; }
        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border);
            margin-bottom: 24px;
            flex-wrap: wrap;
            gap: 16px;
        }

        .header-title h1 {
            font-size: 26px;
            font-weight: 700;
            background: linear-gradient(135deg, #58a6ff 0%, #3fb950 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .header-meta {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-top: 6px;
            font-size: 13px;
            color: var(--text-secondary);
        }

        .timestamp-badge {
            background: var(--bg-tertiary);
            border: 1px solid var(--border);
            padding: 2px 10px;
            border-radius: 20px;
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            color: var(--accent);
        }

        .btn-refresh {
            background: var(--accent-gradient);
            color: #ffffff;
            border: none;
            border-radius: 8px;
            padding: 10px 18px;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 8px;
            transition: all 0.2s ease;
            box-shadow: 0 4px 12px rgba(56, 139, 253, 0.3);
        }

        .btn-refresh:hover { transform: translateY(-1px); box-shadow: 0 6px 18px rgba(56, 139, 253, 0.45); }

        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }

        .metric-card {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 16px;
            box-shadow: var(--card-shadow);
            cursor: pointer;
            transition: all 0.2s ease;
        }

        .metric-card:hover { transform: translateY(-3px); border-color: var(--accent); }

        .metric-label { font-size: 12px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); }
        .metric-value { font-size: 26px; font-weight: 700; color: var(--text-primary); margin-top: 4px; font-family: 'JetBrains Mono', monospace; }
        .metric-sub { font-size: 12px; color: var(--success); margin-top: 4px; }

        .tabs { display: flex; gap: 8px; border-bottom: 1px solid var(--border); margin-bottom: 20px; overflow-x: auto; }
        .tab-btn {
            background: none;
            border: none;
            color: var(--text-secondary);
            font-size: 14px;
            font-weight: 600;
            padding: 10px 18px;
            cursor: pointer;
            border-bottom: 2px solid transparent;
            transition: all 0.2s;
            white-space: nowrap;
        }
        .tab-btn:hover { color: var(--text-primary); }
        .tab-btn.active { color: var(--accent); border-bottom-color: var(--accent); }

        .search-bar { display: flex; gap: 12px; margin-bottom: 16px; }
        .search-input {
            flex: 1;
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 10px 16px;
            color: var(--text-primary);
            font-size: 14px;
            outline: none;
        }
        .search-input:focus { border-color: var(--accent); }

        .table-container {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 12px;
            overflow: hidden;
            box-shadow: var(--card-shadow);
        }

        .scrollable-table { width: 100%; border-collapse: collapse; text-align: left; font-size: 13px; }
        .scrollable-table th {
            background: var(--bg-tertiary);
            color: var(--text-secondary);
            font-weight: 600;
            padding: 12px 16px;
            border-bottom: 1px solid var(--border);
            cursor: pointer;
            user-select: none;
        }
        .scrollable-table td {
            padding: 12px 16px;
            border-bottom: 1px solid rgba(240, 246, 252, 0.05);
            color: var(--text-primary);
        }
        .scrollable-table tr:hover { background: rgba(88, 166, 255, 0.04); }

        .code-cell { font-family: 'JetBrains Mono', monospace; font-size: 12px; color: #79c0ff; }
        .badge {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
        }
        .badge-success { background: rgba(63, 185, 80, 0.15); color: var(--success); }
        .badge-info { background: rgba(88, 166, 255, 0.15); color: var(--accent); }
        .badge-warning { background: rgba(210, 153, 34, 0.15); color: var(--warning); }
        .badge-muted { background: rgba(110, 118, 129, 0.15); color: var(--text-muted); }

        .btn-copy {
            background: var(--bg-tertiary);
            border: 1px solid var(--border);
            color: var(--text-secondary);
            border-radius: 6px;
            padding: 4px 8px;
            font-size: 11px;
            cursor: pointer;
            transition: all 0.15s ease;
        }
        .btn-copy:hover { color: var(--text-primary); border-color: var(--accent); }

        .toast {
            position: fixed;
            bottom: 24px;
            right: 24px;
            background: var(--success);
            color: #0d1117;
            font-weight: 700;
            font-size: 13px;
            padding: 10px 20px;
            border-radius: 8px;
            display: none;
            z-index: 2000;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="header-title">
                <div>
                    <h1>🏢 LCM Workspace Inventory Explorer</h1>
                    <div class="header-meta">
                        <span>Root: <strong>D:\Git_Repositories</strong></span>
                        <span>•</span>
                        <span class="timestamp-badge">Generated: $genTime</span>
                    </div>
                </div>
            </div>
            <div style="display: flex; align-items: center; gap: 12px;">
                <button class="btn-refresh" onclick="refreshInventory()">
                    <span>🔄</span> Refresh Data & View
                </button>
                <span class="badge badge-success">LCM Active &bull; v$schemaVer</span>
            </div>
        </header>

        <div class="metrics-grid">
            <div class="metric-card" onclick="showTab('tab-repos')">
                <div class="metric-label">Total Repositories</div>
                <div class="metric-value">$totalRepos</div>
                <div class="metric-sub">Tracked in Workspace Root</div>
            </div>
            <div class="metric-card" onclick="showTab('tab-repos')">
                <div class="metric-label">Governed Repositories</div>
                <div class="metric-value">$governedRepos / $totalRepos</div>
                <div class="metric-sub">LCM Junction Active</div>
            </div>
            <div class="metric-card" onclick="showTab('tab-repos')">
                <div class="metric-label">LCM v$schemaVer Aligned</div>
                <div class="metric-value">$lcm5Repos</div>
                <div class="metric-sub">Standard Baseline Version</div>
            </div>
            <div class="metric-card" onclick="showTab('tab-repos')">
                <div class="metric-label">Clean Git Trees</div>
                <div class="metric-value">$($totalRepos - $dirtyRepos) / $totalRepos</div>
                <div class="metric-sub">$dirtyRepos Repos With Pending Changes</div>
            </div>
        </div>

        <div class="tabs">
            <button class="tab-btn active" onclick="showTab('tab-repos')">Repositories Ledger ($totalRepos)</button>
            <button class="tab-btn" onclick="showTab('tab-tools')">🛠️ Workspace Tools & Active Help</button>
            <button class="tab-btn" onclick="showTab('tab-rules')">16 Authoritative Governance Rules</button>
        </div>

        <div class="search-bar">
            <input type="text" id="filterInput" class="search-input" placeholder="Search repositories, tools, classifications, commits, or rules..." onkeyup="filterTables()">
        </div>

        <!-- TAB 1: REPOSITORIES -->
        <div id="tab-repos" class="tab-content active">
            <div class="table-container">
                <table class="scrollable-table" id="table-repos">
                    <thead>
                        <tr>
                            <th>Repository Name</th>
                            <th>Domain / Role</th>
                            <th>LCM Version</th>
                            <th>Head Commit</th>
                            <th>Git Status</th>
                            <th>Quality Gate / Rules</th>
                            <th style="text-align: center;">Action</th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($r in $inv.repositories) {
    $statusBadge = if ($r.DirtyState -eq 'clean') { 'badge-success' } else { 'badge-warning' }
    $govBadge = if ($r.LCMStatus -match 'governed') { 'badge-info' } else { 'badge-muted' }
    $ver = if ($r.CurrentLCMVersion) { $r.CurrentLCMVersion } elseif ($r.AbsorbedLCMVersion) { $r.AbsorbedLCMVersion } else { 'Legacy' }
    $head = if ($r.HeadCommit) { $r.HeadCommit } else { '-' }
    $dirty = if ($r.DirtyState) { $r.DirtyState } else { $r.GitStatus }
    $role = if ($r.RepositoryName -match 'HaSSD06') { 'Subsystem Domain (Home Assistant OS)' } elseif ($r.RepositoryName -match 'Workspace_AI|Workspace_Inventory') { 'LCM Core Governance & Parent CM' } elseif ($r.RepositoryName -match 'SharedModules') { 'Core Reusable PowerShell Engine' } else { $r.Classification }

    $html += @"
                        <tr>
                            <td><strong>$($r.RepositoryName)</strong></td>
                            <td>$role</td>
                            <td><span class="badge $govBadge">v$ver</span></td>
                            <td class="code-cell">$head</td>
                            <td><span class="badge $statusBadge">$dirty</span></td>
                            <td>$($r.LCMStatus)</td>
                            <td style="text-align: center;">
                                <button class="btn-copy" onclick="copyText('D:\\Git_Repositories\\$($r.RepositoryName)')">📋 Copy Path</button>
                            </td>
                        </tr>
"@
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 2: TOOLS & ACTIVE HELP -->
        <div id="tab-tools" class="tab-content" style="display: none;">
            <div class="table-container">
                <table class="scrollable-table" id="table-tools">
                    <thead>
                        <tr>
                            <th>Tool Name</th>
                            <th>Repository / Domain</th>
                            <th>Purpose & Active Guidance</th>
                            <th>CLI Execution Syntax</th>
                            <th style="text-align: center;">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong>Show-ToolIndex.ps1</strong></td>
                            <td><span class="badge badge-info">tools</span></td>
                            <td>Generates and launches the authoritative LCM Tool Explorer dashboard.</td>
                            <td class="code-cell">pwsh -File tools/Show-ToolIndex.ps1</td>
                            <td style="text-align: center;"><button class="btn-copy" onclick="copyText('pwsh -File tools/Show-ToolIndex.ps1')">📋 Copy</button></td>
                        </tr>
                        <tr>
                            <td><strong>Invoke-WorkspaceAudit.ps1</strong></td>
                            <td><span class="badge badge-info">Workspace_Inventory</span></td>
                            <td>Scans all 35+ repositories, reconciles drift, and refreshes parent CM ledger.</td>
                            <td class="code-cell">pwsh -File tools/Invoke-WorkspaceAudit.ps1</td>
                            <td style="text-align: center;"><button class="btn-copy" onclick="copyText('pwsh -File tools/Invoke-WorkspaceAudit.ps1')">📋 Copy</button></td>
                        </tr>
                        <tr>
                            <td><strong>Invoke-BeyondCompareReview.ps1</strong></td>
                            <td><span class="badge badge-info">Workspace_Inventory</span></td>
                            <td>Launches Beyond Compare 5 desktop visual review against baseline commit.</td>
                            <td class="code-cell">pwsh -File tools/Invoke-BeyondCompareReview.ps1 -RepositoryName &lt;Name&gt;</td>
                            <td style="text-align: center;"><button class="btn-copy" onclick="copyText('pwsh -File tools/Invoke-BeyondCompareReview.ps1 -RepositoryName ')">📋 Copy</button></td>
                        </tr>
                        <tr>
                            <td><strong>Submit-ReviewResult.ps1</strong></td>
                            <td><span class="badge badge-info">Workspace_Inventory</span></td>
                            <td>Records human Beyond Compare 5 review approval receipt (ACCEPTED/REJECTED).</td>
                            <td class="code-cell">pwsh -File tools/Submit-ReviewResult.ps1 -RepositoryName &lt;Name&gt; -Verdict ACCEPTED</td>
                            <td style="text-align: center;"><button class="btn-copy" onclick="copyText('pwsh -File tools/Submit-ReviewResult.ps1 -RepositoryName ')">📋 Copy</button></td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 3: GOVERNANCE RULES -->
        <div id="tab-rules" class="tab-content" style="display: none;">
            <div class="table-container">
                <table class="scrollable-table" id="table-rules">
                    <thead>
                        <tr><th>Rule File</th><th>Rule Code</th><th>Domain</th><th>Core Governance Invariant</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><strong>ProposalReviewFlowPolicy.md</strong></td><td class="code-cell">RULE-LCM-001 - 006</td><td>Proposal Flow</td><td>Proposal-first intent, batch commands, BC5 review gate, dual-commit sync.</td></tr>
                        <tr><td><strong>PowerShellStandardsPolicy.md</strong></td><td class="code-cell">RULE-PS-001 - 010</td><td>PowerShell</td><td>StrictMode @() wrapping, verb compliance, colon-safety, header metadata, logging & help.</td></tr>
                        <tr><td><strong>ReviewCommitGovernancePolicy.md</strong></td><td class="code-cell">RULE-REV-001 - 005</td><td>Commit Gating</td><td>Mandatory review-gated commits (ACCEPTED), readiness pass, audit receipts.</td></tr>
                        <tr><td><strong>ElevationPolicy.md</strong></td><td class="code-cell">ELEVATION-POLICY</td><td>Security</td><td>Least-privilege default, runner delegation, auto-detection of privileged commands.</td></tr>
                        <tr><td><strong>LanguagePolicy.md</strong></td><td class="code-cell">LANGUAGE-POLICY</td><td>Localization</td><td>English-always invariant for code, comments, docs, commit messages.</td></tr>
                        <tr><td><strong>SubsystemGovernancePolicy.md</strong></td><td class="code-cell">RULE-SUB-001 - 007</td><td>Subsystem Architecture</td><td>Disjunct domains, dedicated inventory, Central Registry Non-Mutation.</td></tr>
                        <tr><td><strong>DocumentationStandardsPolicy.md</strong></td><td class="code-cell">RULE-DOC-001 - 004</td><td>Documentation</td><td>Tripartite core specs (Architecture/Requirements/Implementation) + Runbook.</td></tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="toast" id="toast">✓ Copied to clipboard!</div>

    <script>
        function showTab(tabId) {
            document.querySelectorAll('.tab-content').forEach(el => { el.style.display = 'none'; el.classList.remove('active'); });
            document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
            const target = document.getElementById(tabId);
            if (target) {
                target.style.display = 'block';
                target.classList.add('active');
            }
            if (event && event.target && event.target.classList.contains('tab-btn')) {
                event.target.classList.add('active');
            }
        }

        function filterTables() {
            const query = document.getElementById('filterInput').value.toLowerCase();
            const activeTab = document.querySelector('.tab-content.active');
            if (!activeTab) return;
            const rows = activeTab.querySelectorAll('tbody tr');

            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(query) ? '' : 'none';
            });
        }

        function copyText(text) {
            navigator.clipboard.writeText(text);
            const toast = document.getElementById('toast');
            toast.innerText = '✓ Copied: ' + text;
            toast.style.display = 'block';
            setTimeout(() => { toast.style.display = 'none'; }, 2200);
        }

        function refreshInventory() {
            copyText('pwsh -File tools/Invoke-WorkspaceAudit.ps1; pwsh -File tools/Show-WorkspaceInventoryApp.ps1');
            setTimeout(() => { window.location.reload(); }, 600);
        }
    </script>
</body>
</html>
"@

$html | Set-Content -LiteralPath $htmlPath -Encoding UTF8
Write-Host "Generated Workspace Inventory Viewer: $htmlPath" -ForegroundColor Green

if (-not $NoLaunch) {
    Write-Host "Opening workspace dashboard in default web browser on Desktop (Session 1)..." -ForegroundColor Cyan
    $dispatcher = "D:\Git_Repositories\tools\Invoke-InteractiveDesktop.ps1"
    if (Test-Path $dispatcher) {
        & pwsh -File $dispatcher -FilePath "explorer.exe" -ArgumentList "`"$htmlPath`"" | Out-Null
    } else {
        Start-Process $htmlPath
    }
}
