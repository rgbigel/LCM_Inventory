<#
.SYNOPSIS
  Queries the LCM inbox two-phase acknowledgement back-channel for Gemini Cloud.
.DESCRIPTION
  Module: Get-GeminiInboxStatus
  Purpose: Allows Google Gemini, Gems, or operators to inspect the durable acknowledgement
           back-channel (CRP-263). Queries Phase 1 (Receipt) and Phase 2 (Terminal Success / Failure)
           acknowledgements by correlation ID or lists recent submissions.
  Path: LCM_Inventory/tools/Get-GeminiInboxStatus.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-11-10
.PARAMETER CorrelationId
  The exact correlation identifier of the inbox submission (e.g. INBOX-BUG-20261110-12345).
.PARAMETER InboxPath
  Path to Google Drive inbox. Defaults to 'D:\GDrive\LCM\INBOX'.
.PARAMETER AckLedgerPath
  Path to governed CM acknowledgement ledger. Defaults to 'LCM_Inventory/data/inbox/acks'.
.PARAMETER Latest
  Number of recent acknowledgement records to return when -CorrelationId is omitted. Defaults to 10.
.PARAMETER AsJson
  Emits formatted JSON result.
.PARAMETER PassThru
  Emits acknowledgement objects to pipeline.
.PARAMETER Help
  Displays parameter reference and usage (-h / -Help / -?).
.EXAMPLE
  pwsh LCM_Inventory/tools/Get-GeminiInboxStatus.ps1 -CorrelationId 'INBOX-BUG-20261110-01'
  Inspects the status of a specific submitted inbox item.
.EXAMPLE
  pwsh LCM_Inventory/tools/Get-GeminiInboxStatus.ps1 -Latest 5
  Lists the 5 most recent inbox acknowledgements.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0)]
  [string]$CorrelationId = '',

  [Parameter(Mandatory = $false)]
  [string]$InboxPath = 'D:\GDrive\LCM\INBOX',

  [Parameter(Mandatory = $false)]
  [string]$AckLedgerPath = 'D:\Git_Repositories\LCM_Inventory\data\inbox\acks',

  [Parameter(Mandatory = $false)]
  [int]$Latest = 10,

  [switch]$AsJson,

  [switch]$PassThru,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = '10.0.0'
$scriptName = 'Get-GeminiInboxStatus'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " GEMINI INBOX ACKNOWLEDGEMENT STATUS QUERY (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Queries Phase 1 (Receipt) and Phase 2 (Terminal) inbox acknowledgements (CRP-263)."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Get-GeminiInboxStatus.ps1 [-CorrelationId <id>] [-Latest <n>] [-AsJson] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -CorrelationId <id>     : Exact correlation ID to query."
  Write-Host "  -InboxPath <dir>        : Google Drive inbox folder (Default: 'D:\GDrive\LCM\INBOX')."
  Write-Host "  -AckLedgerPath <dir>    : Governed CM ledger folder."
  Write-Host "  -Latest <int>           : Max records to list when CorrelationId is omitted (Default: 10)."
  Write-Host "  -AsJson                 : Output formatted JSON."
  Write-Host "  -PassThru               : Emit objects to pipeline."
  Write-Host "  -h, -Help, -?           : Displays this help."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# Search candidate folders
$candidateDirs = @()
if (-not [string]::IsNullOrWhiteSpace($AckLedgerPath) -and (Test-Path -LiteralPath $AckLedgerPath)) {
  $candidateDirs += $AckLedgerPath
}
$gdriveAcks = Join-Path $InboxPath 'acks'
if (Test-Path -LiteralPath $gdriveAcks) {
  $candidateDirs += $gdriveAcks
}
$gdriveAckAlt = Join-Path $InboxPath 'ack'
if (Test-Path -LiteralPath $gdriveAckAlt) {
  $candidateDirs += $gdriveAckAlt
}

