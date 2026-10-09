<#
.SYNOPSIS
  Displays live telemetry, runtime status, read-only log viewer, and log cleanup for the LCM Desktop REST Bridge Daemon.
.DESCRIPTION
  Module: Show-LcmDaemon
  Purpose: Real-time diagnostic monitor and lifecycle controller for LcmDesktopDaemon (Port 9876).
           1. Probes GET /status for PID, memory (WorkingSet), session ID, and uptime.
           2. Displays formatted status card with active endpoints and health indicators.
           3. View active daemon log with -Log / -View (read-only) or live tail with -Tail / -Follow.
           4. Clean up old daemon logs with -Cleanup (customizable via -MaxAgeDays).
           5. Controls lifecycle with -Start, -Stop, and -Restart.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: tools/Show-LcmDaemon.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 1.1.0
  Date: 2026-08-28
.PARAMETER Port
  Target TCP port to inspect (Default: 9876). Configurable via $env:LCM_DAEMON_PORT.
.PARAMETER Log
  Displays the recent active daemon audit log in read-only mode (Aliases: -View, -ShowLog).
.PARAMETER Lines
  Number of recent lines to display when viewing log (Default: 50).
.PARAMETER Tail
  Live tails the active daemon audit log to terminal (Aliases: -Follow, -f).
.PARAMETER Cleanup
  Triggers automated cleanup of daemon log files older than -MaxAgeDays (Aliases: -PurgeLogs).
.PARAMETER MaxAgeDays
  Age threshold in days for log cleanup (Default: 7).
.PARAMETER Force
  Forces log cleanup without interactive prompt confirmation.
.PARAMETER Start
  Starts the desktop daemon in background if not already running.
.PARAMETER Stop
  Sends a shutdown signal to the active daemon.
.PARAMETER Restart
  Safely stops and restarts the background daemon.
