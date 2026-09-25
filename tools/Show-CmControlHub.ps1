<#
.SYNOPSIS
    Compatibility forwarder for Show-LcmControl.
.DESCRIPTION
    Module: tools/Show-CmControlHub.ps1
    Note: Show-CmControlHub has been unified into Show-LcmControl.
          This forwarder guarantees 100% backward compatibility for all existing scripts and callers.
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$RemainingArgs
)

$scriptDir = Split-Path -Parent $PSCommandPath
$unifiedTool = Join-Path $scriptDir "Show-LcmControl.ps1"

if (-not (Test-Path -LiteralPath $unifiedTool)) {
    throw "Unified tool not found at: $unifiedTool"
}

& pwsh -NoProfile -ExecutionPolicy Bypass -File $unifiedTool @RemainingArgs
