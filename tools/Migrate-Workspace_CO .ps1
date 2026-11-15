# Module: Migrate-Workspace.ps1
# Purpose: Transform Workspace_GC into a neutral target workspace (Workspace_CO) supporting Cursor & Cline
# Path: D:\@cmd\@aktuell\Migrate-Workspace_CO .ps1
# Authors: Rolf / AI Migration Assistant
# Version: 1.0.0
# Requires: PowerShell 7.6+

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SourcePath = "D:\Git_Repositories\Workspace_GC",

    [Parameter(Mandatory = $false)]
    [string]$TargetPath = "D:\Git_Repositories\Workspace_CO",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting Workspace Migration Phase" -ForegroundColor Cyan
Write-Host " Source: $SourcePath" -ForegroundColor LightGray
Write-Host " Target: $TargetPath" -ForegroundColor LightGray
Write-Host "==========================================================" -ForegroundColor Cyan

# Rule 1: Source Protection Check
if (-not (Test-Path $SourcePath)) {
    throw "Source path '$SourcePath' does not exist."
}

# Ensure Source remains untouched (read-only enforcement)
if ($SourcePath.TrimEnd('\/') -eq $TargetPath.TrimEnd('\/')) {
    throw "Source and Target paths must be different. Workspace_GC is read-only!"
}

# Step 1: Duplicate Workspace_GC to Workspace_CO
if (Test-Path $TargetPath) {
    if ($Force) {
        Write-Host "[1/5] Target directory exists. Removing existing target (-Force)..." -ForegroundColor Yellow
        Remove-Item -Path $TargetPath -Recurse -Force
    } else {
        throw "Target directory '$TargetPath' already exists. Use -Force to overwrite."
    }
}

Write-Host "[1/5] Copying source workspace to target..." -ForegroundColor Green
Copy-Item -Path $SourcePath -Destination $TargetPath -Recurse -Force

# Helper function: File Normalizer (UTF-8 without BOM, CRLF line endings)
function Set-NormalizedContent {
    param(
        [string]$Path,
        [string]$Content
    )
    # Ensure CRLF line endings
    $normalized = $Content -replace "\r?\n", "`r`n"
    
    # Save UTF-8 without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
}

# Step 2: Cleanup Legacy Continue Configurations
Write-Host "[2/5] Cleaning up legacy Continue references..." -ForegroundColor Green
$continueDir = Join-Path $TargetPath ".continue"
$continueRules = Join-Path $TargetPath ".continuerules"

if (Test-Path $continueDir) {
    Remove-Item -Path $continueDir -Recurse -Force
    Write-Host "  - Removed .continue/ directory" -ForegroundColor Gray
}

if (Test-Path $continueRules) {
    Remove-Item -Path $continueRules -Force
    Write-Host "  - Removed .continuerules file" -ForegroundColor Gray
}

# Step 3: Parse Canonical Rules from .copilot/Rules/
Write-Host "[3/5] Reading canonical rules from .copilot/Rules/..." -ForegroundColor Green
$copilotRulesDir = Join-Path $TargetPath ".copilot\Rules"

if (-not (Test-Path $copilotRulesDir)) {
    throw "Canonical rules directory '$copilotRulesDir' not found in target."
}

$ruleFiles = Get-ChildItem -Path $copilotRulesDir -Filter "*.md"

# Step 4: Generate Target Rules for Cursor (.cursor/rules/*.mdc)
Write-Host "[4/5] Generating Cursor rule mirrors (.cursor/rules/*.mdc)..." -ForegroundColor Green
$cursorRulesDir = Join-Path $TargetPath ".cursor\rules"
if (-not (Test-Path $cursorRulesDir)) {
    New-Item -ItemType Directory -Path $cursorRulesDir -Force | Out-Null
}

foreach ($ruleFile in $ruleFiles) {
    $ruleName = [System.IO.Path]::GetFileNameWithoutExtension($ruleFile.Name)
    $mdcPath = Join-Path $cursorRulesDir "$ruleName.mdc"
    
    $rawContent = Get-Content -Path $ruleFile.FullName -Raw
    
    # Frontmatter for Cursor MDC format
    $frontmatter = @"
---
description: Canonical Mirror of $ruleName ($($ruleFile.Name))
globs: "*"
---
<!-- AUTO-GENERATED MIRROR - DO NOT EDIT DIRECTLY -->
<!-- Source: .copilot/Rules/$($ruleFile.Name) -->

"@
    $fullMdcContent = $frontmatter + $rawContent
    Set-NormalizedContent -Path $mdcPath -Content $fullMdcContent
    Write-Host "  - Generated .cursor/rules/$ruleName.mdc" -ForegroundColor Gray
}

# Step 5: Generate Target Rule Entry Point for Cline (.clinerules)
Write-Host "[5/5] Generating Cline rule mirror (.clinerules)..." -ForegroundColor Green
$clinerulesPath = Join-Path $TargetPath ".clinerules"

$clineHeader = @"
# =====================================================================
# CANONICAL RULE MIRROR FOR CLINE / ROO CODE
# Source Authority: .copilot/Rules/
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# =====================================================================

"@

$aggregatedRules = @($clineHeader)

foreach ($ruleFile in $ruleFiles) {
    $ruleName = $ruleFile.Name
    $content = Get-Content -Path $ruleFile.FullName -Raw
    
    $section = @"

# ---------------------------------------------------------------------
# Source: .copilot/Rules/$ruleName
# ---------------------------------------------------------------------
$content

"@
    $aggregatedRules += $section
}

$finalClineContent = $aggregatedRules -join "`n"
Set-NormalizedContent -Path $clinerulesPath -Content $finalClineContent
Write-Host "  - Generated .clinerules at workspace root" -ForegroundColor Gray

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Migration Completed Successfully!" -ForegroundColor Cyan
Write-Host " Target workspace is ready at: $TargetPath" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
