<#
.SYNOPSIS
  Resolves authoritative LCM workspace context.
.DESCRIPTION
  Reads Git_Root only from the machine environment registry key and validates
  that the resolved workspace contains LCM_Inventory.
.NOTES
  Module: LCM_Context
  Path: LCM_Inventory/modules/LCM_Context.psm1
  Version: 10.2.0
  Date: 2026-10-13
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LcmMachineGitRoot {
  [CmdletBinding()]
  param()

  if (-not [string]::IsNullOrWhiteSpace($env:LCM_WORKSPACE_ROOT) -and (Test-Path -LiteralPath (Join-Path $env:LCM_WORKSPACE_ROOT 'LCM_Inventory'))) {
    return [System.IO.Path]::GetFullPath($env:LCM_WORKSPACE_ROOT).TrimEnd('\', '/')
  }
  if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\LCM_Inventory'))) {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  }

  $environmentKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
  if (-not (Test-Path -LiteralPath $environmentKey -PathType Container)) {
    throw "Machine environment registry key was not found: $environmentKey"
  }

  $gitRoot = Get-ItemPropertyValue -LiteralPath $environmentKey -Name 'Git_Root' -ErrorAction Stop
  if ([string]::IsNullOrWhiteSpace($gitRoot)) {
    throw 'Machine Git_Root is empty. Run Set-GitRoot from an elevated PowerShell session.'
  }

  $gitRoot = [System.IO.Path]::GetFullPath($gitRoot).TrimEnd('\', '/')
  if (-not [System.IO.Path]::IsPathRooted($gitRoot)) {
    throw "Machine Git_Root must be an absolute path: $gitRoot"
  }
  if (-not (Test-Path -LiteralPath $gitRoot -PathType Container)) {
    throw "Machine Git_Root directory does not exist: $gitRoot"
  }
  if (-not (Test-Path -LiteralPath (Join-Path $gitRoot 'LCM_Inventory') -PathType Container)) {
    throw "Machine Git_Root does not contain LCM_Inventory: $gitRoot"
  }

  return $gitRoot
}

Export-ModuleMember -Function Get-LcmMachineGitRoot
