<#
.SYNOPSIS
  Toggles or configures the development relief switches across the LCM workspace.
.DESCRIPTION
  Module: Set-LcmReliefMode
  Purpose: Provides a unified control switch to enable, disable, or toggle development
           relief modes across the workspace:
           - Review Granularity (coarse vs tight)
           - Testing Mode (minimal / paused vs active)
           - Flow Mode (doit vs standard)
           - Always Proceed (true vs false)
           When relief mode is ON, velocity is maximized for rapid prototyping.
           When relief mode is OFF (standard / strict), full testing and tight review gating apply.
  Path: LCM_Inventory/tools/Set-LcmReliefMode.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.1
  Date: 2026-11-12 09:40:00
.PARAMETER State
  Target state for relief mode: 'On', 'Off', 'Toggle', or 'Status' (Default: 'Status').
.PARAMETER On
  Enables development relief mode (coarse reviews, minimal testing, doit flow mode).
.PARAMETER Off
  Disables development relief mode, restoring strict governance (tight reviews, active tests, standard flow).
.PARAMETER Toggle
  Toggles the current relief mode between On and Off.
.PARAMETER Help
  Displays this command syntax and parameter reference (-h / -Help / -?).
.EXAMPLE
  pwsh LCM_Inventory/tools/Set-LcmReliefMode.ps1 -On
.EXAMPLE
  pwsh LCM_Inventory/tools/Set-LcmReliefMode.ps1 -Off
.EXAMPLE
  pwsh LCM_Inventory/tools/Set-LcmReliefMode.ps1 -Toggle
.EXAMPLE
  pwsh LCM_Inventory/tools/Set-LcmReliefMode.ps1
#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
  [Parameter(Position = 0, ParameterSetName = 'Default')]
  [ValidateSet('On', 'Off', 'Toggle', 'Status')]
  [string]$State = 'Status',

  [Parameter(ParameterSetName = 'OnFlag')]
  [Alias('Enable')]
  [switch]$On,

  [Parameter(ParameterSetName = 'OffFlag')]
  [Alias('Disable')]
  [switch]$Off,

  [Parameter(ParameterSetName = 'ToggleFlag')]
  [switch]$Toggle,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host ' LCM RELIEF MODE CONTROLLER (Set-LcmReliefMode)' -ForegroundColor Green
  Write-Host '==========================================================================' -ForegroundColor Cyan
  Write-Host 'SYNOPSIS:' -ForegroundColor Yellow
  Write-Host '  Toggles or configures development relief switches across the LCM workspace.'
  Write-Host ''
  Write-Host 'USAGE:' -ForegroundColor Yellow
  Write-Host '  pwsh LCM_Inventory/tools/Set-LcmReliefMode.ps1 [-On | -Off | -Toggle | Status] [-h]'
  Write-Host '  ReliefMode.cmd [on|off|toggle]'
  Write-Host ''
  Write-Host 'PARAMETERS:' -ForegroundColor Yellow
  Write-Host '  -On (-Enable)   : Enables relief mode (coarse review, minimal testing, doit flow).'
  Write-Host '  -Off (-Disable) : Disables relief mode, restoring strict governance baseline.'
  Write-Host '  -Toggle         : Toggles between Relief (On) and Strict (Off).'
  Write-Host '  -Help (-h, -?)  : Displays this help screen.'
  Write-Host '==========================================================================' -ForegroundColor Cyan
  return
}

$workspaceRoot = 'D:\Git_Repositories'
$modulePath = Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'
if (-not (Test-Path -LiteralPath $modulePath)) {
  throw "ProposalManager module not found: $modulePath"
}

Import-Module -Name $modulePath -Force

# Determine effective target action
$action = 'Status'
if ($On -or $State -eq 'On') {
  $action = 'On'
} elseif ($Off -or $State -eq 'Off') {
  $action = 'Off'
} elseif ($Toggle -or $State -eq 'Toggle') {
  $action = 'Toggle'
}

$store = Get-ProposalStore
$currentGranularity = Get-ReviewGranularity
$currentTesting = Get-TestingMode
$currentFlow = if ($store.PSObject.Properties['flow_mode'] -and $store.flow_mode) { $store.flow_mode } else { 'standard' }
$currentProceed = if ($store.PSObject.Properties['always_proceed'] -and $store.always_proceed) { [bool]$store.always_proceed } else { $false }

