[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$WorkspaceRoot = 'D:\Git_Repositories',

  [Parameter(Mandatory = $false)]
  [string]$MetadataPath,

  [switch]$AsJson,

  [Alias('h', '?')]
  [switch]$Help
)

<#
.SYNOPSIS
    Displays Inventory-owned, read-only workspace repository facts.
.DESCRIPTION
    Module: Show-Repos.ps1
    Purpose: Discovers workspace repositories and optionally applies user metadata from a
             JSON overlay without modifying repository state.
    Path: tools/Show-Repos.ps1
    Authors: Rolf, GitHub Copilot
    Version: 1.0.0
    Date: 2026-09-29
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Get-Help -LiteralPath $PSCommandPath -Detailed
  return
}

$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\RepositoryIndexManager.psm1'
Import-Module -Name $modulePath -Force
$parameters = @{ WorkspaceRoot = $WorkspaceRoot }
if (-not [string]::IsNullOrWhiteSpace($MetadataPath)) {
  $parameters.MetadataPath = $MetadataPath
}
$repository = @(Get-RepositoryIndex @parameters)
if ($AsJson) {
  $repository | ConvertTo-Json -Depth 6
}
else {
  Format-RepositoryIndex -Repository $repository | Format-Table -AutoSize
}