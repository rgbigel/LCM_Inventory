<#
.SYNOPSIS
  Direct alias for Export-LCMRules.ps1.
.DESCRIPTION
  Module: Save-LCMRules
  Purpose: Consolidates and exports LCM rules and governance files to markdown and clipboard.
  Path: tools/Save-LCMRules.ps1
  Authors: Rolf, LCM_AI Governance
  Version: 10.2.0
  Date: 2026-10-13
#>

[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true, HelpMessage = 'Arguments forwarded directly to Export-LCMRules.ps1')]
  $Arguments,

  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  & (Join-Path $PSScriptRoot 'Export-LCMRules.ps1') -Help
  return
}

& (Join-Path $PSScriptRoot 'Export-LCMRules.ps1') @Arguments
