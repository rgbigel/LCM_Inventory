<#
.SYNOPSIS
  Archives older Antigravity conversations while preserving the newest N active.
.DESCRIPTION
  Module: Archive-Conversations
  Purpose: Archives older Antigravity conversations while preserving the newest N active.
           Updates on-disk annotations, full-text search index, and broadcasts to the
           live Antigravity hub daemon so the IDE UI updates immediately in real time.
           Ensures that all N newest conversations are active (unarchived if needed).
  Path: LCM_Inventory\tools\Archive-Conversations.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.2
  Date: 2026-11-11
.PARAMETER Older
  Number of newest conversations to preserve active (not archived). Default is 1 (leaves latest active).
  Can be passed positionally or with standard flag formats: -Older 5, 5, or -5.
.PARAMETER AntigravityDir
  Path to the Antigravity data directory. Defaults to $env:USERPROFILE\.gemini\antigravity.
.PARAMETER DryRun
  Simulates execution without modifying any annotation files or databases.
.PARAMETER ShowAll
  Displays detailed status for each processed conversation.
.PARAMETER Help
  Displays this parameter reference (Aliases: -h, -?).
.EXAMPLE
  ArchiveConversations
.EXAMPLE
  ArchiveConversations -5
.EXAMPLE
  ArchiveConversations -Older 3
.EXAMPLE
  pwsh LCM_Inventory\tools\Archive-Conversations.ps1 -Older 1 -DryRun -ShowAll
.DEPENDENCIES
  Python 3.x (with built-in sqlite3)
#>