if ($candidateDirs.Count -eq 0) {
  Write-Host "No acknowledgement directories found (checked $AckLedgerPath, $gdriveAcks)." -ForegroundColor Yellow
  return
}

if (-not [string]::IsNullOrWhiteSpace($CorrelationId)) {
  $foundRecord = $null
  foreach ($dir in $candidateDirs) {
    $targetFile = Join-Path $dir "$CorrelationId.json"
    if (Test-Path -LiteralPath $targetFile) {
      $raw = [System.IO.File]::ReadAllText($targetFile, [System.Text.Encoding]::UTF8)
      $foundRecord = ($raw | ConvertFrom-Json)
      break
    }
  }

  if ($null -eq $foundRecord) {
    Write-Host "Acknowledgement record not found for Correlation ID: '$CorrelationId'" -ForegroundColor Yellow
    return
  }

  if ($AsJson) {
    $foundRecord | ConvertTo-Json -Depth 4
    if ($PassThru) { return $foundRecord }
    return
  }

  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " INBOX SUBMISSION STATUS: $CorrelationId" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " Source File  : $($foundRecord.source_file)" -ForegroundColor White
  Write-Host " Current Phase: Phase $($foundRecord.phase) $(if ($foundRecord.phase -eq 1) { '(Receipt Acknowledged)' } else { '(Terminal Outcome)' })" -ForegroundColor White
  Write-Host " Status       : $($foundRecord.status)" -ForegroundColor $(if ($foundRecord.status -eq 'SUCCESS') { 'Green' } elseif ($foundRecord.status -eq 'FAILURE') { 'Red' } else { 'Yellow' })
  Write-Host " Timestamp    : $($foundRecord.timestamp)" -ForegroundColor Gray
  if ($null -ne $foundRecord.proposal_id) {
    Write-Host " Proposal ID  : #$($foundRecord.proposal_id)" -ForegroundColor Green
  }
  if ($null -ne $foundRecord.error) {
    Write-Host " Failure Reason: $($foundRecord.error)" -ForegroundColor Red
  }
  if ($null -ne $foundRecord.details) {
    Write-Host " Details      : $($foundRecord.details)" -ForegroundColor DarkGray
  }
  Write-Host "==========================================================================" -ForegroundColor Cyan

  if ($PassThru) { return $foundRecord }
  return
}

# List latest records
$ackFiles = @()
$seenIds = [System.Collections.Generic.HashSet[string]]::new()
$allRecords = @()

foreach ($dir in $candidateDirs) {
  $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File | Sort-Object LastWriteTime -Descending)
  foreach ($f in $files) {
    $id = $f.BaseName
    if (-not $seenIds.Contains($id)) {
      $seenIds.Add($id) | Out-Null
      try {
        $raw = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        $rec = ($raw | ConvertFrom-Json)
        $allRecords += $rec
      } catch {}
    }
  }
}

$sortedRecords = @($allRecords | Sort-Object { $_.timestamp } -Descending | Select-Object -First $Latest)

if ($AsJson) {
  $sortedRecords | ConvertTo-Json -Depth 4
  if ($PassThru) { return $sortedRecords }
  return
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " RECENT INBOX ACKNOWLEDGEMENTS (Showing up to $Latest)" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($sortedRecords.Count -eq 0) {
  Write-Host "No acknowledgement records recorded yet." -ForegroundColor DarkGray
  return
}

$displayList = @()
foreach ($r in $sortedRecords) {
  $displayList += [PSCustomObject]@{
    CorrelationId = $r.correlation_id
    SourceFile    = $r.source_file
    Phase         = $r.phase
    Status        = $r.status
    ProposalId    = if ($null -ne $r.proposal_id) { $r.proposal_id } else { '-' }
    Timestamp     = $r.timestamp
  }
}

$displayList | Format-Table -AutoSize | Out-Host

if ($PassThru) { return $sortedRecords }
