<#
.SYNOPSIS
  Displays LCM CRP/BUG/Proposal lifecycle date values and state transitions.

.DESCRIPTION
  Module: Workspace_Inventory/tools/Show-CrpDates.ps1
  Purpose: Queries and presents the complete state change date history (Created, In-Progress,
           Completed, Pushed, Deferred) for selected or all (default) proposals in Workspace_Inventory.
  Authors: Rolf, Workspace_AI Engine
  Version: 1.0.0
  Date: 2026-09-01

.PARAMETER Id
  Optional array of Proposal IDs to filter (e.g. 1, 28, 44). Defaults to all proposals.

.PARAMETER State
  Filter by current proposal state ('suggested', 'in_progress', 'completed', 'pushed', 'deferred').

.PARAMETER StateEvent
  Filter by state change event presence ('created', 'in_progress', 'completed', 'pushed', 'deferred').

.PARAMETER Detail
  Displays detailed individual state transition timeline and notes for each proposal.

.PARAMETER Web
  Launches the interactive CM Control Hub filtered to the date values view.

.PARAMETER Help
  Displays syntax and help information (-h / -Help / -?).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0)]
  [object[]]$Id,

  [Parameter(Mandatory = $false)]
  [string]$State,

  [Parameter(Mandatory = $false)]
  [string]$StateEvent,

  [Parameter(Mandatory = $false)]
  [switch]$Detail,

  [Alias('Cli', 'Text')]
  [switch]$NoBrowser,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM CRP & PROPOSAL STATE CHANGE DATES VIEWER (Show-CrpDates)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Displays the current state and individual state change date values for"
  Write-Host "  all (default) or selected LCM proposals/CRPs."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh Workspace_Inventory/tools/Show-CrpDates.ps1 [[-Id] <int[]>] [-State <str>] [-StateEvent <str>] [-Detail] [-Web] [-h]"
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh Workspace_Inventory/tools/Show-CrpDates.ps1                 # Show all CRP dates"
  Write-Host "  pwsh Workspace_Inventory/tools/Show-CrpDates.ps1 -Id 28,29,44   # Show selected CRPs"
  Write-Host "  pwsh Workspace_Inventory/tools/Show-CrpDates.ps1 -State pushed   # Filter by state"
  Write-Host "  pwsh Workspace_Inventory/tools/Show-CrpDates.ps1 -Detail        # Show full transition history"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

