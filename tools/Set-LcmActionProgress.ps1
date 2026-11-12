<#
.SYNOPSIS
  Updates and queries the live action progress indicator engine.

.DESCRIPTION
  Module: Set-LcmActionProgress
  Purpose: CLI entrypoint for the Universal Multi-Channel Progress Indicator Engine (CRP-2026-027).
           Allows terminal commands, scripts, and background workers to broadcast progress
           milestones for single and multi-item operations (PROCEED, COMPLETE, PUSH, do #n-#m).
  Path: LCM_Inventory/tools/Set-LcmActionProgress.ps1
  Authors: Rolf, LCM_AI Governance
  Version: 10.2.1
  Date: 2026-11-12

.PARAMETER Action
  Operation to execute: 'Start', 'Update', 'Complete', 'Stop', or 'Get'. Defaults to 'Get'.

.PARAMETER Command
  High-level action command name (e.g. 'PROCEED', 'COMPLETE', 'PUSH', 'do'). Required for -Action Start.

.PARAMETER Items
  Array of item IDs or labels to track in the batch. Required for -Action Start.

.PARAMETER Id
  Individual item ID being updated or completed.

.PARAMETER Phase
  Human-readable operational phase description (e.g. 'AST Validation', 'Pester Test Suite').

.PARAMETER Percent
  Completion percentage (0 to 100) for the active item.

.PARAMETER State
  Item state: 'queued', 'in_progress', 'completed', or 'failed'. Defaults to 'in_progress'.

.PARAMETER Error
  Error details if marking an item as failed.

.PARAMETER Help
  Displays parameter reference and usage examples (Aliases: -h, -?).

.EXAMPLE
  pwsh LCM_Inventory/tools/Set-LcmActionProgress.ps1 -Action Start -Command "PROCEED" -Items 106,107,108

.EXAMPLE
  pwsh LCM_Inventory/tools/Set-LcmActionProgress.ps1 -Action Update -Id 106 -Phase "Running Quality Gates" -Percent 50

.EXAMPLE
  pwsh LCM_Inventory/tools/Set-LcmActionProgress.ps1 -Action Complete -Id 106
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = "Operation to execute: 'Start', 'Update', 'Complete', 'Stop', or 'Get'")]
  [ValidateSet('Start', 'Update', 'Complete', 'Stop', 'Get')]
  [string]$Action = 'Get',

  [Parameter(Mandatory = $false, HelpMessage = "High-level action command name (e.g. 'PROCEED', 'COMPLETE', 'PUSH', 'do')")]
  [string]$Command = 'PROCEED',

  [Parameter(Mandatory = $false, HelpMessage = 'Array of item IDs or labels to track in the batch')]
  [string[]]$Items = @(),

  [Parameter(Mandatory = $false, HelpMessage = 'Individual item ID being updated or completed')]
  [string]$Id = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Human-readable operational phase description')]
  [string]$Phase = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Completion percentage (0 to 100) for the active item')]
  [int]$Percent = 0,

  [Parameter(Mandatory = $false, HelpMessage = "Item state: 'queued', 'in_progress', 'completed', or 'failed'")]
  [ValidateSet('queued', 'in_progress', 'completed', 'failed')]
  [string]$State = 'in_progress',

  [Parameter(Mandatory = $false, HelpMessage = 'Error details if marking an item as failed')]
  [string]$ErrorMessage = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = '10.0.0'
$scriptName = 'Set-LcmActionProgress'

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM ACTION PROGRESS INDICATOR CLI (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Broadcasts progress milestones for single and batch actions across"
  Write-Host "  Terminal, Chat, and Web Dashboards per CRP-2026-027."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Set-LcmActionProgress.ps1 -Action <Action> [parameters...]"
  Write-Host ""
  Write-Host "ACTIONS:" -ForegroundColor Yellow
  Write-Host "  Start    : Initiates a new progress batch for a list of items."
  Write-Host "  Update   : Updates phase, percent, and state for an item."
  Write-Host "  Complete : Marks an individual item as 100% completed."
  Write-Host "  Stop     : Finalizes the progress batch."
  Write-Host "  Get      : Retrieves and displays the current active progress snapshot."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Import Module per RULE-PS-012
# ------------------------------------------------------------------------------
$workspaceRoot = if (-not [string]::IsNullOrWhiteSpace($env:LCM_WORKSPACE_ROOT)) {
  $env:LCM_WORKSPACE_ROOT.TrimEnd('\', '/')
} elseif ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\LCM_Inventory'))) {
  (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} elseif (-not [string]::IsNullOrWhiteSpace($env:Git_Root)) {
  $env:Git_Root.TrimEnd('\', '/')
} else {
  'D:\Git_Repositories'
}
$modulePath = Join-Path $workspaceRoot 'LCM_Inventory\modules\LcmProgressAtom.psm1'

if (-not (Test-Path -LiteralPath $modulePath)) {
  throw "LcmProgressAtom module not found at: $modulePath"
}

Import-Module -Name $modulePath -Force

# ------------------------------------------------------------------------------
# 2. Dispatch Action
# ------------------------------------------------------------------------------
switch ($Action) {
  'Start' {
    $expandedItems = @()
    foreach ($it in $Items) {
      if ($it -match ',') {
        $expandedItems += @($it -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
      } else {
        $expandedItems += $it
      }
    }
    $Items = $expandedItems

    if (@($Items).Count -eq 0) {
      throw "Action 'Start' requires at least one item in -Items."
    }
    $batchId = Start-LcmProgressBatch -Command $Command -Items $Items -Origin 'CLI'
    Write-Host "Started progress batch: $batchId ($(@($Items).Count) items)" -ForegroundColor Green
  }
  'Update' {
    if ([string]::IsNullOrWhiteSpace($Id)) {
      throw "Action 'Update' requires an item ID in -Id."
    }
    Update-LcmProgressItem -Id $Id -Phase $Phase -Percent $Percent -State $State
  }
  'Complete' {
    if ([string]::IsNullOrWhiteSpace($Id)) {
      throw "Action 'Complete' requires an item ID in -Id."
    }
    Complete-LcmProgressItem -Id $Id -ErrorMessage $ErrorMessage
    Write-Host "Completed item #$($Id)" -ForegroundColor Green
  }
  'Stop' {
    Stop-LcmProgressBatch
    Write-Host "Finalized progress batch." -ForegroundColor Green
  }
  'Get' {
    $current = Get-LcmActionProgress
    if ($null -eq $current) {
      Write-Host "No active progress batch running." -ForegroundColor DarkGray
    } else {
      $current | ConvertTo-Json -Depth 5
    }
  }
}
