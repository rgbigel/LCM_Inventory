<#
.SYNOPSIS
    Reconciles, repairs, and standardizes LCM rule discovery junctions and .gitignore entries across repositories.
.DESCRIPTION
    Module: tools/Repair-LCMRules.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.1.0
    Date: 2026-09-10
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Specific target repository name or path to repair rules in')]
    [string]$TargetRepository,

    [Parameter(Mandatory = $false, HelpMessage = 'Repair rule junctions across all repositories in the workspace')]
    [switch]$All,

    [Parameter(Mandatory = $false, HelpMessage = 'Root workspace directory containing governed repositories')]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Parameter(Mandatory = $false, HelpMessage = 'Simulate repair operations without making junction or file changes')]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = 'Force replacement or re-creation of invalid junctions')]
    [switch]$Force,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " REPAIR LCM RULES & JUNCTIONS (Repair-LCMRules)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Reconciles, repairs, and standardizes LCM rule discovery junctions across repositories."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh Workspace_Inventory/tools/Repair-LCMRules.ps1 [[-TargetRepository] <str>] [-All] [-WorkspaceRoot <str>] [-DryRun] [-Force] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -TargetRepository : Specific target repository to repair"
    Write-Host "  -All              : Repair rule junctions across all repositories"
    Write-Host "  -WorkspaceRoot    : Root workspace directory (default: D:\Git_Repositories)"
    Write-Host "  -DryRun           : Simulate repair without making changes"
    Write-Host "  -Force            : Force re-creation of invalid junctions"
    Write-Host "  -Help (-h, -?)    : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$canonicalRulesCandidates = @(
    (Join-Path $WorkspaceRoot 'Workspace_Inventory\.agents\rules'),
    (Join-Path $WorkspaceRoot '.lcm\.agents\rules'),
    (Join-Path $WorkspaceRoot '.agents\rules')
)
$canonicalRulesDir = $canonicalRulesCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $canonicalRulesDir) {
    throw "Canonical Rule Hub not found across candidate paths: $($canonicalRulesCandidates -join ', ')"
}

# Read global LCM baseline
$globalVersion = '6.1.1'
$reqDoc = Join-Path $WorkspaceRoot 'Workspace_AI\docs\Requirements.md'
if (Test-Path $reqDoc) {
    $match = Select-String -Path $reqDoc -Pattern '^Version:\s*(\S+)' | Select-Object -First 1
    if ($match -and $match.Matches.Groups.Count -gt 1) {
        $globalVersion = $match.Matches.Groups[1].Value
    }
}

$childDirs = @(Get-ChildItem -Path $WorkspaceRoot -Directory | Where-Object {
    $_.Name -notmatch '^\.' -and
    $_.Name -ne 'Workspace_AI' -and
    $_.Name -ne 'Workspace_Inventory' -and
    (Test-Path (Join-Path $_.FullName '.git'))
})

if (-not $All -and [string]::IsNullOrWhiteSpace($TargetRepository)) {
    Write-Host "Please specify a -TargetRepository <Name> or pass -All to reconcile all governed repositories." -ForegroundColor Yellow
    return
}

if (-not [string]::IsNullOrWhiteSpace($TargetRepository)) {
    $childDirs = @($childDirs | Where-Object { $_.Name -like "*$TargetRepository*" })
    if ($childDirs.Count -eq 0) {
        throw "Target repository '$TargetRepository' not found under $WorkspaceRoot."
    }
}

Write-Host "==========================================================================================" -ForegroundColor Cyan
Write-Host (" LCM Rule & Governance Reconciliation Engine (Target Baseline: v{0})" -f $globalVersion) -ForegroundColor Cyan
Write-Host " Mode: $(if ($DryRun) { 'SIMULATION / DRY-RUN' } else { 'ACTIVE REPAIR' })" -ForegroundColor Cyan
Write-Host "==========================================================================================" -ForegroundColor Cyan

$repairedCount = 0

