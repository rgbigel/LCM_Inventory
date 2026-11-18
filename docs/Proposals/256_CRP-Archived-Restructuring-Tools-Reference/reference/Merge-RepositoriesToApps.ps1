<#
.SYNOPSIS
    Merges an external repository into a target umbrella repository as a modular App: # slice.
.DESCRIPTION
    Module: tools/Merge-RepositoriesToApps.ps1
    Authors: Rolf, LCM_AI Engine
    Version: 10.2.0
    Date: 2026-10-13
    Purpose: High-Order Lifecycle Operator that consolidates independent single-purpose repositories
             into an umbrella system as distinct App: # slices with preserved tripartite history per RULE-DOC-007.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Source child repository to absorb as an App')]
    [string]$SourceRepo = '',

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Target umbrella repository to receive the App')]
    [string]$TargetRepo = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Custom App title (defaults to source repository name)')]
    [string]$AppTitle = '',

    [Parameter(Mandatory = $false, HelpMessage = 'Workspace root path')]
    [string]$WorkspaceRoot = 'D:\Git_Repositories',

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help -or [string]::IsNullOrWhiteSpace($SourceRepo) -or [string]::IsNullOrWhiteSpace($TargetRepo)) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " MERGE REPOSITORY TO APP SLICE (Merge-RepositoriesToApps)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Consolidates a child repository into a target umbrella repo as an App: # slice."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Merge-RepositoriesToApps.ps1 [-SourceRepo] <src> [-TargetRepo] <target> [-AppTitle <title>] [-WhatIf] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -SourceRepo    : Name of child repo being absorbed (e.g. 'InstallFonts')"
    Write-Host "  -TargetRepo    : Target umbrella repository (e.g. 'SystemConfiguration')"
    Write-Host "  -AppTitle      : Title for the absorbed App slice"
    Write-Host "  -WorkspaceRoot : Workspace root directory (default: D:\Git_Repositories)"
    Write-Host "  -WhatIf        : Previews the merge plan without modifying files"
    Write-Host "  -Help (-h, -?) : Displays this parameter reference"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
Import-Module $modulePath -Force

$srcPath = Join-Path $WorkspaceRoot $SourceRepo
$targetPath = Join-Path $WorkspaceRoot $TargetRepo

if (-not (Test-Path -LiteralPath $srcPath)) {
    throw "Source repository '$SourceRepo' not found at: $srcPath"
}
if (-not (Test-Path -LiteralPath $targetPath)) {
    throw "Target repository '$TargetRepo' not found at: $targetPath"
}

$effectiveTitle = if ($AppTitle) { $AppTitle } else { $SourceRepo }

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host (" MERGING REPOSITORY '{0}' INTO '{1}' AS APP SLICE" -f $SourceRepo, $TargetRepo) -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan

# 1. Discover existing Apps in Target Repo
$existingApps = @(Get-LcmApps -Repo $TargetRepo -WorkspaceRoot $WorkspaceRoot)
$maxNum = 0
foreach ($a in $existingApps) {
    if ($a.number -gt $maxNum) { $maxNum = $a.number }
}

$newNum = $maxNum + 1
$appId = "App: $newNum"
$fullTitle = "$appId - $effectiveTitle"

Write-Host (" Target App Allocation: {0}" -f $fullTitle) -ForegroundColor Cyan

# 2. Extract source specifications if present
$srcArch = Join-Path $srcPath 'docs\Architecture.md'
$srcReq  = Join-Path $srcPath 'docs\Requirements.md'
$srcImpl = Join-Path $srcPath 'docs\Implementation.md'

$archSnippet = if (Test-Path -LiteralPath $srcArch) { Get-Content -LiteralPath $srcArch -Raw -Encoding UTF8 } else { "Absorbed capability from repository $SourceRepo." }
$reqSnippet  = if (Test-Path -LiteralPath $srcReq)  { Get-Content -LiteralPath $srcReq -Raw -Encoding UTF8 } else { "- Invariant: Conforms to $TargetRepo standards." }
$implSnippet = if (Test-Path -LiteralPath $srcImpl) { Get-Content -LiteralPath $srcImpl -Raw -Encoding UTF8 } else { "" }

if ($PSCmdlet.ShouldProcess("$TargetRepo/docs/", "Merge $SourceRepo specifications and files as $fullTitle")) {
    $targetDocs = Join-Path $targetPath 'docs'
    if (-not (Test-Path -LiteralPath $targetDocs)) { New-Item -ItemType Directory -Path $targetDocs -Force | Out-Null }

    # Append to target Architecture.md
    $targetArch = Join-Path $targetDocs 'Architecture.md'
    $archBlock = @"


---

## $fullTitle

### 1. Absorbed System Concept (from $SourceRepo)
$archSnippet

"@
    Add-Content -Path $targetArch -Value $archBlock -Encoding UTF8

    # Append to target Requirements.md
    $targetReq = Join-Path $targetDocs 'Requirements.md'
    $reqBlock = @"


---

## $fullTitle

### 1. Absorbed Technical Invariants (from $SourceRepo)
$reqSnippet

"@
    Add-Content -Path $targetReq -Value $reqBlock -Encoding UTF8

    # Append to target Implementation.md with Constituent Manifest
    $targetImpl = Join-Path $targetDocs 'Implementation.md'
    $cleanSrc = ($SourceRepo -replace '[^a-zA-Z0-9]', '')
    $implBlock = @"


---

## $fullTitle

### 1. Constituent Manifest Table
| Relative Path | Role / Layer | Primary Cmdlets / Entrypoints | Pester Test Suite |
|:---|:---|:---|:---|
| `modules/$cleanSrc.psm1` | Absorbed Core | `Invoke-$cleanSrc` | `tests/$cleanSrc.Tests.ps1` |

### 2. Implementation Specifications (from $SourceRepo)
$implSnippet

"@
    Add-Content -Path $targetImpl -Value $implBlock -Encoding UTF8

    # Set active context to newly merged App
    Set-ActiveAppContext -Context "A$newNum" -Repo $TargetRepo -Details "Absorbed $SourceRepo" -WorkspaceRoot $WorkspaceRoot | Out-Null

    # Re-sync catalog
    Sync-LcmAppCatalog -Repo $TargetRepo -WorkspaceRoot $WorkspaceRoot | Out-Null

    Write-Host ("`n[SUCCESS] Successfully merged '{0}' into '{1}' as {2}!" -f $SourceRepo, $TargetRepo, $fullTitle) -ForegroundColor Green
    Format-LcmAppsTable -WorkspaceRoot $WorkspaceRoot
} else {
    Write-Host (" [WhatIf] Would merge '{0}' into '{1}' as {2}" -f $SourceRepo, $TargetRepo, $fullTitle) -ForegroundColor Yellow
}
