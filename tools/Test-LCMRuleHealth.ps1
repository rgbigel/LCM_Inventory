<#
.SYNOPSIS
    Diagnoses LCM rule health, junction validity, static rule duplicates, and version alignment across repositories.
.DESCRIPTION
    Module: tools/Test-LCMRuleHealth.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.0.0
    Date: 2026-08-20
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$TargetRepository,

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$canonicalRulesDir = Join-Path $WorkspaceRoot '.agents\rules'

# Read global LCM baseline
$globalVersion = '4.3.0'
$reqDoc = Join-Path $WorkspaceRoot 'Workspace_AI\docs\Requirements.md'
if (Test-Path $reqDoc) {
    $match = Select-String -Path $reqDoc -Pattern '^Version:\s*(\S+)' | Select-Object -First 1
    if ($match -and $match.Matches.Groups.Count -gt 1) {
        $globalVersion = $match.Matches.Groups[1].Value
    }
}

$childDirs = @(Get-ChildItem -Path $WorkspaceRoot -Directory | Where-Object {
    $_.Name -notmatch '^\.' -and
    (Test-Path (Join-Path $_.FullName '.git'))
})

if (-not [string]::IsNullOrWhiteSpace($TargetRepository)) {
    $childDirs = @($childDirs | Where-Object { $_.Name -like "*$TargetRepository*" })
}

$results = @()

foreach ($dir in $childDirs) {
    $repoName = $dir.Name
    $repoPath = $dir.FullName
    
    # 1. Inspect .agents/rules
    $agentRulesPath = Join-Path $repoPath '.agents\rules'
    $junctionState = 'Missing'
    $junctionTarget = '-'
    $isJunction = $false
    $duplicateCount = 0
    
    if (Test-Path -LiteralPath $agentRulesPath) {
        $item = Get-Item -LiteralPath $agentRulesPath -Force
        if ($item.LinkType -eq 'Junction' -or $item.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
            $isJunction = $true
            $target = $item.Target
            if ($target) {
                $targetStr = [string]$target
                if ($targetStr -eq $canonicalRulesDir -or $targetStr -eq (Get-Item $canonicalRulesDir).FullName) {
                    $junctionState = 'Junction Valid'
                    $junctionTarget = 'Canonical Hub'
                } else {
                    $junctionState = 'Junction Invalid Target'
                    $junctionTarget = $targetStr
                }
            } else {
                $junctionState = 'Junction Valid'
                $junctionTarget = 'Canonical Hub'
            }
        } else {
            $isJunction = $false
            $junctionState = 'Physical Folder'
            $files = @(Get-ChildItem -Path $agentRulesPath -File -Recurse -ErrorAction SilentlyContinue)
            $duplicateCount = $files.Count
        }
    }
    
    # 2. Inspect Legacy Residue
    $copilotRulesPath = Join-Path $repoPath '.copilot\Rules'
    $hasLegacyResidue = (Test-Path -LiteralPath $copilotRulesPath)
    
    # 3. Inspect .lcm/config.json
    $cfgPath = Join-Path $repoPath '.lcm\config.json'
    $absorbedVersion = '-'
    $versionAligned = $false
    
    if (Test-Path -LiteralPath $cfgPath) {
        try {
            $cfg = Get-Content -Path $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $gov = if ($cfg.PSObject.Properties['governance']) { $cfg.governance } else { $null }
            
            if ($cfg.PSObject.Properties['absorbed_lcm_version']) {
                $absorbedVersion = [string]$cfg.absorbed_lcm_version
            } elseif ($cfg.PSObject.Properties['current_lcm_version']) {
                $absorbedVersion = [string]$cfg.current_lcm_version
            } elseif ($gov -and $gov.PSObject.Properties['absorbed_lcm_version']) {
                $absorbedVersion = [string]$gov.absorbed_lcm_version
            } elseif ($gov -and $gov.PSObject.Properties['lcm_version']) {
                $absorbedVersion = [string]$gov.lcm_version
            } elseif ($cfg.PSObject.Properties['lcm_version']) {
                $absorbedVersion = [string]$cfg.lcm_version
            } else {
                $absorbedVersion = 'Unspecified'
            }

            if ($absorbedVersion -eq $globalVersion) {
                $versionAligned = $true
            }
        } catch {
            $absorbedVersion = 'Invalid JSON'
        }
    } else {
        $absorbedVersion = 'Missing .lcm'
    }
    
    # 4. Inspect .gitignore for .agents/
    $gitignorePath = Join-Path $repoPath '.gitignore'
    $agentsIgnored = $false
    if (Test-Path -LiteralPath $gitignorePath) {
        $giContent = Get-Content -Path $gitignorePath -Raw -ErrorAction SilentlyContinue
        if ($giContent -match '(?m)^\.agents/?') {
            $agentsIgnored = $true
        }
    }
    
    # 5. Determine Overall Health Status
    $status = '🟢 In Compliance'
    $issues = @()
    
    if (-not $isJunction -and $duplicateCount -gt 0) {
        $issues += "Physical Duplicate Files ($duplicateCount files)"
        $status = '🔴 Drift: Static Rule Copies'
    } elseif ($junctionState -eq 'Missing') {
        $issues += 'Missing .agents/rules Junction'
        $status = '🔴 Drift: Missing Junction'
    } elseif ($junctionState -eq 'Junction Invalid Target') {
        $issues += "Invalid Junction Target ($junctionTarget)"
        $status = '🔴 Drift: Broken Junction'
    }
    
    if ($hasLegacyResidue) {
        $issues += 'Legacy .copilot/Rules Directory'
        if ($status -eq '🟢 In Compliance') {
            $status = '🟡 Warning: Legacy Residue'
        }
    }
    
    if (-not $versionAligned -and $absorbedVersion -ne 'Missing .lcm') {
        $issues += "Outdated Baseline ($absorbedVersion vs v$globalVersion)"
        if ($status -eq '🟢 In Compliance') {
            $status = '🟡 Warning: Outdated Baseline'
        }
    }
    
    $results += [PSCustomObject]@{
        Repository       = $repoName
        JunctionState    = $junctionState
        PhysicalCopies   = if ($duplicateCount -gt 0) { "$duplicateCount file(s)" } else { 'None (Linked)' }
        AbsorbedLCM      = if ($absorbedVersion -ne '-') { "v$absorbedVersion" } else { '-' }
        LegacyResidue    = if ($hasLegacyResidue) { 'Present' } else { 'Clean' }
        AgentsIgnored    = $agentsIgnored
        Status           = $status
        Issues           = if ($issues.Count -gt 0) { $issues -join '; ' } else { 'None' }
        Path             = $repoPath
    }
}

