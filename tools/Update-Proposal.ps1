<#
.SYNOPSIS
  Update LCM_AI proposal disposition records deterministically.

.PARAMETER Id
  Target proposal identifier to update.

.PARAMETER Disposition
  Updated proposal review disposition (pending-review, accepted, rejected, modified).

.PARAMETER DispositionReason
  Reason or rationale for the review disposition update.

.PARAMETER FinalResult
  Final execution or validation result string.

.PARAMETER ProposalLogPath
  Path to authoritative Proposals.json ledger.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Target proposal identifier to update.')]
  [string]$Id,

  [Parameter(Mandatory = $false, HelpMessage = 'Updated proposal review disposition (pending-review, accepted, rejected, modified).')]
  [ValidateSet('pending-review', 'accepted', 'rejected', 'modified')]
  [string]$Disposition,

  [Parameter(Mandatory = $false, HelpMessage = 'Reason or rationale for the review disposition update.')]
  [string]$DispositionReason,

  [Parameter(Mandatory = $false, HelpMessage = 'Final execution or validation result string.')]
  [string]$FinalResult,

  [Parameter(Mandatory = $false, HelpMessage = 'Path to authoritative Proposals.json ledger.')]
  [string]$ProposalLogPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Update-Proposal.ps1 - Update proposal disposition records." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Update-Proposal.ps1 -Id <id> [-Disposition <disp>] [-DispositionReason <reason>] [-FinalResult <result>] [-ProposalLogPath <path>] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -Id                Proposal identifier."
  Write-Host "  -Disposition       Review disposition state."
  Write-Host "  -DispositionReason Rationale for state update."
  Write-Host "  -FinalResult       Final validation result."
  Write-Host "  -ProposalLogPath   Path to Proposals.json."
  Write-Host "  -Help (-h, -?)     Displays this help message."
  exit 0
}

if (-not $Id) {
  throw "Parameter -Id is required."
}

if (-not $ProposalLogPath) {
  $copilotRoot = Split-Path $PSScriptRoot -Parent
  $ProposalLogPath = Join-Path $PSScriptRoot 'Logs\Proposals.json'
}

if (-not (Test-Path -LiteralPath $ProposalLogPath)) {
  throw "Proposal registry not found: $ProposalLogPath"
}

$proposalState = Get-Content -Raw -Path $ProposalLogPath | ConvertFrom-Json
$proposal = @($proposalState.proposals) | Where-Object { $_.id -eq $Id } | Select-Object -First 1

if (-not $proposal) {
  throw "Proposal not found: $Id"
}

if ($PSBoundParameters.ContainsKey('Disposition')) {
  $proposal.disposition = $Disposition
}

if ($PSBoundParameters.ContainsKey('DispositionReason')) {
  if ($proposal.PSObject.Properties['disposition_reason']) {
    $proposal.disposition_reason = $DispositionReason
  } else {
    $proposal | Add-Member -NotePropertyName 'disposition_reason' -NotePropertyValue $DispositionReason
  }
}

if ($PSBoundParameters.ContainsKey('FinalResult')) {
  if ($proposal.PSObject.Properties['final_result']) {
    $proposal.final_result = $FinalResult
  } else {
    $proposal | Add-Member -NotePropertyName 'final_result' -NotePropertyValue $FinalResult
  }
}

if (($proposal.disposition -eq 'rejected' -or $proposal.disposition -eq 'modified') -and -not $proposal.PSObject.Properties['disposition_reason']) {
  throw "Proposal requires disposition_reason for disposition '$($proposal.disposition)': $Id"
}

$proposalState | ConvertTo-Json -Depth 8 | Set-Content -Path $ProposalLogPath -Encoding utf8
Write-Host "Updated proposal: $Id"
Write-Host "Disposition: $($proposal.disposition)"