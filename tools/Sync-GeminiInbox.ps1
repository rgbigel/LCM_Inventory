<#
.SYNOPSIS
  Watches and ingests Google Gemini instructions and BUG reports from GDrive Inbox into the LCM Proposal Queue.
.DESCRIPTION
  Module: Sync-GeminiInbox
  Purpose: Ingests external input files dropped by Google Gemini (Cloud / Gems) in D:\GDrive\LCM\INBOX,
           validates mandatory timestamps, creates lightweight BUG reports / proposals in the LCM Proposal
           ledger (proposals.json), stores the raw plan, and cleanly archives processed files from the inbox.
           Conforms to RULE-PS-001 through RULE-PS-014, RULE-DOC-001 - 004, and the Gemini Inbox Security Invariant.
  Path: .lcm/tools/internal/Sync-GeminiInbox.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 1.0.0
  Date: 2026-08-30
.PARAMETER InboxPath
  Path to the Google Drive inbox folder. Defaults to 'D:\GDrive\LCM\INBOX'.
.PARAMETER ArchivePath
  Path to the archive folder for processed items. Defaults to 'D:\GDrive\LCM\INBOX\archive'.
.PARAMETER Watch
  Runs in continuous scheduled watching loop.
.PARAMETER IntervalSeconds
  Polling interval when running in -Watch mode. Defaults to 30 seconds.
.PARAMETER LogFile
  Custom log file path. Defaults to .lcm/logs/Sync-GeminiInbox-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays this command syntax and parameter reference (-h / -Help / -?).
.EXAMPLE
  pwsh .lcm/tools/internal/Sync-GeminiInbox.ps1
  Performs a one-shot intake of all pending items in the Inbox.
.EXAMPLE
  pwsh .lcm/tools/internal/Sync-GeminiInbox.ps1 -Watch -IntervalSeconds 15
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

$scriptVersion = "1.0.0"
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
  Write-Host "  pwsh .lcm/tools/internal/Sync-GeminiInbox.ps1 [-Watch] [-IntervalSeconds <sec>] [-h]"
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
$lcdRoot = Join-Path $workspaceRoot '.lcm'
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
if (-not (Test-Path -LiteralPath $InboxPath)) {
  New-Item -ItemType Directory -Force -Path $InboxPath | Out-Null
}
if (-not (Test-Path -LiteralPath $ArchivePath)) {
  New-Item -ItemType Directory -Force -Path $ArchivePath | Out-Null
}

# Import ProposalManager module
$modulePath = Join-Path $workspaceRoot 'LCM_Inventory\modules\ProposalManager.psm1'
if (Test-Path -LiteralPath $modulePath) {
  Import-Module -Name $modulePath -Force
} else {
  Write-ToolLog -Message "ProposalManager module not found at: $($modulePath)" -Level ERROR
  throw "ProposalManager module missing."
}

# ------------------------------------------------------------------------------
# 2. Intake Parsing Logic
# ------------------------------------------------------------------------------
function Parse-InboxItem {
  param([System.IO.FileInfo]$File)

  $rawContent = [System.IO.File]::ReadAllText($File.FullName)
  $itemData = @{
    FileName        = $File.Name
    RawContent      = $rawContent
    Type            = 'TASK'
    Title           = $File.BaseName
    Timestamp       = $File.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    TimestampValid  = $false
    OriginRepo      = 'Gemini / GDrive Inbox'
    Criticality     = 'MEDIUM'
    Details         = ''
  }

  if ($File.Extension -eq '.json') {
    try {
      $json = $rawContent | ConvertFrom-Json
      if ($json.type) { $itemData.Type = $json.type }
      if ($json.title) { $itemData.Title = $json.title }
      if ($json.timestamp) {
        $itemData.Timestamp = $json.timestamp
        $itemData.TimestampValid = $true
      }
      if ($json.target_repo) { $itemData.OriginRepo = "Gemini / $($json.target_repo)" }
      if ($json.criticality) { $itemData.Criticality = $json.criticality }
      if ($json.details) { $itemData.Details = $json.details }
      elseif ($json.summary) { $itemData.Details = $json.summary }
      return $itemData
    } catch {
      Write-ToolLog -Message "JSON parse failed for $($File.Name): $($_.Exception.Message)" -Level WARN
    }
  }

  # Parse Markdown / Text metadata headers
  $lines = $rawContent -split "\r?\n"
  foreach ($line in $lines) {
    if ($line -match '^(?:#\s*)?\[?(?:TYPE:\s*)?(BUG|TASK|PROPOSAL|FEATURE|NOTE)\]?:?\s*(.+)$') {
      $itemData.Type = $matches[1].ToUpperInvariant()
      $itemData.Title = $matches[2].Trim().TrimStart(':').Trim()
    }
    if ($line -match '(?i)\*\*(?:Timestamp|Date)\*\*:\s*([0-9T:_\-+ ]+)') {
      $itemData.Timestamp = $matches[1].Trim()
      $itemData.TimestampValid = $true
    }
    if ($line -match '(?i)\*\*(?:Target Repository|Target Repo|Repo)\*\*:\s*(.+)$') {
      $itemData.OriginRepo = "Gemini / $($matches[1].Trim())"
    }
    if ($line -match '(?i)\*\*(?:Criticality|Severity|Priority)\*\*:\s*(.+)$') {
      $itemData.Criticality = $matches[1].Trim().ToUpperInvariant()
    }
  }

  # Fallback if title still default
  if ([string]::IsNullOrWhiteSpace($itemData.Title) -or $itemData.Title -eq $File.BaseName) {
    $firstHeader = $lines | Where-Object { $_ -match '^#+\s+(.+)$' } | Select-Object -First 1
    if ($firstHeader) {
      $itemData.Title = ($firstHeader -replace '^#+\s+', '').Trim()
    }
  }

  $itemData.Details = $rawContent
  return $itemData
}

