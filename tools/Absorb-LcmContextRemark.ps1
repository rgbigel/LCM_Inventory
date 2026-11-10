<#
.SYNOPSIS
  Absorbs an operator remark from ACTIVE_CONTEXT.md into a target CRP specification, performing contradiction checks and uncluttering the source (RULE-LCM-031).
.DESCRIPTION
  Module: tools/Absorb-LcmContextRemark.ps1
  Purpose: Enforces the "Reverse the Ticket" pattern codified in RULE-LCM-031. When an operator remark is taken
           up by an active CRP, the verbatim text is checked for semantic contradictions, incorporated into the
           CRP's Specification.md under '## Absorbed Operator Remarks', and immediately removed from ACTIVE_CONTEXT.md.
  Path: LCM_Inventory/tools/Absorb-LcmContextRemark.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-11-10 18:48:00
  Rule: RULE-LCM-031, RULE-DOC-003, RULE-PS-001 - RULE-PS-025
.PARAMETER Id
  Proposal ID number (e.g. 280, 267) or CRP identifier (e.g. CRP-280, BUG-311).
.PARAMETER TextMatch
  Substring or regex pattern matching the operator remark in ACTIVE_CONTEXT.md to absorb.
.PARAMETER DryRun
  Previews absorption and removal without modifying ACTIVE_CONTEXT.md or the proposal specification.
.PARAMETER CheckOnly
  Performs contradiction analysis between the remark and the target CRP specification without mutating files.
.PARAMETER Help
  Displays parameter reference and syntax.
.EXAMPLE
  pwsh LCM_Inventory/tools/Absorb-LcmContextRemark.ps1 -Id 312 -TextMatch "duplicate viewer"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Id,

  [Parameter(Mandatory = $true, Position = 1)]
  [string]$TextMatch,

  [switch]$DryRun,
  [switch]$CheckOnly,
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " ABSORB LCM CONTEXT REMARK (RULE-LCM-031) v10.0.0" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Transfers an operator remark from ACTIVE_CONTEXT.md into a CRP specification,"
  Write-Host "  checks for semantic contradiction, and removes the source entry (unclutter)."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Absorb-LcmContextRemark.ps1 -Id <CRP-ID> -TextMatch <pattern> [-DryRun] [-CheckOnly] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Id <string>        : Target proposal ID (e.g. 267 or 'CRP-267')."
  Write-Host "  -TextMatch <string> : Substring or regex pattern matching the remark to absorb."
  Write-Host "  -DryRun             : Preview changes without modifying files."
  Write-Host "  -CheckOnly          : Validate contradiction status only."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Resolve Workspace Paths & Proposal
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
$contextFile = Join-Path $workspaceRoot '.agents\ACTIVE_CONTEXT.md'
if (-not (Test-Path -LiteralPath $contextFile)) {
  throw "ACTIVE_CONTEXT.md was not found at expected path: $contextFile"
}

$proposalModule = Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'
if (-not (Test-Path -LiteralPath $proposalModule)) {
  throw "ProposalManager module missing at: $proposalModule"
}
Import-Module -Name $proposalModule -Force

$numId = 0
if ($Id -match '^(?:CRP-|BUG-)?(\d+)$') {
  $numId = [int]$Matches[1]
} else {
  throw "Invalid proposal ID format: '$Id'. Must be integer or 'CRP-XXX' / 'BUG-XXX'."
}

$store = Get-ProposalStore
$proposal = @($store.proposals | Where-Object { [int]$_.id -eq $numId })
if ($proposal.Count -eq 0) {
  throw "Proposal #$numId was not found in proposals.json."
}
$targetProposal = $proposal[0]

# Locate proposal specification file
$specRelative = if ($targetProposal.bundle_dir) {
  Join-Path $targetProposal.bundle_dir "Specification.md"
} else {
  "docs/Proposals/CRP-$numId/Specification.md"
}

$specPath = Join-Path $workspaceRoot $specRelative
if (-not (Test-Path -LiteralPath $specPath)) {
  $specPath = Join-Path (Join-Path $workspaceRoot 'LCM_Inventory') $specRelative
}
if (-not (Test-Path -LiteralPath $specPath)) {
  throw "Specification document for Proposal #$numId not found: $specRelative"
}

# ------------------------------------------------------------------------------
# 2. Extract Matching Remark from ACTIVE_CONTEXT.md
# ------------------------------------------------------------------------------
$contextLines = [System.Collections.Generic.List[string]]::new()
$contextLines.AddRange([string[]]@([System.IO.File]::ReadAllLines($contextFile)))

$remarksHeader = $contextLines.FindIndex([Predicate[string]]{ param($l) $l -like '## Operator Remarks*' })
if ($remarksHeader -lt 0) {
  throw "Section '## Operator Remarks' was not found in ACTIVE_CONTEXT.md"
}

# Locate end of Operator Remarks section (next ## header or EOF)
$remarksEnd = $contextLines.Count
for ($i = $remarksHeader + 1; $i -lt $contextLines.Count; $i++) {
  if ($contextLines[$i] -match '^##\s+[^#]') {
    $remarksEnd = $i
    break
  }
}

$matchStart = -1
$matchEnd = -1

