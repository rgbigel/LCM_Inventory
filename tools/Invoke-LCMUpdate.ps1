<#
.SYNOPSIS
    Dispatches an LCM version upgrade to a target repository.

.DESCRIPTION
    Invokes Workspace_AI's LCM onboarding engine in Update mode, refreshing NTFS directory
    junctions, root agent instructions, and standard templates while preserving .lcm/overrides.json.
    Logs the update event to Workspace_Inventory's activity ledger.

.PARAMETER TargetRepository
    The name or full path of the target repository to update.

.PARAMETER DryRun
    Simulate the update without modifying files on disk.

.EXAMPLE
    .\tools\Invoke-LCMUpdate.ps1 -TargetRepository "VolumeInventory"
    .\tools\Invoke-LCMUpdate.ps1 -TargetRepository "VolumeInventory" -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$TargetRepository,
    
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cmModule = Join-Path $PSScriptRoot '..\modules\WorkspaceCM.psm1'
Import-Module $cmModule -Force

$wsRoot = Get-WorkspaceRoot
$targetPath = if (Test-Path $TargetRepository) {
    (Get-Item $TargetRepository).FullName
} else {
    Join-Path $wsRoot $TargetRepository
}

if (-not (Test-Path $targetPath)) {
    throw "Target repository path not found: $targetPath"
}

$repoName = (Get-Item $targetPath).Name
$onboardEngine = Join-Path $wsRoot 'Workspace_AI\tools\Invoke-LCMOnboardRepo.ps1'

if (-not (Test-Path $onboardEngine)) {
    throw "LCM Onboarding Engine not found at: $onboardEngine"
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Workspace_Inventory: Dispatching LCM Version Upgrade            " -ForegroundColor Cyan
Write-Host " Target Repository : $repoName" -ForegroundColor Cyan
Write-Host " Target Path       : $targetPath" -ForegroundColor Cyan
Write-Host " Mode              : $(if ($DryRun) { 'Dry-Run Simulation' } else { 'Live Update' })" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$params = @{
    TargetRepositoryPath = $targetPath
    Update = $true
}
if ($DryRun) {
    $params['DryRun'] = $true
}

& $onboardEngine @params

if (-not $DryRun) {
    Write-CMLog -Action 'LCM_UPDATE' -TargetRepo $repoName -Details "Upgraded to current LCM baseline version"
    Update-WorkspaceInventory -WorkspaceRoot $wsRoot | Out-Null
    Write-Host "`nUpdated CM Inventory for $repoName." -ForegroundColor Green
}