foreach ($dir in $childDirs) {
    $repoName = $dir.Name
    $repoPath = $dir.FullName
    $actionsTaken = @()
    
    Write-Host "`n--> Processing Repository: $repoName" -ForegroundColor Yellow
    
    # Ensure .agents parent folder exists
    $agentDir = Join-Path $repoPath '.agents'
    if (-not (Test-Path $agentDir)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
        }
        $actionsTaken += 'Created .agents parent folder'
    }
    
    # 1. Handle .agents/rules junction
    $agentRulesPath = Join-Path $repoPath '.agents\rules'
    $needsJunction = $true
    
    if (Test-Path -LiteralPath $agentRulesPath) {
        $item = Get-Item -LiteralPath $agentRulesPath -Force
        $isJunction = ($item.LinkType -eq 'Junction' -or $item.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint))
        
        if ($isJunction) {
            $target = [string]$item.Target
            if ($canonicalRulesCandidates -contains $target -or $target -eq $canonicalRulesDir -or $target -eq (Get-Item $canonicalRulesDir).FullName) {
                $needsJunction = $false
            } else {
                Write-Host "    [!] Removing broken/invalid junction: $target" -ForegroundColor Yellow
                if (-not $DryRun) {
                    cmd /c rmdir "$agentRulesPath" 2>$null | Out-Null
                }
                $actionsTaken += 'Removed broken junction'
            }
        } else {
            # Physical directory: check for unique local files
            $localFiles = @(Get-ChildItem -Path $agentRulesPath -File -Recurse -ErrorAction SilentlyContinue)
            $canonicalNames = @(Get-ChildItem -Path $canonicalRulesDir -File | Select-Object -ExpandProperty Name)
            
            $uniqueFiles = @($localFiles | Where-Object { $canonicalNames -notcontains $_.Name })
            if ($uniqueFiles.Count -gt 0) {
                $backupDir = Join-Path $repoPath 'docs\local_rules'
                Write-Host "    [!] Backing up $($uniqueFiles.Count) custom local rule(s) to docs\local_rules..." -ForegroundColor Cyan
                if (-not $DryRun) {
                    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
                    foreach ($uf in $uniqueFiles) {
                        Copy-Item -LiteralPath $uf.FullName -Destination $backupDir -Force
                    }
                }
                $actionsTaken += "Backed up $($uniqueFiles.Count) local rules to docs/local_rules"
            }
            
            Write-Host "    [!] Removing redundant physical rule directory ($($localFiles.Count) files)..." -ForegroundColor Yellow
            if (-not $DryRun) {
                Remove-Item -LiteralPath $agentRulesPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            $actionsTaken += 'Removed redundant physical rule files'
        }
    }
    
    # Create clean junction if needed
    if ($needsJunction) {
        Write-Host "    [+] Establishing NTFS Junction -> $canonicalRulesDir" -ForegroundColor Green
        if (-not $DryRun) {
            cmd /c mklink /J "$agentRulesPath" "$canonicalRulesDir" 2>$null | Out-Null
        }
        $actionsTaken += 'Created .agents/rules NTFS junction'
    }
    
    # 2. Handle .gitignore
    $gitignorePath = Join-Path $repoPath '.gitignore'
    $needsGitignore = $true
    if (Test-Path -LiteralPath $gitignorePath) {
        $giContent = Get-Content -Path $gitignorePath -Raw -ErrorAction SilentlyContinue
        if ($giContent -match '(?m)^\.agents/?') {
            $needsGitignore = $false
        }
    }
    
    if ($needsGitignore) {
        Write-Host "    [+] Adding '.agents/' to .gitignore" -ForegroundColor Green
        if (-not $DryRun) {
            Add-Content -Path $gitignorePath -Value "`n# LCM Local Governance Link`n.agents/" -Encoding UTF8
        }
        $actionsTaken += 'Added .agents/ to .gitignore'
    }
    
    # 3. Update .lcm/config.json baseline version
    $cfgPath = Join-Path $repoPath '.lcm\config.json'
    if (Test-Path -LiteralPath $cfgPath) {
        try {
            $cfg = Get-Content -Path $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $gov = if ($cfg.PSObject.Properties['governance']) { $cfg.governance } else { $null }
            $currentAbsorbed = if ($gov -and $gov.PSObject.Properties['absorbed_lcm_version']) {
                [string]$gov.absorbed_lcm_version
            } elseif ($gov -and $gov.PSObject.Properties['lcm_version']) {
                [string]$gov.lcm_version
            } else {
                ''
            }
            
            if ($currentAbsorbed -ne $globalVersion) {
                Write-Host "    [+] Aligning .lcm/config.json absorbed_lcm_version: $currentAbsorbed -> v$globalVersion" -ForegroundColor Green
                if (-not $DryRun) {
                    if ($gov) {
                        $gov | Add-Member -NotePropertyName 'absorbed_lcm_version' -NotePropertyValue $globalVersion -Force
                    } else {
                        $cfg | Add-Member -NotePropertyName 'absorbed_lcm_version' -NotePropertyValue $globalVersion -Force
                    }
                    $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $cfgPath -Encoding UTF8
                }
                $actionsTaken += "Updated absorbed_lcm_version to v$globalVersion"
            }
        } catch { }
    }
    
    if ($actionsTaken.Count -gt 0) {
        $repairedCount++
        Write-Host "    Summary: $($actionsTaken -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host '    Status: Already in full compliance (no action required).' -ForegroundColor Green
    }
}

Write-Host "`n==========================================================================================" -ForegroundColor Cyan
Write-Host (" Reconciliation Complete. {0} repository(ies) updated." -f $repairedCount) -ForegroundColor Green
Write-Host "==========================================================================================" -ForegroundColor Cyan