.PARAMETER Help
  Displays this comprehensive parameter reference (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Show-LcmDaemon.ps1 -h
.EXAMPLE
  pwsh tools/Show-LcmDaemon.ps1
.EXAMPLE
  pwsh tools/Show-LcmDaemon.ps1 -Log
.EXAMPLE
  pwsh tools/Show-LcmDaemon.ps1 -Tail
.EXAMPLE
  pwsh tools/Show-LcmDaemon.ps1 -Cleanup -MaxAgeDays 7
.EXAMPLE
  pwsh tools/Show-LcmDaemon.ps1 -Restart
#>

[CmdletBinding()]
param(
  [int]$Port = 0,

  [Alias('View', 'ShowLog', 'Read')]
  [switch]$Log,

  [int]$Lines = 50,

  [Alias('Follow', 'f')]
  [switch]$Tail,

  [Alias('PurgeLogs')]
  [switch]$Cleanup,

  [int]$MaxAgeDays = 7,

  [switch]$Force,

  [switch]$Start,

  [switch]$Stop,

  [switch]$Restart,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "1.1.0"
$scriptName = "Show-LcmDaemon"

# Resolve port
if ($Port -le 0) {
  if ($env:LCM_DAEMON_PORT -match '^\d+$') {
    $Port = [int]$env:LCM_DAEMON_PORT
  } else {
    $Port = 9876
  }
}

$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcdRoot 'tools\internal'
$daemonScript = Join-Path $toolsDir 'LcmDesktopDaemon.ps1'
$manifestPath = Join-Path $env:TEMP 'lcm_desktop_daemon.json'
$logsDir = Join-Path $toolsDir 'logs'
$dateStamp = (Get-Date).ToString("yyyyMMdd")

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM DESKTOP DAEMON MONITOR & TELEMETRY (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Real-time telemetry, health probe, read-only log viewer, and cleanup for LcmDesktopDaemon (Port $Port)."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Show-LcmDaemon.ps1 [-Port <int>] [-Log] [-Lines <int>] [-Tail] [-Cleanup] [-MaxAgeDays <int>] [-Start] [-Stop] [-Restart] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Port <int>        : Target TCP port (Default: 9876)."
  Write-Host "  -Log, -View        : Displays recent read-only audit log in terminal."
  Write-Host "  -Lines <int>       : Number of log lines to show (Default: 50)."
  Write-Host "  -Tail, -f          : Live tail active daemon audit log."
  Write-Host "  -Cleanup           : Triggers purge of daemon logs older than -MaxAgeDays."
  Write-Host "  -MaxAgeDays <int>  : Retention threshold in days (Default: 7)."
  Write-Host "  -Force             : Bypasses confirmation during cleanup."
  Write-Host "  -Start             : Starts daemon in background."
  Write-Host "  -Stop              : Shuts down active daemon."
  Write-Host "  -Restart           : Restarts daemon."
  Write-Host "  -h, -Help, -?      : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Resolve Active Log File & Status Probe
# ------------------------------------------------------------------------------
$statusUri = "http://127.0.0.1:$Port/status"
$status = $null
$isOnline = $false

try {
  $status = Invoke-RestMethod -Uri $statusUri -TimeoutSec 2 -ErrorAction Stop
  $isOnline = $true
} catch {
  $isOnline = $false
}

$activeLogFile = ""
if ($isOnline -and $status -and $status.PSObject.Properties['logFile'] -and (Test-Path -LiteralPath $status.logFile)) {
  $activeLogFile = $status.logFile
} else {
  $latestLog = Get-ChildItem -Path $logsDir -File -Filter "LcmDesktopDaemon-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($latestLog) { $activeLogFile = $latestLog.FullName }
  else { $activeLogFile = Join-Path $logsDir "LcmDesktopDaemon-$dateStamp.log" }
}

# ------------------------------------------------------------------------------
# 2. Helper Functions: Log Viewer & Cleanup Engine
# ------------------------------------------------------------------------------

function Show-DaemonLogContent {
  param([string]$FilePath, [int]$LineCount = 50)
  if (-not (Test-Path -LiteralPath $FilePath)) {
    Write-Host "Active log file not found: $FilePath" -ForegroundColor Yellow
    return
  }
  Write-Host ""
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " DAEMON AUDIT LOG (READ-ONLY) - Last $LineCount Lines" -ForegroundColor Cyan
  Write-Host " Source: $FilePath" -ForegroundColor Gray
  Write-Host "==========================================================================" -ForegroundColor Cyan
  $logContent = @(Get-Content -LiteralPath $FilePath -Tail $LineCount)
  foreach ($line in $logContent) {
    if ($line -match '\[ERROR\]') { Write-Host $line -ForegroundColor Red }
    elseif ($line -match '\[WARN\]') { Write-Host $line -ForegroundColor Yellow }
    elseif ($line -match '\[ACTION\]') { Write-Host $line -ForegroundColor Green }
    elseif ($line -match '\[DEBUG\]') { Write-Host $line -ForegroundColor DarkGray }
    else { Write-Host $line -ForegroundColor Gray }
  }
  Write-Host "==========================================================================" -ForegroundColor Cyan
}

function Invoke-DaemonLogCleanupEngine {
  param([string]$LogsDirectory, [int]$Days = 7, [bool]$BypassPrompt = $false)
  if (-not (Test-Path -LiteralPath $LogsDirectory)) {
    Write-Host "Logs directory not found: $LogsDirectory" -ForegroundColor Yellow
    return
  }

  $cutoff = (Get-Date).AddDays(-$Days)
  $allDaemonLogs = @(Get-ChildItem -Path $LogsDirectory -File -Filter "LcmDesktopDaemon-*.log")
  $purgeCandidates = @($allDaemonLogs | Where-Object { $_.LastWriteTime -lt $cutoff })
  $meas = $purgeCandidates | Measure-Object -Property Length -Sum
  $totalBytes = if ($meas -and $meas.PSObject.Properties['Sum'] -and $meas.Sum) { $meas.Sum } else { 0 }
  $totalMB = [math]::Round($totalBytes / 1MB, 2)

  Write-Host ""
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " DAEMON LOG RETENTION & CLEANUP" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "  Log Directory    : $LogsDirectory"
  Write-Host "  Total Daemon Logs: $($allDaemonLogs.Count)"
  Write-Host "  Age Threshold    : Older than $Days days (< $($cutoff.ToString('yyyy-MM-dd')))"
  Write-Host "  Purge Candidates : $($purgeCandidates.Count) files ($totalMB MB / $totalBytes bytes)"

  if ($purgeCandidates.Count -eq 0) {
    Write-Host "  Result           : No expired daemon logs found. Directory is clean." -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
  }

  if (-not $BypassPrompt) {
    Write-Host ""
    $confirm = Read-Host "Proceed with purging $($purgeCandidates.Count) expired log files? [y/N]"
    if ($confirm -notmatch '^(y|yes)$') {
      Write-Host "Cleanup aborted by operator." -ForegroundColor Yellow
      return
    }
  }

  $deletedCount = 0
  $freedBytes = 0
  foreach ($f in $purgeCandidates) {
    try {
      $freedBytes += $f.Length
      Remove-Item -LiteralPath $f.FullName -Force
      $deletedCount++
      Write-Host "  [PURGED] $($f.Name)" -ForegroundColor Gray
    } catch {
      Write-Host "  [FAILED] $($f.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
  }

  $freedMB = [math]::Round($freedBytes / 1MB, 2)
  Write-Host "--------------------------------------------------------------------------" -ForegroundColor Gray
  Write-Host "  Cleanup Complete : $deletedCount files removed, $freedMB MB ($freedBytes bytes) freed." -ForegroundColor Green
  Write-Host "==========================================================================" -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# 3. Stop / Restart / Start Handlers
# ------------------------------------------------------------------------------
if ($Stop -or $Restart) {
  Write-Host "Sending stop signal to daemon on port $Port..." -ForegroundColor Yellow
  & pwsh -File $daemonScript -Port $Port -Stop
  Start-Sleep -Milliseconds 600
}

if ($Start -or $Restart) {
  Write-Host "Starting daemon in background on port $Port..." -ForegroundColor Green
  & pwsh -File $daemonScript -Port $Port -Background
  Start-Sleep -Milliseconds 800
}

# ------------------------------------------------------------------------------
# 4. Direct Cleanup / View / Tail Action Execution
# ------------------------------------------------------------------------------
if ($Cleanup) {
  Invoke-DaemonLogCleanupEngine -LogsDirectory $logsDir -Days $MaxAgeDays -BypassPrompt $Force
  return
}

if ($Log) {
  Show-DaemonLogContent -FilePath $activeLogFile -LineCount $Lines
  return
}

if ($Tail) {
  if (-not (Test-Path -LiteralPath $activeLogFile)) {
    Write-Host "Log file not yet created: $activeLogFile" -ForegroundColor Yellow
    return
  }
  Write-Host ""
  Write-Host "--- Tailing Live Daemon Log (Ctrl+C to exit) ---" -ForegroundColor Yellow
  Get-Content -LiteralPath $activeLogFile -Tail 30 -Wait
  return
}

# ------------------------------------------------------------------------------
# 5. Status & Health Probe Card
# ------------------------------------------------------------------------------
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM DESKTOP DAEMON TELEMETRY & HEALTH STATUS" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($isOnline) {
  $uptimeFormatted = "$($status.uptimeSec)s"
  if ($status.uptimeSec -gt 3600) {
    $hrs = [math]::Floor($status.uptimeSec / 3600)
    $mins = [math]::Floor(($status.uptimeSec % 3600) / 60)
    $uptimeFormatted = "${hrs}h ${mins}m ($($status.uptimeSec)s)"
  } elseif ($status.uptimeSec -gt 60) {
    $mins = [math]::Floor($status.uptimeSec / 60)
    $secs = $status.uptimeSec % 60
    $uptimeFormatted = "${mins}m ${secs}s"
  }

  Write-Host "  Status      : " -NoNewline; Write-Host "ONLINE" -ForegroundColor Green
  Write-Host "  Version     : $($status.version)"
  Write-Host "  Port        : $($status.port)"
  Write-Host "  PID         : $($status.pid)"
  Write-Host "  Session ID  : $($status.sessionId) (Interactive Desktop)"
  Write-Host "  User        : $($status.user)"
  Write-Host "  Uptime      : $uptimeFormatted"
  if ($status.PSObject.Properties['workingSetMB'] -and $status.workingSetMB) {
    Write-Host "  Working Set : $($status.workingSetMB) MB"
  }
  Write-Host "  Log File    : $activeLogFile"
  Write-Host "--------------------------------------------------------------------------" -ForegroundColor Gray
  Write-Host "  Registered Endpoints:" -ForegroundColor Cyan
  Write-Host "    GET  /ping, /status  - Health probe & session telemetry"
  Write-Host "    POST /open           - Instant browser / app / dashboard launch"
  Write-Host "    POST /foreground     - Bring target window to focus"
  Write-Host "    POST /execute        - Run visible console command"
  Write-Host "    POST /open_editor    - Open source file in VS Code / IDE"
  Write-Host "    POST /query_cleanup  - Probe artifact sizes before purge"
  Write-Host "    POST /cleanup        - Purge logs or archive history"
  Write-Host "    POST /rename         - Dual-field tool rename & sync"
  Write-Host "    POST /archive        - Move tool to archive"
  Write-Host "    POST /sync_json      - Merge dashboard overrides & catalog state"
  Write-Host "    POST /stop           - Graceful shutdown"
} else {
  Write-Host "  Status      : " -NoNewline; Write-Host "OFFLINE (No listener on port $Port)" -ForegroundColor Red
  Write-Host "  Log File    : $activeLogFile"
  Write-Host "  Start Cmd   : pwsh tools/LcmDesktopDaemon.ps1 -Background" -ForegroundColor Yellow
}
Write-Host "==========================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 6. Interactive Keyboard Action Trigger Menu
# ------------------------------------------------------------------------------
if ([System.Environment]::UserInteractive) {
  Write-Host "Actions: [V]iew Log  |  [T]ail Log  |  [C]leanup Logs  |  [R]estart Daemon  |  [Q]uit" -ForegroundColor Yellow
  Write-Host "Select action (or press Enter to exit): " -NoNewline -ForegroundColor Cyan
  $key = [System.Console]::ReadLine()

  if ($key -match '^(v|view|l|log)$') {
    Show-DaemonLogContent -FilePath $activeLogFile -LineCount $Lines
  } elseif ($key -match '^(t|tail|f)$') {
    Write-Host ""
    Write-Host "--- Tailing Live Daemon Log (Ctrl+C to exit) ---" -ForegroundColor Yellow
    Get-Content -LiteralPath $activeLogFile -Tail 30 -Wait
  } elseif ($key -match '^(c|clean|cleanup)$') {
    Invoke-DaemonLogCleanupEngine -LogsDirectory $logsDir -Days $MaxAgeDays -BypassPrompt $false
  } elseif ($key -match '^(r|restart)$') {
    Write-Host "Restarting daemon..." -ForegroundColor Yellow
    & pwsh -File $daemonScript -Port $Port -Stop
    Start-Sleep -Milliseconds 600
    & pwsh -File $daemonScript -Port $Port -Background
    Start-Sleep -Milliseconds 800
    & pwsh -File $PSCommandPath -Port $Port
  }
}

