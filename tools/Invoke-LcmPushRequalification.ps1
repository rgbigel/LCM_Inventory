<#
.SYNOPSIS
  Stepwise pre-publish requalification and dynamic remediation runner.
.DESCRIPTION
  Module: LCM_Inventory/tools/Invoke-LcmPushRequalification.ps1
  Purpose: Standalone runner for the 5-step requalification pipeline per RULE-DEC-005.
           Resets relief switches, validates AST syntax and UTF-8 encoding,
           runs quality gates, upgrades minimal-test proposals to verified completed,
           and records an audit receipt.
  Path: LCM_Inventory/tools/Invoke-LcmPushRequalification.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.1
  Date: 2026-11-12 12:45:00
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Specific repositories to include (defaults to all workspace repositories)')]
  [string[]]$Repositories,

  [Parameter(Mandatory = $false, HelpMessage = 'Auto-remediate mechanical issues (BOM, switch reset) without prompting')]
  [switch]$AutoRemediate,

  [Parameter(Mandatory = $false, HelpMessage = 'Non-interactive mode (fail closed on unresolvable issues)')]
  [switch]$NonInteractive,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " STEPWISE PUSH REQUALIFICATION ENGINE (Invoke-LcmPushRequalification)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Runs the transparent 5-step requalification DAG to qualify all workspace"
  Write-Host "  proposals and code for remote push per RULE-DEC-005."
  Write-Host "`nUSAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Invoke-LcmPushRequalification.ps1 [-AutoRemediate] [-NonInteractive]"
  return
}

$workspaceRoot = 'D:\Git_Repositories'
$proposalsFile = Join-Path $workspaceRoot 'LCM_Inventory\data\proposals\proposals.json'
$eligibilityModule = Join-Path $workspaceRoot 'LCM_Inventory\modules\LCM_PushEligibility.psm1'
$requalModule = Join-Path $workspaceRoot 'LCM_Inventory\modules\LcmPushRequalification.psm1'

Import-Module -Name $eligibilityModule -Force
Import-Module -Name $requalModule -Force

$ledgerJson = Get-Content -LiteralPath $proposalsFile -Raw -Encoding UTF8 | ConvertFrom-Json
$requestedRepositories = if ($null -eq $Repositories) { @() } else { @($Repositories | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
$pushPlan = Resolve-WorkspacePushPlan -Proposals @($ledgerJson.proposals) -RequestedRepositories $requestedRepositories -ProposalIds @()

$result = Invoke-LcmStepwiseRequalification -PushPlan $pushPlan -WorkspaceRoot $workspaceRoot -ProposalsFile $proposalsFile -AutoRemediate:$AutoRemediate -NonInteractive:$NonInteractive

if ($result.Success) {
  Write-Host "`n[SUCCESS] Workspace successfully requalified. Ready for remote Publish / Push." -ForegroundColor Green
  exit 0
} else {
  Write-Host "`n[FAILED] Requalification failed at step $($result.FailedStep)." -ForegroundColor Red
  exit 1
}

