<#
.SYNOPSIS
  Purges conversations from the Antigravity archive that are older than a specified duration threshold.
.DESCRIPTION
  Module: Archive-Clean
  Purpose: Permanently deletes archived conversations older than a specified age threshold (e.g. 1m, 3d).
  Path: LCM_Inventory\tools\Archive-Clean.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-11-11
.PARAMETER Older
  Age threshold for archived conversations to delete. Default is '1m' (older than 1 month).
  Supported units: d (days), w (weeks), m (months), y (years), h (hours). Examples: '3d', '2w', '1m', '6m'.
.PARAMETER AntigravityDir
  Path to the Antigravity data directory. Defaults to $env:USERPROFILE\.gemini\antigravity.
.PARAMETER DryRun
  Simulates execution without deleting files or records.
.PARAMETER Force
  Bypasses the interactive confirmation prompt before deletion.
.PARAMETER ShowAll
  Displays detailed information for each evaluated archived conversation.
.PARAMETER Help
  Displays this parameter reference (Aliases: -h, -?).
.EXAMPLE
  ArchiveClean
.EXAMPLE
  ArchiveClean -Older 3d
.EXAMPLE
  pwsh LCM_Inventory\tools\Archive-Clean.ps1 -Older 1m -DryRun
.DEPENDENCIES
  Python 3.x (with built-in sqlite3)
#>

[CmdletBinding()]
param(
  [string]$Older = '1m',

  [string]$AntigravityDir = "",

  [switch]$DryRun,

  [switch]$Force,

  [switch]$ShowAll,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.2.0"
$scriptName = "Archive-Clean"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " $($scriptName.ToUpper()) (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Purges conversations from the Antigravity archive that are older than a threshold."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory\tools\Archive-Clean.ps1 [-Older <string>] [-DryRun] [-Force] [-ShowAll] [-h]"
  Write-Host "  ArchiveClean [-Older <string>] [-DryRun] [-Force] [-ShowAll] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Older <string>     : Age threshold for deletion. Default is '1m' (1 month)."
  Write-Host "                        Supported units: d (days), w (weeks), m (months), y (years), h (hours)."
  Write-Host "                        Examples: '3d' (3 days), '2w' (2 weeks), '1m' (1 month), '6m' (6 months)."
  Write-Host "  -AntigravityDir <s> : Optional custom path to Antigravity directory."
  Write-Host "  -DryRun             : Preview conversations to delete without removing files or records."
  Write-Host "  -Force              : Bypasses the confirmation prompt before permanent deletion."
  Write-Host "  -ShowAll            : List all individual conversations and their status."
  Write-Host "  -h, -Help, -?       : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
$logDir = Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm'
if (-not (Test-Path -Path $logDir)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$dateStamp = (Get-Date).ToString("yyyyMMdd")
$auditLog = Join-Path $logDir "$($scriptName)-$dateStamp.log"

function Write-ToolLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [ValidateSet('INFO', 'ACTION', 'WARN', 'ERROR', 'SUMMARY')]
    [string]$Level = 'INFO'
  )
  $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  $line = "[$stamp] [$Level] $Message"
  Add-Content -LiteralPath $auditLog -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
  if ($Level -eq 'ERROR') { Write-Host $line -ForegroundColor Red }
  elseif ($Level -eq 'WARN') { Write-Host $line -ForegroundColor Yellow }
  elseif ($Level -eq 'ACTION') { Write-Host $line -ForegroundColor Green }
  elseif ($Level -eq 'SUMMARY') { Write-Host $line -ForegroundColor Cyan }
  else { Write-Host $line -ForegroundColor Gray }
}

# ------------------------------------------------------------------------------
# Helper: Parse Duration String into Cutoff DateTime
# ------------------------------------------------------------------------------
function Resolve-OlderCutoffDate {
  param([string]$Duration)

  if ([string]::IsNullOrWhiteSpace($Duration)) {
    return (Get-Date).AddMonths(-1)
  }

  $clean = $Duration.Trim().ToLowerInvariant()
  if ($clean -match '^(\d+)\s*([a-z]+)$') {
    $count = [int]$Matches[1]
    $unit = $Matches[2]
    switch -Wildcard ($unit) {
      'd*' { return (Get-Date).AddDays(-$count) }
      'w*' { return (Get-Date).AddDays(-($count * 7)) }
      'm*' { return (Get-Date).AddMonths(-$count) }
      'y*' { return (Get-Date).AddYears(-$count) }
      'h*' { return (Get-Date).AddHours(-$count) }
      default {
        throw "Unsupported duration unit '$unit'. Supported units: d (days), w (weeks), m (months), y (years), h (hours)."
      }
    }
  } elseif ($clean -match '^\d+$') {
    $count = [int]$clean
    return (Get-Date).AddDays(-$count)
  } else {
    throw "Invalid -Older duration format '$Duration'. Valid examples: '1m', '3d', '2w', '1y'."
  }
}

