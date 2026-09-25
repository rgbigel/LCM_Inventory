<#
.SYNOPSIS
    Compatibility forwarder for Show-LcmControl in Dates mode.
.DESCRIPTION
    Module: tools/Show-CrpDates.ps1
    Note: Show-CrpDates has been unified into Show-LcmControl.
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

$hasDatesSwitch = $false
$hasCliSwitch = $false
foreach ($arg in $RemainingArgs) {
    if ($arg -match '(?i)^-(?:Dates|DatesMode)$') { $hasDatesSwitch = $true }
    if ($arg -match '(?i)^-(?:Cli|Text|NoBrowser)$') { $hasCliSwitch = $true }
}

$forwardArgs = @()
if (-not $hasDatesSwitch -and -not $hasCliSwitch) {
    $forwardArgs += "-Dates"
}
$forwardArgs += $RemainingArgs

& pwsh -NoProfile -ExecutionPolicy Bypass -File $unifiedTool @forwardArgs
