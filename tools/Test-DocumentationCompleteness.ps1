<#
.SYNOPSIS
  Audits tripartite specifications and installation runbooks across workspace repositories.
.DESCRIPTION
  Module: Test-DocumentationCompleteness
  Purpose: Verifies compliance with RULE-DOC-001 (tripartite docs: Architecture.md, Requirements.md,
           Implementation.md) and RULE-DOC-004 (install/Installation.md 7-phase runbook) across
           all LCM-governed workspace repositories. Emits structured compliance diagnostics and summary.
  Path: LCM_Inventory/tools/Test-DocumentationCompleteness.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-11-10
.PARAMETER WorkspaceRoot
  Path to the root container of repositories. Defaults to 'D:\Git_Repositories'.
.PARAMETER Repositories
  Optional list of specific repository folder names to audit. If omitted, audits all discovered repositories.
.PARAMETER RequireInstall
  When set, treats missing install/Installation.md as a failure.
.PARAMETER AsJson
  Outputs audit results as formatted JSON.
.PARAMETER PassThru
  Returns structured audit result objects to the PowerShell pipeline.
.PARAMETER Help
  Displays this command syntax and parameter reference (-h / -Help / -?).
.EXAMPLE
  pwsh LCM_Inventory/tools/Test-DocumentationCompleteness.ps1
  Audits all workspace repositories for tripartite documentation completeness.
.EXAMPLE
  pwsh LCM_Inventory/tools/Test-DocumentationCompleteness.ps1 -Repositories LCM_Inventory -RequireInstall
  Audits LCM_Inventory requiring both tripartite documents and 7-phase Installation.md.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$WorkspaceRoot = 'D:\Git_Repositories',

  [Parameter(Mandatory = $false)]
  [string[]]$Repositories = @(),

  [Parameter(Mandatory = $false)]
  [ValidateSet('Core', 'Governed', 'All')]
  [string]$Scope = 'Governed',

  [switch]$RequireInstall,

  [switch]$AsJson,

  [switch]$PassThru,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = '10.0.0'
$scriptName = 'Test-DocumentationCompleteness'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM DOCUMENTATION COMPLETENESS AUDITOR (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Audits workspace repositories for compliance with RULE-DOC-001 (tripartite docs)"
  Write-Host "  and RULE-DOC-004 (install/Installation.md 7-phase runbook standard)."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Test-DocumentationCompleteness.ps1 [-Repositories <names>] [-RequireInstall] [-AsJson] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -WorkspaceRoot <dir>    : Root repositories directory (Default: 'D:\Git_Repositories')."
  Write-Host "  -Repositories <array>   : Filter audit to specific repositories."
  Write-Host "  -RequireInstall         : Enforce install/Installation.md as mandatory."
  Write-Host "  -AsJson                 : Output structured JSON result."
  Write-Host "  -PassThru               : Emit audit objects to pipeline."
  Write-Host "  -h, -Help, -?           : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

function Test-DoxHeaderCompliance {
  param([string]$FilePath)

  if (-not (Test-Path -LiteralPath $FilePath)) {
    return @{ Compliant = $false; MissingFields = @('File Not Found') }
  }

  $firstLines = @(Get-Content -LiteralPath $FilePath -TotalCount 20 -Encoding UTF8)
  $headerText = $firstLines -join "`n"

  $requiredFields = @('Module:', 'Purpose:', 'Path:', 'Authors:', 'Version:', 'Date:')
  $missing = @()

  foreach ($field in $requiredFields) {
    if ($headerText -notmatch "(?i)$([regex]::Escape($field))") {
      $missing += $field
    }
  }

  return @{
    Compliant     = ($missing.Count -eq 0)
    MissingFields = $missing
  }
}

function Test-InstallRunbookPhases {
  param([string]$FilePath)

  if (-not (Test-Path -LiteralPath $FilePath)) {
    return @{ Compliant = $false; PresentPhases = 0; MissingPhases = @('File Not Found') }
  }

  $content = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)

  $phasePatterns = @(
    @{ Phase = 1; Pattern = '(?i)Phase\s*1.*Prerequisite' },
    @{ Phase = 2; Pattern = '(?i)Phase\s*2.*(Layout|Destination|Topology)' },
    @{ Phase = 3; Pattern = '(?i)Phase\s*3.*(Preflight|Health Check)' },
    @{ Phase = 4; Pattern = '(?i)Phase\s*4.*(Deployment|Configuration|Step)' },
    @{ Phase = 5; Pattern = '(?i)Phase\s*5.*(Post-Deployment|Verification|Smoke)' },
    @{ Phase = 6; Pattern = '(?i)Phase\s*6.*(Servicing|Update|Maintenance)' },
    @{ Phase = 7; Pattern = '(?i)Phase\s*7.*(Rollback|Uninstall|De-provisioning)' }
  )

  $missingPhases = @()
  $presentCount = 0

  foreach ($p in $phasePatterns) {
    if ($content -match $p.Pattern) {
      $presentCount++
    } else {
      $missingPhases += "Phase $($p.Phase)"
    }
  }

  return @{
    Compliant     = ($presentCount -eq 7)
    PresentPhases = $presentCount
    MissingPhases = $missingPhases
  }
}

# Discover repositories
if (-not (Test-Path -LiteralPath $WorkspaceRoot)) {
  throw "Workspace root not found: $WorkspaceRoot"
}

