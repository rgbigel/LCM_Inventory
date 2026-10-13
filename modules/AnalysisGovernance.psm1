<#
.SYNOPSIS
  Enforces read-only analysis gating, runtime state tracking, and circuit breaker protocol.
.DESCRIPTION
  Module: modules/AnalysisGovernance.psm1
  Purpose: Enforces RULE-ANA-001 through RULE-ANA-006: modal separation between
           READ_ONLY_ANALYSIS, GOVERNED_IMPLEMENTATION, and CIRCUIT_BREAKER_HALT.
  Path: LCM_Inventory/modules/AnalysisGovernance.psm1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LcmSessionStatePath {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  return (Join-Path $WorkspaceRoot 'LCM_Inventory\data\session_state\active_session.json')
}

function Get-LcmAnalysisState {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $path = Get-LcmSessionStatePath -WorkspaceRoot $WorkspaceRoot
  if (-not (Test-Path -LiteralPath $path)) {
    $parent = Split-Path -Path $path -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $initial = [ordered]@{
      updated_at      = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
      active_context  = $null
      operating_mode  = 'GOVERNED_IMPLEMENTATION'
      active_gate     = 'STEP_001'
      search_radius   = 2
      settled_facts   = @()
      open_hypotheses = @()
      circuit_breaker = $false
    }
    $json = ConvertTo-Json -InputObject $initial -Depth 5
    Set-Content -LiteralPath $path -Value $json -Encoding UTF8
    return (ConvertFrom-Json -InputObject $json)
  }

  $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  $data = ConvertFrom-Json -InputObject $raw

  # Ensure default properties exist
  $changed = $false
  if (-not ($data.PSObject.Properties.Name -contains 'operating_mode')) {
    $data | Add-Member -MemberType NoteProperty -Name 'operating_mode' -Value 'GOVERNED_IMPLEMENTATION'
    $changed = $true
  }
  if (-not ($data.PSObject.Properties.Name -contains 'active_gate')) {
    $data | Add-Member -MemberType NoteProperty -Name 'active_gate' -Value 'STEP_001'
    $changed = $true
  }
  if (-not ($data.PSObject.Properties.Name -contains 'search_radius')) {
    $data | Add-Member -MemberType NoteProperty -Name 'search_radius' -Value 2
    $changed = $true
  }
  if (-not ($data.PSObject.Properties.Name -contains 'settled_facts')) {
    $data | Add-Member -MemberType NoteProperty -Name 'settled_facts' -Value @()
    $changed = $true
  }
  if (-not ($data.PSObject.Properties.Name -contains 'open_hypotheses')) {
    $data | Add-Member -MemberType NoteProperty -Name 'open_hypotheses' -Value @()
    $changed = $true
  }
  if (-not ($data.PSObject.Properties.Name -contains 'circuit_breaker')) {
    $data | Add-Member -MemberType NoteProperty -Name 'circuit_breaker' -Value $false
    $changed = $true
  }

  if ($changed) {
    Set-LcmAnalysisState -State $data -WorkspaceRoot $WorkspaceRoot | Out-Null
  }

  return $data
}

function Set-LcmAnalysisState {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [psobject]$State,

    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $path = Get-LcmSessionStatePath -WorkspaceRoot $WorkspaceRoot
  $parent = Split-Path -Path $path -Parent
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  $now = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
  if ($State.PSObject.Properties.Name -contains 'updated_at') {
    $State.updated_at = $now
  } else {
    $State | Add-Member -MemberType NoteProperty -Name 'updated_at' -Value $now
  }

  $json = ConvertTo-Json -InputObject $State -Depth 5
  Set-Content -LiteralPath $path -Value $json -Encoding UTF8
  return $State
}

function Get-LcmOperatingMode {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $state = Get-LcmAnalysisState -WorkspaceRoot $WorkspaceRoot
  return [string]$state.operating_mode
}

function Set-LcmOperatingMode {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('READ_ONLY_ANALYSIS', 'GOVERNED_IMPLEMENTATION', 'CIRCUIT_BREAKER_HALT')]
    [string]$Mode,

    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $state = Get-LcmAnalysisState -WorkspaceRoot $WorkspaceRoot
  $state.operating_mode = $Mode
  if ($Mode -eq 'CIRCUIT_BREAKER_HALT') {
    $state.circuit_breaker = $true
  } elseif ($Mode -eq 'GOVERNED_IMPLEMENTATION') {
    $state.circuit_breaker = $false
  }
  Set-LcmAnalysisState -State $state -WorkspaceRoot $WorkspaceRoot | Out-Null
  return $Mode
}

function Assert-LcmImplementationAllowed {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $mode = Get-LcmOperatingMode -WorkspaceRoot $WorkspaceRoot
  if ($mode -eq 'READ_ONLY_ANALYSIS') {
    throw "GOVERNANCE BLOCK: Modifications and execution are disallowed while in READ_ONLY_ANALYSIS mode per RULE-ANA-001. Issue 'IMPLEMENT' to transition."
  }
  if ($mode -eq 'CIRCUIT_BREAKER_HALT') {
    throw "GOVERNANCE BLOCK: Circuit breaker is tripped (CIRCUIT_BREAKER_HALT) per RULE-ANA-005. Resolve block before proceeding."
  }
}

function Invoke-LcmCircuitBreaker {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Reason,

    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $state = Get-LcmAnalysisState -WorkspaceRoot $WorkspaceRoot
  $state.operating_mode = 'CIRCUIT_BREAKER_HALT'
  $state.circuit_breaker = $true
  Set-LcmAnalysisState -State $state -WorkspaceRoot $WorkspaceRoot | Out-Null

  Write-Warning ("CIRCUIT BREAKER TRIPPED: " + $Reason)
  return $state
}

function Reset-LcmCircuitBreaker {
  [CmdletBinding()]
  param(
    [string]$TargetMode = 'READ_ONLY_ANALYSIS',
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $state = Get-LcmAnalysisState -WorkspaceRoot $WorkspaceRoot
  $state.circuit_breaker = $false
  $state.operating_mode = $TargetMode
  Set-LcmAnalysisState -State $state -WorkspaceRoot $WorkspaceRoot | Out-Null
  return $state
}

Export-ModuleMember -Function @(
  'Get-LcmSessionStatePath',
  'Get-LcmAnalysisState',
  'Set-LcmAnalysisState',
  'Get-LcmOperatingMode',
  'Set-LcmOperatingMode',
  'Assert-LcmImplementationAllowed',
  'Invoke-LcmCircuitBreaker',
  'Reset-LcmCircuitBreaker'
)
