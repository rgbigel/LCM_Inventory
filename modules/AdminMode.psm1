<#
Module: AdminMode.psm1
Purpose: Provides non-elevation administrator authorization for governed rule changes.
Path: modules/AdminMode.psm1
Authors: Rolf, LCM_AI Engine
Version: 1.0.0
Date: 2026-10-05
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AdministratorsSid = 'S-1-5-32-544'

function Get-AdminModeWorkspaceRoot {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  return [System.IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
}

function Get-AdminModeStatePath {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  return Join-Path (Get-AdminModeWorkspaceRoot -WorkspaceRoot $WorkspaceRoot) 'LCM_Inventory\data\adminmode.json'
}

function Get-AdminModeActor {
  [CmdletBinding()]
  param()

  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $groupSids = @($identity.Groups | ForEach-Object { $_.Value })
  $isAdministrator = $groupSids -contains $script:AdministratorsSid
  if (-not $isAdministrator) {
    $groupOutput = @(& whoami /groups /fo csv /nh 2>$null)
    $isAdministrator = @($groupOutput -match [regex]::Escape($script:AdministratorsSid)).Count -gt 0
  }

  return [pscustomobject]@{
    User = $identity.Name
    Sid = $identity.User.Value
    IsAdministrator = $isAdministrator
  }
}

function Write-AdminModeAudit {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$Details,

    [string]$CRP = '',

    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $actor = Get-AdminModeActor
  $root = Get-AdminModeWorkspaceRoot -WorkspaceRoot $WorkspaceRoot
  $logDirectory = Join-Path $root 'LCM_Inventory\logs'
  $null = New-Item -ItemType Directory -Path $logDirectory -Force
  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $crpLabel = if ([string]::IsNullOrWhiteSpace($CRP)) { '-' } else { $CRP }
  $entry = '[{0}] [ADMINMODE] [Action: {1}] [User: {2}] [SID: {3}] [CRP: {4}] {5}' -f $timestamp, $Action, $actor.User, $actor.Sid, $crpLabel, $Details
  Add-Content -LiteralPath (Join-Path $logDirectory 'cm_activity.log') -Value $entry -Encoding utf8
}

function Get-AdminModeState {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $statePath = Get-AdminModeStatePath -WorkspaceRoot $WorkspaceRoot
  if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    return $null
  }

  return Get-Content -LiteralPath $statePath -Raw -Encoding utf8 | ConvertFrom-Json
}

function Initialize-AdminMode {
  [CmdletBinding()]
  param(
    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $root = Get-AdminModeWorkspaceRoot -WorkspaceRoot $WorkspaceRoot
  $actor = Get-AdminModeActor
  $state = [ordered]@{
    schema_version = '1.0'
    enabled = [bool]$actor.IsAdministrator
    actor_user = $actor.User
    actor_sid = $actor.Sid
    initialized_at = (Get-Date).ToString('o')
    authorization_source = 'Windows local Administrators SID S-1-5-32-544'
    elevated_process_required = $false
  }
  $statePath = Get-AdminModeStatePath -WorkspaceRoot $root
  $null = New-Item -ItemType Directory -Path (Split-Path $statePath -Parent) -Force
  [System.IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json -Depth 3) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
  Write-AdminModeAudit -Action 'ADMINMODE_INITIALIZED' -Details ('Enabled={0}; administrator_membership={1}.' -f $state.enabled, $actor.IsAdministrator) -WorkspaceRoot $root
  return [pscustomobject]$state
}

function Set-AdminMode {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [bool]$Enabled,

    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $root = Get-AdminModeWorkspaceRoot -WorkspaceRoot $WorkspaceRoot
  $actor = Get-AdminModeActor
  if (-not $actor.IsAdministrator) {
    Write-AdminModeAudit -Action 'ADMINMODE_DENIED' -Details ('Requested enabled={0}; state unchanged.' -f $Enabled) -WorkspaceRoot $root
    return Get-AdminModeState -WorkspaceRoot $root
  }

  $state = [ordered]@{
    schema_version = '1.0'
    enabled = $Enabled
    actor_user = $actor.User
    actor_sid = $actor.Sid
    initialized_at = (Get-Date).ToString('o')
    authorization_source = 'Windows local Administrators SID S-1-5-32-544'
    elevated_process_required = $false
  }
  $statePath = Get-AdminModeStatePath -WorkspaceRoot $root
  $null = New-Item -ItemType Directory -Path (Split-Path $statePath -Parent) -Force
  [System.IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json -Depth 3) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
  Write-AdminModeAudit -Action 'ADMINMODE_SET' -Details ('Enabled={0}.' -f $Enabled) -WorkspaceRoot $root
  return [pscustomobject]$state
}

function Get-RuleChangePaths {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths
  )

  return @($Paths | Where-Object {
      $_ -match '(^|[\\/])\.agents[\\/]rules([\\/]|$)' -or
      $_ -match '(^|[\\/])\.copilot[\\/]Rules([\\/]|$)'
    })
}

function Assert-AdminModeForRuleChange {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,

    [string]$CRP = '',

    [string]$WorkspaceRoot = 'D:\Git_Repositories'
  )

  $rulePaths = Get-RuleChangePaths -Paths $Paths
  if ($rulePaths.Count -eq 0) {
    return
  }

  $root = Get-AdminModeWorkspaceRoot -WorkspaceRoot $WorkspaceRoot
  $actor = Get-AdminModeActor
  $state = Get-AdminModeState -WorkspaceRoot $root
  $isEnabledForActor = $null -ne $state -and
    $state.enabled -eq $true -and
    $state.actor_sid -eq $actor.Sid -and
    $actor.IsAdministrator
  $details = 'Rule paths: {0}. ADMINMODE enabled for actor: {1}.' -f ($rulePaths -join ', '), $isEnabledForActor
  if (-not $isEnabledForActor) {
    Write-AdminModeAudit -Action 'RULE_CHANGE_DENIED' -Details $details -CRP $CRP -WorkspaceRoot $root
    throw 'Rule changes require ADMINMODE enabled for the current Windows local Administrators member.'
  }

  Write-AdminModeAudit -Action 'RULE_CHANGE_AUTHORIZED' -Details $details -CRP $CRP -WorkspaceRoot $root
}

Export-ModuleMember -Function @(
  'Get-AdminModeActor',
  'Get-AdminModeState',
  'Initialize-AdminMode',
  'Set-AdminMode',
  'Get-RuleChangePaths',
  'Assert-AdminModeForRuleChange'
)
