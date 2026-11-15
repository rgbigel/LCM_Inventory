<#
Module: tools/Test-RepoReadiness.ps1
Purpose: Executes all LCM readiness quality gates for the HaSSD06 Subsystem repository.
Architecture: Two-Step Subsystem Readiness (CRP-310)
  Step 1: Universal General LCM Readiness (LCM_Inventory/tools/Test-GeneralReadiness.ps1)
  Step 2: Subsystem Domain Quality Gates (Tripartite documentation, identity, catalog sync)
Path: tools/Test-RepoReadiness.ps1
Authors: Rolf, LCM_AI Engine
Version: 5.0.3
Date: 2026-11-08 17:35:00
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Single-cycle minimal testing scope: fast syntax and AST validation only')]
    [switch]$MinimalTests,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " HaSSD06 QUALITY GATE READINESS CHECK (Test-RepoReadiness.ps1 v5.0.3)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS: Executes two-step LCM readiness quality gates for the HaSSD06 Subsystem repository."
    Write-Host "USAGE:    pwsh tools/Test-RepoReadiness.ps1 [-MinimalTests] [-h]"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$repoRoot = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $PSScriptRoot 'QualityGates\RepoQualityGates.psm1'
Import-Module (Resolve-Path $modulePath) -Force

$gates = [System.Collections.Generic.List[PSCustomObject]]::new()
$allPassed = $true

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " HaSSD06 Subsystem Quality Gate Readiness Check                  " -ForegroundColor Cyan
Write-Host " Target Repository: $repoRoot" -ForegroundColor Cyan
Write-Host " Architecture: Two-Step Subsystem Readiness (CRP-310)           " -ForegroundColor Cyan
if ($MinimalTests) {
Write-Host " Scope: Fast-Tier Minimal Tests (AST, Structure & Syntax Only)   " -ForegroundColor Yellow
}
Write-Host "=================================================================" -ForegroundColor Cyan

# =========================================================================
# STEP 1: Universal General LCM Readiness Gate (CRP-310)
# =========================================================================
Write-Host "`n[Step 1/2] Executing Universal General Readiness Gates..." -ForegroundColor Cyan
$workspaceRoot = Split-Path $repoRoot -Parent
$generalScript = Join-Path $workspaceRoot 'LCM_Inventory\tools\Test-GeneralReadiness.ps1'

if (Test-Path -LiteralPath $generalScript) {
    $g0Sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & pwsh -NoProfile -File $generalScript -RepositoryPath $repoRoot
        if ($LASTEXITCODE -ne 0) {
            throw "General readiness quality gates failed with exit code $LASTEXITCODE"
        }
        $g0Sw.Stop()
        $gates.Add([PSCustomObject]@{
            id = 1
            name = "Universal General LCM Readiness"
            status = "PASSED"
            details = "Junction, UTF-8 No-BOM, AST syntax, and secrets verified via Test-GeneralReadiness.ps1"
            duration_ms = [int]$g0Sw.ElapsedMilliseconds
            failure_reason = $null
        })
    } catch {
        $g0Sw.Stop()
        $allPassed = $false
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $gates.Add([PSCustomObject]@{
            id = 1
            name = "Universal General LCM Readiness"
            status = "FAILED"
            details = "Universal general readiness check failed"
            duration_ms = [int]$g0Sw.ElapsedMilliseconds
            failure_reason = $_.Exception.Message
        })
    }
}

# =========================================================================
# STEP 2: Subsystem Domain Quality Gates
# =========================================================================
Write-Host "`n[Step 2/2] Validating Subsystem Domain Quality Gates..." -ForegroundColor Cyan

