<#
.SYNOPSIS
  Configures and standardizes child repositories in Git World for LCM hybrid operation.
.DESCRIPTION
  Module: tools/Initialize-GitWorld.ps1
  Purpose: Prepares detached or offloaded child repositories in Git World (e.g. D:\Git_World)
           so they can operate seamlessly under LCM governance when mounted into Git Root.
           1. Discovers all Git child repositories in Git World.
           2. Establishes the canonical .agents/rules NTFS junction linking back to LCM_AI.
           3. Ensures .gitignore entries isolate local governance links.
           4. Configures Git safe.directory to prevent dubious ownership warnings.
           Does NOT alter or replace existing repositories in Git Root.
  Path: LCM_Inventory/tools/Initialize-GitWorld.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
  Rule: RULE-PS-001 - RULE-PS-021, RULE-LCM-020
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Root path to Git World containing child repositories')]
    [string]$GitWorldRoot = 'D:\Git_World',

    [Parameter(Mandatory = $false, HelpMessage = 'Explicit canonical rules hub directory (defaults to machine Git_Root\LCM_AI\.agents\rules)')]
    [string]$CanonicalRulesHub = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Configure Git global safe.directory for Git World')]
    [switch]$ConfigureGitSafeDirectory = $true,

    [Parameter(Mandatory = $false, HelpMessage = 'Force recreation of existing junctions')]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = 'Simulate actions without modifying files or junctions')]
    [switch]$DryRun,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Initialize-GitWorld.ps1 requires PowerShell 7 (pwsh.exe). Windows PowerShell (powershell.exe) is not supported.'
}

$scriptVersion = '10.0.0'
$scriptName = 'Initialize-GitWorld'

if ($Help) {
    Write-Host '==========================================================================' -ForegroundColor Cyan
    Write-Host " LCM GIT WORLD ADJUSTMENT & TOPOLOGY TOOL (v$($scriptVersion))" -ForegroundColor Cyan
    Write-Host '==========================================================================' -ForegroundColor Cyan
    Write-Host 'SYNOPSIS:' -ForegroundColor Yellow
    Write-Host '  Adjusts and pre-links child repositories in Git World so they can operate'
    Write-Host '  seamlessly under LCM governance without altering live Git Root.'
    Write-Host ''
    Write-Host 'USAGE:' -ForegroundColor Yellow
    Write-Host '  pwsh LCM_Inventory/tools/Initialize-GitWorld.ps1 [[-GitWorldRoot] <path>] [-CanonicalRulesHub <path>] [-Force] [-DryRun] [-h]'
    Write-Host ''
    Write-Host 'PARAMETERS:' -ForegroundColor Yellow
    Write-Host '  -GitWorldRoot                : Root containing child repositories (default: D:\Git_World)'
    Write-Host '  -CanonicalRulesHub           : Canonical rules directory in Git Root'
    Write-Host '  -ConfigureGitSafeDirectory   : Ensure git config --global safe.directory includes Git World (default: true)'
    Write-Host '  -Force                       : Recreate existing junctions if present'
    Write-Host '  -DryRun                      : Report proposed adjustments without executing changes'
    Write-Host '  -h, -Help, -?                : Displays this parameter reference'
    Write-Host '==========================================================================' -ForegroundColor Cyan
    return
}

# ------------------------------------------------------------------------------
# 1. Resolve Canonical Rules Hub from Git Root
# ------------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($CanonicalRulesHub)) {
    $contextModule = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LCM_Context.psm1'
    if (Test-Path -LiteralPath $contextModule) {
        Import-Module -Name $contextModule -Force
        $gitRoot = Get-LcmMachineGitRoot
    } else {
        $gitRoot = 'D:\Git_Repositories'
    }
    $CanonicalRulesHub = Join-Path $gitRoot 'LCM_AI\.agents\rules'
}

if (-not (Test-Path -LiteralPath $CanonicalRulesHub -PathType Container)) {
    throw "Canonical Rules Hub was not found at: $($CanonicalRulesHub)"
}

if (-not (Test-Path -LiteralPath $GitWorldRoot -PathType Container)) {
    throw "Git World root directory was not found at: $($GitWorldRoot)"
}

Write-Host '==========================================================================' -ForegroundColor Cyan
Write-Host " LCM GIT WORLD ADJUSTMENT ENGINE (v$($scriptVersion))" -ForegroundColor Cyan
Write-Host " Git World Root    : $($GitWorldRoot)" -ForegroundColor Cyan
Write-Host " Canonical Hub     : $($CanonicalRulesHub)" -ForegroundColor Cyan
Write-Host " Mode              : $(if ($DryRun) { 'DRY RUN (Simulation)' } else { 'ACTIVE' })" -ForegroundColor Yellow
Write-Host '==========================================================================' -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 2. Configure Git safe.directory if requested
# ------------------------------------------------------------------------------
if ($ConfigureGitSafeDirectory) {
    $safePattern = "$($GitWorldRoot.Replace('\', '/'))/*"
    $existingSafe = @(git config --global --get-all safe.directory 2>$null)
    if ($existingSafe -notcontains $safePattern -and $existingSafe -notcontains '*') {
        if ($DryRun) {
            Write-Host "`n[DRY RUN] Would configure Git safe.directory: $($safePattern)" -ForegroundColor Yellow
        } else {
            Write-Host "`nConfiguring Git global safe.directory for Git World..." -ForegroundColor Yellow
            git config --global --add safe.directory "$($safePattern)"
            Write-Host "  [OK] Added safe.directory: $($safePattern)" -ForegroundColor Green
        }
    } else {
        Write-Host "`n[OK] Git safe.directory already encompasses Git World." -ForegroundColor Green
    }
}

# ------------------------------------------------------------------------------
# 3. Discover and Adjust Child Repositories in Git World
# ------------------------------------------------------------------------------
$childEntries = @(Get-ChildItem -LiteralPath $GitWorldRoot -Directory | Where-Object {
    $_.Name -notmatch '^\.' -and
    (Test-Path -LiteralPath (Join-Path $_.FullName '.git'))
})

if ($childEntries.Count -eq 0) {
    Write-Warning "No Git child repositories were discovered in $($GitWorldRoot)."
    return
}

Write-Host "`nDiscovered $($childEntries.Count) child repository(ies) in $($GitWorldRoot):" -ForegroundColor Cyan

$adjustedCount = 0
$junctionsCreated = 0
$gitignoresUpdated = 0

foreach ($repoDir in $childEntries) {
    $repoName = $repoDir.Name
    $repoPath = $repoDir.FullName
    Write-Host "`n--> Processing Repository: $($repoName)" -ForegroundColor Yellow

    $agentDir = Join-Path $repoPath '.agents'
    $agentRulesPath = Join-Path $agentDir 'rules'
    $gitignorePath = Join-Path $repoPath '.gitignore'

    # Step A: Ensure .agents directory exists
    if (-not (Test-Path -LiteralPath $agentDir)) {
        if ($DryRun) {
            Write-Host "    [DRY RUN] Would create directory: $($agentDir)" -ForegroundColor Yellow
        } else {
            New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
            Write-Host '    [+] Created .agents parent directory' -ForegroundColor Green
        }
    }

    # Step B: Manage .agents/rules junction
    $needsJunction = $true
    if (Test-Path -LiteralPath $agentRulesPath) {
        $item = Get-Item -LiteralPath $agentRulesPath -Force
        $isJunction = ($item.LinkType -eq 'Junction' -or $item.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint))
        if ($isJunction) {
            $target = [string]$item.Target
            if ($target -eq $CanonicalRulesHub -or $target -eq (Get-Item -LiteralPath $CanonicalRulesHub).FullName) {
                Write-Host '    [OK] .agents/rules junction already valid' -ForegroundColor Green
                $needsJunction = $false
            } else {
                Write-Host "    [!] Existing junction points to mismatched target: $($target)" -ForegroundColor DarkYellow
                if ($Force) {
                    if ($DryRun) {
                        Write-Host "    [DRY RUN] Would remove invalid junction: $($agentRulesPath)" -ForegroundColor Yellow
                    } else {
                        cmd /c rmdir "$($agentRulesPath)" 2>$null | Out-Null
                        Write-Host '    [-] Removed invalid junction' -ForegroundColor DarkYellow
                    }
                } else {
                    $needsJunction = $false
                }
            }
        } else {
            Write-Warning "    [!] Physical directory exists at $($agentRulesPath). Use -Force to replace with junction."
            $needsJunction = $false
        }
    }

    if ($needsJunction) {
        if ($DryRun) {
            Write-Host "    [DRY RUN] Would create NTFS junction: $($agentRulesPath) -> $($CanonicalRulesHub)" -ForegroundColor Yellow
            $junctionsCreated++
        } else {
            if ($PSCmdlet.ShouldProcess($agentRulesPath, "Create NTFS junction to $($CanonicalRulesHub)")) {
                $mklinkOut = cmd /c mklink /J "$($agentRulesPath)" "$($CanonicalRulesHub)" 2>&1
                if (Test-Path -LiteralPath $agentRulesPath) {
                    Write-Host "    [+] Created .agents/rules NTFS junction -> $($CanonicalRulesHub)" -ForegroundColor Green
                    $junctionsCreated++
                } else {
                    Write-Warning "    Failed to create junction: $($mklinkOut)"
                }
            }
        }
    }

    # Step C: Ensure .gitignore contains .agents/
    $needsGitignore = $true
    if (Test-Path -LiteralPath $gitignorePath) {
        $giContent = Get-Content -LiteralPath $gitignorePath -Raw -ErrorAction SilentlyContinue
        if ($giContent -match '(?m)^\.agents/?') {
            $needsGitignore = $false
        }
    }

    if ($needsGitignore) {
        if ($DryRun) {
            Write-Host '    [DRY RUN] Would add .agents/ to .gitignore' -ForegroundColor Yellow
            $gitignoresUpdated++
        } else {
            if ($PSCmdlet.ShouldProcess($gitignorePath, "Add .agents/ to .gitignore")) {
                Add-Content -LiteralPath $gitignorePath -Value "`n# LCM Local Governance Link`n.agents/" -Encoding UTF8
                Write-Host '    [+] Appended .agents/ to .gitignore' -ForegroundColor Green
                $gitignoresUpdated++
            }
        }
    }

    $adjustedCount++
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " GIT WORLD ADJUSTMENT COMPLETE" -ForegroundColor Green
Write-Host " Repositories Checked   : $($adjustedCount)" -ForegroundColor Cyan
Write-Host " Junctions Created      : $($junctionsCreated)" -ForegroundColor Cyan
Write-Host " Gitignores Updated     : $($gitignoresUpdated)" -ForegroundColor Cyan
Write-Host ' Live Git Root was untouched and remains operational as is.' -ForegroundColor Green
Write-Host '==========================================================================' -ForegroundColor Cyan
