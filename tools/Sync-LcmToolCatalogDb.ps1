<#
.SYNOPSIS
    Synchronizes, dumps, hydrates, and queries the LCM Tool Catalog & Intents SQLite Database under Dual-State Projection architecture.
.DESCRIPTION
    Module: tools/Sync-LcmToolCatalogDb.ps1
    Purpose: Provides high-speed SQLite synchronization, canonical SQL text projection (tools.sql),
             and parity verification between config/tool_catalog.json, config/tool_intents.json,
             data/tools/tools.db, and data/tools/tools.sql.
    Authors: Rolf, LCM_AI Engine
    Version: 10.2.4
    Date: 2026-11-13 13:30:00
.PARAMETER Action
    Operation to perform:
    - 'Sync'   : JSON -> SQLite DB + SQL text dump (default).
    - 'Dump'   : SQLite DB -> Canonical tools.sql text dump.
    - 'Verify' : Parity check across JSON, SQLite DB, and SQL text dump.
#>

[CmdletBinding()]
param(
    [ValidateSet('Sync', 'Dump', 'Verify')]
    [string]$Action = 'Sync',

    [switch]$Silent,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.2.4"
$scriptName = "Sync-LcmToolCatalogDb"

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM TOOLS & INTENTS SQLITE DUAL-STATE SYNC ENGINE (v$scriptVersion)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Synchronizes tool catalog and intents ledgers into high-speed SQLite database."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Sync-LcmToolCatalogDb.ps1 [-Action <Sync|Dump|Verify>] [-Silent] [-h]"
    return
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$pyEngine = Join-Path -Path $PSScriptRoot -ChildPath 'sync_tool_catalog_db.py'

if (-not (Test-Path -LiteralPath $pyEngine)) {
    throw "SQLite tools synchronization engine not found: $pyEngine"
}

$argsList = @($pyEngine, "--action", $Action.ToLower())
if ($Silent) {
    $argsList += "--silent"
}

$proc = Start-Process -FilePath "python" -ArgumentList $argsList -NoNewWindow -PassThru -Wait
if ($proc.ExitCode -ne 0) {
    throw "SQLite tool catalog action '$Action' failed with exit code $($proc.ExitCode)"
}