[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [int]$Older = 1,

  [string]$AntigravityDir = "",

  [switch]$DryRun,

  [switch]$ShowAll,

  [Alias('h', '?')]
  [switch]$Help,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$RemainingArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.2.2"
$scriptName = "Archive-Conversations"

# Resolve negative or trailing arguments (e.g. -5, 5, or -Older 5)
if ($Older -lt 0) {
  $Older = [Math]::Abs($Older)
}
if ($null -ne $RemainingArgs -and $RemainingArgs.Count -gt 0) {
  foreach ($arg in $RemainingArgs) {
    if ($arg -match '^-?(\d+)$') {
      $Older = [int]$Matches[1]
      break
    }
  }
}

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " $($scriptName.ToUpper()) (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Archives older Antigravity conversations while preserving the newest N active."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  ArchiveConversations [-Older <int>] [-DryRun] [-ShowAll] [-h]"
  Write-Host "  ArchiveConversations -5"
  Write-Host "  pwsh LCM_Inventory\tools\Archive-Conversations.ps1 [-Older <int>] [-DryRun] [-ShowAll] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Older <int>        : Number of newest conversations to keep active. Default is 1."
  Write-Host "                        (e.g. -Older 1 archives all conversations except the single latest)."
  Write-Host "                        Supports positional numbers and shorthand (e.g. '5' or '-5')."
  Write-Host "  -AntigravityDir <s> : Optional custom path to Antigravity directory."
  Write-Host "  -DryRun             : Preview conversations to archive without making changes."
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

Write-ToolLog -Message "Executing $scriptName v$scriptVersion (Preserve Newest: $Older, DryRun: $DryRun)..." -Level INFO

# ------------------------------------------------------------------------------
# 2. Main Execution Block
# ------------------------------------------------------------------------------
try {
  if ($null -eq $AntigravityDir -or [string]::IsNullOrWhiteSpace($AntigravityDir)) {
    $AntigravityDir = Join-Path $env:USERPROFILE '.gemini\antigravity'
  }

  if (-not (Test-Path -LiteralPath $AntigravityDir)) {
    throw "Antigravity directory not found at: $AntigravityDir"
  }

  $annotationsDir = Join-Path $AntigravityDir 'annotations'
  $dbPath = Join-Path $AntigravityDir 'conversation_summaries.db'

  if (-not (Test-Path -LiteralPath $annotationsDir)) {
    New-Item -Path $annotationsDir -ItemType Directory -Force | Out-Null
  }

  Write-ToolLog -Message "Connecting to conversation database: $dbPath" -Level INFO

  # Fetch conversation list sorted by last_modified_time DESC
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
  Write-ToolLog -Message "Discovered $totalCount total conversations." -Level INFO

  if ($totalCount -eq 0) {
    Write-ToolLog -Message "No conversations found to process." -Level WARN
    return
  }

  $preservedCount = [Math]::Min($Older, $totalCount)
  $preservedList = @()
  $targetList = @()

  if ($preservedCount -gt 0) {
    $preservedList = @($convList[0..($preservedCount - 1)])
  }
  if ($totalCount -gt $preservedCount) {
    $targetList = @($convList[$preservedCount..($totalCount - 1)])
  }

  $unarchivedIds = [System.Collections.Generic.List[string]]::new()
  Write-ToolLog -Message "Preserving newest $preservedCount conversation(s) active." -Level INFO
  if ($preservedCount -gt 0) {
    foreach ($p in $preservedList) {
      $dispTitle = if ($p.title.Length -gt 45) { $p.title.Substring(0, 42) + '...' } else { $p.title }
      $pbtxtPath = Join-Path $annotationsDir "$($p.id).pbtxt"

      # If an item within the newest N was previously archived, unarchive it so it is visible
      if (Test-Path -LiteralPath $pbtxtPath) {
        $pContent = [System.IO.File]::ReadAllText($pbtxtPath, [System.Text.Encoding]::UTF8)
        if ($pContent -match 'archived:\s*true') {
          Write-ToolLog -Message "  [RESTORING TO ACTIVE] $($p.id) - $dispTitle (Within newest $Older)" -Level ACTION
          if (-not $DryRun) {
            $pContent = $pContent -replace 'archived:\s*true', 'archived:false'
            [System.IO.File]::WriteAllText($pbtxtPath, $pContent, [System.Text.UTF8Encoding]::new($false))
            $unarchivedIds.Add($p.id)
          }
        } else {
          Write-ToolLog -Message "  [PRESERVED ACTIVE] $($p.id) - $dispTitle ($($p.last_modified))" -Level INFO
        }
      } else {
        Write-ToolLog -Message "  [PRESERVED ACTIVE] $($p.id) - $dispTitle ($($p.last_modified))" -Level INFO
      }
    }
  }

  $archivedCount = 0
  $alreadyArchivedCount = 0
  $newlyArchivedIds = [System.Collections.Generic.List[string]]::new()
  $epochNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

  foreach ($t in $targetList) {
    $id = $t.id
    $title = $t.title
    $dispTitle = if ($title.Length -gt 45) { $title.Substring(0, 42) + '...' } else { $title }
    $pbtxtPath = Join-Path $annotationsDir "$id.pbtxt"

    $isAlreadyArchived = $false
    $content = ""

    if (Test-Path -LiteralPath $pbtxtPath) {
      $content = [System.IO.File]::ReadAllText($pbtxtPath, [System.Text.Encoding]::UTF8)
      if ($content -match 'archived:\s*true') {
        $isAlreadyArchived = $true
      }
    }

    if ($isAlreadyArchived) {
      $alreadyArchivedCount++
      if ($ShowAll) {
        Write-ToolLog -Message "  [ALREADY ARCHIVED] $id - $dispTitle" -Level INFO
      }
    } else {
      $archivedCount++
      $newlyArchivedIds.Add($id)
      Write-ToolLog -Message "  [ARCHIVE TARGET]   $id - $dispTitle ($($t.last_modified))" -Level ACTION

      if (-not $DryRun) {
        # Update or create .pbtxt annotation
        $newContent = ""
        if (Test-Path -LiteralPath $pbtxtPath) {
          if ($content -match 'archived:\s*false') {
            $newContent = $content -replace 'archived:\s*false', 'archived:true'
          } else {
            $newContent = ($content.Trim() + "  archived:true  archival_status_timestamp:{seconds:$epochNow  nanos:0}").Trim()
          }
        } else {
          $escapedTitle = $title -replace '"', '\"'
          $newContent = "title:`"$escapedTitle`"  archived:true  archival_status_timestamp:{seconds:$epochNow  nanos:0}"
        }
        [System.IO.File]::WriteAllText($pbtxtPath, $newContent, [System.Text.UTF8Encoding]::new($false))
      }
    }
  }

  # Update conversation_summaries.db FTS table if live execution
  if (-not $DryRun -and ($newlyArchivedIds.Count -gt 0 -or $unarchivedIds.Count -gt 0)) {
    Write-ToolLog -Message "Updating full-text search index in $dbPath..." -Level INFO
    $idListJson = ($newlyArchivedIds | ConvertTo-Json -Compress)
    $unarchivedListJson = ($unarchivedIds | ConvertTo-Json -Compress)
    $pyUpdate = @"
import sqlite3, json, os

db = r'$dbPath'
archived_ids = json.loads(r'''$idListJson''') if r'''$idListJson''' else []
unarchived_ids = json.loads(r'''$unarchivedListJson''') if r'''$unarchivedListJson''' else []

if os.path.exists(db):
    conn = sqlite3.connect(db, timeout=10.0)
    c = conn.cursor()
    if len(archived_ids) > 0:
        placeholders = ','.join(['?' for _ in archived_ids])
        c.execute(f"UPDATE conversations_fts SET archived = 1 WHERE chunk_index = -1 AND conversation_id IN ({placeholders})", archived_ids)
    if len(unarchived_ids) > 0:
        placeholders = ','.join(['?' for _ in unarchived_ids])
        c.execute(f"UPDATE conversations_fts SET archived = 0 WHERE chunk_index = -1 AND conversation_id IN ({placeholders})", unarchived_ids)
    conn.commit()
    conn.close()
"@
    python -c $pyUpdate

    # Notify running Antigravity Hub via Connect-RPC for instant live UI update
    Write-ToolLog -Message "Broadcasting state to live Antigravity daemon..." -Level INFO
    $pySyncHub = @"
import urllib.request, json, subprocess, re

archived_ids = json.loads(r'''$idListJson''') if r'''$idListJson''' else []
unarchived_ids = json.loads(r'''$unarchivedListJson''') if r'''$unarchivedListJson''' else []

try:
    proc = subprocess.check_output(["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process -Filter \"Name = 'agy.exe'\" | Select-Object -ExpandProperty CommandLine"]).decode()
    port_m = re.search(r"--hub-port=(\d+)", proc)
    csrf_m = re.search(r"--csrf_token=([a-f0-9\-]+)", proc)
    if port_m and csrf_m:
        port = port_m.group(1)
        csrf = csrf_m.group(1)
        url = f"http://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/UpdateConversationAnnotations"
        headers = {"Content-Type": "application/json", "x-codeium-csrf-token": csrf, "Connect-Protocol-Version": "1"}

        for cid in archived_ids:
            body = json.dumps({"cascadeIds": [cid], "annotations": {"archived": True}, "mergeAnnotations": True}).encode("utf-8")
            try:
                urllib.request.urlopen(urllib.request.Request(url, data=body, headers=headers))
            except Exception:
                pass

        for cid in unarchived_ids:
            body = json.dumps({"cascadeIds": [cid], "annotations": {"archived": False}, "mergeAnnotations": True}).encode("utf-8")
            try:
                urllib.request.urlopen(urllib.request.Request(url, data=body, headers=headers))
            except Exception:
                pass
except Exception:
    pass
"@
    python -c $pySyncHub
  }

  $statusStr = if ($DryRun) { "DRY_RUN" } else { "COMPLETED" }
  Write-Host ""
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
  Write-ToolLog -Message " $($scriptName.ToUpper()) SUMMARY" -Level SUMMARY
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
  Write-ToolLog -Message " Status             : $statusStr" -Level SUMMARY
  Write-ToolLog -Message " Version            : $scriptVersion" -Level SUMMARY
  Write-ToolLog -Message " Total Conversations: $totalCount" -Level SUMMARY
  Write-ToolLog -Message " Preserved Active   : $preservedCount" -Level SUMMARY
  Write-ToolLog -Message " Restored to Active : $($unarchivedIds.Count)" -Level SUMMARY
  Write-ToolLog -Message " Newly Archived     : $archivedCount" -Level SUMMARY
  Write-ToolLog -Message " Already Archived   : $alreadyArchivedCount" -Level SUMMARY
  Write-ToolLog -Message " Log File           : $auditLog" -Level SUMMARY
  Write-ToolLog -Message " Timestamp          : $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))" -Level SUMMARY
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY

} catch {
  Write-ToolLog -Message "Execution error: $($_.Exception.Message)" -Level ERROR
  throw $_
}
