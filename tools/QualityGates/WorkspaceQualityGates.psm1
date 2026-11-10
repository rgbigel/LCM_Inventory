<#
Module: WorkspaceQualityGates.psm1
Purpose: Backward-compatibility shim forwarding to LCM_QualityGates.psm1
Path: tools/QualityGates/WorkspaceQualityGates.psm1
Authors: LCM Governance
Version: 10.2.0
Changelog:
- 2026-11-06: Forwarding shim to LCM_QualityGates.psm1.
#>

$canonicalModule = Join-Path $PSScriptRoot 'LCM_QualityGates.psm1'
if (Test-Path -LiteralPath $canonicalModule) {
  . $canonicalModule
}
else {
  throw "Cannot locate canonical module: $canonicalModule"
}

