<#
.SYNOPSIS
  Displays recent operational actions, tool executions, and step-by-step summaries in the terminal (KISS).
.DESCRIPTION
  Module: Show-Actions
  Purpose: Fast, lightweight terminal reader that extracts and displays the execution steps,
           actions, and status results of recent operations from tools/logs/ and LCM_Inventory/data/logs/lcm/actions.jsonl.
           Follows the KISS principle for quick inspection of what the AI/operator executed.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), RULE-PS-010 (CLI Help), and RULE-PS-011 (Interactive Desktop Dispatch).
  Path: tools/Show-Actions.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
.PARAMETER Count
  Number of recent actions to display (Default: 5).
.PARAMETER Subsystem
  Filters action log stream by specific subsystem (e.g. 'HaSSD06').
.PARAMETER Detailed
  Displays all raw log lines for the action instead of the compact step summary.
.PARAMETER ToolName
  Filter by a specific tool name (e.g. 'Show-ToolIndex', 'Update-ToolCatalog', 'Export-LCMRules').
.PARAMETER Open
  Opens the latest action log in Notepad on Session 1 interactive desktop.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Show-Actions.ps1 -h
.EXAMPLE
  pwsh tools/Show-Actions.ps1
.EXAMPLE
  pwsh tools/Show-Actions.ps1 -Count 10
.EXAMPLE
  pwsh tools/Show-Actions.ps1 -Subsystem HaSSD06
.EXAMPLE
  pwsh tools/Show-Actions.ps1 -Detailed
.EXAMPLE
  pwsh tools/Show-Actions.ps1 -Open
#>

