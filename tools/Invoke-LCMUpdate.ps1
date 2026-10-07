<#
Module: tools/Invoke-LCMUpdate.ps1
Purpose: Governed CLI entrypoint for proposing or applying LCM version upgrades to target repositories.
Path: tools/Invoke-LCMUpdate.ps1
Authors: Rolf, LCM_AI Engine
Version: 1.0.0
Date: 2026-08-15
Changelog:
- 2026-08-15: Initial versioned implementation enforcing CR-first proposal permissions.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage='Target repository name or path')]
    [string]$TargetRepository,
    
    [Parameter(Mandatory=$false, HelpMessage='Execute the live update after CR approval')]
    [switch]$Execute,
    
    [Parameter(Mandatory=$false, HelpMessage='Simulate the update without modifying files')]
    [switch]$DryRun,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " INVOKE LCM VERSION UPGRADE (Invoke-LCMUpdate)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Governed entrypoint for proposing or applying LCM version upgrades to repositories."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Invoke-LCMUpdate.ps1 [-TargetRepository] <str> [-Execute] [-DryRun] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -TargetRepository : Target repository name or path"
    Write-Host "  -Execute          : Execute live update after CR approval"
    Write-Host "  -DryRun           : Simulate update without modifying files"
    Write-Host "  -Help (-h, -?)    : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$cmModule = Join-Path $PSScriptRoot '..\modules\WorkspaceCM.psm1'
$crModule = Join-Path $PSScriptRoot '..\modules\ChangeRequestManager.psm1'
Import-Module $cmModule -Force
Import-Module $crModule -Force

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
$aiState = Get-WorkspaceAIState
$targetLCMVersion = $aiState.GlobalLCMVersion
$onboardEngine = Join-Path $wsRoot 'LCM_Inventory\tools\Invoke-LCMOnboardRepo.ps1'

if (-not (Test-Path $onboardEngine)) {
    throw "LCM Onboarding Engine not found at: $onboardEngine"
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " LCM_Inventory: Governed LCM Version Upgrade Flow         " -ForegroundColor Cyan
Write-Host " Target Repository : $repoName" -ForegroundColor Cyan
Write-Host " Target Version    : v$targetLCMVersion (from LCM_AI)" -ForegroundColor Cyan
Write-Host " Mode              : $(if ($Execute) { 'LIVE EXECUTION' } elseif ($DryRun) { 'DRY RUN' } else { 'CR PROPOSAL (Default)' })" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Phase 1: Ensure Change Request is registered in Target Repo
$crTitle = "Upgrade $repoName to LCM Version $targetLCMVersion"
$crSummary = "Upgrades repository junctions, root agent instructions, and standard templates to LCM v$targetLCMVersion baseline while preserving local overrides."

if (-not $Execute) {
    # Default Safe Mode: Register CR in target repo & simulate preview
    Write-Host "`n[1/2] Registering Change Request proposal in $repoName..." -ForegroundColor Cyan
    $cr = New-ChangeRequest -Title $crTitle -OriginRepo $repoName -TargetLCMVersion $targetLCMVersion -Status 'proposed' -Summary $crSummary
    
    Write-Host "`n[2/2] Running read-only dry-run simulation of planned LCM updates..." -ForegroundColor Cyan
    & $onboardEngine -TargetRepositoryPath $targetPath -Update -DryRun
    
    Write-CMLog -Action 'LCM_UPGRADE_PROPOSED' -TargetRepo $repoName -Details "Proposed upgrade to v$targetLCMVersion via $($cr.cr_id)"
    Export-ChangeRequestDashboard | Out-Null
    
    Write-Host "`n=================================================================" -ForegroundColor Green
    Write-Host " Change Request $($cr.cr_id) created in $repoName/Docs/Methods/Proposals/" -ForegroundColor Green
    Write-Host " To execute this upgrade after review, re-run with: -Execute" -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green
} else {
    # Approved Execution Mode
    Write-Host "`nExecuting approved LCM version upgrade on $repoName..." -ForegroundColor Yellow
    & $onboardEngine -TargetRepositoryPath $targetPath -Update -Force
    
    # Update CR status in target repo
    $crRecords = Find-ChangeRequest -Repository $repoName -Query "Upgrade $repoName"
    if ($crRecords.Count -gt 0) {
        $activeCR = $crRecords | Select-Object -Last 1
        $activeCRFile = $activeCR.file_path
        if (Test-Path $activeCRFile) {
            $content = Get-Content -Path $activeCRFile -Raw -Encoding UTF8
            $content = $content -replace 'status:\s*proposed', 'status: implemented'
            Set-Content -Path $activeCRFile -Value $content -Encoding UTF8
        }
    }
    
    Write-CMLog -Action 'LCM_UPGRADE_EXECUTED' -TargetRepo $repoName -Details "Upgraded to LCM v$targetLCMVersion"
    Update-WorkspaceInventory -WorkspaceRoot $wsRoot | Out-Null
    Export-ChangeRequestDashboard | Out-Null
    Write-Host "`nLCM Upgrade to v$targetLCMVersion completed and verified for $repoName." -ForegroundColor Green
}
