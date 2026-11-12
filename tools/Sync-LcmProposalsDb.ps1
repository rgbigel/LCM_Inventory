<#
.SYNOPSIS
    Synchronizes, dumps, hydrates, and queries the LCM Proposals SQLite Database under Dual-State Projection architecture.

.DESCRIPTION
    Module: tools/Sync-LcmProposalsDb.ps1
    Purpose: Provides high-speed SQLite synchronization, canonical SQL text projection (proposals.sql),
             parity verification, and release-horizon querying for the LCM Proposals ledger.
             Equipped with sandbox identity tagging and Git pull/checkout auto-hydration hooks.
             Implements CRP-322.
    Path: LCM_Inventory/tools/Sync-LcmProposalsDb.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 10.2.3
    Date: 2026-11-12 12:15:00

.PARAMETER Action
    Operation to perform:
    - 'Sync'         : JSON -> SQLite DB + SQL text dump (default).
    - 'Dump'         : SQLite DB -> Canonical proposals.sql text dump.
    - 'Hydrate'      : Reconstructs SQLite DB from canonical proposals.sql text dump.
    - 'Verify'       : 3-way parity check across JSON, SQLite DB, and SQL text dump.
    - 'Query'        : High-speed query returning objects from SQLite.
    - 'InstallHooks' : Installs Git post-merge and post-checkout hooks for automatic hydration on pull/checkout.

.PARAMETER Horizon
    Release horizon filter for querying: 'active' (hides published historical releases < 10.2.0),
    'historical' (only historical releases), or 'all' (all 296+ proposals).

.PARAMETER Version
    Specific LCM version to filter by (e.g. '10.2.3', '10.2.x', '10.1.0', '10.0.0', 'Legacy (<10.0)').

.PARAMETER State
    Specific proposal lifecycle state to filter by (e.g. 'in_progress', 'pushed', 'held').

.PARAMETER ActiveOnly
    Filters only active/open proposals (excluding terminal pushed, rejected, superseded, withdrawn).

.PARAMETER WorkspaceRole
    Context role for database metadata: 'LIVE' (default), 'SANDBOX', or 'BASELINE_ARCHIVE'.

.PARAMETER SandboxId
    Sandbox identifier when executing within an isolated sandbox (e.g. 'SBX-01').

.PARAMETER DatabasePath
    Custom path to SQLite database. Defaults to LCM_Inventory/data/proposals/proposals.db.

.PARAMETER JsonPath
    Custom path to JSON proposals ledger. Defaults to LCM_Inventory/data/proposals/proposals.json.

.PARAMETER SqlPath
    Custom path to canonical SQL dump. Defaults to LCM_Inventory/data/proposals/proposals.sql.

.PARAMETER Silent
    Suppresses informational console banners.

.PARAMETER Help
    Displays command-line syntax and parameter usage.

.EXAMPLE
    .\Sync-LcmProposalsDb.ps1
    Synchronizes proposals.json into proposals.db and generates proposals.sql.

.EXAMPLE
    .\Sync-LcmProposalsDb.ps1 -Action Verify
    Verifies 100% 3-way data and state parity between proposals.json, proposals.db, and proposals.sql.

.EXAMPLE
    .\Sync-LcmProposalsDb.ps1 -Action Hydrate
    Reconstructs proposals.db from proposals.sql in ~20ms.

.EXAMPLE
    .\Sync-LcmProposalsDb.ps1 -Action InstallHooks
    Installs Git post-merge and post-checkout auto-hydration hooks.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Sync', 'Verify', 'Query', 'Dump', 'Hydrate', 'InstallHooks')]
    [string]$Action = 'Sync',

    [Parameter()]
    [ValidateSet('active', 'all', 'historical')]
    [string]$Horizon,

    [Parameter()]
    [string]$Version,

    [Parameter()]
    [string]$State,

    [Parameter()]
    [switch]$ActiveOnly,

    [Parameter()]
    [ValidateSet('LIVE', 'SANDBOX', 'BASELINE_ARCHIVE')]
    [string]$WorkspaceRole = 'LIVE',

    [Parameter()]
    [string]$SandboxId = '',

    [Parameter()]
    [string]$DatabasePath,

    [Parameter()]
    [string]$JsonPath,

    [Parameter()]
    [string]$SqlPath,

    [Parameter()]
    [switch]$Silent,

    [Parameter()]
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help -Path $PSCommandPath -Detailed
    return
}

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$pyEngine = Join-Path -Path $PSScriptRoot -ChildPath 'sync_proposals_db.py'

if (-not (Test-Path -LiteralPath $pyEngine)) {
    throw "SQLite proposals synchronization engine not found: $pyEngine"
}

$defaultJson = Join-Path -Path $repoRoot -ChildPath 'data\proposals\proposals.json'
$defaultDb   = Join-Path -Path $repoRoot -ChildPath 'data\proposals\proposals.db'
$defaultSql  = Join-Path -Path $repoRoot -ChildPath 'data\proposals\proposals.sql'

$targetJson = if ([string]::IsNullOrWhiteSpace($JsonPath)) { $defaultJson } else { $JsonPath }
$targetDb   = if ([string]::IsNullOrWhiteSpace($DatabasePath)) { $defaultDb } else { $DatabasePath }
$targetSql  = if ([string]::IsNullOrWhiteSpace($SqlPath)) { $defaultSql } else { $SqlPath }

$actionArg = switch ($Action) {
    'InstallHooks' { 'install-hooks' }
    default        { $Action.ToLowerInvariant() }
}

$pythonExe = 'python'
$pyArgs = @(
    $pyEngine,
    '--action', $actionArg,
    '--json-path', $targetJson,
    '--db-path', $targetDb,
    '--sql-path', $targetSql,
    '--workspace-role', $WorkspaceRole,
    '--sandbox-id', $SandboxId
)

if ($Silent) {
    $pyArgs += '--silent'
}

if ($ActiveOnly) {
    $pyArgs += '--active-only'
}

if (-not [string]::IsNullOrWhiteSpace($Horizon)) {
    $pyArgs += @('--horizon', $Horizon)
}

if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $pyArgs += @('--version', $Version)
}

if (-not [string]::IsNullOrWhiteSpace($State)) {
    $pyArgs += @('--state', $State)
}

if ($Action -eq 'Query') {
    $jsonOutput = & $pythonExe @pyArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to execute SQLite proposal query (Exit code: $LASTEXITCODE)"
    }
    if ([string]::IsNullOrWhiteSpace($jsonOutput)) {
        return @()
    }
    return ($jsonOutput | ConvertFrom-Json)
} else {
    & $pythonExe @pyArgs
    if ($LASTEXITCODE -ne 0) {
        throw "SQLite proposal action '$Action' failed with exit code $LASTEXITCODE"
    }
}
