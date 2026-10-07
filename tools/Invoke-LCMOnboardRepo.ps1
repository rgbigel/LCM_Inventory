<#
.SYNOPSIS
  CLI entry point for the 4-Phase Lifecycle Model (LCM) Repository Onboarding Engine.

.PARAMETER TargetRepositoryPath
  Path to target repository to onboard or update.

.PARAMETER Parameters
  Optional parameter overrides for onboarding templates.

.PARAMETER Update
  Refreshes and upgrades an already onboarded repository.

.PARAMETER StepByStep
  Pauses for operator confirmation between onboarding phases.

.PARAMETER DryRun
  Simulates onboarding actions without writing changes to disk.

.PARAMETER Force
  Overwrites existing files and junction points during onboarding.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Path to target repository to onboard or update.')]
  [string]$TargetRepositoryPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Optional parameter overrides for onboarding templates.')]
  [hashtable]$Parameters = @{},

  [Parameter(Mandatory = $false, HelpMessage = 'Refreshes and upgrades an already onboarded repository.')]
  [switch]$Update,

  [Parameter(Mandatory = $false, HelpMessage = 'Pauses for operator confirmation between onboarding phases.')]
  [switch]$StepByStep,

  [Parameter(Mandatory = $false, HelpMessage = 'Simulates onboarding actions without writing changes to disk.')]
  [switch]$DryRun,

  [Parameter(Mandatory = $false, HelpMessage = 'Overwrites existing files and junction points during onboarding.')]
  [switch]$Force,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Invoke-LCMOnboardRepo.ps1 - 4-Phase Lifecycle Model Repository Onboarding Engine." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Invoke-LCMOnboardRepo.ps1 [-TargetRepositoryPath <path>] [-Update] [-StepByStep] [-DryRun] [-Force] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -TargetRepositoryPath Path to repository to onboard or update."
  Write-Host "  -Parameters           Optional hashtable overrides."
  Write-Host "  -Update               Refresh/upgrade an existing onboarded repo."
  Write-Host "  -StepByStep           Prompt before each onboarding phase."
  Write-Host "  -DryRun               Preview changes without writing."
  Write-Host "  -Force                Overwrite existing files and links."
  Write-Host "  -Help (-h, -?)        Displays this help message."
  exit 0
}

if (-not $TargetRepositoryPath) {
  throw "Parameter -TargetRepositoryPath is required."
}

<#
Module: Invoke-LCMOnboardRepo.ps1
Purpose: CLI entry point for the 4-Phase Lifecycle Model (LCM) Repository Onboarding Engine.
Path: tools/Invoke-LCMOnboardRepo.ps1
Authors: Rolf, LCM_AI Engine
Version: 1.1.0
Changelog:
- 2026-08-15: Added -Update switch for refreshing/upgrading already onboarded repositories.
- 2026-08-15: Initial CLI wrapper for LCMOnboarding module.
#>

$modulePath = Join-Path $PSScriptRoot 'Onboarding\LCMOnboarding.psd1'
Import-Module $modulePath -Force

Invoke-LCMOnboardRepo -TargetRepositoryPath $TargetRepositoryPath -Parameters $Parameters -Update:$Update -StepByStep:$StepByStep -DryRun:$DryRun -Force:$Force