$coreRepos = @('LCM_Inventory', 'LCM_AI', 'LCM_Shared', 'LCM_Supervision', 'LCM_Tools')
$governedKnown = @(
  'AuthorizeMasterUser', 'BackgroundModifier', 'BGMSAMVInv', 'BootEntryManager',
  'HaSSD06', 'HaSSD06_Inventory', 'NextBootTray', 'OneDriveMaintenance',
  'RollingCalendar', 'VolumeInventory', 'MacriumTemplateUpdater'
) + $coreRepos

$repoDirs = @(Get-ChildItem -LiteralPath $WorkspaceRoot -Directory | Where-Object {
  $name = $_.Name
  if ($name.StartsWith('.')) { return $false }
  if ($Repositories.Count -gt 0) {
    return ($name -in $Repositories)
  }
  if ($Scope -eq 'Core') {
    return ($name -in $coreRepos)
  }
  if ($Scope -eq 'Governed') {
    return ($name -in $governedKnown)
  }
  return $true
})

$results = @()
$totalPassed = 0
$totalFailed = 0

foreach ($dir in $repoDirs) {
  $repoName = $dir.Name
  $repoPath = $dir.FullName

  # Tripartite files in docs/
  $archPath = Join-Path $repoPath 'docs\Architecture.md'
  $reqPath  = Join-Path $repoPath 'docs\Requirements.md'
  $implPath = Join-Path $repoPath 'docs\Implementation.md'

  $hasArch = Test-Path -LiteralPath $archPath
  $hasReq  = Test-Path -LiteralPath $reqPath
  $hasImpl = Test-Path -LiteralPath $implPath

  $tripartiteComplete = ($hasArch -and $hasReq -and $hasImpl)

  # DOX check on tripartite
  $doxArch = if ($hasArch) { Test-DoxHeaderCompliance -FilePath $archPath } else { @{ Compliant = $false; MissingFields = @('File Not Found') } }
  $doxReq  = if ($hasReq)  { Test-DoxHeaderCompliance -FilePath $reqPath }  else { @{ Compliant = $false; MissingFields = @('File Not Found') } }
  $doxImpl = if ($hasImpl) { Test-DoxHeaderCompliance -FilePath $implPath } else { @{ Compliant = $false; MissingFields = @('File Not Found') } }

  # Installation runbook check
  $installCandidates = @(
    (Join-Path $repoPath 'install\Installation.md'),
    (Join-Path $repoPath 'Install\Installation.md')
  )
  $installPath = $null
  foreach ($cand in $installCandidates) {
    if (Test-Path -LiteralPath $cand) {
      $installPath = $cand
      break
    }
  }

  $hasInstall = ($null -ne $installPath)
  $installAudit = if ($hasInstall) { Test-InstallRunbookPhases -FilePath $installPath } else { @{ Compliant = $false; PresentPhases = 0; MissingPhases = @('Missing') } }

  $isCompliant = $tripartiteComplete
  if ($RequireInstall) {
    $isCompliant = $isCompliant -and $hasInstall -and $installAudit.Compliant
  }

  if ($isCompliant) {
    $totalPassed++
  } else {
    $totalFailed++
  }

  $repoResult = [PSCustomObject]@{
    Repository          = $repoName
    Compliant           = $isCompliant
    TripartiteComplete  = $tripartiteComplete
    Architecture        = $hasArch
    Requirements        = $hasReq
    Implementation      = $hasImpl
    HasInstallationMd   = $hasInstall
    InstallationPhases  = if ($hasInstall) { "$($installAudit.PresentPhases)/7" } else { "N/A" }
    InstallCompliant    = if ($hasInstall) { $installAudit.Compliant } else { $false }
    MissingItems        = @()
  }

  if (-not $hasArch) { $repoResult.MissingItems += 'docs/Architecture.md' }
  if (-not $hasReq)  { $repoResult.MissingItems += 'docs/Requirements.md' }
  if (-not $hasImpl) { $repoResult.MissingItems += 'docs/Implementation.md' }
  if ($RequireInstall -and -not $hasInstall) { $repoResult.MissingItems += 'install/Installation.md' }
  elseif ($hasInstall -and -not $installAudit.Compliant) {
    $repoResult.MissingItems += "install/Installation.md missing: $($installAudit.MissingPhases -join ', ')"
  }

  $results += $repoResult
}

if ($AsJson) {
  $results | ConvertTo-Json -Depth 5
  if ($PassThru) { return $results }
  return
}

# Render console output
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM DOCUMENTATION COMPLETENESS AUDIT REPORT (v$($scriptVersion))" -ForegroundColor Cyan
Write-Host " Repositories Scanned : $($results.Count)" -ForegroundColor White
Write-Host " Passed               : $totalPassed" -ForegroundColor Green
Write-Host " Gaps / Incomplete    : $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { 'Yellow' } else { 'Green' })
Write-Host " Require Installation : $(if ($RequireInstall) { 'ENABLED (RULE-DOC-004)' } else { 'DISABLED (Tripartite Only)' })" -ForegroundColor Gray
Write-Host "==========================================================================" -ForegroundColor Cyan

$results | Format-Table Repository, Compliant, TripartiteComplete, HasInstallationMd, InstallationPhases -AutoSize | Out-Host

if ($totalFailed -gt 0) {
  Write-Host "COMPLIANCE GAPS IDENTIFIED:" -ForegroundColor Yellow
  foreach ($r in ($results | Where-Object { -not $_.Compliant })) {
    Write-Host "  - $($r.Repository):" -ForegroundColor Yellow
    foreach ($m in $r.MissingItems) {
      Write-Host "      * Missing: $m" -ForegroundColor Red
    }
  }
}

if ($PassThru) {
  return $results
}

if ($RequireInstall -and $totalFailed -gt 0) {
  exit 1
}
