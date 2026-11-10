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
  Write-Host "Test-LCM_Readiness.ps1 - Run native LCM_AI self-readiness checks." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Test-LCM_Readiness.ps1 [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -Help (-h, -?) Displays this help message."
  exit 0
}

<#
Module: Test-LCM_Readiness.ps1
Purpose: Run native LCM_AI self-readiness checks before real-repository testing.
Path: tools/Test-LCM_Readiness.ps1
Authors: LCM_AI Engine
Version: 10.2.1
Date: 2026-11-08 15:02:28
Caller Contract: Called manually before enabling real-repository tests; validates current native governance pipeline.
Changelog:
- 2026-10-13: Decoupled ignored-repositories validation to root container settings.json.
- 2026-10-13: Added target-local proposal cleanup scanner parsing.
- 2026-10-13: Added target-local method instance bootstrap command parsing.
- 2026-10-13: Added intended-action preview command parsing and readiness output.
- 2026-10-13: Added target-profile command parsing and readiness output.
- 2026-10-13: Added guarded real-repository transition command parsing and plan inspection.
- 2026-10-13: Added real-repository dry-run contract checks.
- 2026-10-13: Consolidated helper checks behind WorkspaceQualityGates module.
- 2026-10-13: Added stabilization policy and stale-reference checks.
- 2026-10-13: Added LCM_AI readiness self-test wrapper.
#>

$inventoryRoot = Split-Path $PSScriptRoot -Parent
$workspaceRoot = Split-Path $inventoryRoot -Parent
Set-Location $inventoryRoot

$qualityGateModulePath = Join-Path $PSScriptRoot 'QualityGates\LCM_QualityGates.psm1'
Import-Module $qualityGateModulePath -Force

Get-Content -Raw (Join-Path $workspaceRoot '.vscode\settings.json') | ConvertFrom-Json | Out-Null
Get-Content -Raw (Join-Path $workspaceRoot '.copilot\History\Logs\Proposals.json') | ConvertFrom-Json | Out-Null
Get-Content -Raw (Join-Path $workspaceRoot '.copilot\History\Logs\Stabilization.json') | ConvertFrom-Json | Out-Null
Get-Content -Raw (Join-Path $workspaceRoot '.copilot\History\Logs\RealRepoTestPlan.json') | ConvertFrom-Json | Out-Null

$scriptFiles = @(
  '.\tools/APPLY.ps1',
  '.\tools/Generate-Log.ps1',
  '.\tools/Advance-Governance.ps1',
  '.\tools/Get-LCM_Repositories.ps1',
  '.\tools/Get-RealRepoTestPlan.ps1',
  '.\tools/Get-RealRepoTargetProfile.ps1',
  '.\tools/Get-RealRepoActionPlan.ps1',
  '.\tools/Set-RealRepoTestPlan.ps1',
  '.\tools/Initialize-RealRepoMethodInstance.ps1',
  '.\tools/Test-RealRepoProposalCleanup.ps1',
  '.\tools/Invoke-RealRepoDryRun.ps1',
  '.\tools/QualityGates\LCM_QualityGates.psm1',
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

Assert-IgnoredRepositories -SettingsPath (Join-Path $workspaceRoot '.vscode\settings.json') -WorkspaceParent $workspaceRoot | Out-Host
$stabilizationPath = Join-Path $workspaceRoot '.copilot\History\Logs\Stabilization.json'
$realRepoTestPlanPath = Join-Path $workspaceRoot '.copilot\History\Logs\RealRepoTestPlan.json'
Assert-StabilizationPolicy -StabilizationPath $stabilizationPath -RealRepoTestPlanPath $realRepoTestPlanPath -WorkspaceRoot $inventoryRoot | Out-Host
Assert-RealRepoTestPlan -RealRepoTestPlanPath $realRepoTestPlanPath -StabilizationPath $stabilizationPath -WorkspaceRoot $inventoryRoot | Out-Host
Assert-StaleAuthorityReferences -WorkspaceRoot $inventoryRoot | Out-Host
.\tools/Get-RealRepoTestPlan.ps1 | Out-Host
.\tools/Get-RealRepoTargetProfile.ps1 | Out-Host
.\tools/Get-RealRepoActionPlan.ps1 | Out-Host
.\tools/Invoke-RealRepoDryRun.ps1 | Out-Host
.\tools/Generate-Log.ps1
.\tools/Advance-Governance.ps1

$toolUpdater = Join-Path $workspaceRoot 'tools\Update-ToolCatalog.ps1'
if (Test-Path $toolUpdater) {
  & $toolUpdater -Silent
}

Write-Host 'LCM_AI readiness self-test: OK'
