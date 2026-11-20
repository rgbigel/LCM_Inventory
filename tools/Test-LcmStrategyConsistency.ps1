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

# CRP-358: the check lives in tools/sync_proposals_db.py (check-strategies; no inline Python, RULE-PY-010)
Import-Module -Name (Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LcmRuntimeAtoms.psm1') -Force
$result = & (Get-LcmRuntimePath -Key 'python') -I (Join-Path $PSScriptRoot 'sync_proposals_db.py') --action check-strategies --db-path $DbPath
$exitCode = $LASTEXITCODE

$result | ForEach-Object { Write-Host $_ }
if ($exitCode -ne 0) {
    throw "Strategy consistency audit failed with exit code $exitCode."
}
