<#
.SYNOPSIS
  Discover sibling Git repositories read-only for LCM_AI stabilization checks.

.PARAMETER WorkspaceParent
  Parent directory containing workspace repositories.

.PARAMETER ActiveRepository
  Path to currently active repository to optionally exclude.

.PARAMETER IncludeActiveRepository
  Include active repository in discovery results.

.PARAMETER AsJson
  Output discovered repositories as JSON.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Parent directory containing workspace repositories.')]
  [string]$WorkspaceParent = 'D:\Git_Repositories',

  [Parameter(Mandatory = $false, HelpMessage = 'Path to currently active repository to optionally exclude.')]
  [string]$ActiveRepository = 'D:\Git_Repositories\LCM_AI',

  [Parameter(Mandatory = $false, HelpMessage = 'Include active repository in discovery results.')]
  [switch]$IncludeActiveRepository,

  [Parameter(Mandatory = $false, HelpMessage = 'Output discovered repositories as JSON.')]
  [switch]$AsJson,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Get-WorkspaceRepositories.ps1 - Discover sibling Git repositories." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Get-WorkspaceRepositories.ps1 [-WorkspaceParent <path>] [-ActiveRepository <path>] [-IncludeActiveRepository] [-AsJson] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -WorkspaceParent          Parent folder (default: D:\Git_Repositories)."
  Write-Host "  -ActiveRepository         Active repository path."
  Write-Host "  -IncludeActiveRepository  Include the active repo in results."
  Write-Host "  -AsJson                   Output as JSON."
  Write-Host "  -Help                     (-h, -?) Displays this help message."
  exit 0
}

<#
Module: Get-WorkspaceRepositories.ps1
Purpose: Discover sibling Git repositories read-only for LCM_AI stabilization checks.
Path: tools/Get-WorkspaceRepositories.ps1
Authors: LCM_AI Engine
Version: 1.0.0
Caller Contract: Called during LCM_AI stabilization; returns direct child directories with .git folders without modifying them.
Changelog:
- 2026-08-01: Added read-only sibling repository discovery command.
#>

if (-not (Test-Path -LiteralPath $WorkspaceParent)) {
  throw "Workspace parent not found: $WorkspaceParent"
}

$activeRepositoryPath = [System.IO.Path]::GetFullPath($ActiveRepository).TrimEnd('\')
$repositories = Get-ChildItem -Path $WorkspaceParent -Directory | Where-Object {
  $candidate = $_
  Test-Path -LiteralPath (Join-Path $candidate.FullName '.git')
} | Where-Object {
  $candidate = $_
  $candidatePath = [System.IO.Path]::GetFullPath($candidate.FullName).TrimEnd('\')
  $IncludeActiveRepository -or -not $candidatePath.Equals($activeRepositoryPath, [System.StringComparison]::OrdinalIgnoreCase)
} | Sort-Object -Property FullName | ForEach-Object {
  $repository = $_
  [pscustomobject]@{
    Name = $repository.Name
    Path = $repository.FullName
  }
}

if ($AsJson) {
  $repositories | ConvertTo-Json -Depth 4
} else {
  $repositories
}