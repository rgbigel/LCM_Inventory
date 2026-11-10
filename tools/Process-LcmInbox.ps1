<#
.SYNOPSIS
  Processes pending LCM inbox items with a two-phase acknowledgement protocol.
.DESCRIPTION
  Module: Process-LcmInbox
  Purpose: Ingests external input files dropped in the LCM Inbox (e.g. D:\GDrive\LCM\INBOX)
           using the authoritative two-phase acknowledgement protocol (CRP-263):
           Phase 1: Persists immediate receipt ACK before parsing or proposal intake.
           Phase 2: Persists terminal success ACK with proposal ID, or terminal failure ACK
           with actionable diagnostics.
  Path: LCM_Inventory/tools/Process-LcmInbox.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-11-10
.PARAMETER InboxPath
  Path to the source inbox folder. Defaults to 'D:\GDrive\LCM\INBOX'.
.PARAMETER ArchivePath
  Path to the archive folder for processed items. Defaults to 'D:\GDrive\LCM\INBOX\archive'.
.PARAMETER AckPath
  Sender-visible acknowledgement return channel folder. Defaults to 'D:\GDrive\LCM\INBOX\ack'.
.PARAMETER AckLedgerPath
  CM-governed persistent acknowledgement store. Defaults to 'LCM_Inventory/data/inbox_ack'.
.PARAMETER Watch
  Runs in continuous scheduled watching loop.
.PARAMETER IntervalSeconds
  Polling interval when running in -Watch mode. Defaults to 30 seconds.
.PARAMETER DryRun
  Simulates intake and Phase 1 receipt ACK without modifying the proposal ledger or moving files.
.PARAMETER LogFile
  Custom log file path.
.PARAMETER Help
  Displays command syntax and parameter reference (-h / -Help / -?).
.EXAMPLE
  pwsh LCM_Inventory/tools/Process-LcmInbox.ps1
  Performs one-shot intake of pending inbox items with two-phase ACK.
.EXAMPLE
  pwsh LCM_Inventory/tools/Process-LcmInbox.ps1 -Watch -IntervalSeconds 15
  Runs continuous watcher with two-phase ACK protocol.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$InboxPath = 'D:\GDrive\LCM\INBOX',

  [Parameter(Mandatory = $false)]
  [string]$ArchivePath = 'D:\GDrive\LCM\INBOX\archive',

  [Parameter(Mandatory = $false)]
  [string]$AckPath = '',

  [Parameter(Mandatory = $false)]
  [string]$AckLedgerPath = '',

  [switch]$Watch,

  [int]$IntervalSeconds = 30,

  [switch]$DryRun,

  [string]$LogFile = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = '10.0.0'
