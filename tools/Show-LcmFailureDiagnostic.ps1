<#
.SYNOPSIS
  Shows a structured lifecycle failure diagnostic without mutating state.
.DESCRIPTION
  Module: Show-LcmFailureDiagnostic
  Purpose: Exercises the lifecycle validator only for an action that is invalid
           for every selected proposal, then renders its authoritative failure
           report. It never applies a valid lifecycle action.
  Path: LCM_Inventory/tools/Show-LcmFailureDiagnostic.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-10-15
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Lifecycle action to diagnose. It must be invalid for every target.')]
  [ValidateSet('do', 'delete', 'defer', 'deferred', 'complete', 'completed', 'suggest', 'suggested', 'reject', 'rejected', 'approve', 'approved', 'bug', 'push', 'pushed', 'hold', 'held', 'resume', 'continue', 'withdraw', 'supersede', 'reopen', 'reinstate', 'reset')]
  [string]$Action = 'do',

  [Parameter(Mandatory = $false, HelpMessage = 'Exact CRP or BUG target expression to diagnose.')]
  [string]$TargetExpression = 'CRP-279',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Show-LcmFailureDiagnostic.ps1 [-Action <action>] [-TargetExpression <CRP|BUG>] [-h]'
  Write-Host '  Safely renders a real lifecycle failure report. The action must be invalid for every target.'
  Write-Host '  Defaults: -Action do -TargetExpression CRP-279'
  Write-Host '  Example: ShowFailureDiagnostic -Action do -TargetExpression CRP-279'
  return
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
  $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$proposalModulePath = Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'
Import-Module -Name $proposalModulePath -Force

$targetIds = @(Resolve-ProposalIdExpression -Expression $TargetExpression)
if ($targetIds.Count -eq 0) {
  throw "Target expression '$TargetExpression' did not resolve to a proposal."
}

$store = Get-ProposalStore
foreach ($id in $targetIds) {
  $proposal = @($store.proposals | Where-Object { [int]$_.id -eq [int]$id })[0]
  if ($null -eq $proposal) {
    throw "Target expression '$TargetExpression' includes missing proposal #$id."
  }
  $state = [string]$proposal.state
  $validActions = @(Get-LcmProposalLifecycleActions -State $state)
  if ($Action -in $validActions) {
    $identity = if ($proposal.crp_id) { [string]$proposal.crp_id } elseif ($proposal.cr_id) { [string]$proposal.cr_id } else { "CRP-$id" }
    throw "ShowFailureDiagnostic refuses valid action '$Action' for $identity in '$state'; it never applies lifecycle actions."
  }
}

try {
  $null = Invoke-ProposalBatchAction -Action $Action -TargetExpression $TargetExpression
  throw "Lifecycle validator unexpectedly accepted '$Action' for '$TargetExpression'; no diagnostic was rendered."
} catch {
  $reportJson = $_.Exception.Data['LcmLifecycleFailureReport']
  if ([string]::IsNullOrWhiteSpace([string]$reportJson)) {
    throw
  }
  $report = $reportJson | ConvertFrom-Json
  Format-LcmLifecycleFailureReport -Report $report
  return $report
}
