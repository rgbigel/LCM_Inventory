<#
.SYNOPSIS
    Create-LCM-CRP.ps1
.DESCRIPTION
    Generates a standardized Change Request Proposal (CRP) for LCM convergence 
    and stages it directly into the canonical Google Drive path.
.AUTHOR
    Rolf / Gemini Collaboration
.VERSION
    2.2.0
.DATE
    2026-09-04
.CHANGELOG
    2.2.0 - Added RULE-PS-010 -h/-Help handler, positional parameter binding,
            and parameter set decoupling for help invocation.
    2.1.0 - Added aliases (Analysis, CRP, ShortName), optional Purpose/ProposedChanges defaults,
            and automatic numeric padding for AnalysisRange (D2) and ProposalId (D3).
    2.0.0 - Enforced PowerShell governance header, removed unauthorized \Home subpath,
            and enabled multi-analysis dynamic parameterization.
    1.0.0 - Initial stub implementation.
.PARAMETER AnalysisRange
    Analysis sequence number or range (e.g. 1, 01, 01-02).
.PARAMETER ProposalId
    Proposal numeric identifier or prefixed code (e.g. 5, 005, CRP-005).
.PARAMETER Title
    Short descriptive title or slug for the proposal.
.PARAMETER Purpose
    Purpose statement for the change request.
.PARAMETER ProposedChanges
    Array of change bullet points.
.PARAMETER DriveRoot
    Root drive for Google Drive synchronization. Defaults to D:\GDrive.
.PARAMETER StagingSubPath
    Subdirectory within DriveRoot for proposal staging. Defaults to LCM_ConvergenceProposals.
.PARAMETER Help
    Displays command syntax and usage instructions (Aliases: -h, -?).
.EXAMPLE
    pwsh Create-LCM-CRP.ps1 -Analysis 01 -CRP 005 -Title "Rule-Persistence-Architecture"
.EXAMPLE
    pwsh Create-LCM-CRP.ps1 -h
#>

[CmdletBinding(DefaultParameterSetName = 'Execute')]
param(
    [Parameter(ParameterSetName = 'Execute', Mandatory = $true, Position = 0, HelpMessage = 'Analysis number or range (e.g. 01, 1, 01-02)')]
    [Alias('Analysis', 'A')]
    [string]$AnalysisRange,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $true, Position = 1, HelpMessage = 'Proposal ID (e.g. 005, 5, CRP-005)')]
    [Alias('CRP', 'Id', 'P')]
    [string]$ProposalId,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $true, Position = 2, HelpMessage = 'Short descriptive title')]
    [Alias('ShortName', 'Name', 'S')]
    [string]$Title,

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false)]
    [string]$Purpose = 'LCM architectural convergence and rule standardization.',

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false)]
    [string[]]$ProposedChanges = @('Automated proposal generation from analysis.'),

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false)]
    [string]$DriveRoot = 'D:\GDrive',

    [Parameter(ParameterSetName = 'Execute', Mandatory = $false)]
    [string]$StagingSubPath = 'LCM_ConvergenceProposals',

    [Parameter(ParameterSetName = 'Help', Mandatory = $false)]
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " CREATE LCM CHANGE REQUEST PROPOSAL (v2.2.0)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Generates a standardized Change Request Proposal (CRP) markdown file"
    Write-Host "  and stages it directly into D:\GDrive\LCM_ConvergenceProposals\."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  Create-LCM-CRP.ps1 -Analysis <range> -CRP <id> -Title <short-name> [-Purpose <str>] [-h]"
    Write-Host "  Create-LCM-CRP.ps1 <range> <id> <short-name>"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  Create-LCM-CRP.ps1 -Analysis 1 -CRP 5 -Title Rule-Persistence-Architecture"
    Write-Host "  Create-LCM-CRP.ps1 -Analysis 01 -CRP CRP-005 -Title 'Rule-Persistence-Architecture'"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

# Normalize identifiers
$formattedAnalysis = if ($AnalysisRange -match '^\d+$') { "{0:D2}" -f [int]$AnalysisRange } else { $AnalysisRange }
$cleanProposalId = $ProposalId -replace '^CRP-?', ''
$formattedProposalId = if ($cleanProposalId -match '^\d+$') { "{0:D3}" -f [int]$cleanProposalId } else { $cleanProposalId }

# Resolve target path strictly without unauthorized subpaths
$TargetDir = Join-Path $DriveRoot $StagingSubPath
if (-not (Test-Path -LiteralPath $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$sanitizedTitle = $Title -replace '[\\/:*?"<>| ]', '-'
$fileName = "Analysis-{0}_CRP-{1}-{2}.md" -f $formattedAnalysis, $formattedProposalId, $sanitizedTitle
$filePath = Join-Path $TargetDir $fileName

$changesMarkdown = ""
foreach ($change in $ProposedChanges) {
    $changesMarkdown += "- $change`n"
}

$crpContent = @"
# Change Request Proposal: Analysis #$formattedAnalysis - $Title

## Metadata
- **Proposal ID:** CRP-$formattedProposalId
- **Target Analysis:** Analysis #$formattedAnalysis
- **Status:** OPEN
- **Staging Location:** $TargetDir\
- **Author:** Automated LCM Generator

## Purpose
$Purpose

## Proposed Changes
$changesMarkdown

## Verification
- Validate schema compliance under IDE workspace rules.
- Confirm local synchronization via canonical D:\GDrive mount.
"@

Set-Content -LiteralPath $filePath -Value $crpContent -Encoding UTF8
Write-Host "CRP successfully generated at: $filePath" -ForegroundColor Green
