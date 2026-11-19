<#
.SYNOPSIS
  Executes the LCM readiness quality gates for the LCM_Inventory repository and emits a CRP-152 receipt.

.DESCRIPTION
  Module: tools/Test-RepoReadiness.ps1
  Purpose: Repository readiness gate of LCM_Inventory (CM engine): two-step readiness per CRP-310.
    Step 1: Universal general LCM readiness (tools/Test-GeneralReadiness.ps1).
    Step 2: LCM_Inventory domain gates: tripartite documentation, CM engine structure
            (rules junction, tool catalog and intents, inventory, SQLite stores, DO gateway), unit tests.
  Writes data/readiness/latest_readiness.json (CRP-152), read by Show-LCM_Readiness.ps1.
  Path: LCM_Inventory/tools/Test-RepoReadiness.ps1
  Authors: Rolf, Claude
  Version: 10.7.4
  Date: 2026-11-19
  Implementation Choices (CRP-343, operator 2026-11-19 option 2A): replaces a content copy of
    HaSSD06/tools/Test-RepoReadiness.ps1 (HaSSD06 labels and gates, ingestion left-over); keeps the
    CRP-310 two-step layout and the CRP-152 receipt; the HaSSD06 subsystem identity gate does not apply
    to LCM_Inventory; the former tool catalog sync is dropped (a readiness gate does not mutate data).

.PARAMETER MinimalTests
  Single-cycle minimal scope: general readiness, documentation and structure only; the unit test gate is skipped.

.PARAMETER Help
  Displays this help screen (Aliases: -h, -?).

.EXAMPLE
  pwsh LCM_Inventory/tools/Test-RepoReadiness.ps1 -MinimalTests