Write-ToolLog -Message "Executing $scriptName v$scriptVersion (Older: $Older, DryRun: $DryRun)..." -Level INFO

# ------------------------------------------------------------------------------
# 2. Main Execution Block
# ------------------------------------------------------------------------------
try {
  $cutoffDate = Resolve-OlderCutoffDate -Duration $Older
  $cutoffStr = $cutoffDate.ToString("yyyy-MM-dd HH:mm:ss")
  Write-ToolLog -Message "Calculated archive pruning cutoff threshold: $cutoffStr ($Older ago)" -Level INFO

  if ($null -eq $AntigravityDir -or [string]::IsNullOrWhiteSpace($AntigravityDir)) {
    $AntigravityDir = Join-Path $env:USERPROFILE '.gemini\antigravity'
  }

  if (-not (Test-Path -LiteralPath $AntigravityDir)) {
    throw "Antigravity directory not found at: $AntigravityDir"
  }

  $annotationsDir = Join-Path $AntigravityDir 'annotations'
  $dbPath = Join-Path $AntigravityDir 'conversation_summaries.db'
  $conversationsDir = Join-Path $AntigravityDir 'conversations'
  $brainDir = Join-Path $AntigravityDir 'brain'
  $presenceDir = Join-Path $AntigravityDir 'presence'

  Write-ToolLog -Message "Inspecting conversation summaries database: $dbPath" -Level INFO

  # Query all conversations
  $pyQuery = @"
import sqlite3, json, os, sys

db = r'$dbPath'
if not os.path.exists(db):
    print('[]')
    sys.exit(0)

conn = sqlite3.connect(db, timeout=10.0)
c = conn.cursor()
c.execute('''
    SELECT conversation_id, title, last_modified_time, last_user_input_time
    FROM conversation_summaries
    ORDER BY last_modified_time DESC
''')
rows = []
for r in c.fetchall():
    rows.append({
        'id': r[0],
        'title': r[1] if r[1] else '(Untitled Conversation)',
        'last_modified': r[2],
        'last_user_input': r[3]
    })
print(json.dumps(rows))
"@

  $jsonOutput = python -c $pyQuery
  $convList = @()
  if ($null -ne $jsonOutput -and -not [string]::IsNullOrWhiteSpace($jsonOutput)) {
    $convList = @($jsonOutput | ConvertFrom-Json)
  }

  $totalCount = $convList.Count
  Write-ToolLog -Message "Discovered $totalCount total conversations in database." -Level INFO

  # Identify items that are ARCHIVED AND older than cutoff
  $deleteTargets = [System.Collections.Generic.List[PSCustomObject]]::new()
  $archivedKept = 0
  $activeIgnored = 0

  foreach ($conv in $convList) {
    $id = $conv.id
    $title = $conv.title
    $dispTitle = if ($title.Length -gt 45) { $title.Substring(0, 42) + '...' } else { $title }
    $pbtxtPath = Join-Path $annotationsDir "$id.pbtxt"

    $isArchived = $false
    if (Test-Path -LiteralPath $pbtxtPath) {
      $pbtxtContent = [System.IO.File]::ReadAllText($pbtxtPath, [System.Text.Encoding]::UTF8)
      if ($pbtxtContent -match 'archived:\s*true') {
        $isArchived = $true
      }
    }

    if (-not $isArchived) {
      $activeIgnored++
      if ($ShowAll) {
        Write-ToolLog -Message "  [ACTIVE - SKIPPED]  $id - $dispTitle" -Level INFO
      }
      continue
    }

    # Conversation is archived. Parse its last modified date
    $dt = [DateTime]::MinValue
    $rawTime = $conv.last_modified
    if ($rawTime -match '^(\d{4}-\d{2}-\d{2})') {
      [DateTime]::TryParse($rawTime, [ref]$dt) | Out-Null
    }

    if ($dt -eq [DateTime]::MinValue -and (Test-Path -LiteralPath $pbtxtPath)) {
      $dt = (Get-Item -LiteralPath $pbtxtPath).LastWriteTime
    }

    if ($dt -lt $cutoffDate) {
      $deleteTargets.Add([PSCustomObject]@{
        Id           = $id
        Title        = $title
        DispTitle    = $dispTitle
        LastModified = $conv.last_modified
        DateTime     = $dt
      })
      Write-ToolLog -Message "  [ARCHIVE PRUNE TARGET] $id - $dispTitle ($($conv.last_modified))" -Level WARN
    } else {
      $archivedKept++
      if ($ShowAll) {
        Write-ToolLog -Message "  [ARCHIVED - PRESERVED] $id - $dispTitle (Within $Older threshold)" -Level INFO
      }
    }
  }

  $targetCount = $deleteTargets.Count
  Write-ToolLog -Message "Evaluated archive: $targetCount item(s) older than $Older threshold ($cutoffStr)." -Level INFO

  if ($targetCount -eq 0) {
    Write-ToolLog -Message "No archived conversations match the $Older threshold. Nothing to clean." -Level ACTION
    return
  }

  # Confirmation Gate if interactive and not Force or DryRun per RULE-PS-024
  if (-not $Force -and -not $DryRun) {
    Write-Host ""
    Write-Host "CAUTION: You are about to permanently delete $targetCount conversation(s) from the Antigravity archive!" -ForegroundColor Yellow
    $confirm = Read-Host "Proceed with permanent deletion? (Type 'YES' to confirm)"
    if ($confirm -ne 'YES') {
      Write-ToolLog -Message "Operation cancelled by operator. No files deleted." -Level WARN
      return
    }
  }

  $deletedCount = 0
  $freedBytes = 0
  $targetIds = [System.Collections.Generic.List[string]]::new()

  foreach ($target in $deleteTargets) {
    $id = $target.Id
    $targetIds.Add($id)

    if ($DryRun) {
      $deletedCount++
      continue
    }

    # 1. Delete annotations file
    $pbtxtPath = Join-Path $annotationsDir "$id.pbtxt"
    if (Test-Path -LiteralPath $pbtxtPath) {
      $freedBytes += (Get-Item -LiteralPath $pbtxtPath).Length
      Remove-Item -LiteralPath $pbtxtPath -Force -ErrorAction SilentlyContinue
    }

    # 2. Delete conversations db and wal/shm
    $dbFile = Join-Path $conversationsDir "$id.db"
    $dbShm = Join-Path $conversationsDir "$id.db-shm"
    $dbWal = Join-Path $conversationsDir "$id.db-wal"
    foreach ($f in @($dbFile, $dbShm, $dbWal)) {
      if (Test-Path -LiteralPath $f) {
        $freedBytes += (Get-Item -LiteralPath $f).Length
        Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
      }
    }

    # 3. Delete brain folder
    $convBrain = Join-Path $brainDir $id
    if (Test-Path -LiteralPath $convBrain) {
      $items = @(Get-ChildItem -LiteralPath $convBrain -Recurse -File -ErrorAction SilentlyContinue)
      foreach ($item in $items) {
        $freedBytes += $item.Length
      }
      Remove-Item -LiteralPath $convBrain -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 4. Delete presence lock if exists
    $lockFile = Join-Path $presenceDir "$id.lock"
    if (Test-Path -LiteralPath $lockFile) {
      Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
    }

    $deletedCount++
    Write-ToolLog -Message "  [DELETED FROM ARCHIVE] $id - $($target.DispTitle)" -Level ACTION
  }

  # 5. Remove rows from conversation_summaries.db
  if (-not $DryRun -and $targetIds.Count -gt 0) {
    Write-ToolLog -Message "Purging deleted conversation records from $dbPath..." -Level INFO
    $idListJson = ($targetIds | ConvertTo-Json -Compress)
    $pyPurge = @"
import sqlite3, json, os

db = r'$dbPath'
ids = json.loads(r'''$idListJson''')

if os.path.exists(db) and len(ids) > 0:
    conn = sqlite3.connect(db, timeout=10.0)
    c = conn.cursor()
    placeholders = ','.join(['?' for _ in ids])
    c.execute(f"DELETE FROM conversation_summaries WHERE conversation_id IN ({placeholders})", ids)
    c.execute(f"DELETE FROM conversations_fts WHERE conversation_id IN ({placeholders})", ids)
    conn.commit()
    conn.close()
"@
    python -c $pyPurge
  }

  $mbFreed = [Math]::Round($freedBytes / 1MB, 2)
  $statusStr = if ($DryRun) { "DRY_RUN" } else { "COMPLETED" }

  Write-Host ""
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
  Write-ToolLog -Message " $($scriptName.ToUpper()) SUMMARY" -Level SUMMARY
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
  Write-ToolLog -Message " Status              : $statusStr" -Level SUMMARY
  Write-ToolLog -Message " Version             : $scriptVersion" -Level SUMMARY
  Write-ToolLog -Message " Threshold Parameter : -Older $Older ($cutoffStr)" -Level SUMMARY
  Write-ToolLog -Message " Archived Deleted    : $deletedCount" -Level SUMMARY
  Write-ToolLog -Message " Archived Preserved  : $archivedKept" -Level SUMMARY
  Write-ToolLog -Message " Active Skipped      : $activeIgnored" -Level SUMMARY
  Write-ToolLog -Message " Estimated Space Free: $mbFreed MB" -Level SUMMARY
  Write-ToolLog -Message " Log File            : $auditLog" -Level SUMMARY
  Write-ToolLog -Message " Timestamp           : $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))" -Level SUMMARY
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY

} catch {
  Write-ToolLog -Message "Execution error: $($_.Exception.Message)" -Level ERROR
  throw $_
}