# Render Table
Write-Host "`n========================================================================================================" -ForegroundColor Cyan
Write-Host (" LCM Governance & Rule Discovery Diagnostic Report (Global Baseline: v{0})" -f $globalVersion) -ForegroundColor Cyan
Write-Host "========================================================================================================" -ForegroundColor Cyan
Write-Host (" {0,-22} | {1,-18} | {2,-16} | {3,-10} | {4}" -f 'Repository', 'Junction State', 'Physical Copies', 'Baseline', 'Health Status') -ForegroundColor Yellow
Write-Host "-----------------------+--------------------+------------------+------------+---------------------------" -ForegroundColor DarkGray

$driftCount = 0
foreach ($r in $results) {
    $color = if ($r.Status -like '*In Compliance*') {
        [ConsoleColor]::Green
    } elseif ($r.Status -like '*Warning*') {
        [ConsoleColor]::Yellow
    } else {
        $driftCount++
        [ConsoleColor]::Red
    }

    Write-Host (" {0,-22} | {1,-18} | {2,-16} | {3,-10} | {4}" -f $r.Repository, $r.JunctionState, $r.PhysicalCopies, $r.AbsorbedLCM, $r.Status) -ForegroundColor $color
}

Write-Host "========================================================================================================" -ForegroundColor Cyan

if ($driftCount -gt 0) {
    Write-Host (" [!] {0} repository(ies) require governance reconciliation. Run 'Repair-LCMRules.ps1' to resolve." -f $driftCount) -ForegroundColor Yellow
} else {
    Write-Host " [✓] All repositories are in full compliance with canonical LCM rule discovery standards." -ForegroundColor Green
}

return $results
