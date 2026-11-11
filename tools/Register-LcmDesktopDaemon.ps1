<#
.SYNOPSIS
  Registers, manages, and automates the LCM Desktop REST Daemon for auto-start at user logon.
.DESCRIPTION
  Module: Register-LcmDesktopDaemon
  Purpose: Manages the lifecycle of LcmDesktopDaemon:
           1. -Install   : Registers a single user Scheduled Task that owns automatic
                           startup at interactive logon and bounded restart-on-failure recovery.
           2. -Uninstall : Removes startup entries and scheduled task cleanly.
           3. -Status    : Checks registration health and queries live daemon status.
           4. -Start     : Starts the daemon in background immediately.
           5. -Stop      : Sends stop command to the running daemon.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: tools/Register-LcmDesktopDaemon.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.2
  Date: 2026-11-11 21:44:00
.PARAMETER Install
  Installs the user scheduled task for automatic launch at user logon.
.PARAMETER Uninstall
  Removes user startup hooks and scheduled tasks.
.PARAMETER Status
  Displays active installation and daemon runtime status.
.PARAMETER Start
  Starts the desktop daemon immediately in the background.
.PARAMETER Stop
  Stops the running desktop daemon.
.PARAMETER Port
  Configures the target port (Default: 9876).
.PARAMETER Help
  Displays this parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Register-LcmDesktopDaemon.ps1 -h
.EXAMPLE
  pwsh tools/Register-LcmDesktopDaemon.ps1 -Install
.EXAMPLE
  pwsh tools/Register-LcmDesktopDaemon.ps1 -Status
.EXAMPLE
  pwsh tools/Register-LcmDesktopDaemon.ps1 -Uninstall
#>

[CmdletBinding()]
param(
  [switch]$Install,

  [switch]$Uninstall,

  [switch]$Status,

  [switch]$Start,

  [switch]$Stop,

  [int]$Port = 9876,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.1"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help -or (-not $Install -and -not $Uninstall -and -not $Status -and -not $Start -and -not $Stop)) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM DESKTOP DAEMON REGISTRATION MANAGER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Registers and manages automatic logon startup for LcmDesktopDaemon (Port $Port)."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Register-LcmDesktopDaemon.ps1 [-Install] [-Uninstall] [-Status] [-Start] [-Stop] [-Port <int>] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Install       : Configures the logon-owned daemon task."
  Write-Host "  -Uninstall     : Removes the daemon task and obsolete startup entry."
  Write-Host "  -Status        : Displays registration and runtime status."
  Write-Host "  -Start         : Starts daemon in background now."
  Write-Host "  -Stop          : Stops running daemon."
  Write-Host "  -Port <int>    : Port number (Default: 9876)."
  Write-Host "  -h, -Help, -?  : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcdRoot 'tools'
$daemonScript = Join-Path $toolsDir 'LcmDesktopDaemon.ps1'
$doExe = Join-Path $lcdRoot 'Cmd\do.exe'
$runKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runKeyName = 'LcmDesktopDaemon'
$taskName = "LCM_DesktopDaemon_$env:USERNAME"

# ------------------------------------------------------------------------------
# 1. Status Check
# ------------------------------------------------------------------------------
if ($Status) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM DESKTOP DAEMON STATUS CHECK" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan

  # Check legacy HKCU Run key
  $runKeyProperties = Get-ItemProperty -Path $runKeyPath -ErrorAction SilentlyContinue
  $runKeyProperty = if ($runKeyProperties) { $runKeyProperties.PSObject.Properties[$runKeyName] } else { $null }
  $runVal = if ($runKeyProperty) { $runKeyProperty.Value } else { $null }
  Write-Host " Legacy HKCU Run Key : $(if ($runVal) { "PRESENT - REMOVE ON INSTALL ($runVal)" } else { "ABSENT (expected)" })" -ForegroundColor $(if ($runVal) { 'Yellow' } else { 'Green' })

  # Check Scheduled Task
  $taskExists = $false
  try {
    $t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($t) { $taskExists = $true }
  } catch {}
  Write-Host " Logon Task ($taskName) : $(if ($taskExists) { "REGISTERED" } else { "NOT REGISTERED" })" -ForegroundColor $(if ($taskExists) { 'Green' } else { 'Yellow' })

  # Check Live Daemon Endpoint
  & (Join-Path $toolsDir 'LcmDesktopDaemon.ps1') -Port $Port -Status
  return
}

# ------------------------------------------------------------------------------
# 2. Stop Action
# ------------------------------------------------------------------------------
if ($Stop) {
  & (Join-Path $toolsDir 'LcmDesktopDaemon.ps1') -Port $Port -Stop
  return
}