[CmdletBinding()]
param(
  [int]$Count = 5,
  [Alias('Instance')]
  [string]$Subsystem = "",
  [switch]$Detailed,
  [string]$ToolName = "",
  [switch]$Open,
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Show-Actions"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM ACTION & STEP LOG VIEWER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Displays chronological steps and actions from operations and actions.jsonl."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Show-Actions.ps1 [-Count <N>] [-Subsystem <name>] [-Detailed] [-ToolName <Name>] [-Open] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Count <int>     : Number of recent actions to show (Default: 5)."
  Write-Host "  -Subsystem <str> : Filters by subsystem name (e.g. 'HaSSD06')."
  Write-Host "  -Detailed        : Prints full raw log lines for each action."
  Write-Host "  -ToolName <str>  : Filters by specific tool name."
  Write-Host "  -Open            : Opens the latest log file in Notepad."
  Write-Host "  -h, -Help, -?    : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcdRoot 'tools\internal'

$logDirs = @(
  (Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm'),
  (Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm-internal'),
  (Join-Path $workspaceRoot 'tools\logs')
) | Where-Object { Test-Path -LiteralPath $_ }

if ($logDirs.Count -eq 0) {
  Write-Host "No logs directory found." -ForegroundColor Red
  return
}

$isSelfQuery = (-not [string]::IsNullOrWhiteSpace($ToolName) -and ($ToolName -replace '[^a-zA-Z0-9]', '') -match '^(?i)ShowActions')

# Fetch recent logs across all LCM log directories excluding interactive desktop routing wrapper
$allLogs = @(Get-ChildItem -Path $logDirs -Filter "*.log" -File | 
  Where-Object { $_.Name -notlike "Invoke-InteractiveDesktop-*" } | 
  Sort-Object LastWriteTime -Descending)

$logFiles = @()
if (-not $isSelfQuery -and -not [string]::IsNullOrWhiteSpace($ToolName)) {
  $cleanToolName = $ToolName.Trim()
  $cleanStem = ($cleanToolName -replace '\.[^/.]+$', '') -replace '[^a-zA-Z0-9]', ''
  $logFiles = @($allLogs | 
    Where-Object { 
      $_.Name -like "*$cleanToolName*" -or 
      ($cleanStem -and ($_.Name -replace '[^a-zA-Z0-9]', '') -like "*$cleanStem*")
    } | 
    Select-Object -First $Count)
}

if ($logFiles.Count -eq 0) {
  if ($isSelfQuery) {
    Write-Host "Note: 'Show-Actions' is a log reader. Querying recent general action logs..." -ForegroundColor DarkGray
  } elseif (-not [string]::IsNullOrWhiteSpace($ToolName)) {
    Write-Host "Notice: No dedicated logs found matching '$ToolName'. Querying recent general action logs..." -ForegroundColor Yellow
  }

  $logFiles = @($allLogs | Select-Object -First $Count)
}

if ($logFiles.Count -eq 0) {
  Write-Host "No action logs found in log directories." -ForegroundColor Yellow
  return
}

if ($Open) {
  $targetLog = $logFiles[0].FullName
  Write-Host "Opening log in editor: $targetLog" -ForegroundColor Cyan
  $daemonPort = if ($env:LCM_DAEMON_PORT -match '^\d+$') { [int]$env:LCM_DAEMON_PORT } else { 9876 }
  $openedViaDaemon = $false
  try {
    $payload = @{
      filePath   = "notepad.exe"
      args       = "`"$targetLog`""
      foreground = $true
      title      = [System.IO.Path]::GetFileName($targetLog)
    } | ConvertTo-Json -Compress
    $res = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/open" -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 2 -ErrorAction Stop
    if ($res.status -eq 'OPENED') {
      $openedViaDaemon = $true
    }
  } catch {}

  if (-not $openedViaDaemon) {
    $dispatcher = Join-Path $toolsDir "Invoke-InteractiveDesktop.ps1"
    if (Test-Path $dispatcher) {
      & pwsh -File $dispatcher -FilePath "notepad.exe" -ArgumentList "`"$targetLog`"" | Out-Null
    } else {
      Start-Process "notepad.exe" -ArgumentList "`"$targetLog`""
    }
  }
  return
}

$actionsJsonlPath = Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm\actions.jsonl'
$jsonlRecords = @()
if (Test-Path -LiteralPath $actionsJsonlPath) {
  try {
    $rawLines = [System.IO.File]::ReadAllLines($actionsJsonlPath, [System.Text.Encoding]::UTF8)
    for ($i = $rawLines.Count - 1; $i -ge 0; $i--) {
      $line = $rawLines[$i].Trim()
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      try {
        $rec = $line | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace($Subsystem)) {
          if ($rec.subsystem -ne $Subsystem -and $rec.source -notlike "*$Subsystem*") { continue }
        }
        if (-not [string]::IsNullOrWhiteSpace($ToolName)) {
          if ($rec.target -notlike "*$ToolName*" -and $rec.command -notlike "*$ToolName*" -and $rec.action_type -notlike "*$ToolName*") { continue }
        }
        $jsonlRecords += $rec
        if ($jsonlRecords.Count -ge $Count) { break }
      } catch {}
    }
  } catch {}
}

if ($jsonlRecords.Count -gt 0) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host (" LCM ACTION STREAM AUDIT (actions.jsonl - {0} events)" -f $jsonlRecords.Count) -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan

  foreach ($r in $jsonlRecords) {
    $time = if ($r.timestamp) { $r.timestamp } else { "-" }
    $type = if ($r.action_type) { $r.action_type } else { "ACTION" }
    $tgt = if ($r.target) { $r.target } else { "-" }
    $stat = if ($r.status) { $r.status } else { "OK" }
    $sub = if ($r.subsystem) { "[$($r.subsystem)]" } else { "" }
    $det = if ($r.details) { " | $($r.details)" } else { "" }
    
    $color = if ($stat -eq 'FAILED') { [ConsoleColor]::Red } elseif ($stat -eq 'SUCCESS') { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow }
    
    Write-Host (" >> [{0}] {1} [{2}] {3} ({4}){5}" -f $time, $sub, $type, $tgt, $stat, $det) -ForegroundColor $color
    if ($Detailed -and $r.command) {
      Write-Host ("     Cmd: {0}" -f $r.command) -ForegroundColor DarkGray
    }
  }
  Write-Host "==========================================================================`n" -ForegroundColor Cyan
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM RECENT ACTION & STEP LOG (Count: $($logFiles.Count))" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

foreach ($file in $logFiles) {
  $lines = @(Get-Content -LiteralPath $file.FullName)
  $timestamp = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
  
  Write-Host ""
  Write-Host ">> [$timestamp] $($file.Name)" -ForegroundColor Yellow
  
  if ($Detailed) {
    foreach ($line in $lines) {
      if ($line -match '\[ERROR\]|Status\s*:\s*FAILED') {
        Write-Host "  $line" -ForegroundColor Red
      } elseif ($line -match '\[ACTION\]') {
        Write-Host "  $line" -ForegroundColor Green
      } elseif ($line -match '\[SUMMARY\]|Status\s*:\s*COMPLETED') {
        Write-Host "  $line" -ForegroundColor Cyan
      } elseif ($line -match '\[DEBUG\]') {
        Write-Host "  $line" -ForegroundColor DarkGray
      } else {
        Write-Host "  $line" -ForegroundColor Gray
      }
    }
  } else {
    # KISS Compact View: Filter to Action & Summary lines
    $actionLines = @($lines | Where-Object { $_ -match '\[ACTION\]|Status\s*:\s*|Dashboard\s*:\s*|Target\s*:\s*|\[ERROR\]' })
    if ($actionLines.Count -eq 0) {
      $actionLines = @($lines | Select-Object -First 5)
    }
    
    foreach ($a in $actionLines) {
      $clean = $a -replace '\[\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\.\d{3}\]\s*', ''
      if ($clean -match '\[ERROR\]|FAILED') {
        Write-Host "  [-] $clean" -ForegroundColor Red
      } elseif ($clean -match '\[ACTION\]') {
        Write-Host "  [>] $clean" -ForegroundColor Green
      } elseif ($clean -match 'Status\s*:\s*COMPLETED') {
        Write-Host "  [+] $clean" -ForegroundColor Cyan
      } else {
        Write-Host "   *  $clean" -ForegroundColor Gray
      }
    }
  }
}

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan

