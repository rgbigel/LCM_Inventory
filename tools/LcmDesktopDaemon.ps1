<#
.SYNOPSIS
  Lightweight modular high-performance HTTP/REST bridge daemon running in Session 1 for cross-session GUI dispatch.
.DESCRIPTION
  Module: LcmDesktopDaemon
  Purpose: Runs inside the user's interactive desktop (Session 1) listening on localhost TCP (Default: 9876).
           Accepts HTTP JSON-RPC requests from background agent workers, CLI scripts, and IDE sub-processes:
           1. /ping or /status  : Validates daemon health, session ID, user context, and uptime.
           2. /open            : Opens URLs, HTML dashboards, or file paths in default browser/app with foreground focus.
           3. /execute         : Dispatches interactive visible console commands or GUI tools.
           4. /foreground      : Forces top-level window matching title to the foreground.
           5. /open_editor     : Opens source files at specified line in VS Code / IDE.
           6. /query_cleanup   : Probes exact file counts and byte sizes for logs and archives.
           7. /cleanup         : Atomically purges logs, archive snapshots, or caches based on selections.
           8. /rename          : Safely renames physical source files and updates short-name aliases.
           9. /archive         : Moves deprecated tools to LCM_Inventory/tools/archive/ and updates catalog.
           10. /sync_json      : Merges window-close dashboard state and review overrides into catalog.
           11. /stop           : Cleanly terminates listener.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: tools/LcmDesktopDaemon.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.1
  Date: 2026-10-21
.PARAMETER Port
  The local TCP listening port (Default: 9876). Configurable via parameter or $env:LCM_DAEMON_PORT.
.PARAMETER Status
  Queries and displays the active status of the local desktop daemon without starting a new instance.
.PARAMETER Stop
  Sends a shutdown signal to the running desktop daemon instance.
.PARAMETER Background
  Spawns the daemon in a hidden, detached background process.
.PARAMETER LogFile
  Custom log file destination. Defaults to tools/logs/LcmDesktopDaemon-yyyyMMdd.log.
.PARAMETER MaxLogAgeDays
  Maximum age in days before daemon log files are automatically pruned (Default: 7).
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/LcmDesktopDaemon.ps1 -h
.EXAMPLE
  pwsh tools/LcmDesktopDaemon.ps1
.EXAMPLE
  pwsh tools/LcmDesktopDaemon.ps1 -Background
.EXAMPLE
  pwsh tools/LcmDesktopDaemon.ps1 -Status
.EXAMPLE
  pwsh tools/LcmDesktopDaemon.ps1 -Stop
.DEPENDENCIES
  tools/modules/LcmDaemonCore.psm1
#>

