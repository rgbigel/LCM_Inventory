<#
Module: tools/Show-WorkspaceInventoryApp.ps1
Purpose: Generates a modern, interactive, scrollable HTML explorer for Workspace_Inventory (data/inventory.json) and opens it in the browser.
Governance Invariant (RULE-EFF-001): Auto-accepted mechanical dashboard renderer.
Path: tools/Show-WorkspaceInventoryApp.ps1
Authors: Rolf, Workspace_AI Engine
Version: 5.0.2
Date: 2026-08-21
#>

[CmdletBinding()]
param(
    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LCM Workspace Inventory Explorer</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
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

        .container { max-width: 1400px; margin: 0 auto; }
        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border);
            margin-bottom: 24px;
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

        .header-title p { color: var(--text-secondary); font-size: 14px; margin-top: 4px; }

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
        }

        .metric-label { font-size: 12px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); }
        .metric-value { font-size: 24px; font-weight: 700; color: var(--text-primary); margin-top: 4px; font-family: 'JetBrains Mono', monospace; }
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

        .scrollable-table { width: 100%; border-collapse: collapse; text-align: left; font-size: 14px; }
        .scrollable-table th {
            background: var(--bg-tertiary);
            color: var(--text-secondary);
            font-weight: 600;
            padding: 12px 16px;
            border-bottom: 1px solid var(--border);
            position: sticky;
            top: 0;
        }
        .scrollable-table td {
            padding: 12px 16px;
            border-bottom: 1px solid rgba(240, 246, 252, 0.05);
            color: var(--text-primary);
        }
        .scrollable-table tr:hover { background: rgba(88, 166, 255, 0.04); }

        .code-cell { font-family: 'JetBrains Mono', monospace; font-size: 13px; color: #79c0ff; }
        .badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }
        .badge-success { background: rgba(63, 185, 80, 0.15); color: var(--success); }
        .badge-info { background: rgba(88, 166, 255, 0.15); color: var(--accent); }
        .badge-warning { background: rgba(210, 153, 34, 0.15); color: var(--warning); }
        .badge-muted { background: rgba(110, 118, 129, 0.15); color: var(--text-muted); }

        .tab-content { display: none; }
        .tab-content.active { display: block; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="header-title">
                <h1>🏢 Lifecycle Model (LCM) Workspace Explorer</h1>
                <p>Root Workspace: D:\Git_Repositories &bull; Framework Version: $schemaVer &bull; Generated: $($inv.generated_at)</p>
            </div>
            <div>
                <span class="badge badge-success">LCM Active &bull; v$schemaVer</span>
            </div>
        </header>

        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-label">Total Repositories</div>
                <div class="metric-value">$totalRepos</div>
                <div class="metric-sub">Tracked in Workspace Root</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Governed Repositories</div>
                <div class="metric-value">$governedRepos / $totalRepos</div>
                <div class="metric-sub">LCM Junction Active</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">LCM v5.0.2 Aligned</div>
                <div class="metric-value">$lcm5Repos</div>
                <div class="metric-sub">Standard Baseline Version</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Clean Git Trees</div>
                <div class="metric-value">$($totalRepos - $dirtyRepos) / $totalRepos</div>
                <div class="metric-sub">$dirtyRepos Repos With Pending Changes</div>
            </div>
        </div>

        <div class="tabs">
            <button class="tab-btn active" onclick="showTab('tab-repos')">Repositories Ledger ($totalRepos)</button>
            <button class="tab-btn" onclick="showTab('tab-tools')">🛠️ Workspace Tools & Active Help</button>
            <button class="tab-btn" onclick="showTab('tab-rules')">15 Authoritative Governance Rules</button>
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
                        </tr>
"@
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 2: TOOLS & ACTIVE HELP -->
        <div id="tab-tools" class="tab-content">
            <div class="table-container">
                <table class="scrollable-table" id="table-tools">
                    <thead>
                        <tr>
                            <th>Tool Name</th>
                            <th>Repository / Domain</th>
                            <th>Purpose & Active Guidance</th>
                            <th>CLI Execution Syntax</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><strong>Invoke-WorkspaceAudit.ps1</strong></td>
                            <td><span class="badge badge-info">Workspace_Inventory</span></td>
                            <td>Scans all 35+ repositories, reconciles drift, and refreshes parent CM ledger.</td>
                            <td class="code-cell">pwsh -File tools/Invoke-WorkspaceAudit.ps1</td>
                        </tr>
                        <tr>
                            <td><strong>Invoke-BeyondCompareReview.ps1</strong></td>
                            <td><span class="badge badge-info">Workspace_Inventory</span></td>
                            <td>Launches Beyond Compare 5 desktop visual review against baseline commit.</td>
                            <td class="code-cell">pwsh -File tools/Invoke-BeyondCompareReview.ps1 -RepositoryName &lt;Name&gt;</td>
                        </tr>
                        <tr>
                            <td><strong>Submit-ReviewResult.ps1</strong></td>
                            <td><span class="badge badge-info">Workspace_Inventory</span></td>
                            <td>Generates formal audit receipt in data/reviews/ and gates repository commit.</td>
                            <td class="code-cell">pwsh -File tools/Submit-ReviewResult.ps1 -RepositoryName &lt;Name&gt; -Result Accepted</td>
                        </tr>
                        <tr>
                            <td><strong>Invoke-LCMOnboardBatch.ps1</strong></td>
                            <td><span class="badge badge-info">Workspace_Inventory</span></td>
                            <td>Batch onboards un-governed repositories with rules junctions, tripartite docs & gates.</td>
                            <td class="code-cell">pwsh -File tools/Invoke-LCMOnboardBatch.ps1</td>
                        </tr>
                        <tr>
                            <td><strong>Test-LCMRuleHealth.ps1</strong></td>
                            <td><span class="badge badge-info">Workspace_Inventory</span></td>
                            <td>Verifies NTFS junction health and rule integrity across all child repositories.</td>
                            <td class="code-cell">pwsh -File tools/Test-LCMRuleHealth.ps1</td>
                        </tr>
                        <tr>
                            <td><strong>Update-HaInventory.ps1</strong></td>
                            <td><span class="badge badge-success">HaSSD06_Inventory</span></td>
                            <td>Extracts live Home Assistant Central Registry, entities & renders dashboard.</td>
                            <td class="code-cell">pwsh -File tools/Update-HaInventory.ps1</td>
                        </tr>
                        <tr>
                            <td><strong>Show-HaInventoryApp.ps1</strong></td>
                            <td><span class="badge badge-success">HaSSD06_Inventory</span></td>
                            <td>Launches interactive browser explorer for HaSSD06 devices & 937 entities.</td>
                            <td class="code-cell">pwsh -File tools/Show-HaInventoryApp.ps1</td>
                        </tr>
                        <tr>
                            <td><strong>Invoke-HaUpdateGate.ps1</strong></td>
                            <td><span class="badge badge-warning">HaSSD06_Inventory</span></td>
                            <td>5-stage external update runner with breaking-change parsing & pre-backup.</td>
                            <td class="code-cell">pwsh -File tools/Invoke-HaUpdateGate.ps1</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- TAB 3: RULES -->
        <div id="tab-rules" class="tab-content">
            <div class="table-container">
                <table class="scrollable-table" id="table-rules">
                    <thead>
                        <tr>
                            <th>Rule File</th>
                            <th>Rule Code</th>
                            <th>Domain / Scope</th>
                            <th>Core Invariant</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr><td><strong>ProposalReviewFlowPolicy.md</strong></td><td class="code-cell">RULE-LCM-001 - 006</td><td>Proposal & Review</td><td>Proposal-first intent, BC5 review gate, dual-commit sync.</td></tr>
                        <tr><td><strong>PowerShellStandardsPolicy.md</strong></td><td class="code-cell">RULE-PS-001 - 007</td><td>PowerShell</td><td>StrictMode @(...) wrapping, Microsoft approved verbs, test elevation.</td></tr>
                        <tr><td><strong>ReviewCommitGovernancePolicy.md</strong></td><td class="code-cell">RULE-REV-001 - 005</td><td>Commit Gating</td><td>Mandatory review-gated commits, quality gate pass, audit receipts.</td></tr>
                        <tr><td><strong>MethodEfficiencyPolicy.md</strong></td><td class="code-cell">RULE-EFF-001 - 005</td><td>Efficiency</td><td>Auto-acceptance of mechanical evidence, zero-test cascade.</td></tr>
                        <tr><td><strong>ElevationPolicy.md</strong></td><td class="code-cell">ELEVATION-POLICY</td><td>Security</td><td>Least-privilege execution default, elevated script runner delegation.</td></tr>
                        <tr><td><strong>LanguagePolicy.md</strong></td><td class="code-cell">LANGUAGE-POLICY</td><td>Localization</td><td>English-always invariant for code, comments, docs, commit messages.</td></tr>
                        <tr><td><strong>RepositoryContextPolicy.md</strong></td><td class="code-cell">REPO-CONTEXT</td><td>Context Scoping</td><td>Strict repository boundary separation, deterministic relative paths.</td></tr>
                        <tr><td><strong>SubsystemGovernancePolicy.md</strong></td><td class="code-cell">RULE-SUB-001 - 007</td><td>Subsystem Architecture</td><td>Disjunct domains, dedicated inventory, Central Registry Non-Mutation.</td></tr>
                        <tr><td><strong>DocumentationStandardsPolicy.md</strong></td><td class="code-cell">RULE-DOC-001 - 004</td><td>Documentation</td><td>Tripartite core specs (Architecture/Requirements/Implementation) + Runbook.</td></tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        function showTab(tabId) {
            document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
            document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
            document.getElementById(tabId).classList.add('active');
            event.target.classList.add('active');
        }

        function filterTables() {
            const query = document.getElementById('filterInput').value.toLowerCase();
            const activeTab = document.querySelector('.tab-content.active');
            const rows = activeTab.querySelectorAll('tbody tr');

            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(query) ? '' : 'none';
            });
        }
    </script>
</body>
</html>
"@

$html | Set-Content -LiteralPath $htmlPath -Encoding UTF8
Write-Host "Generated Workspace Inventory Viewer: $htmlPath" -ForegroundColor Green

if (-not $NoLaunch) {
    Write-Host "Opening workspace dashboard in default web browser..." -ForegroundColor Cyan
    Start-Process $htmlPath
}
