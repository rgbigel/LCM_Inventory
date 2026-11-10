<#
.SYNOPSIS
  Watches and ingests Google Gemini instructions and BUG reports from GDrive Inbox into the LCM Proposal Queue.
.DESCRIPTION
  Module: Sync-GeminiInbox
  Purpose: Ingests external input files dropped by Google Gemini (Cloud / Gems) in D:\GDrive\LCM\INBOX,
           validates mandatory timestamps, creates lightweight BUG reports / proposals in the LCM Proposal
           ledger (proposals.json), stores the raw plan, and cleanly archives processed files from the inbox.
           Conforms to RULE-PS-001 through RULE-PS-014, RULE-DOC-001 - 004, and the Gemini Inbox Security Invariant.
  Path: LCM_Inventory/tools/Sync-GeminiInbox.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
.PARAMETER InboxPath
  Path to the Google Drive inbox folder. Defaults to 'D:\GDrive\LCM\INBOX'.
.PARAMETER ArchivePath
  Path to the archive folder for processed items. Defaults to 'D:\GDrive\LCM\INBOX\archive'.
.PARAMETER Watch
  Runs in continuous scheduled watching loop.
.PARAMETER IntervalSeconds
  Polling interval when running in -Watch mode. Defaults to 30 seconds.
.PARAMETER LogFile
  Custom log file path. Defaults to LCM_Inventory/data/logs/lcm/Sync-GeminiInbox-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays this command syntax and parameter reference (-h / -Help / -?).
.EXAMPLE
  pwsh LCM_Inventory/tools/Sync-GeminiInbox.ps1
  Performs a one-shot intake of all pending items in the Inbox.
.EXAMPLE
  pwsh LCM_Inventory/tools/Sync-GeminiInbox.ps1 -Watch -IntervalSeconds 15
  Runs a continuous watcher polling every 15 seconds.
#>

[CmdletBinding()]
param(
  [string]$InboxPath = 'D:\GDrive\LCM\INBOX',
  [string]$ArchivePath = 'D:\GDrive\LCM\INBOX\archive',
  [switch]$Watch,
  [int]$IntervalSeconds = 30,
  [string]$LogFile = '',
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Sync-GeminiInbox"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " GEMINI GDRIVE INBOX WATCHER & LCM PROPOSAL INTAKE (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Safely ingests incoming Gemini instructions & BUG reports from Google Drive"
  Write-Host "  into the LCM Proposal ledger, archives processed files, and clears the Inbox."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Sync-GeminiInbox.ps1 [-Watch] [-IntervalSeconds <sec>] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -InboxPath <dir>        : Source inbox folder (Default: 'D:\GDrive\LCM\INBOX')."
  Write-Host "  -ArchivePath <dir>      : Archive directory for absorbed items."
  Write-Host "  -Watch                  : Runs continuously in background polling mode."
  Write-Host "  -IntervalSeconds <int>  : Interval between polling cycles in watch mode."
  Write-Host "  -LogFile <path>         : Custom log file destination."
  Write-Host "  -h, -Help, -?           : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Path Discovery & Logging Setup per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$logDir = Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm'
if (-not (Test-Path -LiteralPath $logDir)) {
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $LogFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"
}
$script:ActiveLogFile = $LogFile

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

# Ensure directories exist
$ackPath = Join-Path $InboxPath 'acks'
$ackLedgerPath = Join-Path $workspaceRoot 'LCM_Inventory\data\inbox\acks'

foreach ($dir in @($InboxPath, $ArchivePath, $ackPath, $ackLedgerPath)) {
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
}

# Import ProposalManager and InboxWatcher modules
$pmPath = Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'
if (Test-Path -LiteralPath $pmPath) {
  Import-Module -Name $pmPath -Force
} else {
  Write-ToolLog -Message "ProposalManager module not found at: $pmPath" -Level ERROR
  throw "ProposalManager module missing."
}

$iwPath = Join-Path $workspaceRoot 'LCM_Inventory\modules\InboxWatcher.psm1'
if (Test-Path -LiteralPath $iwPath) {
  Import-Module -Name $iwPath -Force
} else {
  Write-ToolLog -Message "InboxWatcher module not found at: $iwPath" -Level ERROR
  throw "InboxWatcher module missing."
}

# ------------------------------------------------------------------------------
# 2. Intake Execution with Two-Phase ACK Protocol (CRP-263)
# ------------------------------------------------------------------------------
function Invoke-InboxIntakeCycle {
  $logCallback = {
    param([string]$Msg, [string]$Lvl)
    Write-ToolLog -Message $Msg -Level $Lvl
  }

  $outcomes = @(Invoke-TwoPhaseInboxIntake -InboxPath $InboxPath `
                                         -ArchivePath $ArchivePath `
                                         -AckPath $ackPath `
                                         -AckLedgerPath $ackLedgerPath `
                                         -WorkspaceRoot $workspaceRoot `
                                         -LogCallback $logCallback)

  $successful = @($outcomes | Where-Object { $_.Status -eq 'SUCCESS' })
  return $successful.Count
}

# ------------------------------------------------------------------------------
# 4. Execution Dispatch (One-Shot vs Watcher)
# ------------------------------------------------------------------------------
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " GEMINI GDRIVE INBOX WATCHER & LCM PROPOSAL INTAKE (v$($scriptVersion))" -ForegroundColor Cyan
Write-Host " Inbox Path  : $InboxPath" -ForegroundColor White
Write-Host " Archive Path: $ArchivePath" -ForegroundColor White
Write-Host " Mode        : $(if ($Watch) { "CONTINUOUS WATCHER (Interval: $($IntervalSeconds)s)" } else { "ONE-SHOT INTAKE" })" -ForegroundColor White
Write-Host " Audit Log   : $LogFile" -ForegroundColor Gray
Write-Host "==========================================================================" -ForegroundColor Cyan

if (-not $Watch) {
  $count = Invoke-InboxIntakeCycle
  Write-Host ""
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " [SUMMARY] $scriptName (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host " Items Ingested : $count" -ForegroundColor $(if ($count -gt 0) { 'Green' } else { 'White' })
  Write-Host " Status         : COMPLETED" -ForegroundColor Green
  Write-Host " Log File       : $LogFile" -ForegroundColor Gray
  Write-Host "==========================================================================" -ForegroundColor Cyan
} else {
  Write-ToolLog -Message "Starting continuous watcher loop on $InboxPath (polling every $($IntervalSeconds)s)..." -Level INFO
  try {
    while ($true) {
      $c = Invoke-InboxIntakeCycle
      Start-Sleep -Seconds $IntervalSeconds
    }
  } catch {
    Write-ToolLog -Message "Watcher terminated: $($_.Exception.Message)" -Level WARN
  }
}



