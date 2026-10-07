<#
.SYNOPSIS
  Run native LCM_AI self-readiness checks before real-repository testing.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Test-WorkspaceReadiness.ps1 - Run native LCM_AI self-readiness checks." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Test-WorkspaceReadiness.ps1 [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -Help (-h, -?) Displays this help message."
  exit 0
}

<#
Module: Test-WorkspaceReadiness.ps1
Purpose: Run native LCM_AI self-readiness checks before real-repository testing.
Path: tools/Test-WorkspaceReadiness.ps1
Authors: LCM_AI Engine
Version: 1.8.1
Caller Contract: Called manually before enabling real-repository tests; validates current native governance pipeline.
Changelog:
- 2026-08-17: Decoupled ignored-repositories validation to root container settings.json.
- 2026-08-02: Added target-local proposal cleanup scanner parsing.
- 2026-08-02: Added target-local method instance bootstrap command parsing.
- 2026-08-01: Added intended-action preview command parsing and readiness output.
- 2026-08-01: Added target-profile command parsing and readiness output.
- 2026-08-01: Added guarded real-repository transition command parsing and plan inspection.
- 2026-08-01: Added real-repository dry-run contract checks.
- 2026-08-01: Consolidated helper checks behind WorkspaceQualityGates module.
- 2026-08-01: Added stabilization policy and stale-reference checks.
- 2026-08-01: Added LCM_AI readiness self-test wrapper.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
Set-Location $workspaceRoot

$qualityGateModulePath = Join-Path $PSScriptRoot 'QualityGates\WorkspaceQualityGates.psm1'
Import-Module $qualityGateModulePath -Force

Get-Content -Raw .\.vscode\settings.json | ConvertFrom-Json | Out-Null
Get-Content -Raw .\.copilot\History\Logs\Proposals.json | ConvertFrom-Json | Out-Null
Get-Content -Raw .\.copilot\History\Logs\Stabilization.json | ConvertFrom-Json | Out-Null
Get-Content -Raw .\.copilot\History\Logs\RealRepoTestPlan.json | ConvertFrom-Json | Out-Null

$scriptFiles = @(
  '.\tools/APPLY.ps1',
  '.\tools/Generate-Log.ps1',
  '.\tools/Advance-Governance.ps1',
  '.\tools/Get-WorkspaceRepositories.ps1',
  '.\tools/Get-RealRepoTestPlan.ps1',
  '.\tools/Get-RealRepoTargetProfile.ps1',
  '.\tools/Get-RealRepoActionPlan.ps1',
  '.\tools/Set-RealRepoTestPlan.ps1',
  '.\tools/Initialize-RealRepoMethodInstance.ps1',
  '.\tools/Test-RealRepoProposalCleanup.ps1',
  '.\tools/Invoke-RealRepoDryRun.ps1',
  '.\tools/QualityGates\WorkspaceQualityGates.psm1',
  '.\tools/Update-Proposal.ps1'
)

foreach ($scriptFile in $scriptFiles) {
  $currentScriptFile = $scriptFile
  $parseErrors = @()
  [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw $currentScriptFile), [ref]$parseErrors) | Out-Null
  if ($parseErrors.Count -gt 0) {
    throw "PowerShell parse failed: $currentScriptFile"
  }
}

.\tools/APPLY.ps1 -FixName Fix_S3E03 -NoLog
$rootContainer = Split-Path $workspaceRoot -Parent
$rootSettings = Join-Path $rootContainer '.vscode\settings.json'
Assert-IgnoredRepositories -SettingsPath $rootSettings -WorkspaceParent $rootContainer | Out-Host
Assert-StabilizationPolicy -WorkspaceRoot $workspaceRoot | Out-Host
Assert-RealRepoTestPlan -WorkspaceRoot $workspaceRoot | Out-Host
Assert-StaleAuthorityReferences -WorkspaceRoot $workspaceRoot | Out-Host
.\tools/Get-RealRepoTestPlan.ps1 | Out-Host
.\tools/Get-RealRepoTargetProfile.ps1 | Out-Host
.\tools/Get-RealRepoActionPlan.ps1 | Out-Host
.\tools/Invoke-RealRepoDryRun.ps1 | Out-Host
.\tools/Generate-Log.ps1
.\tools/Advance-Governance.ps1

$toolUpdater = Join-Path $rootContainer 'tools\Update-ToolCatalog.ps1'
if (Test-Path $toolUpdater) {
  & $toolUpdater -Silent
}

Write-Host 'LCM_AI readiness self-test: OK'