.NOTES
  Caveats: the unit test gate runs every tests/*.Tests.ps1 file and fails on any failed case, including
  known pre-existing failures; the receipt records test_scope (full or minimal).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Minimal scope: skip the unit test gate')]
  [switch]$MinimalTests,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host '=========================================================================='
  Write-Host ' LCM_Inventory QUALITY GATE READINESS CHECK (Test-RepoReadiness.ps1 10.7.4)'
  Write-Host '=========================================================================='
  Write-Host 'SYNOPSIS:'
  Write-Host '  Two-step readiness (CRP-310) for LCM_Inventory; writes data/readiness/latest_readiness.json (CRP-152).'
  Write-Host 'GATES:'
  Write-Host '  1 Universal general LCM readiness (Test-GeneralReadiness.ps1)'
  Write-Host '  2 Tripartite documentation (Architecture, Requirements, Implementation)'
  Write-Host '  3 CM engine structure (rules junction, catalog, intents, inventory, tools.db, proposals.db, do.exe)'
  Write-Host '  4 Unit tests (tests/*.Tests.ps1; skipped with -MinimalTests)'
  Write-Host 'USAGE:'
  Write-Host '  pwsh LCM_Inventory/tools/Test-RepoReadiness.ps1 [-MinimalTests] [-h]'
  Write-Host '=========================================================================='
  return
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$repoRoot = Split-Path $PSScriptRoot -Parent
$gates = [System.Collections.Generic.List[PSCustomObject]]::new()
$script:allPassed = $true

function Add-GateResult {
  param(
    [int]$Id,
    [string]$Name,
    [string]$Status,
    [string]$Details,
    [System.Diagnostics.Stopwatch]$Timer,
    [string]$FailureReason
  )
  $Timer.Stop()
  if ('FAILED' -eq $Status) {
    $script:allPassed = $false
    Write-Host ('  FAILED: ' + $FailureReason) -ForegroundColor Red
  } elseif ('SKIPPED' -eq $Status) {
    Write-Host ('  Skipped: ' + $Details) -ForegroundColor DarkGray
  } else {
    Write-Host ('  Passed: ' + $Details) -ForegroundColor Green
  }
  $gates.Add([pscustomobject]@{
      id             = $Id
      name           = $Name
      status         = $Status
      details        = $Details
      duration_ms    = [int]$Timer.ElapsedMilliseconds
      failure_reason = $(if ('FAILED' -eq $Status) { $FailureReason } else { $null })
    })
}

Write-Host '================================================================='
Write-Host ' LCM_Inventory Quality Gate Readiness Check (CRP-310 two-step)'
Write-Host (' Target Repository: ' + $repoRoot)
if ($MinimalTests) { Write-Host ' Scope: minimal (unit test gate skipped)' -ForegroundColor Yellow }
Write-Host '================================================================='

# Gate 1: universal general readiness (CRP-310 step 1)
Write-Host "`n[Gate 1/4] Universal general LCM readiness..." -ForegroundColor Yellow
$t = [System.Diagnostics.Stopwatch]::StartNew()
try {
  $generalScript = Join-Path $PSScriptRoot 'Test-GeneralReadiness.ps1'
  & pwsh -NoProfile -File $generalScript -RepositoryPath $repoRoot
  if (0 -ne $LASTEXITCODE) { throw ('Test-GeneralReadiness.ps1 exit code ' + $LASTEXITCODE) }
  Add-GateResult -Id 1 -Name 'Universal General LCM Readiness' -Status 'PASSED' -Details 'Junction, UTF-8 without BOM, AST syntax and secrets verified via Test-GeneralReadiness.ps1' -Timer $t
} catch {
  Add-GateResult -Id 1 -Name 'Universal General LCM Readiness' -Status 'FAILED' -Details 'General readiness failed' -Timer $t -FailureReason $_.Exception.Message
}

# Gate 2: tripartite documentation (RULE-DOC-001)
Write-Host "`n[Gate 2/4] Tripartite documentation..." -ForegroundColor Yellow
$t = [System.Diagnostics.Stopwatch]::StartNew()
try {
  Import-Module -Name (Join-Path $PSScriptRoot 'QualityGates\LCM_QualityGates.psm1') -Force
  $docRes = Assert-TripartiteDocumentationCompliance -TargetRepositoryPath $repoRoot -ThrowOnMissing
  $noDox = @($docRes.Details.Keys | Where-Object { -not $docRes.Details[$_].DoxHeader })
  if (0 -lt $noDox.Count) { throw ('DOX header missing in docs/' + ($noDox -join ', docs/')) }
  Add-GateResult -Id 2 -Name 'Tripartite Documentation Fabric' -Status 'PASSED' -Details 'Architecture, Requirements and Implementation present with DOX headers' -Timer $t
} catch {
  Add-GateResult -Id 2 -Name 'Tripartite Documentation Fabric' -Status 'FAILED' -Details 'Documentation validation failed' -Timer $t -FailureReason $_.Exception.Message
}

# Gate 3: CM engine structure
Write-Host "`n[Gate 3/4] CM engine structure..." -ForegroundColor Yellow
$t = [System.Diagnostics.Stopwatch]::StartNew()
try {
  $problems = [System.Collections.Generic.List[string]]::new()
  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.agents\rules'))) { $problems.Add('.agents/rules junction missing') }
  foreach ($rel in @('config\tool_catalog.json', 'config\tool_intents.json', 'data\inventory.json')) {
    $p = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $p)) { $problems.Add($rel + ' missing'); continue }
    try { $null = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $problems.Add($rel + ' does not parse') }
  }
  foreach ($rel in @('data\tools\tools.db', 'data\proposals\proposals.db')) {
    $p = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $p)) { $problems.Add($rel + ' missing'); continue }
    $head = [byte[]]::new(16)
    $fs = [System.IO.File]::Open($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try { $null = $fs.Read($head, 0, 16) } finally { $fs.Dispose() }
    if ('SQLite format 3' -ne [System.Text.Encoding]::ASCII.GetString($head, 0, 15)) { $problems.Add($rel + ' is not an SQLite database') }
  }
  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'DoT\do.exe'))) { $problems.Add('DoT/do.exe missing') }
  if (0 -lt $problems.Count) { throw ($problems -join '; ') }
  Add-GateResult -Id 3 -Name 'CM Engine Structure' -Status 'PASSED' -Details 'Rules junction, catalog, intents, inventory, tools.db, proposals.db and do.exe verified' -Timer $t
} catch {
  Add-GateResult -Id 3 -Name 'CM Engine Structure' -Status 'FAILED' -Details 'CM engine structure check failed' -Timer $t -FailureReason $_.Exception.Message
}

# Gate 4: unit tests
Write-Host "`n[Gate 4/4] Unit tests..." -ForegroundColor Yellow
$t = [System.Diagnostics.Stopwatch]::StartNew()
if ($MinimalTests) {
  Add-GateResult -Id 4 -Name 'Unit Tests' -Status 'SKIPPED' -Details 'deferred under -MinimalTests' -Timer $t
} else {
  try {
    # BUG-364: the suite runs in a clean process (background job), so this gate's StrictMode, error preference
    # and imported modules do not leak into the tests
    $job = Start-Job -ArgumentList (Join-Path $repoRoot 'tests') -ScriptBlock {
      param([string]$TestRoot)
      $files = @(Get-ChildItem -LiteralPath $TestRoot -Filter '*.Tests.ps1' -File -Recurse)
      $r = Invoke-Pester -Path $files.FullName -Output None -PassThru
      [pscustomobject]@{ Total = $r.TotalCount; Passed = $r.PassedCount; Failed = $r.FailedCount; Files = $files.Count; FailedNames = @($r.Failed | ForEach-Object { $_.ExpandedPath }) }
    }
    $res = @(Receive-Job -Job $job -Wait -AutoRemoveJob -ErrorAction SilentlyContinue 6>$null | Where-Object { $_.PSObject.Properties['Total'] })[-1]
    if ($null -eq $res) { throw 'unit test job returned no result' }
    if (0 -lt $res.Failed) {
      $failedNames = @($res.FailedNames) | Select-Object -First 10
      throw ([string]$res.Failed + ' of ' + [string]$res.Total + ' failed: ' + ($failedNames -join ' | '))
    }
    Add-GateResult -Id 4 -Name 'Unit Tests' -Status 'PASSED' -Details ([string]$res.Passed + ' passed in ' + [string]$res.Files + ' files') -Timer $t
  } catch {
    Add-GateResult -Id 4 -Name 'Unit Tests' -Status 'FAILED' -Details 'Unit tests failed' -Timer $t -FailureReason $_.Exception.Message
  }
}

$sw.Stop()
$passedCount = @($gates | Where-Object { 'PASSED' -eq $_.status }).Count
$overallStatus = if ($script:allPassed) { 'PASSED' } else { 'FAILED' }

# Persist the machine-readable readiness receipt (CRP-152)
$readinessDir = Join-Path $repoRoot 'data\readiness'
if (-not (Test-Path -LiteralPath $readinessDir)) { $null = New-Item -ItemType Directory -Path $readinessDir -Force }
$receiptPath = Join-Path $readinessDir 'latest_readiness.json'
$receipt = [pscustomobject]@{
  '$schema'      = 'https://json-schema.org/draft/2020-12/schema'
  repository     = 'LCM_Inventory'
  timestamp      = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffffK')
  overall_status = $overallStatus
  test_scope     = $(if ($MinimalTests) { 'minimal' } else { 'full' })
  passed_count   = $passedCount
  total_count    = $gates.Count
  duration_ms    = [int]$sw.ElapsedMilliseconds
  gates          = $gates
}
$tmp = $receiptPath + '.tmp'
$receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $tmp -Encoding utf8NoBOM
Move-Item -LiteralPath $tmp -Destination $receiptPath -Force

Write-Host "`n================================================================="
if ($script:allPassed) {
  Write-Host (' All LCM_Inventory quality gates PASSED (' + $passedCount + '/' + $gates.Count + ')') -ForegroundColor Green
} else {
  Write-Host (' Quality gate check FAILED (' + $passedCount + '/' + $gates.Count + ' passed)') -ForegroundColor Red
}
Write-Host (' Receipt saved: data/readiness/latest_readiness.json (' + [int]$sw.ElapsedMilliseconds + ' ms)')
Write-Host '================================================================='

if (-not $script:allPassed) { exit 1 }