function Get-ObjProperty {
  param($Object, [string]$PropName, $Default = "-")
  if ($null -eq $Object) { return $Default }
  $prop = $Object.PSObject.Properties[$PropName]
  if ($null -ne $prop -and $null -ne $prop.Value -and $prop.Value -ne '') {
    return [string]$prop.Value
  }
  return $Default
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
  $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

if (-not $NoBrowser) {
  $hubScript = Join-Path $workspaceRoot "Workspace_Inventory\tools\Show-CmControlHub.ps1"
  if (Test-Path -LiteralPath $hubScript) {
    $hubArgs = @("-DatesMode")
    if ($State) { $hubArgs += @("-State", $State) }
    & pwsh -File $hubScript @hubArgs
    return
  }
}

$propFile = Join-Path $workspaceRoot 'Workspace_Inventory\data\proposals\proposals.json'
if (-not (Test-Path -LiteralPath $propFile)) {
  Write-Error "Proposals ledger not found at: $propFile"
  return
}

$jsonRaw = [System.IO.File]::ReadAllText($propFile, [System.Text.UTF8Encoding]::new($false))
$data = $jsonRaw | ConvertFrom-Json
$proposals = @($data.proposals)

# Parse and normalize target IDs
$targetIds = @()
if ($Id) {
  foreach ($item in $Id) {
    if ($item -is [string] -and $item.Contains(',')) {
      $parts = $item -split ','
      foreach ($p in $parts) {
        if (-not [string]::IsNullOrWhiteSpace($p)) { $targetIds += [int]$p.Trim() }
      }
    } elseif ($null -ne $item -and [string]::IsNullOrWhiteSpace([string]$item) -eq $false) {
      $targetIds += [int]$item
    }
  }
}

# Filter by ID if specified (default is ALL)
if ($targetIds.Count -gt 0) {
  $proposals = @($proposals | Where-Object { $targetIds -contains [int]$_.id })
}

# Filter by Current State if specified
if (-not [string]::IsNullOrWhiteSpace($State)) {
  $stateLower = $State.ToLower().Trim()
  $proposals = @($proposals | Where-Object {
    $curState = Get-ObjProperty $_ 'state' ''
    $progState = Get-ObjProperty $_ 'progress_state' ''
    $curState.ToLower() -eq $stateLower -or $progState.ToLower() -eq $stateLower
  })
}

# Filter by State Event if specified
if (-not [string]::IsNullOrWhiteSpace($StateEvent)) {
  $evLower = $StateEvent.ToLower().Trim()
  $proposals = @($proposals | Where-Object {
    $dObj = $_.PSObject.Properties['dates']
    if ($dObj -and $dObj.Value) {
      $val = Get-ObjProperty $dObj.Value $evLower ''
      return ($val -ne '')
    }
    return $false
  })
}

Write-Host "========================================================================================================================" -ForegroundColor Cyan
Write-Host " LCM PROPOSAL & CRP STATE CHANGE DATES LEDGER (Total: $($proposals.Count) proposals)" -ForegroundColor Cyan
Write-Host "========================================================================================================================" -ForegroundColor Cyan

$formatted = foreach ($p in $proposals) {
  $dObj = if ($p.PSObject.Properties['dates']) { $p.dates } else { $null }
  $created = Get-ObjProperty $dObj 'created' (Get-ObjProperty $p 'timestamp' '-')
  $inProg  = Get-ObjProperty $dObj 'in_progress' '-'
  $comp    = Get-ObjProperty $dObj 'completed' '-'
  $pushed  = Get-ObjProperty $dObj 'pushed' (Get-ObjProperty $p 'pushed_at' '-')
  
  $crId = Get-ObjProperty $p 'cr_id' "CR-$($p.id)"
  $curState = (Get-ObjProperty $p 'state' 'UNKNOWN').ToUpper()
  $rawTitle = Get-ObjProperty $p 'title' ''
  $titleTrunc = if ($rawTitle.Length -gt 38) { $rawTitle.Substring(0, 35) + "..." } else { $rawTitle }

  [PSCustomObject]@{
    ID          = "#$($p.id)"
    CR_ID       = $crId
    State       = $curState
    Created     = $created
    InProgress  = $inProg
    Completed   = $comp
    Pushed      = $pushed
    Title       = $titleTrunc
  }
}

$formatted | Format-Table -AutoSize | Out-String -Stream -Width 4096

if ($Detail -or ($Id -and $Id.Count -gt 0 -and $Id.Count -le 5)) {
  Write-Host "`n========================================================================================================================" -ForegroundColor Yellow
  Write-Host " DETAILED STATE CHANGE TRANSITION TIMELINES" -ForegroundColor Yellow
  Write-Host "========================================================================================================================" -ForegroundColor Yellow
  foreach ($p in $proposals) {
    $proposalId = Get-ObjProperty $p 'id' '0'
    $pCr = Get-ObjProperty $p 'cr_id' "CR-$proposalId"
    $pTitle = Get-ObjProperty $p 'title' ''
    $pState = Get-ObjProperty $p 'state' 'unknown'
    $pProg = Get-ObjProperty $p 'progress_state' 'unknown'
    $pRepo = Get-ObjProperty $p 'origin_repo' 'unknown'
    Write-Host "`n[#$($proposalId)] $($pCr): $($pTitle)" -ForegroundColor Cyan
    Write-Host "  Current State: $pState (Progress: $pProg) | Scope: $pRepo" -ForegroundColor White
    
    $histProp = $p.PSObject.Properties['state_history']
    if ($histProp -and $histProp.Value -and $histProp.Value.Count -gt 0) {
      Write-Host "  State Transitions:" -ForegroundColor Gray
      foreach ($h in $histProp.Value) {
        $hTs = Get-ObjProperty $h 'timestamp' '-'
        $hSt = (Get-ObjProperty $h 'state' 'unknown').ToUpper()
        $hUs = Get-ObjProperty $h 'user' 'User'
        $hNt = Get-ObjProperty $h 'note' ''
        Write-Host "    -> [$hTs] State: $hSt by $hUs - $hNt" -ForegroundColor Green
      }
    } else {
      Write-Host "    -> [No detailed transition log]" -ForegroundColor DarkGray
    }
  }
}