# ------------------------------------------------------------------------------
# 3. Start Action
# ------------------------------------------------------------------------------
if ($Start) {
  try {
    Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
    Write-Host "  -> Started daemon via elevated scheduled task ($taskName)." -ForegroundColor Green
    return
  } catch {
    & (Join-Path $toolsDir 'LcmDesktopDaemon.ps1') -Port $Port -Background
    return
  }
}

# ------------------------------------------------------------------------------
# 4. Uninstall Action
# ------------------------------------------------------------------------------
if ($Uninstall) {
  Write-Host "Removing LCM Desktop Daemon startup hooks..." -ForegroundColor Yellow

  # Stop daemon
  & (Join-Path $toolsDir 'LcmDesktopDaemon.ps1') -Port $Port -Stop

  # Remove HKCU Run key
  if (Test-Path $runKeyPath) {
    Remove-ItemProperty -Path $runKeyPath -Name $runKeyName -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  -> Removed HKCU Run registry value." -ForegroundColor Green
  }

  # Remove Scheduled Task
  try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  -> Removed scheduled task $taskName." -ForegroundColor Green
  } catch {}

  Write-Host "[COMPLETED] Uninstalled LCM Desktop Daemon registration." -ForegroundColor Green
  return
}

# ------------------------------------------------------------------------------
# 5. Install Action
# ------------------------------------------------------------------------------
if ($Install) {
  # Verify administrative elevation for RunLevel Highest registration (RULE-ELEV-005 / RULE-ELEV-006)
  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
  $isElevated = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

  if (-not $isElevated) {
    Write-Host "Registering Scheduled Task with Highest Available privileges requires elevation (RULE-ELEV-006)..." -ForegroundColor Yellow
    $thisScript = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { Join-Path $toolsDir 'Register-LcmDesktopDaemon.ps1' }
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$thisScript`" -Install -Port $Port"
    $proc = Start-Process -FilePath "pwsh.exe" -ArgumentList $argList -Verb RunAs -PassThru
    $proc.WaitForExit()
    if ($proc.ExitCode -eq 0) {
      Write-Host "[COMPLETED] LCM Desktop Daemon scheduled task registered elevated." -ForegroundColor Green
    } else {
      Write-Host "[ERROR] Elevated registration failed with exit code $($proc.ExitCode)." -ForegroundColor Red
    }
    return
  }

  Write-Host "Registering LCM Desktop Daemon for automatic logon startup (Elevated: HighestAvailable)..." -ForegroundColor Yellow

  # 1. Remove the legacy Run-key launcher so the scheduled task has one owner.
  if (Test-Path -LiteralPath $runKeyPath) {
    Remove-ItemProperty -Path $runKeyPath -Name $runKeyName -ErrorAction SilentlyContinue | Out-Null
  }
  Write-Host "  -> Removed legacy HKCU Run launcher (if present)." -ForegroundColor Green

  # 2. Configure one logon-owned daemon task with bounded restart-on-failure and Highest privileges.
  try {
    $action = if (Test-Path -LiteralPath $doExe) {
      New-ScheduledTaskAction -Execute $doExe -Argument "daemon -port $Port"
    } else {
      New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$daemonScript`" -Port $Port"
    }
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 365) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $logonTrigger -Principal $taskPrincipal -Settings $settings -Force | Out-Null
    Write-Host "  -> Configured single-owner logon task with Highest privileges: $taskName" -ForegroundColor Green
  } catch {
    Write-Host "  -> Scheduled task registration error: $($_.Exception.Message)" -ForegroundColor Red
    throw
  }

  # 3. Start daemon in background via the scheduled task so it runs under the elevated token
  try {
    # Stop existing un-elevated instance if running
    & (Join-Path $toolsDir 'LcmDesktopDaemon.ps1') -Port $Port -Stop -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Milliseconds 500
    Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
    Write-Host "  -> Started daemon via elevated scheduled task ($taskName)." -ForegroundColor Green
  } catch {
    Write-Host "  -> Fallback: Starting background daemon directly." -ForegroundColor Yellow
    & (Join-Path $toolsDir 'LcmDesktopDaemon.ps1') -Port $Port -Background
  }

  Write-Host ""
  Write-Host "==========================================================================" -ForegroundColor Green
  Write-Host " LCM DESKTOP DAEMON REGISTERED SUCCESSFULLY (ELEVATED)" -ForegroundColor Green
  Write-Host " Port         : $Port" -ForegroundColor White
  Write-Host " RunLevel     : HighestAvailable (Administrative Token)" -ForegroundColor White
  Write-Host " Auto-Start   : Active at User Logon" -ForegroundColor White
  Write-Host " Auto-Restart : Enabled (3 bounded retries; no recurring watchdog launch)" -ForegroundColor White
  Write-Host " Script       : $daemonScript" -ForegroundColor White
  Write-Host "==========================================================================" -ForegroundColor Green
}
