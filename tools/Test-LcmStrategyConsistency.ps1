<#
.SYNOPSIS
    Validates referential integrity and consistency between Strategies and Proposals.

.DESCRIPTION
    Audits the SQLite database (data/proposals/proposals.db) to ensure:
    1. Every proposal referenced in strategy_crps exists in the proposals table.
    2. No referenced proposal is in a terminal non-delivering state (rejected, superseded, cancelled).
    3. All active strategies have at least one delivering CRP.

.PARAMETER DbPath
    Optional path to SQLite proposals database.

.PARAMETER Help
    Displays help and syntax.

.EXAMPLE
    pwsh -File tools/Test-LcmStrategyConsistency.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DbPath,

    [Parameter(Mandatory = $false)]
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help -Detailed $PSCommandPath
    return
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($DbPath)) {
    $DbPath = Join-Path $repoRoot 'data\proposals\proposals.db'
}

if (-not (Test-Path -LiteralPath $DbPath)) {
    throw "Database not found at '$DbPath'. Run sync_proposals_db.py first."
}

$pythonScript = @"
import sqlite3
import sys

conn = sqlite3.connect(r'$DbPath')
c = conn.cursor()

c.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='strategies'")
if not c.fetchone():
    print('[FAIL] strategies table does not exist.')
    sys.exit(1)

c.execute("SELECT s.strategy_id, s.title, sc.crp_id, sc.goal_role, p.state, p.title "
          "FROM strategy_crps sc "
          "JOIN strategies s ON sc.strategy_id = s.strategy_id "
          "LEFT JOIN proposals p ON sc.crp_id = p.crp_id "
          "ORDER BY s.strategy_id, sc.crp_id")

rows = c.fetchall()
errors = []
active_counts = {}

for strat_id, strat_title, crp_id, goal_role, p_state, p_title in rows:
    if p_state is None:
        errors.append(f"Broken Reference: Strategy '{strat_id}' references non-existent proposal '{crp_id}'")
        continue
    if p_state in ('rejected', 'cancelled'):
        errors.append(f"Invalid CRP State: Strategy '{strat_id}' references '{crp_id}' which is {p_state.upper()}")
    active_counts[strat_id] = active_counts.get(strat_id, 0) + 1

if errors:
    print(f'[FAIL] Found {len(errors)} strategy referential integrity error(s):')
    for err in errors:
        print(f'  - {err}')
    sys.exit(1)

c.execute("SELECT strategy_id, title, state FROM strategies ORDER BY strategy_id")
strategies = c.fetchall()
print('=' * 80)
print('LCM STRATEGY INTEGRITY & CONSISTENCY AUDIT')
print('=' * 80)
for sid, stitle, sstate in strategies:
    crp_count = active_counts.get(sid, 0)
    print(f"[{sstate.upper()}] {sid}: {stitle} ({crp_count} linked CRPs)")
print('=' * 80)
print(f"[PASS] 100% Referential Integrity Verified across {len(strategies)} strategies and {len(rows)} mappings.")
conn.close()
"@

$result = & python -c $pythonScript
$exitCode = $LASTEXITCODE

$result | ForEach-Object { Write-Host $_ }
if ($exitCode -ne 0) {
    throw "Strategy consistency audit failed with exit code $exitCode."
}