# Gate 2: Tripartite Documentation Check
Write-Host "`n[Gate 2/3] Validating Tripartite & Runbook Documentation..." -ForegroundColor White
$g1Sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $docRes = Test-TripartiteDocumentation -RepoRoot $repoRoot
    $g1Sw.Stop()
    $g1Details = "$($docRes.CheckedDocs) documentation specifications validated."
    Write-Host "  Passed: $g1Details" -ForegroundColor Green
    $gates.Add([PSCustomObject]@{
        id = 2
        name = "Tripartite Documentation Fabric"
        status = "PASSED"
        details = $g1Details
        duration_ms = [int]$g1Sw.ElapsedMilliseconds
        failure_reason = $null
    })
} catch {
    $g1Sw.Stop()
    $allPassed = $false
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $gates.Add([PSCustomObject]@{
        id = 2
        name = "Tripartite Documentation Fabric"
        status = "FAILED"
        details = "Documentation validation failed"
        duration_ms = [int]$g1Sw.ElapsedMilliseconds
        failure_reason = $_.Exception.Message
    })
}

# Gate 3: LCM Configuration Check
Write-Host "`n[Gate 3/3] Validating Subsystem Identity (README.md)..." -ForegroundColor White
$g2Sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $lcmRes = Test-LCMConfig -RepoRoot $repoRoot
    $g2Sw.Stop()
    $g2Details = "Configured as Subsystem Domain ($($lcmRes.SubsystemType))."
    Write-Host "  Passed: $g2Details" -ForegroundColor Green
    $gates.Add([PSCustomObject]@{
        id = 3
        name = "Subsystem Identity (README.md)"
        status = "PASSED"
        details = $g2Details
        duration_ms = [int]$g2Sw.ElapsedMilliseconds
        failure_reason = $null
    })
} catch {
    $g2Sw.Stop()
    $allPassed = $false
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $gates.Add([PSCustomObject]@{
        id = 3
        name = "Subsystem Identity (README.md)"
        status = "FAILED"
        details = "Subsystem identity check failed"
        duration_ms = [int]$g2Sw.ElapsedMilliseconds
        failure_reason = $_.Exception.Message
    })
}

# Optional: Tool Catalog Sync
$toolUpdater = Join-Path $workspaceRoot 'tools\Update-ToolCatalog.ps1'
if (-not $MinimalTests -and (Test-Path $toolUpdater)) {
    Write-Host "`nSynchronizing Workspace Tool Catalog..." -ForegroundColor White
    & $toolUpdater -Silent
    Write-Host "  Passed: Tool catalog synchronized." -ForegroundColor Green
} elseif ($MinimalTests) {
    Write-Host "`nTool Catalog Sync deferred under Minimal Tests." -ForegroundColor DarkGray
}

$sw.Stop()
$totalDuration = [int]$sw.ElapsedMilliseconds
$passedCount = @($gates | Where-Object { $_.status -eq 'PASSED' }).Count
$totalCount = $gates.Count
$overallStatus = if ($allPassed) { 'PASSED' } else { 'FAILED' }

Write-Host "`n=================================================================" -ForegroundColor $(if ($allPassed) { 'Green' } else { 'Red' })
if ($allPassed) {
    Write-Host " All HaSSD06 Subsystem Quality Gates PASSED (Readiness: OK)      " -ForegroundColor Green
} else {
    Write-Host " Quality Gate Check FAILED ($passedCount/$totalCount passed)                  " -ForegroundColor Red
}
Write-Host "=================================================================" -ForegroundColor $(if ($allPassed) { 'Green' } else { 'Red' })

# Persist Machine-Readable Readiness Receipt (CRP-152)
$readinessDir = Join-Path $repoRoot 'data\readiness'
if (-not (Test-Path -LiteralPath $readinessDir)) {
    New-Item -ItemType Directory -Path $readinessDir -Force | Out-Null
}
$receiptPath = Join-Path $readinessDir 'latest_readiness.json'

$receipt = [pscustomobject]@{
    '$schema'      = "https://json-schema.org/draft/2020-12/schema"
    repository     = "HaSSD06"
    timestamp      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
    overall_status = $overallStatus
    passed_count   = $passedCount
    total_count    = $totalCount
    duration_ms    = $totalDuration
    gates          = $gates
}
$receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
Write-Host " Receipt saved: data/readiness/latest_readiness.json ($($totalDuration)ms)" -ForegroundColor DarkGray

if (-not $allPassed) {
    throw "One or more quality gates failed. See receipt at: $receiptPath"
}