# ------------------------------------------------------------------------------
# 3. Process Pending Inbox Items
# ------------------------------------------------------------------------------
function Invoke-InboxIntakeCycle {
  $pendingFiles = @(Get-ChildItem -Path $InboxPath -File | Where-Object {
    $_.Extension -in @('.md', '.txt', '.json') -and $_.DirectoryName -ne $ArchivePath
  })

  if ($pendingFiles.Count -eq 0) {
    return 0
  }

  Write-ToolLog -Message "Discovered $($pendingFiles.Count) pending item(s) in Inbox." -Level ACTION
  $processed = 0

  foreach ($file in $pendingFiles) {
    try {
      $parsed = Parse-InboxItem -File $file

      if (-not $parsed.TimestampValid) {
        Write-ToolLog -Message "Notice: No explicit timestamp found in '$($file.Name)'. Using file timestamp: $($parsed.Timestamp)" -Level WARN
      }

      $proposalTitle = "[$($parsed.Type)] $($parsed.Title)"
      $proposalDetails = "Source: Gemini Inbox ($($file.Name)) | Time: $($parsed.Timestamp) | Criticality: $($parsed.Criticality)`n`n$($parsed.Details)"

      # Register in LCM proposal store
      $prop = New-WorkspaceProposal -Title $proposalTitle -OriginRepo $parsed.OriginRepo -Details $proposalDetails -Author 'Gemini Cloud'

      # Save complete content to proposal plan path
      $fullPlanPath = Join-Path $workspaceRoot $prop.plan_path
      $planDir = Split-Path $fullPlanPath -Parent
      if (-not (Test-Path -LiteralPath $planDir)) {
        New-Item -ItemType Directory -Force -Path $planDir | Out-Null
      }

      $planHeader = @(
        "# LCM Proposal #$($prop.id): $($prop.title)",
        "",
        "- **CR ID**: $($prop.cr_id)",
        "- **Origin**: $($prop.origin_repo)",
        "- **Intake Timestamp**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))",
        "- **Gemini Source Timestamp**: $($parsed.Timestamp)",
        "- **Criticality**: $($parsed.Criticality)",
        "- **Status**: $($prop.state) (Awaiting operator review: ProposalAction do $($prop.id))",
        "",
        "---",
        "",
        "## Gemini Intake Payload",
        "",
        $parsed.RawContent
      ) -join "`n"

      [System.IO.File]::WriteAllText($fullPlanPath, $planHeader, [System.Text.UTF8Encoding]::new($false))
      Write-ToolLog -Message "Created Proposal #$($prop.id) -> $($prop.plan_path)" -Level ACTION

      # Archive original item with timestamp prefix and delete from inbox
      $stampPrefix = (Get-Date).ToString("yyyyMMdd_HHmmss")
      $archivedName = "$($stampPrefix)_$($file.Name)"
      $archivedPath = Join-Path $ArchivePath $archivedName

      Move-Item -LiteralPath $file.FullName -Destination $archivedPath -Force
      Write-ToolLog -Message "Archived and removed from Inbox: $($file.Name) -> archive/$($archivedName)" -Level ACTION

      $processed++
    } catch {
      Write-ToolLog -Message "Failed to process item '$($file.FullName)': $($_.Exception.Message)" -Level ERROR
    }
  }

  return $processed
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



