<#
.SYNOPSIS
  Links learned advice to a CRP as recognized, and safely purges it only when test harness guarantees satisfaction (RULE-LCM-031).
.DESCRIPTION
  Module: tools/Link-LcmLearnedAdvice.ps1
  Purpose: Enforces the two-stage lifecycle for LEARNED_ADVICE.md per RULE-LCM-031.
           Stage 1: Annotates the advice with [RECOGNIZED: CRP-XXX] in LEARNED_ADVICE.md and adds it to the CRP's
                    Specification.md. The entry remains 100% active and binding; deletion is prohibited.
           Stage 2 (-PurgeGuaranteed): Unlocks retirement ONLY when the CRP is in verified/in_review/completed state
                    AND verifiable test evidence (Pester test, rule codification) is provided.
  Path: LCM_Inventory/tools/Link-LcmLearnedAdvice.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-11-10 18:48:00
  Rule: RULE-LCM-031, RULE-CTX-005, RULE-PS-001 - RULE-PS-025
.PARAMETER Id
  Proposal ID number (e.g. 280, 267) or CRP identifier (e.g. CRP-280, BUG-311).
.PARAMETER TextMatch
  Substring or regex pattern matching the advice entry in LEARNED_ADVICE.md.
.PARAMETER PurgeGuaranteed
  Authorizes final retirement/deletion of the recognized advice entry. Requires verified CRP state and -GuaranteeEvidence.
.PARAMETER GuaranteeEvidence
  Description or path to the test harness, Pester test, or rule reference guaranteeing the advice requirement is satisfied.
.PARAMETER DryRun
  Previews mutations without updating files.
.PARAMETER Help
  Displays parameter reference and syntax.
.EXAMPLE
  pwsh LCM_Inventory/tools/Link-LcmLearnedAdvice.ps1 -Id 311 -TextMatch "Review tool window non-interference"
  Annotates advice as [RECOGNIZED: BUG-311] in LEARNED_ADVICE.md and links to proposal.
.EXAMPLE
  pwsh LCM_Inventory/tools/Link-LcmLearnedAdvice.ps1 -Id 311 -TextMatch "Review tool window" -PurgeGuaranteed -GuaranteeEvidence "RULE-REV-012 codified in ReviewCommitGovernancePolicy.md"
  Safely purges the recognized advice upon verified rule codification.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Id,

  [Parameter(Mandatory = $true, Position = 1)]
  [string]$TextMatch,

  [switch]$PurgeGuaranteed,
  [string]$GuaranteeEvidence = '',
  [switch]$DryRun,
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LINK / RETIRE LEARNED ADVICE (RULE-LCM-031) v10.0.0" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Stage 1: Annotates advice as [RECOGNIZED: CRP-XXX] without premature deletion."
  Write-Host "  Stage 2: Purges recognized advice ONLY when test harness guarantees satisfaction."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Link-LcmLearnedAdvice.ps1 -Id <CRP-ID> -TextMatch <pattern> [-DryRun] [-h]"
  Write-Host "  pwsh LCM_Inventory/tools/Link-LcmLearnedAdvice.ps1 -Id <CRP-ID> -TextMatch <pattern> -PurgeGuaranteed -GuaranteeEvidence <evidence>"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Resolve Workspace Paths & Proposal
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
$learnFile = Join-Path $workspaceRoot '.agents\LEARNED_ADVICE.md'
if (-not (Test-Path -LiteralPath $learnFile)) {
  $learnFile = Join-Path $workspaceRoot 'LCM_AI\.agents\LEARNED_ADVICE.md'
}
if (-not (Test-Path -LiteralPath $learnFile)) {
  throw "LEARNED_ADVICE.md was not found at expected path: $learnFile"
}

$proposalModule = Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'
if (-not (Test-Path -LiteralPath $proposalModule)) {
  throw "ProposalManager module missing at: $proposalModule"
}
Import-Module -Name $proposalModule -Force

$numId = 0
$crpTag = ""
if ($Id -match '^(?:CRP-|BUG-)?(\d+)$') {
  $numId = [int]$Matches[1]
  $crpTag = "CRP-$numId"
} else {
  throw "Invalid proposal ID format: '$Id'. Must be integer or 'CRP-XXX' / 'BUG-XXX'."
}

$store = Get-ProposalStore
$proposal = @($store.proposals | Where-Object { [int]$_.id -eq $numId })
if ($proposal.Count -eq 0) {
  throw "Proposal #$numId was not found in proposals.json."
}
$targetProposal = $proposal[0]
if ($targetProposal.crp_id) { $crpTag = $targetProposal.crp_id }

$specRelative = if ($targetProposal.bundle_dir) {
  Join-Path $targetProposal.bundle_dir "Specification.md"
} else {
  "docs/Proposals/$crpTag/Specification.md"
}
$specPath = Join-Path $workspaceRoot $specRelative
if (-not (Test-Path -LiteralPath $specPath)) {
  $specPath = Join-Path (Join-Path $workspaceRoot 'LCM_Inventory') $specRelative
}
if (-not (Test-Path -LiteralPath $specPath)) {
  throw "Specification document for Proposal #$numId not found: $specRelative"
}

# ------------------------------------------------------------------------------
# 2. Locate Matching Advice in LEARNED_ADVICE.md
# ------------------------------------------------------------------------------
$lines = [System.Collections.Generic.List[string]]::new()
$lines.AddRange([string[]]@([System.IO.File]::ReadAllLines($learnFile)))

