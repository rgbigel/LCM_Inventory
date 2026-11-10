[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Optional CRP/BUG identity, repository, or declared cohort')]
  [string]$Scope = '',

  [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Optional baseline commit')]
  [string]$BaseCommit = 'HEAD',

  [Parameter(Mandatory = $false, HelpMessage = 'Resolve and display the BCR cohort without launching review')]
  [switch]$Preview,

  [Parameter(Mandatory = $false, HelpMessage = 'Confirm an omitted or broadened cohort')]
  [switch]$Confirm,

  [Alias('h', '?')]
  [switch]$Help
)

<#
.SYNOPSIS
  Resolves and dispatches an LCM Beyond Compare review cohort.
.DESCRIPTION
  Module: tools/Invoke-BcrDispatcher.ps1
  Purpose: Provides BCR scope defaulting and confirmation while delegating lifecycle
           validation and review launching to Invoke-ProposalAction.ps1.
  Path: tools/Invoke-BcrDispatcher.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-10-13
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Usage: BCR [CRP-ID|BUG-ID|repo|cohort] [commit] [-Preview] [-Confirm]' -ForegroundColor Yellow
  return
}

$actionPath = Join-Path $PSScriptRoot 'Invoke-ProposalAction.ps1'
$arguments = @{
  Action = 'bcr'
  TargetExpression = $Scope
  BaseCommit = $BaseCommit
}

if ($Preview) {
  $arguments.Preview = $true
  & $actionPath @arguments
  return
}

if (-not $Confirm -and [string]::IsNullOrWhiteSpace($Scope)) {
  if (-not [Environment]::UserInteractive) {
    throw 'An omitted BCR scope requires interactive confirmation. Use -Preview, select a scope, or re-run with -Confirm.'
  }
  & $actionPath @arguments -Preview
  $response = Read-Host 'Launch the resolved BCR cohort? [y/N]'
  if ($response -notmatch '^(?i)y(?:es)?$') {
    throw 'BCR cohort launch was cancelled by the operator.'
  }
  $Confirm = $true
}

if ($Confirm) {
  $arguments.Confirm = $true
}
& $actionPath @arguments