$isReliefActive = ($currentGranularity -eq 'coarse') -or ($currentTesting -ne 'active') -or ($currentFlow -eq 'doit') -or ($currentProceed -eq $true) -or ($store.PSObject.Properties['minimal_tests'] -and $store.minimal_tests -eq $true)

if ($action -eq 'Toggle') {
  $action = if ($isReliefActive) { 'Off' } else { 'On' }
}

if ($action -eq 'On') {
  Set-ReviewGranularity -Granularity 'coarse' | Out-Null
  Set-TestingMode -Mode 'paused' | Out-Null

  $store = Get-ProposalStore
  if (-not $store.PSObject.Properties['flow_mode']) {
    $store | Add-Member -NotePropertyName 'flow_mode' -NotePropertyValue 'doit'
  } else {
    $store.flow_mode = 'doit'
  }
  if (-not $store.PSObject.Properties['always_proceed']) {
    $store | Add-Member -NotePropertyName 'always_proceed' -NotePropertyValue $true
  } else {
    $store.always_proceed = $true
  }
  $store | Add-Member -NotePropertyName 'minimal_tests' -NotePropertyValue $true -Force
  $store | Add-Member -NotePropertyName 'test_scope' -NotePropertyValue 'minimal' -Force
  Set-ProposalStore -Store $store
  Write-Host "`n>>> [RELIEF MODE ACTIVATED] <<<" -ForegroundColor Yellow
} elseif ($action -eq 'Off') {
  Set-ReviewGranularity -Granularity 'tight' | Out-Null
  Set-TestingMode -Mode 'active' | Out-Null

  $store = Get-ProposalStore
  if ($store.PSObject.Properties['flow_mode']) {
    $store.flow_mode = 'standard'
  }
  if ($store.PSObject.Properties['always_proceed']) {
    $store.always_proceed = $false
  }
  $store | Add-Member -NotePropertyName 'minimal_tests' -NotePropertyValue $false -Force
  $store | Add-Member -NotePropertyName 'test_scope' -NotePropertyValue 'full' -Force
  Set-ProposalStore -Store $store
  Write-Host "`n>>> [STRICT GOVERNANCE RESTORED (RELIEF OFF)] <<<" -ForegroundColor Green
}

# Fetch updated states for reporting
$finalStore = Get-ProposalStore
$finalGranularity = Get-ReviewGranularity
$finalTesting = Get-TestingMode
$finalFlow = if ($finalStore.PSObject.Properties['flow_mode'] -and $finalStore.flow_mode) { $finalStore.flow_mode } else { 'standard' }
$finalProceed = if ($finalStore.PSObject.Properties['always_proceed'] -and $finalStore.always_proceed) { [bool]$finalStore.always_proceed } else { $false }
$finalMinTests = if ($finalStore.PSObject.Properties['minimal_tests'] -and $finalStore.minimal_tests) { $true } else { $false }
$finalRelief = ($finalGranularity -eq 'coarse') -or ($finalTesting -ne 'active') -or ($finalFlow -eq 'doit') -or ($finalProceed -eq $true) -or $finalMinTests

$summaryColor = if ($finalRelief) { 'Yellow' } else { 'Green' }
$modeLabel = if ($finalRelief) { 'RELIEF (Rapid Prototyping)' } else { 'STRICT (Standard Governance)' }

Write-Host '==========================================================================' -ForegroundColor Cyan
Write-Host " LCM Workspace Operational Mode: $modeLabel" -ForegroundColor $summaryColor
Write-Host '==========================================================================' -ForegroundColor Cyan

[PSCustomObject]@{
  ReviewGranularity = $finalGranularity
  TestingMode       = $finalTesting
  FlowMode          = $finalFlow
  AlwaysProceed     = $finalProceed
  MinimalTests      = $finalMinTests
  TestDAG           = if ($finalMinTests) { 'Fast Single DAG' } else { 'Standard DAG' }
  ReliefActive      = $finalRelief
} | Format-List

Write-Host "Note: Remote 'PUSH' (Invoke-LCM_Push.ps1) will automatically reset relief switches to Strict baseline per RULE-DEC-005.`n" -ForegroundColor DarkGray