[CmdletBinding()]
param(
  [int]$Port = 0,

  [switch]$Status,

  [switch]$Stop,

  [switch]$Background,

  [string]$LogFile = "",

  [int]$MaxLogAgeDays = 7,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.1"
$scriptName = "LcmDesktopDaemon"

# Resolve configured port: Parameter > EnvVar > Default (9876)
if ($Port -le 0) {
  if ($env:LCM_DAEMON_PORT -match '^\d+$') {
    $Port = [int]$env:LCM_DAEMON_PORT
  } else {
    $Port = 9876
  }
}

$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcdRoot 'tools'
$manifestPath = Join-Path $env:TEMP 'lcm_desktop_daemon.json'

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM DESKTOP REST BRIDGE DAEMON (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Lightweight HTTP REST daemon running in Session 1 for sub-millisecond"
  Write-Host "  cross-session GUI dispatch, browser activation, and console launching."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/LcmDesktopDaemon.ps1 [-Port <int>] [-Background] [-Status] [-Stop] [-MaxLogAgeDays <int>] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Port <int>         : TCP Port to bind (Default: 9876)."
  Write-Host "  -Background         : Launches daemon detached in hidden background window."
  Write-Host "  -Status             : Tests if daemon is running and displays active manifest."
  Write-Host "  -Stop               : Sends stop command to running daemon."
  Write-Host "  -MaxLogAgeDays <int>: Maximum age in days before rotating/purging daemon logs (Default: 7)."
  Write-Host "  -h, -Help, -?       : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Status & Stop Actions
# ------------------------------------------------------------------------------
if ($Status) {
  $pingUri = "http://127.0.0.1:$Port/ping"
  try {
    $res = Invoke-RestMethod -Uri $pingUri -TimeoutSec 2 -ErrorAction Stop
    Write-Host "[ONLINE] LCM Desktop Daemon is active on port $Port" -ForegroundColor Green
    $res | Format-List
    return $res
  } catch {
    Write-Host "[OFFLINE] No daemon responding on port $Port" -ForegroundColor Red
    if (Test-Path -LiteralPath $manifestPath) {
      Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
    }
    return $null
  }
}

if ($Stop) {
  $stopUri = "http://127.0.0.1:$Port/stop"
  try {
    Invoke-RestMethod -Uri $stopUri -Method Post -TimeoutSec 2 -ErrorAction Stop | Out-Null
    Write-Host "[STOPPED] Signal sent to daemon on port $Port" -ForegroundColor Yellow
  } catch {
    Write-Host "[INFO] Daemon was not running on port $Port" -ForegroundColor Gray
  }
  if (Test-Path -LiteralPath $manifestPath) {
    Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
  }
  return
}

# ------------------------------------------------------------------------------
# 2. Background Detach Mode
# ------------------------------------------------------------------------------
if ($Background) {
  $pingUri = "http://127.0.0.1:$Port/ping"
  try {
    $res = Invoke-RestMethod -Uri $pingUri -TimeoutSec 1 -ErrorAction Stop
    Write-Host "[INFO] Daemon already running on port $Port (PID: $($res.pid))" -ForegroundColor Green
    return
  } catch {}

  $scriptPath = $PSCommandPath
  $taskName = "LCM_Daemon_InteractiveStarter"
  $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Port $Port"
  $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
  try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Milliseconds 1500
  } catch {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "pwsh.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Port $Port"
    $psi.UseShellExecute = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $proc = [System.Diagnostics.Process]::Start($psi)
    Start-Sleep -Milliseconds 1200
  } finally {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
  }

  try {
    $res = Invoke-RestMethod -Uri $pingUri -TimeoutSec 2 -ErrorAction Stop
    Write-Host "[STARTED] LCM Desktop Daemon active on port $Port (PID: $($res.pid))" -ForegroundColor Green
  } catch {
    Write-Host "[STARTED] LCM Desktop Daemon spawned (Port: $Port)" -ForegroundColor Green
  }
  return
}

# ------------------------------------------------------------------------------
# 3. Import Object-Oriented Daemon Core (Dot-source for class visibility)
# ------------------------------------------------------------------------------
$moduleRoot = Join-Path $lcdRoot 'modules\LcmDaemon'
$classesDir = Join-Path $moduleRoot 'Classes'

if (-not (Test-Path -LiteralPath $classesDir)) {
  throw "Required LcmDaemon Classes directory not found: $classesDir"
}

. (Join-Path $classesDir 'DaemonDto.ps1')
. (Join-Path $classesDir 'DaemonEnvironment.ps1')
. (Join-Path $classesDir 'DaemonActionController.ps1')

if ($null -eq ('LcmControlHubRefreshBroker' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

public static class LcmControlHubRefreshBroker
{
  private sealed class Subscriber
  {
    public readonly HttpListenerResponse Response;
    public readonly ManualResetEventSlim Closed = new ManualResetEventSlim(false);
    public readonly object SyncRoot = new object();

    public Subscriber(HttpListenerResponse response)
    {
      Response = response;
    }
  }

  private static readonly ConcurrentDictionary<Guid, Subscriber> Subscribers =
    new ConcurrentDictionary<Guid, Subscriber>();

  public static void Subscribe(HttpListenerResponse response)
  {
    var id = Guid.NewGuid();
    var subscriber = new Subscriber(response);
    Subscribers[id] = subscriber;
    response.StatusCode = 200;
    response.ContentType = "text/event-stream";
    response.SendChunked = true;
    response.Headers["Cache-Control"] = "no-cache";
    response.Headers["Connection"] = "keep-alive";
    response.Headers["Access-Control-Allow-Origin"] = "*";

    Task.Run(() =>
    {
      try
      {
        Write(subscriber, "event: connected\ndata: ready\n\n");
        subscriber.Closed.Wait();
      }
      catch
      {
      }
      finally
      {
        Subscriber removed;
        Subscribers.TryRemove(id, out removed);
        try { response.Close(); } catch { }
      }
    });
  }

  public static int Publish(string payload)
  {
    var delivered = 0;
    foreach (var item in Subscribers)
    {
      try
      {
        Write(item.Value, "event: refresh\ndata: " + payload + "\n\n");
        delivered++;
      }
      catch
      {
        item.Value.Closed.Set();
      }
    }
    return delivered;
  }

  private static void Write(Subscriber subscriber, string message)
  {
    lock (subscriber.SyncRoot)
    {
      var bytes = Encoding.UTF8.GetBytes(message);
      subscriber.Response.OutputStream.Write(bytes, 0, bytes.Length);
      subscriber.Response.OutputStream.Flush();
    }
  }
}
'@
}

$logDir = Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm-internal'
if (-not (Test-Path -Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $dateStamp = (Get-Date).ToString("yyyyMMdd")
  $LogFile = Join-Path $logDir "$($scriptName)-$dateStamp.log"
}

# Instantiate strongly typed environment state and controller
$envObj = [DaemonEnvironment]::new($workspaceRoot, $Port, $scriptVersion, $LogFile)
$controller = [DaemonActionController]::new($envObj)
Import-Module -Name (Join-Path $lcdRoot 'modules\LcmDisplayHttp.psm1') -Force

# Run automated log retention maintenance
$controller.PerformLogMaintenance($MaxLogAgeDays)

# ------------------------------------------------------------------------------
# 4. HTTP Listener Initialization
# ------------------------------------------------------------------------------
$listener = [System.Net.HttpListener]::new()
$prefix = "http://127.0.0.1:$Port/"
$listener.Prefixes.Add($prefix)

try {
  $listener.Start()
} catch {
  $envObj.Log("Failed to bind to port $Port : $($_.Exception.Message)", 'ERROR')
  throw $_
}

# Write session manifest
$manifest = [PSCustomObject]@{
  status      = "ONLINE"
  port        = $Port
  pid         = $envObj.Pid
  sessionId   = $envObj.SessionId
  user        = $envObj.User
  host        = $env:COMPUTERNAME
  startedAt   = $envObj.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
  prefix      = $prefix
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$envObj.Log("Listening on $prefix (SessionId: $($envObj.SessionId), PID: $($envObj.Pid))", 'ACTION')
$proposalDocumentsRoot = Join-Path $workspaceRoot 'LCM_Inventory\docs\Proposals'
$proposalDocumentWatcher = $null
$proposalDocumentWatcherSubscription = $null

# ------------------------------------------------------------------------------
# 5. Core Request Dispatch Loop (Strongly-Typed OOP Routing)
# ------------------------------------------------------------------------------
$isRunning = $true

try {
  while ($isRunning -and $listener.IsListening) {
    try {
      $httpContext = $listener.GetContext()
      $request = $httpContext.Request
      $response = $httpContext.Response
      $rawUrl = $request.RawUrl
      $reqPath = $request.Url.AbsolutePath.ToLowerInvariant()
      if ($reqPath.Length -gt 1 -and $reqPath.EndsWith('/')) {
        $reqPath = $reqPath.TrimEnd('/')
      }
      $httpMethod = $request.HttpMethod

      if (Invoke-LcmDisplayHttpRequest -Request $request -Response $response -WorkspaceRoot $workspaceRoot) {
        continue
      }

      $envObj.Log("$httpMethod $rawUrl from $($request.RemoteEndPoint)", 'DEBUG')

      # Parse Body if present
      $bodyJson = $null
      $bodyStr = ""
      if ($request.HasEntityBody) {
        $reader = [System.IO.StreamReader]::new($request.InputStream, [System.Text.Encoding]::UTF8)
        $bodyStr = $reader.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($bodyStr)) {
          try { $bodyJson = $bodyStr | ConvertFrom-Json } catch {}
        }
      }

      # Route: OPTIONS (CORS Preflight)
      if ($httpMethod -eq 'OPTIONS') {
        Send-DaemonJsonResponse -Response $response -Data @{ status = "OK" }
        continue
      }

      # Route: GET /ping or /status
      if ($httpMethod -eq 'GET' -and ($reqPath -in @('/ping', '/status', '/', '/api/ping', '/api/status'))) {
        $daemonStatus = $controller.GetStatus()
        $daemonStatus['standardDisplays'] = 1
        Send-DaemonJsonResponse -Response $response -Data $daemonStatus
        continue
      }

      if ($httpMethod -eq 'GET' -and ($reqPath -in @('/proposal-documents', '/api/proposal-documents'))) {
        $documents = @{}
        if (Test-Path -LiteralPath $proposalDocumentsRoot) {
          Get-ChildItem -LiteralPath $proposalDocumentsRoot -Recurse -File -Filter '*.md' | ForEach-Object {
            $key = $_.FullName.Substring($workspaceRoot.Length + 1).Replace('\', '/')
            $documents[$key] = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
          }
        }
        Send-DaemonJsonResponse -Response $response -Data @{ status = 'OK'; documents = $documents }
        continue
      }

      # Route: GET /hub-events (completion-triggered Control Hub refresh stream)
      if ($httpMethod -eq 'GET' -and ($reqPath -in @('/hub-events', '/api/hub-events'))) {
        [LcmControlHubRefreshBroker]::Subscribe($response)
        continue
      }

      # Route: POST /hub-refresh (publish a lifecycle completion display refresh)
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/hub-refresh', '/api/hub-refresh'))) {
        $payload = if ($bodyStr) { $bodyStr } else { '{"event":"refresh"}' }
        $delivered = [LcmControlHubRefreshBroker]::Publish($payload)
        Send-DaemonJsonResponse -Response $response -Data @{ status = 'OK'; delivered = $delivered }
        continue
      }

      # Route: GET /proposals (LCM Standard Display Dynamic Re-Query per CRP-115 & CRP-108)
      if ($httpMethod -eq 'GET' -and ($reqPath -in @('/proposals', '/proposals.json', '/api/proposals', '/api/proposals.json'))) {
        $propFile = Join-Path $envObj.WorkspaceRoot 'LCM_Inventory\data\proposals\proposals.json'
        $propData = @{ last_proposal_id = 0; proposals = @() }
        if (Test-Path -LiteralPath $propFile) {
          try {
            $rawP = [System.IO.File]::ReadAllText($propFile, [System.Text.Encoding]::UTF8)
            $propData = $rawP | ConvertFrom-Json
          } catch {}
        }
        $sessFile = Join-Path $envObj.WorkspaceRoot 'LCM_Inventory\data\session_state\active_session.json'
        if (Test-Path -LiteralPath $sessFile) {
          try {
            $rawS = [System.IO.File]::ReadAllText($sessFile, [System.Text.Encoding]::UTF8)
            $propData | Add-Member -MemberType NoteProperty -Name 'session_state' -Value ($rawS | ConvertFrom-Json) -Force
          } catch {}
        }
        Send-DaemonJsonResponse -Response $response -Data $propData
        continue
      }

      # Route: GET /session_state or /analysis_state (Analysis Governance State per RULE-ANA-006)
      if ($httpMethod -eq 'GET' -and ($reqPath -in @('/session_state', '/api/session_state', '/analysis_state', '/api/analysis_state'))) {
        $sessFile = Join-Path $envObj.WorkspaceRoot 'LCM_Inventory\data\session_state\active_session.json'
        $sessData = @{
          operating_mode  = 'GOVERNED_IMPLEMENTATION'
          active_gate     = 'STEP_001'
          search_radius   = 2
          settled_facts   = @()
          open_hypotheses = @()
          circuit_breaker = $false
        }
        if (Test-Path -LiteralPath $sessFile) {
          try {
            $rawS = [System.IO.File]::ReadAllText($sessFile, [System.Text.Encoding]::UTF8)
            $sessData = $rawS | ConvertFrom-Json
          } catch {}
        }
        Send-DaemonJsonResponse -Response $response -Data $sessData
        continue
      }

      # Route: POST /set_priority or /priority (Immediate Priority Update)
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/set_priority', '/priority', '/api/set_priority', '/api/priority'))) {
        $id = [int]$bodyJson.id
        $prio = [int]$bodyJson.priority
        $propFile = Join-Path $envObj.WorkspaceRoot 'LCM_Inventory\data\proposals\proposals.json'
        if (Test-Path -LiteralPath $propFile) {
          try {
            $rawP = [System.IO.File]::ReadAllText($propFile, [System.Text.Encoding]::UTF8)
            $propData = $rawP | ConvertFrom-Json
            $target = $propData.proposals | Where-Object { $_.id -eq $id }
            if ($target) {
              $target.priority = $prio
              [System.IO.File]::WriteAllText($propFile, ($propData | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
              $logFile = Join-Path $envObj.WorkspaceRoot 'LCM_Inventory\logs\cm_activity.log'
              if (Test-Path -LiteralPath (Split-Path $logFile -Parent)) {
                $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Add-Content -LiteralPath $logFile -Value "[$ts] PRIORITY CHANGE: Proposal #$id set to priority $prio" -Encoding UTF8
              }
              Send-DaemonJsonResponse -Response $response -Data @{ status = 'OK'; id = $id; priority = $prio }
              continue
            }
          } catch {
            Send-DaemonJsonResponse -Response $response -Data @{ error = $_.Exception.Message } -StatusCode 500
            continue
          }
        }
        Send-DaemonJsonResponse -Response $response -Data @{ error = "Proposal not found" } -StatusCode 404
        continue
      }

      # Route: GET /progress/current or /progress (CRP-110)
      if ($httpMethod -eq 'GET' -and ($reqPath -in @('/progress/current', '/progress', '/api/progress/current', '/api/progress'))) {
        $progressFile = Join-Path ([System.IO.Path]::GetTempPath()) 'lcm\active_progress.json'
        $progData = @{}
        if (Test-Path -LiteralPath $progressFile) {
          try {
            $rawP = [System.IO.File]::ReadAllText($progressFile, [System.Text.Encoding]::UTF8)
            $progData = $rawP | ConvertFrom-Json
          } catch {}
        }
        Send-DaemonJsonResponse -Response $response -Data $progData
        continue
      }

      # Route: POST /progress/update or /progress/start (CRP-110)
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/progress/update', '/progress/start', '/api/progress/update', '/api/progress/start'))) {
        $progressFile = Join-Path ([System.IO.Path]::GetTempPath()) 'lcm\active_progress.json'
        if ($bodyJson) {
          $scratchD = Split-Path $progressFile -Parent
          if (-not (Test-Path -LiteralPath $scratchD)) { New-Item -Path $scratchD -ItemType Directory -Force | Out-Null }
          [System.IO.File]::WriteAllText($progressFile, ($bodyJson | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
        }
        Send-DaemonJsonResponse -Response $response -Data @{ status = "OK" }
        continue
      }

      # Route: POST /stop
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/stop', '/api/stop'))) {
        $envObj.Log("Received shutdown signal via /stop", 'ACTION')
        Send-DaemonJsonResponse -Response $response -Data @{ status = "STOPPING" }
        $isRunning = $false
        break
      }

      # Route: POST /abort or /abort_execution
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/abort', '/abort_execution', '/api/abort'))) {
        $data = $controller.AbortExecution()
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /open
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/open', '/api/open'))) {
        $dto = [DaemonOpenRequest]::FromJson($bodyJson)
        $data = $controller.OpenTarget($dto)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /foreground
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/foreground', '/api/foreground'))) {
        $title = if ($bodyJson -and $bodyJson.PSObject.Properties['title']) { [string]$bodyJson.title } else { "" }
        $data = $controller.ForegroundWindow($title)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /execute
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/execute', '/api/execute'))) {
        $dto = [DaemonExecuteRequest]::FromJson($bodyJson)
        $data = $controller.ExecuteCommand($dto)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /open_editor or /edit
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/open_editor', '/edit', '/api/open_editor', '/api/edit'))) {
        $dto = [DaemonEditRequest]::FromJson($bodyJson)
        $data = $controller.OpenEditor($dto)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /tool_help
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/tool_help', '/api/tool_help'))) {
        $dto = [DaemonHelpRequest]::FromJson($bodyJson)
        $data = $controller.ShowToolHelp($dto)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /query_cleanup
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/query_cleanup', '/api/query_cleanup'))) {
        $dto = [DaemonCleanupQueryRequest]::FromJson($bodyJson)
        $data = $controller.QueryCleanup($dto)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /cleanup
      if ($httpMethod -eq 'POST' -and ($reqPath -in @('/cleanup', '/api/cleanup'))) {
        $dto = [DaemonCleanupRequest]::FromJson($bodyJson)
        $data = $controller.ExecuteCleanup($dto)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /rename
      if ($httpMethod -eq 'POST' -and $rawUrl -eq '/rename') {
        $dto = [DaemonRenameRequest]::FromJson($bodyJson)
        $data = $controller.RenameTool($dto)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /query_all_short_names or GET /short_names_map
      if (($httpMethod -eq 'POST' -or $httpMethod -eq 'GET') -and ($rawUrl -eq '/query_all_short_names' -or $rawUrl -eq '/short_names_map')) {
        $catalogPath = Join-Path $workspaceRoot 'LCM_Inventory\config\tool_catalog.json'
        $map = @{}
        if (Test-Path -LiteralPath $catalogPath) {
          try {
            $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($entry in $catalog) {
              $leaf = $entry.Name
              if (-not [string]::IsNullOrWhiteSpace($leaf)) {
                if (-not $map.ContainsKey($leaf)) { $map[$leaf] = [System.Collections.Generic.List[string]]::new() }
                if (-not [string]::IsNullOrWhiteSpace($entry.ShortName) -and -not $map[$leaf].Contains($entry.ShortName)) {
                  $map[$leaf].Add($entry.ShortName)
                }
                if ($entry.Aliases) {
                  foreach ($alias in $entry.Aliases) {
                    if (-not [string]::IsNullOrWhiteSpace($alias) -and -not $map[$leaf].Contains($alias)) {
                      $map[$leaf].Add($alias)
                    }
                  }
                }
              }
            }
          } catch {}
        }
        Send-DaemonJsonResponse -Response $response -Data @{
          status = 'OK'
          map    = $map
        }
        continue
      }

      # Route: POST /query_short_names
      if ($httpMethod -eq 'POST' -and $rawUrl -eq '/query_short_names') {
        $targetScript = if ($bodyJson.PSObject.Properties['targetScript']) { [string]$bodyJson.targetScript } else { '' }
        $targetLeaf = [System.IO.Path]::GetFileName($targetScript)
        $catalogPath = Join-Path $workspaceRoot 'LCM_Inventory\config\tool_catalog.json'
        $matching = [System.Collections.Generic.List[string]]::new()
        if (Test-Path -LiteralPath $catalogPath) {
          try {
            $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($entry in $catalog) {
              if ($entry.Name -ieq $targetLeaf -or [System.IO.Path]::GetFileNameWithoutExtension($entry.Name) -ieq [System.IO.Path]::GetFileNameWithoutExtension($targetLeaf)) {
                if (-not [string]::IsNullOrWhiteSpace($entry.ShortName) -and -not $matching.Contains($entry.ShortName)) {
                  $matching.Add($entry.ShortName)
                }
                if ($entry.Aliases) {
                  foreach ($alias in $entry.Aliases) {
                    if (-not [string]::IsNullOrWhiteSpace($alias) -and -not $matching.Contains($alias)) {
                      $matching.Add($alias)
                    }
                  }
                }
              }
            }
          } catch {}
        }
        Send-DaemonJsonResponse -Response $response -Data @{
          status       = 'OK'
          targetScript = $targetLeaf
          shortNames   = @($matching)
          count        = $matching.Count
        }
        continue
      }

      # Route: POST /delete_short_name
      if ($httpMethod -eq 'POST' -and $rawUrl -eq '/delete_short_name') {
        $sn = if ($bodyJson.PSObject.Properties['shortName']) { [string]$bodyJson.shortName } else { '' }
        $ts = if ($bodyJson.PSObject.Properties['targetScript']) { [string]$bodyJson.targetScript } else { '' }
        $removeScript = Join-Path $workspaceRoot 'LCM_Inventory\tools\Remove-LcmShortName.ps1'
        $resObj = & $removeScript -ShortName $sn -TargetScript $ts -Force
        Send-DaemonJsonResponse -Response $response -Data $resObj
        continue
      }

      # Route: POST /rename
      if ($httpMethod -eq 'POST' -and ($rawUrl -eq '/rename' -or $rawUrl -eq '/api/rename')) {
        $dto = [DaemonRenameRequest]::FromJson($bodyJson)
        $data = $controller.RenameTool($dto)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /archive
      if ($httpMethod -eq 'POST' -and $rawUrl -eq '/archive') {
        $dto = [DaemonArchiveRequest]::FromJson($bodyJson)
        $data = $controller.ArchiveTool($dto)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /sync_json or /sync_overrides
      if ($httpMethod -eq 'POST' -and ($rawUrl -eq '/sync_json' -or $rawUrl -eq '/sync_overrides')) {
        $dto = [DaemonSyncRequest]::FromJson($bodyJson)
        $data = $controller.SyncCatalogState($dto, $bodyStr)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /report_incident or /telemetry
      if ($httpMethod -eq 'POST' -and ($rawUrl -eq '/report_incident' -or $rawUrl -eq '/incident' -or $rawUrl -eq '/telemetry')) {
        $dto = [DaemonIncidentReportRequest]::FromJson($bodyJson)
        $data = $controller.ReportIncident($dto, $bodyStr)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /print or /export_pdf (LCD Standard Display Table Channel)
      if ($httpMethod -eq 'POST' -and ($rawUrl -eq '/print' -or $rawUrl -eq '/export_pdf')) {
        $dto = [DaemonPrintRequest]::FromJson($bodyJson)
        $data = $controller.HandlePrint($dto)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /add_explorer_option
      if ($httpMethod -eq 'POST' -and $rawUrl -eq '/add_explorer_option') {
        $data = $controller.AddExplorerOption($bodyJson)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }

      # Route: POST /log or /action_log (CRP-151 Universal Action Logging Engine)
      if ($httpMethod -eq 'POST' -and ($rawUrl -like '/log*' -or $rawUrl -like '/action_log*')) {
        $dto = [DaemonActionLogRequest]::FromJson($bodyJson)
        $data = $controller.RecordActionLog($dto, $bodyStr)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }


      # Route: GET /logs or /action_logs or /actions (CRP-151)
      if ($httpMethod -eq 'GET' -and ($rawUrl -like '/logs*' -or $rawUrl -like '/action_logs*' -or $rawUrl -like '/actions*')) {
        $count = 50
        $subsystemFilter = ""
        if ($request.QueryString['count']) {
          [int]::TryParse($request.QueryString['count'], [ref]$count) | Out-Null
        }
        if ($request.QueryString['subsystem']) {
          $subsystemFilter = [string]$request.QueryString['subsystem']
        }
        $data = $controller.GetActionLogs($count, $subsystemFilter)
        Send-DaemonJsonResponse -Response $response -Data $data
        continue
      }


      # 404 Not Found
      Send-DaemonJsonResponse -Response $response -Data @{ error = "Endpoint not found: $rawUrl" } -StatusCode 404
    } catch {
      $envObj.Log("Request dispatch error: $($_.Exception.Message)", 'WARN')
      try {
        Send-DaemonJsonResponse -Response $response -Data @{ error = $_.Exception.Message } -StatusCode 500
      } catch {}
    }
  }
} finally {
  Stop-LcmDisplayHttp
  $listener.Stop()
  $listener.Close()
  if (Test-Path $manifestPath) { Remove-Item $manifestPath -Force -ErrorAction SilentlyContinue }
  $envObj.Log("LCM Desktop Daemon stopped.", 'INFO')
}