$scriptName = 'Process-LcmInbox'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM TWO-PHASE INBOX PROCESSOR (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Ingests incoming Gemini instructions & reports using two-phase ACK (CRP-263):"
  Write-Host "  Phase 1: Immediate receipt ACK persisted before irreversible intake."
  Write-Host "  Phase 2: Terminal success/failure ACK after processing concludes."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Process-LcmInbox.ps1 [-InboxPath <dir>] [-Watch] [-DryRun] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -InboxPath <dir>        : Source inbox folder (Default: 'D:\GDrive\LCM\INBOX')."
  Write-Host "  -ArchivePath <dir>      : Archive directory for absorbed items."
  Write-Host "  -AckPath <dir>          : Sender-facing ACK return channel."
  Write-Host "  -AckLedgerPath <dir>    : Governed CM ACK ledger."
  Write-Host "  -Watch                  : Runs continuously in background polling mode."
  Write-Host "  -IntervalSeconds <int>  : Interval between polling cycles in watch mode."
  Write-Host "  -DryRun                 : Simulates intake without changing proposal ledger."
  Write-Host "  -LogFile <path>         : Custom log file destination."
  Write-Host "  -h, -Help, -?           : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# Resolve paths
$workspaceRoot = 'D:\Git_Repositories'
$logDir = Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm'
if (-not (Test-Path -LiteralPath $logDir)) {
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $LogFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"
}
$script:ActiveLogFile = $LogFile

if ([string]::IsNullOrWhiteSpace($AckLedgerPath)) {
  $AckLedgerPath = Join-Path $workspaceRoot 'LCM_Inventory\data\inbox_ack'
}

function Write-ToolLog {
  param(
    [string]$Message,
    [ValidateSet('INFO', 'ACTION', 'DEBUG', 'WARN', 'ERROR', 'SUMMARY')]
    [string]$Level = 'INFO'
  )
  $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  $line = "[$stamp] [$Level] $Message"
  Add-Content -LiteralPath $script:ActiveLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue

  switch ($Level) {
    'ERROR'   { Write-Host $line -ForegroundColor Red }
    'WARN'    { Write-Host $line -ForegroundColor Yellow }
    'ACTION'  { Write-Host $line -ForegroundColor Green }
    'SUMMARY' { Write-Host $line -ForegroundColor Cyan }
    'DEBUG'   { }
    Default   { Write-Host $line -ForegroundColor Gray }
  }
}

# Import InboxWatcher module
$modulePath = Join-Path $workspaceRoot 'LCM_Inventory\modules\InboxWatcher.psm1'
if (Test-Path -LiteralPath $modulePath) {
  Import-Module -Name $modulePath -Force
} else {
  Write-ToolLog -Message "InboxWatcher module not found at: $modulePath" -Level ERROR
  throw "InboxWatcher module missing."
}

$logCallback = {
  param([string]$Msg, [string]$Lvl)
  Write-ToolLog -Message $Msg -Level $Lvl
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM TWO-PHASE INBOX PROCESSOR (v$($scriptVersion))" -ForegroundColor Cyan
Write-Host " Inbox Path     : $InboxPath" -ForegroundColor White
Write-Host " Archive Path   : $ArchivePath" -ForegroundColor White
Write-Host " Return Channel : $(if ([string]::IsNullOrWhiteSpace($AckPath)) { Join-Path $InboxPath 'ack' } else { $AckPath })" -ForegroundColor White
Write-Host " Mode           : $(if ($Watch) { "CONTINUOUS WATCHER (Interval: $($IntervalSeconds)s)" } else { "ONE-SHOT INTAKE" })" -ForegroundColor White
Write-Host " Dry-Run        : $(if ($DryRun) { 'ENABLED' } else { 'DISABLED' })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Gray' })
Write-Host " Audit Log      : $LogFile" -ForegroundColor Gray
Write-Host "==========================================================================" -ForegroundColor Cyan

if (-not $Watch) {
  $outcomes = @(Invoke-TwoPhaseInboxIntake -InboxPath $InboxPath `
                                         -ArchivePath $ArchivePath `
                                         -AckPath $AckPath `
                                         -AckLedgerPath $AckLedgerPath `
                                         -WorkspaceRoot $workspaceRoot `
                                         -DryRun:$DryRun `
                                         -LogCallback $logCallback)

  $successCount = @($outcomes | Where-Object { $_.Status -eq 'SUCCESS' }).Count
  $failureCount = @($outcomes | Where-Object { $_.Status -eq 'FAILURE' }).Count

  Write-Host ""
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " [SUMMARY] $scriptName (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host " Items Processed : $($outcomes.Count)" -ForegroundColor White
  Write-Host " Success (Phase2): $successCount" -ForegroundColor $(if ($successCount -gt 0) { 'Green' } else { 'White' })
  Write-Host " Failures/Rejects: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { 'Red' } else { 'White' })
  Write-Host " Status          : COMPLETED" -ForegroundColor Green
  Write-Host " Log File        : $LogFile" -ForegroundColor Gray
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return $outcomes
} else {
  Write-ToolLog -Message "Starting continuous watcher loop on $InboxPath (polling every $($IntervalSeconds)s)..." -Level INFO
  try {
    while ($true) {
      $null = Invoke-TwoPhaseInboxIntake -InboxPath $InboxPath `
                                         -ArchivePath $ArchivePath `
                                         -AckPath $AckPath `
                                         -AckLedgerPath $AckLedgerPath `
                                         -WorkspaceRoot $workspaceRoot `
                                         -DryRun:$DryRun `
                                         -LogCallback $logCallback
      Start-Sleep -Seconds $IntervalSeconds
    }
  } catch {
    Write-ToolLog -Message "Watcher terminated: $($_.Exception.Message)" -Level WARN
  }
}
