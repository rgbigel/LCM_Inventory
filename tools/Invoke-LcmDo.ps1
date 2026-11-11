<#
.SYNOPSIS
Dispatches commands through the LCM Desktop Daemon on port 9876 for elevated or sandbox-free user desktop execution.

.DESCRIPTION
Module: LCM_Inventory/tools/Invoke-LcmDo.ps1
Purpose: Canonical client wrapper for the LCM Desktop Daemon (Port 9876).
         Routes privileged commands to visible elevated Session 1 console windows,
         and routes un-elevated commands outside the agent sandbox into the interactive user desktop.
         Eliminates silent Session 0 failures and avoids slow recursive filesystem fallbacks.
Path: LCM_Inventory/tools/Invoke-LcmDo.ps1
Authors: Rolf, Antigravity
Version: 1.0.0
Date: 2026-11-11

.PARAMETER Command
The command line or executable path to execute via the Desktop Daemon.

.PARAMETER Elevated
Executes the command with Administrator elevation in Session 1.

.PARAMETER Sync
Executes the command synchronously and captures/returns stdout, stderr, and exitCode.

.PARAMETER NoExit
Keeps the spawned console window open after completion.

.PARAMETER TimeoutSec
Maximum execution timeout in seconds for synchronous calls (default: 30).

.PARAMETER Port
Desktop Daemon port (default: 9876 or $env:LCM_DAEMON_PORT).

.PARAMETER Help
Displays help documentation and usage syntax (Aliases: -h, -?).

.EXAMPLE
Invoke-LcmDo -Command "es.exe FolderTimeUpdate" -Sync
.EXAMPLE
Invoke-LcmDo -Command "KillLogitechUpdateFull.ps1" -Elevated -NoExit
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0, Mandatory = $false, HelpMessage = "The command line or executable path to execute.")]
  [string]$Command = '',

  [Parameter(Mandatory = $false, HelpMessage = "Executes with Administrator elevation.")]
  [switch]$Elevated,

  [Parameter(Mandatory = $false, HelpMessage = "Executes synchronously and returns stdout/stderr.")]
  [switch]$Sync,

  [Parameter(Mandatory = $false, HelpMessage = "Keeps spawned console window open.")]
  [switch]$NoExit,

  [Parameter(Mandatory = $false, HelpMessage = "Maximum timeout in seconds for synchronous execution.")]
  [int]$TimeoutSec = 30,

  [Parameter(Mandatory = $false, HelpMessage = "Desktop Daemon port.")]
  [int]$Port = 9876,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help -or [string]::IsNullOrWhiteSpace($Command)) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM DO / DESKTOP DAEMON DISPATCHER (Invoke-LcmDo)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Unified command gateway to the interactive desktop daemon (Port 9876)."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  Invoke-LcmDo [-Command] <string> [-Elevated] [-Sync] [-NoExit] [-TimeoutSec <int>]"
  Write-Host "  do <string> [-Elevated] [-Sync]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Command    : Command line string to execute."
  Write-Host "  -Elevated   : Dispatches with Administrator elevation onto Session 1 desktop."
  Write-Host "  -Sync       : Executes synchronously, capturing stdout and stderr."
  Write-Host "  -NoExit     : Keeps console window open on user desktop."
  Write-Host "  -TimeoutSec : Synchronous execution timeout in seconds (default: 30)."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$daemonPort = if ($env:LCM_DAEMON_PORT -and [int]::TryParse($env:LCM_DAEMON_PORT, [ref]$null)) {
  [int]$env:LCM_DAEMON_PORT
} else {
  $Port
}

$payload = [ordered]@{
  command   = $Command
  elevated  = [bool]$Elevated
  sync      = [bool]$Sync
  noExit    = [bool]$NoExit
  timeoutMs = ($TimeoutSec * 1000)
} | ConvertTo-Json

$uri = "http://127.0.0.1:$daemonPort/execute"

try {
  $res = Invoke-RestMethod -Uri $uri -Method Post -Body $payload -ContentType "application/json" -TimeoutSec ($TimeoutSec + 5)
  if ($Sync) {
    if ($null -ne $res -and $null -ne $res.exitCode -and $res.exitCode -ne 0) {
      if ($res.stderr) { Write-Error $res.stderr }
      $global:LASTEXITCODE = $res.exitCode
    }
    if ($null -ne $res -and $null -ne $res.stdout) {
      return $res.stdout
    }
    return $res
  }
  return $res
} catch {
  throw "Invoke-LcmDo failed to communicate with Desktop Daemon at $uri : $($_.Exception.Message)"
}

