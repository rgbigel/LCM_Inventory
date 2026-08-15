<#
.SYNOPSIS
    Captures a full configuration baseline snapshot of all workspace repositories.

.PARAMETER BaselineId
    Identifier for the baseline (e.g. BASELINE-v4.1.0-20260815).

.PARAMETER Description
    Human-readable description of the baseline event.

.EXAMPLE
    .\tools\New-WorkspaceBaseline.ps1 -BaselineId "BASELINE-v4.1.0"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$BaselineId,
    
    [string]$Description
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cmModule = Join-Path $PSScriptRoot '..\modules\WorkspaceCM.psm1'
Import-Module $cmModule -Force

if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = "Baseline snapshot $BaselineId created on $((Get-Date).ToString('yyyy-MM-dd'))"
}

New-WorkspaceBaseline -BaselineId $BaselineId -Description $Description
