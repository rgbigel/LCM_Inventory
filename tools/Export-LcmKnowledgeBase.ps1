<#
.SYNOPSIS
    [DEPRECATED / ARCHIVED] Forwarding stub for Sync-LCMResearchSnapshot.ps1.
.DESCRIPTION
    Module: Export-LcmKnowledgeBase
    Purpose: Preserves backward compatibility by delegating invocations to the upgraded Sync-LCMResearchSnapshot.ps1.
             The original predecessor implementation is archived at LCM_Inventory/data/archives/legacy_tools/Export-LcmKnowledgeBase.ps1.
    Path: LCM_Inventory/tools/Export-LcmKnowledgeBase.ps1
    Authors: Rolf, Antigravity AI
    Version: 10.0.0-DEPRECATED
    Date: 2026-10-13
.PARAMETER DestinationPath
    Mapped to TargetRoot for backward compatibility.
.PARAMETER SourcePath
    Mapped to SourceRoot for backward compatibility.
.PARAMETER Force
    Forces full export.
.PARAMETER CleanOrphans
    Accepted for backward compatibility.
.PARAMETER LogFile
    Accepted for backward compatibility.
.PARAMETER Help
    Displays usage guidance.
#>
[CmdletBinding()]
param(
    [string]$DestinationPath = "",
    [string]$SourcePath = "",
    [switch]$Force,
    [bool]$CleanOrphans = $true,
    [string]$LogFile = "",
    [Alias('h', '?')][switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Warning "[DEPRECATED] Export-LcmKnowledgeBase.ps1 has been superseded by Sync-LCMResearchSnapshot.ps1."
Write-Warning "The legacy implementation is archived at: LCM_Inventory\data\archives\legacy_tools\Export-LcmKnowledgeBase.ps1"

$targetScript = Join-Path $PSScriptRoot "Sync-LCMResearchSnapshot.ps1"
if (-not (Test-Path $targetScript)) {
    $targetScript = "D:\Git_Repositories\LCM_Tools\Sync-LCMResearchSnapshot.ps1"
}

$forwardArgs = @{}
if ($DestinationPath) { $forwardArgs['TargetRoot'] = $DestinationPath }
if ($SourcePath) { $forwardArgs['SourceRoot'] = $SourcePath }
if ($Force) { $forwardArgs['Force'] = $true }
if ($Help) { $forwardArgs['Help'] = $true }

& $targetScript @forwardArgs
