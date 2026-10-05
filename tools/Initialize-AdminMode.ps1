<#
.SYNOPSIS
  Initializes hidden ADMINMODE for the current workspace user.
#>
[CmdletBinding()]
param(
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Initialize-AdminMode.ps1 initializes ADMINMODE from Windows local Administrators membership.'
  return
}

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $workspaceRoot 'modules\AdminMode.psm1'
Import-Module -Name $modulePath -Force
Initialize-AdminMode -WorkspaceRoot (Split-Path $workspaceRoot -Parent) | Out-Null
