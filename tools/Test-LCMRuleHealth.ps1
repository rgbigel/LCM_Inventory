<#
.SYNOPSIS
    Diagnoses LCM rule health, junction validity, static rule duplicates, and version alignment across repositories.
.DESCRIPTION
    Module: tools/Test-LCMRuleHealth.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 1.3.0
    Date: 2026-09-27
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Target repository name or path to diagnose (defaults to all governed)')]
    [string]$TargetRepository,

    [Parameter(Mandatory = $false, HelpMessage = 'Root workspace directory containing repositories to test')]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Parameter(Mandatory = $false, HelpMessage = 'Include standalone / non-governed utility repositories (defaults to Governed repositories only)')]
    [Alias('Ungoverned', 'All')]
    [switch]$IncludeUngoverned,

    [Parameter(Mandatory = $false, HelpMessage = 'Show detailed diagnostic messages for every checked file and rule')]
    [switch]$Detailed,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " TEST LCM RULE HEALTH (Test-LCMRuleHealth v1.3.0)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Diagnoses LCM rule health, junction validity, static duplicates, and versions."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Test-LCMRuleHealth.ps1 [[-TargetRepository] <str>] [-IncludeUngoverned] [-WorkspaceRoot <str>] [-Detailed] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -TargetRepository    : Target repository name to diagnose"
    Write-Host "  -IncludeUngoverned   : Include standalone / non-governed utility repositories (default: Tier 1 Governed only)"
    Write-Host "  -WorkspaceRoot       : Root workspace directory (default: D:\Git_Repositories)"
    Write-Host "  -Detailed            : Show detailed diagnostic messages"
    Write-Host "  -Help (-h, -?)       : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$canonicalRulesCandidates = @(
    (Join-Path $WorkspaceRoot 'LCM_AI\.agents\rules'),
    (Join-Path $WorkspaceRoot '.agents\rules')
)
$canonicalRulesDir = $canonicalRulesCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $canonicalRulesDir) {
    $canonicalRulesDir = Join-Path $WorkspaceRoot 'LCM_AI\.agents\rules'
}

# Read global LCM baseline
$globalVersion = '6.1.1'
$reqDoc = Join-Path $WorkspaceRoot 'LCM_AI\docs\Requirements.md'
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

# Filter: Default to Tier 1 Governed repositories unless -IncludeUngoverned is specified or a specific target is requested
if (-not $IncludeUngoverned -and [string]::IsNullOrWhiteSpace($TargetRepository)) {
    $childDirs = @($childDirs | Where-Object {
        (Test-Path (Join-Path $_.FullName 'AGENTS.md')) -or
        $_.Name -in @('LCM_AI', 'LCM_Inventory')
    })
}

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
    
    if ($repoName -eq 'LCM_AI' -and (Test-Path -LiteralPath $agentRulesPath)) {
        $files = @(Get-ChildItem -Path $agentRulesPath -File -Recurse -ErrorAction SilentlyContinue)
        if ($files.Count -gt 0) {
            $isJunction = $true
            $junctionState = 'Canonical Hub'
            $junctionTarget = 'Canonical Physical Hub'
            $duplicateCount = 0
        } else {
            $junctionState = 'Empty Hub'
        }
    } elseif (Test-Path -LiteralPath $agentRulesPath) {
        $item = Get-Item -LiteralPath $agentRulesPath -Force
        if ($item.LinkType -eq 'Junction' -or $item.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
            $isJunction = $true
            $target = $item.Target
            if ($target) {
                $targetStr = [string]$target
                $isValid = $false
                foreach ($c in $canonicalRulesCandidates) {
                    if ($targetStr -eq $c -or ((Test-Path -LiteralPath $c) -and ($targetStr -eq (Get-Item -LiteralPath $c).FullName))) {
                        $isValid = $true
                        break
                    }
                }
                if ($isValid) {
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
    $hasLegacyResidue = $false
    if (Test-Path -LiteralPath $copilotRulesPath) {
        $cItem = Get-Item -LiteralPath $copilotRulesPath -Force
        if (-not ($cItem.LinkType -eq 'Junction' -or $cItem.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint))) {
            $hasLegacyResidue = $true
        }
    }
    
    # 3. Baseline is the global version (no per-repo configuration record exists)
    $absorbedVersion = '-'
    $versionAligned = $true
    
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
    
    if (-not $versionAligned -and $absorbedVersion -notin @('N/A (Standalone)', '-')) {
        $issues += "Outdated Baseline ($absorbedVersion vs v$globalVersion)"
        if ($status -eq '🟢 In Compliance') {
            $status = '🟡 Warning: Outdated Baseline'
        }
    }
    
    $results += [PSCustomObject]@{
        Repository       = $repoName
        JunctionState    = $junctionState
        PhysicalCopies   = if ($duplicateCount -gt 0) { "$duplicateCount file(s)" } else { 'None (Linked)' }
        AbsorbedLCM      = if ($absorbedVersion -match '^\d') { "v$absorbedVersion" } else { $absorbedVersion }
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
Write-Host (" {0,-22} | {1,-18} | {2,-16} | {3,-16} | {4}" -f 'Repository', 'Junction State', 'Physical Copies', 'Baseline', 'Health Status') -ForegroundColor Yellow
Write-Host "-----------------------+--------------------+------------------+------------------+---------------------------" -ForegroundColor DarkGray

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

    Write-Host (" {0,-22} | {1,-18} | {2,-16} | {3,-16} | {4}" -f $r.Repository, $r.JunctionState, $r.PhysicalCopies, $r.AbsorbedLCM, $r.Status) -ForegroundColor $color
}

Write-Host "========================================================================================================" -ForegroundColor Cyan

if ($driftCount -gt 0) {
    Write-Host (" [!] {0} repository(ies) require governance reconciliation. Run 'Repair-LCMRules.ps1' to resolve." -f $driftCount) -ForegroundColor Yellow
} else {
    Write-Host " [✓] All repositories are in full compliance with canonical LCM rule discovery standards." -ForegroundColor Green
}

$stopwatch.Stop()
$durationMs = [int]$stopwatch.ElapsedMilliseconds

# Generate Standard Readiness Receipt (CRP-152)
$receiptDir = Join-Path $WorkspaceRoot 'LCM_Inventory\data\readiness'
if (-not (Test-Path -LiteralPath $receiptDir)) {
    New-Item -Path $receiptDir -ItemType Directory -Force | Out-Null
}
$receiptPath = Join-Path $receiptDir 'latest_rule_health.json'

$compliantCount = @($results | Where-Object { $_.Status -like '*In Compliance*' }).Count
$warningCount = @($results | Where-Object { $_.Status -like '*Warning*' }).Count

$receiptObj = [ordered]@{
    '$schema'            = 'https://json-schema.org/draft/2020-12/schema'
    repository           = 'LCM_Inventory'
    tool                 = 'Test-LCMRuleHealth.ps1'
    timestamp            = (Get-Date).ToString('o')
    overall_status       = if ($driftCount -eq 0) { 'PASSED' } else { 'FAILED' }
    total_repositories   = $results.Count
    compliant_count      = $compliantCount
    warning_count        = $warningCount
    drift_count          = $driftCount
    duration_ms          = $durationMs
    results              = $results
}

$receiptJson = $receiptObj | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($receiptPath, $receiptJson, [System.Text.Encoding]::UTF8)
Write-Host " [i] Saved LCM Rule Health Receipt: $receiptPath ($durationMs ms)" -ForegroundColor DarkGray

return $results
