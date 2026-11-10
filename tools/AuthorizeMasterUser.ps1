<#
.SYNOPSIS
  Root workspace wrapper for AuthorizeMasterUser Quad-Principal security engine.
.DESCRIPTION
  Module: AuthorizeMasterUser Wrapper
  Path: D:\Git_Repositories\LCM_Tools\AuthorizeMasterUser.ps1
  Authors: Rolf, LCM_AI Governance
  Version: 10.2.0
  Date: 2026-10-13
#>

[CmdletBinding()]
param(
  [Parameter(Position = 0, HelpMessage = 'Target volume drive letter (e.g. D:)')]
  [string]$Volume = 'D:',

  [Parameter(HelpMessage = 'Process all discovered volumes')]
  [switch]$All,

  [Parameter(HelpMessage = 'List of top-level folder names to skip')]
  [string[]]$SkipFolders = @(),

  [Parameter(HelpMessage = 'Simulate authorization checks without modifying ACL permissions')]
  [Alias('WhatIf')]
  [switch]$DryRun,

  [Parameter(HelpMessage = 'Display verbose diagnostic output to terminal')]
  [switch]$ShowAll,

  [Parameter(HelpMessage = 'Custom log file destination path')]
  [string]$LogFile = "",

  [Parameter(HelpMessage = 'Suppress automatic UAC elevation check')]
  [switch]$NoElevation,

  [Alias('h', '?')]
  [switch]$Help
)

$canonicalScript = "D:\Git_Repositories\AuthorizeMasterUser\Source\AuthorizeMasterUser.ps1"
if (-not (Test-Path -LiteralPath $canonicalScript)) {
  Write-Error "Canonical script not found: $canonicalScript"
  return
}

& $canonicalScript @PSBoundParameters
