<#
.SYNOPSIS
  Validate that loaded LCM_AI rule sets are present and non-empty.

.PARAMETER rules
  Hashtable of rule sets returned by LoadRules.ps1.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Hashtable of rule sets returned by LoadRules.ps1.')]
  [hashtable]$rules,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "ValidateRules.ps1 - Validate loaded rule sets are present and non-empty." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File ValidateRules.ps1 [-rules <hashtable>] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -rules Hashtable of rule sets."
  Write-Host "  -Help  (-h, -?) Displays this help message."
  exit 0
}

<#
Module: ValidateRules.ps1
Purpose: Validate that loaded LCM_AI rule sets are present and non-empty.
Path: tools/ValidateRules.ps1
Authors: LCM_AI Engine
Version: 1.0.0
Caller Contract: Called with a hashtable returned by LoadRules.ps1; throws on missing or empty rule sets.
Changelog:
- 2026-08-12: Added standard LCM_AI script header.
#>

foreach ($key in $rules.Keys) {
    if (-not $rules[$key] -or $rules[$key].Count -eq 0) {
        throw "Rule set '$key' is empty or missing."
    }
}

"OK"
