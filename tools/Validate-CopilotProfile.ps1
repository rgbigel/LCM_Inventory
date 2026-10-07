<#
.SYNOPSIS
  Validate the active LCM_AI .copilot profile structure.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Validate-CopilotProfile.ps1 - Validate active .copilot profile structure." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Validate-CopilotProfile.ps1 [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -Help (-h, -?) Displays this help message."
  exit 0
}

<#
Module: Validate-CopilotProfile.ps1
Purpose: Validate the active LCM_AI .copilot profile structure.
Path: tools/Validate-CopilotProfile.ps1
Authors: LCM_AI Engine
Version: 4.1.0
Caller Contract: Called from the LCM_AI repository root or tools folder; performs read-only file existence and version checks.
Changelog:
- 2026-08-15: Bumped to LCM pre-release Version 4.1.0.
- 2026-08-12: Replaced parent-level profile validation with LCM_AI-local profile validation.
#>

$workspaceRoot = Split-Path $PSScriptRoot -Parent
$copilotRoot = Join-Path $workspaceRoot '.copilot'

$requiredFiles = @(
    'instructions.md',
    'MEMORY.md',
    'CopilotRules.md',
    'CopilotTools.md',
    'VSCode_Agent.md',
    'problems.md',
    'Rules/RuleAuthority.md',
    'Rules/InvariantRules.md',
    'Rules/PowerShellRules.md',
    'Rules/CMDRules.md',
    'Rules/JsonRules.md',
    'Rules/macro-definitions.md'
)

Write-Host 'COPILOT VALIDATION -- WORKSPACE_AI'
Write-Host 'version: 4.1.0'
Write-Host ''

Write-Host 'CHECK: profile file presence'
$missingFiles = @()
foreach ($requiredFile in $requiredFiles) {
    $requiredPath = Join-Path $copilotRoot $requiredFile
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        $missingFiles += $requiredFile
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host 'RESULT: FAIL'
    Write-Host 'Missing files:'
    foreach ($missingFile in $missingFiles) {
        Write-Host ('- {0}' -f $missingFile)
    }
    exit 1
}
Write-Host 'RESULT: PASS'
Write-Host ''

Write-Host 'CHECK: version markers'
$missingVersionFiles = @()
foreach ($requiredFile in $requiredFiles) {
    $requiredPath = Join-Path $copilotRoot $requiredFile
    $content = Get-Content -Raw -Path $requiredPath
    if ($content -notmatch '(?im)(^Version:\s*|^# version:\s*|"version"\s*:)') {
        $missingVersionFiles += $requiredFile
    }
}

if ($missingVersionFiles.Count -gt 0) {
    Write-Host 'RESULT: FAIL'
    Write-Host 'Missing version marker:'
    foreach ($missingVersionFile in $missingVersionFiles) {
        Write-Host ('- {0}' -f $missingVersionFile)
    }
    exit 1
}
Write-Host 'RESULT: PASS'
Write-Host ''

Write-Host 'CHECK: workspace-location'
$expectedRoot = 'D:\Git_Repositories\LCM_AI\.copilot'
if (-not ([System.IO.Path]::GetFullPath($copilotRoot).TrimEnd('\').Equals($expectedRoot, [System.StringComparison]::OrdinalIgnoreCase))) {
    Write-Host 'RESULT: FAIL'
    Write-Host ('Expected: {0}' -f $expectedRoot)
    Write-Host ('Actual: {0}' -f $copilotRoot)
    exit 1
}
Write-Host 'RESULT: PASS'
Write-Host ''
Write-Host 'FINAL RESULT: PASS'
