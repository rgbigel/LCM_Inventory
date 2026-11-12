<#
Module: RepoQualityGates.psm1
Purpose: Backward-compatibility shim forwarding to LCM_QualityGates.psm1
Path: tools/QualityGates/RepoQualityGates.psm1
Authors: LCM Governance
Version: 10.2.1
Date: 2026-11-12
#>

$canonicalModule = Join-Path $PSScriptRoot 'LCM_QualityGates.psm1'
if (Test-Path -LiteralPath $canonicalModule) {
  . $canonicalModule
}
else {
  throw "Cannot locate canonical module: $canonicalModule"
}