for ($i = $remarksHeader + 1; $i -lt $remarksEnd; $i++) {
  $line = $contextLines[$i]
  if ($line -match [regex]::Escape($TextMatch) -or $line -like "*$TextMatch*") {
    # Find start of this bullet/paragraph block
    $s = $i
    while ($s -gt ($remarksHeader + 1) -and -not ($contextLines[$s] -match '^(\s*[-*]|\s*\d+\.|\s*###)')) {
      $s--
    }
    $matchStart = $s

    # Find end of this bullet/paragraph block
    $e = $i + 1
    while ($e -lt $remarksEnd -and -not ($contextLines[$e] -match '^(\s*[-*]|\s*\d+\.|\s*###|^---)')) {
      $e++
    }
    $matchEnd = $e
    break
  }
}

if ($matchStart -lt 0) {
  throw "No operator remark matching pattern '$TextMatch' was found under '## Operator Remarks' in ACTIVE_CONTEXT.md"
}

$extractedBlock = @($contextLines[$matchStart..($matchEnd - 1)])
$extractedText = ($extractedBlock -join "`r`n").Trim()

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " [REVERSE-THE-TICKET] Discovered Operator Remark in ACTIVE_CONTEXT.md:" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host $extractedText -ForegroundColor DarkYellow
Write-Host "--------------------------------------------------------------------------" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 3. Contradiction Pre-Check
# ------------------------------------------------------------------------------
$specContent = [System.IO.File]::ReadAllText($specPath)

# Check for explicit contradictions: e.g. text demands retention when CRP deletes, or vice versa
$contradictionFound = $false
$contradictionReason = ""

# Example contradiction heuristic: If remark explicitly prohibits an action the CRP title/details mandates
if ($extractedText -match "(?i)\bdo not\b|\bnever\b|\bprohibit\b" -and $targetProposal.title -match "(?i)\benable\b|\bactivate\b|\breinstate\b") {
  $contradictionFound = $true
  $contradictionReason = "Remark contains prohibition terms ('do not'/'never'/'prohibit') while CRP title contains activation terms ('enable'/'activate'/'reinstate')."
}

if ($contradictionFound) {
  Write-Host " [WARNING] Semantic contradiction detected between remark and CRP #$($numId):" -ForegroundColor Red
  Write-Host "   $contradictionReason" -ForegroundColor Red
  if (-not $DryRun -and -not $CheckOnly) {
    throw "RULE-LCM-031 Invariant Violation: Semantic contradiction detected. Reconcile explicitly before absorption."
  }
} else {
  Write-Host " [OK] Contradiction pre-check passed: No obvious semantic conflict with Proposal #$($numId)." -ForegroundColor Green
}

if ($CheckOnly) {
  Write-Host " CheckOnly mode requested. No changes persisted." -ForegroundColor Gray
  return
}

# ------------------------------------------------------------------------------
# 4. Ingest Verbatim Remark into CRP Specification
# ------------------------------------------------------------------------------
$stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$absorbedSection = @"


## Absorbed Operator Remarks (RULE-LCM-031)
- **Absorbed Timestamp**: $stamp
- **Source File**: `.agents/ACTIVE_CONTEXT.md`
- **Original Text**:
> $($extractedText -replace "`r?`n", "`r`n> ")
"@

if ($specContent -notmatch '## Absorbed Operator Remarks') {
  $updatedSpec = $specContent.TrimEnd() + "`r`n" + $absorbedSection + "`r`n"
} else {
  # Append to existing section
  $insertPoint = $specContent.IndexOf('## Absorbed Operator Remarks')
  $nextHeader = $specContent.IndexOf("`n## ", $insertPoint + 28)
  if ($nextHeader -ge 0) {
    $updatedSpec = $specContent.Substring(0, $nextHeader) + "`r`n" + $absorbedSection + "`r`n" + $specContent.Substring($nextHeader)
  } else {
    $updatedSpec = $specContent.TrimEnd() + "`r`n" + $absorbedSection + "`r`n"
  }
}

# ------------------------------------------------------------------------------
# 5. Remove Remark from ACTIVE_CONTEXT.md (Unclutter)
# ------------------------------------------------------------------------------
# Remove lines from matchEnd - 1 down to matchStart
$removeCount = $matchEnd - $matchStart
for ($k = $matchEnd - 1; $k -ge $matchStart; $k--) {
  $contextLines.RemoveAt($k)
}

# Clean up any trailing double blank lines
$updatedContext = ($contextLines -join "`r`n") -replace "(\r?\n){3,}", "`r`n`r`n"

# ------------------------------------------------------------------------------
# 6. Apply or Preview Changes
# ------------------------------------------------------------------------------
if ($DryRun) {
  Write-Host ""
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " [DRY-RUN] Proposed Absorption into $($specRelative):" -ForegroundColor Yellow
  Write-Host $absorbedSection -ForegroundColor White
  Write-Host " [DRY-RUN] Removed $removeCount line(s) from ACTIVE_CONTEXT.md (lines $matchStart to $($matchEnd - 1))." -ForegroundColor Yellow
  Write-Host " [DRY-RUN] No files were modified." -ForegroundColor Green
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($specPath, $updatedSpec, $utf8NoBom)
[System.IO.File]::WriteAllText($contextFile, $updatedContext, $utf8NoBom)

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " [SUCCESS] Ingested remark into Proposal #$numId ($specRelative)" -ForegroundColor Green
Write-Host " [SUCCESS] Uncluttered ACTIVE_CONTEXT.md (removed $removeCount line(s))" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan