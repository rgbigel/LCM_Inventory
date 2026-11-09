<#
.SYNOPSIS
  Universal Command Gateway CLI client dispatching typed Interface Objects to Port 9876.
.DESCRIPTION
  Module: tools/Invoke-LcmAction.ps1
  Purpose: Primary CLI interface for executing workspace tools and actions via the Port 9876
           Elevated Desktop Daemon and Security Authorization Gateway per CRP-309 Clause 9.
  Path: LCM_Inventory/tools/Invoke-LcmAction.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.2
  Date: 2026-11-08 22:00:00
.NOTES
  Implementation Choices (CRP-309):
  1. Serializes CLI flags and arguments into a typed Interface Object (Action Intent DTO).
  2. Dispatches HTTP POST to http://127.0.0.1:9876/api/action with synchronous stream capture.
  3. Provides automatic self-healing recovery if the daemon task is offline.
  4. Returns the tool's exact exitCode and streams stdout/stderr transparently to the console.
#>

[CmdletBinding(PositionalBinding = $true)]
param(
  [Parameter(Position = 0, Mandatory = $false, HelpMessage = 'Action to perform (e.g. do, status, start, stop, token)')]
  [string]$Action = "do",

  [Parameter(Position = 1, Mandatory = $false, HelpMessage = 'Target tool name or action intent (e.g. RestoreSettings, MacriumDailyBaseline)')]
  [string]$Target = "",

  [Parameter(Mandatory = $false, HelpMessage = 'Raw JSON string or file path containing the Interface Object')]
  [string]$InputObject = "",

  [Parameter(Mandatory = $false, HelpMessage = 'Caller identity for audit telemetry')]
  [string]$Caller = "CLI",

  [Parameter(Mandatory = $false, HelpMessage = 'Optional JIT ephemeral token for Tier 3 mutations')]
  [string]$Token = "",

  [Parameter(Mandatory = $false, HelpMessage = 'Force asynchronous execution without waiting for completion')]
  [switch]$Async,

  [Parameter(Mandatory = $false, HelpMessage = 'Keep console open after execution in interactive mode')]
  [switch]$NoExit,

  [Parameter(Mandatory = $false, HelpMessage = 'Explicitly request elevated execution')]
  [switch]$Elevated,

  [Parameter(ValueFromRemainingArguments = $true, HelpMessage = 'Additional command-line parameters and arguments passed directly to the target tool')]
  [string[]]$RemainingArgs,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help -or ([string]::IsNullOrWhiteSpace($Target) -and $Action -notin @('status', 'start', 'stop', 'help'))) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM UNIVERSAL COMMAND GATEWAY (lcm do)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNTAX:" -ForegroundColor Yellow
  Write-Host "  lcm do <Target> [flags/parameters]" -ForegroundColor White
  Write-Host "  lcm do --input <json-string-or-file>" -ForegroundColor White
  Write-Host "  lcm status | start | stop" -ForegroundColor White
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  lcm do RestoreSettings -DryRun" -ForegroundColor Gray
  Write-Host "  lcm do MacriumDailyBaseline -Drive G" -ForegroundColor Gray
  Write-Host "  lcm do RunProposalAction -crpId CRP-308 -action verify" -ForegroundColor Gray
  Write-Host "  lcm status" -ForegroundColor Gray
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$port = if ($env:LCM_DAEMON_PORT -match '^\d+$') { [int]$env:LCM_DAEMON_PORT } else { 9876 }
$baseUrl = "http://127.0.0.1:$port"
$workspaceRoot = 'D:\Git_Repositories'

# 1. Handle Daemon Control Commands (status, start, stop)
if ($Action -eq 'status') {
  try {
    $res = Invoke-RestMethod -Uri "$baseUrl/ping" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "✅ LCM Desktop Daemon is ONLINE on Port $port (Session $($res.sessionId), PID $($res.pid))" -ForegroundColor Green
    exit 0
  } catch {
    Write-Host "❌ LCM Desktop Daemon is OFFLINE on Port $port" -ForegroundColor Red
    exit 1
  }
}

if ($Action -eq 'start') {
  $regScript = Join-Path $workspaceRoot 'LCM_Inventory\tools\Register-LcmDesktopDaemon.ps1'
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $regScript -Start -Port $port
  exit 0
}

if ($Action -eq 'stop') {
  try {
    $null = Invoke-RestMethod -Uri "$baseUrl/stop" -Method Post -TimeoutSec 2 -ErrorAction Stop
    Write-Host "✅ Stop signal sent to LCM Desktop Daemon." -ForegroundColor Green
    exit 0
  } catch {
    Write-Host "⚠️  Daemon was not reachable on Port $port." -ForegroundColor Yellow
    exit 0
  }
}

# 2. Daemon Reachability & Self-Healing Check
$daemonOnline = $false
try {
  $ping = Invoke-RestMethod -Uri "$baseUrl/ping" -TimeoutSec 1 -ErrorAction Stop
  if ($ping.status -eq 'ONLINE') { $daemonOnline = $true }
} catch {}

if (-not $daemonOnline) {
  Write-Host "ℹ️  LCM Desktop Daemon is offline. Attempting automated self-healing launch..." -ForegroundColor Yellow
  try {
    Start-ScheduledTask -TaskName "LCM_DesktopDaemon_$env:USERNAME" -ErrorAction Stop
    Start-Sleep -Milliseconds 1200
  } catch {
    $regScript = Join-Path $workspaceRoot 'LCM_Inventory\tools\Register-LcmDesktopDaemon.ps1'
    if (Test-Path -LiteralPath $regScript) {
      & pwsh -NoProfile -ExecutionPolicy Bypass -File $regScript -Start -Port $port | Out-Null
      Start-Sleep -Milliseconds 1200
    }
  }

  try {
    $ping = Invoke-RestMethod -Uri "$baseUrl/ping" -TimeoutSec 2 -ErrorAction Stop
    if ($ping.status -eq 'ONLINE') {
      $daemonOnline = $true
      Write-Host "✅ LCM Desktop Daemon recovered and listening on Port $port." -ForegroundColor Green
    }
  } catch {}

  if (-not $daemonOnline) {
    Write-Host "❌ [FATAL] LCM Desktop Daemon (Port $port) is unreachable." -ForegroundColor Red
    Write-Host "   Run 'lcm start' or 'pwsh LCM_Inventory/tools/Register-LcmDesktopDaemon.ps1 -Start'." -ForegroundColor Gray
    exit 1
  }
}

# 3. Construct Interface Object (Action Intent DTO)
$requiresElevation = [bool]$Elevated
if (-not $requiresElevation -and -not [string]::IsNullOrWhiteSpace($Target)) {
  $catalogPath = Join-Path $workspaceRoot 'LCM_Inventory\config\tool_catalog.json'
  if (Test-Path -LiteralPath $catalogPath) {
    try {
      $rawCat = [System.IO.File]::ReadAllText($catalogPath, [System.Text.Encoding]::UTF8)
      $catList = $rawCat | ConvertFrom-Json
      $tools = if ($catList -is [System.Collections.IEnumerable] -and $catList -isnot [PSCustomObject]) { $catList } elseif ($catList.PSObject.Properties['tools']) { $catList.tools } else { @($catList) }
      $cleanTarget = $Target.Trim()
      $match = @($tools | Where-Object {
        $_.Name -eq $cleanTarget -or
        $_.ShortName -eq $cleanTarget -or
        ($_.RelativePath -and ($cleanTarget -like "*$($_.RelativePath)*" -or $cleanTarget -like "*$($_.Name)*"))
      })[0]
      if ($null -ne $match -and ($match.Admin -or $match.Elevated)) {
        $requiresElevation = $true
      }
    } catch {}
  }
}

$intent = @{
  action     = "DO"
  target     = $Target
  caller     = $Caller
  token      = $Token
  context    = @{
    workingDirectory = (Get-Location).Path
    workspaceRoot    = $workspaceRoot
  }
  parameters = @{}
  options    = @{
    sync     = (-not $Async)
    noExit   = [bool]$NoExit
    elevated = $requiresElevation
  }
}

# If raw InputObject provided, parse JSON
if (-not [string]::IsNullOrWhiteSpace($InputObject)) {
  if (Test-Path -LiteralPath $InputObject) {
    $rawIn = [System.IO.File]::ReadAllText($InputObject, [System.Text.Encoding]::UTF8)
    $obj = $rawIn | ConvertFrom-Json
  } else {
    $obj = $InputObject | ConvertFrom-Json
  }
  if ($obj.target) { $intent['target'] = $obj.target }
  if ($obj.parameters) {
    foreach ($p in $obj.parameters.PSObject.Properties) {
      $intent['parameters'][$p.Name] = $p.Value
    }
  }
  if ($obj.options) {
    foreach ($o in $obj.options.PSObject.Properties) {
      $intent['options'][$o.Name] = $o.Value
    }
  }
}

# Parse CLI switch tokens from RemainingArgs: e.g. -DryRun, -Drive G, --key val
if ($null -ne $RemainingArgs -and $RemainingArgs.Length -gt 0) {
  for ($i = 0; $i -lt $RemainingArgs.Length; $i++) {
    $arg = $RemainingArgs[$i]
    if ($arg.StartsWith('-')) {
      $key = $arg.TrimStart('-')
      if ($i + 1 -lt $RemainingArgs.Length -and -not $RemainingArgs[$i + 1].StartsWith('-')) {
        $intent['parameters'][$key] = $RemainingArgs[$i + 1]
        $i++
      } else {
        $intent['parameters'][$key] = $true
      }
    }
  }
}

# 4. Dispatch Intent to Gateway
$bodyJson = $intent | ConvertTo-Json -Depth 10 -Compress
try {
  $response = Invoke-RestMethod -Uri "$baseUrl/api/action" -Method Post -Body $bodyJson -ContentType "application/json; charset=utf-8" -TimeoutSec 300 -ErrorAction Stop
} catch {
  Write-Host "❌ Gateway dispatch error: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

# 5. Render Output Streams
if ($response.PSObject.Properties['stdout'] -and -not [string]::IsNullOrWhiteSpace($response.stdout)) {
  [Console]::Out.Write($response.stdout)
}

if ($response.PSObject.Properties['stderr'] -and -not [string]::IsNullOrWhiteSpace($response.stderr)) {
  [Console]::Error.Write($response.stderr)
}

$exitCode = if ($response.PSObject.Properties['exitCode']) { [int]$response.exitCode } else { 0 }
exit $exitCode

