<#
.SYNOPSIS
  Enables or disables hidden ADMINMODE for the current administrator.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('On', 'Off')]
  [string]$Mode,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Usage: pwsh tools\Make-Admin.ps1 -Mode <On|Off>'
  return
}

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $workspaceRoot 'modules\AdminMode.psm1'
Import-Module -Name $modulePath -Force
$actor = Get-AdminModeActor
$state = Set-AdminMode -Enabled ($Mode -eq 'On') -WorkspaceRoot (Split-Path $workspaceRoot -Parent)
if ($actor.IsAdministrator) {
  Write-Host ('ADMINMODE set to {0}.' -f $state.enabled)
}