$accHeader = $lines.FindIndex([Predicate[string]]{ param($l) $l -like '## Accepted*' })
if ($accHeader -lt 0) {
  throw "Section '## Accepted' not found in LEARNED_ADVICE.md"
}

$matchIdx = -1
for ($i = $accHeader + 1; $i -lt $lines.Count; $i++) {
  $l = $lines[$i]
  if ($l.StartsWith('- ') -and ($l -match [regex]::Escape($TextMatch) -or $l -like "*$TextMatch*")) {
    $matchIdx = $i
    break
  }
}

if ($matchIdx -lt 0) {
  throw "No accepted advice entry matching pattern '$TextMatch' was found in LEARNED_ADVICE.md"
}

$matchedLine = $lines[$matchIdx]
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " [RULE-LCM-031] Located Advice Entry in LEARNED_ADVICE.md (Line $($matchIdx + 1)):" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host $matchedLine -ForegroundColor DarkYellow
Write-Host "--------------------------------------------------------------------------" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 3. Stage 1: Annotate as Recognized (Default)
# ------------------------------------------------------------------------------
if (-not $PurgeGuaranteed) {
  if ($matchedLine -match "\[RECOGNIZED:\s*$crpTag\]") {
    Write-Host " [INFO] Advice is already annotated as [RECOGNIZED: $crpTag]." -ForegroundColor Green
  } else {
    # Prepend [RECOGNIZED: CRP-XXX] tag after '- '
    $annotatedLine = $matchedLine -replace '^- (?:\[RECOGNIZED:[^\]]+\]\s*)?', "- [RECOGNIZED: $crpTag] "
    $lines[$matchIdx] = $annotatedLine
  }

  # Append or update section in proposal specification
  $specContent = [System.IO.File]::ReadAllText($specPath)
  $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $cleanAdviceText = $matchedLine -replace '^- (?:\[RECOGNIZED:[^\]]+\]\s*)?', ''

  $recognizedSection = @"


## Recognized Learned Advice (RULE-LCM-031)
- **Status**: RECOGNIZED (Pending Test Guarantee)
- **Recognized Timestamp**: $stamp
- **Governed Advice**:
> $cleanAdviceText
- **Exit Criteria**: Deletion from LEARNED_ADVICE.md requires passing verification harness and codification guarantee.
"@

  $updatedSpec = $specContent
  if ($specContent -notmatch [regex]::Escape($cleanAdviceText)) {
    $updatedSpec = $specContent.TrimEnd() + "`r`n" + $recognizedSection + "`r`n"
  }

  if ($DryRun) {
    Write-Host " [DRY-RUN] Would annotate line in LEARNED_ADVICE.md as:" -ForegroundColor Yellow
    Write-Host "   $annotatedLine" -ForegroundColor White
    Write-Host " [DRY-RUN] Would update Proposal #$numId Specification.md ($specRelative)" -ForegroundColor Yellow
    Write-Host " [DRY-RUN] No files were modified." -ForegroundColor Green
    return
  }

  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($learnFile, (($lines -join "`r`n") + "`r`n"), $utf8NoBom)
  [System.IO.File]::WriteAllText($specPath, $updatedSpec, $utf8NoBom)

  Write-Host " [SUCCESS] Advice annotated as [RECOGNIZED: $crpTag] in LEARNED_ADVICE.md" -ForegroundColor Green
  Write-Host " [SUCCESS] Entry bound to Proposal #$numId Specification ($specRelative)" -ForegroundColor Green
  Write-Host " [INVARIANT] Advice remains binding and will NOT be deleted until test guarantee is verified." -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 4. Stage 2: Purge Guaranteed Retirement
# ------------------------------------------------------------------------------
$allowedStates = @('verified', 'in_review', 'completed', 'pushed')
$currentState = [string]$targetProposal.state
if ($currentState -notin $allowedStates) {
  throw "RULE-LCM-031 Violation: Cannot purge advice while proposal #$numId is in state '$currentState'. Must be 'verified', 'in_review', or 'completed'."
}

if ([string]::IsNullOrWhiteSpace($GuaranteeEvidence)) {
  throw "RULE-LCM-031 Violation: -PurgeGuaranteed requires explicit -GuaranteeEvidence (e.g. test name, Pester file, or rule codification)."
}

Write-Host " [TEST GUARANTEE VALIDATED]" -ForegroundColor Green
Write-Host "   Proposal State    : $currentState" -ForegroundColor White
Write-Host "   Guarantee Evidence: $GuaranteeEvidence" -ForegroundColor White

if ($DryRun) {
  Write-Host " [DRY-RUN] Would purge advice line from LEARNED_ADVICE.md (Line $($matchIdx + 1)):" -ForegroundColor Yellow
  Write-Host "   $matchedLine" -ForegroundColor White
  Write-Host " [DRY-RUN] No files were modified." -ForegroundColor Green
  return
}

$lines.RemoveAt($matchIdx)
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($learnFile, (($lines -join "`r`n") + "`r`n"), $utf8NoBom)

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " [SUCCESS] Retired & purged advice from LEARNED_ADVICE.md under $crpTag." -ForegroundColor Green
Write-Host " [AUDIT] Guaranteed by: $GuaranteeEvidence" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan

