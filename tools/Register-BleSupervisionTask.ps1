<#
.SYNOPSIS
  Registers the permanent Windows Scheduled Task for 48-Hour Bluetooth LE fleet stability supervision.

.DESCRIPTION
  Creates or updates the 'HaSSD06_BLE_Supervision' Windows Scheduled Task.
  Runs 'verify_ble_stability.py 240' every 4 hours with 'StartWhenAvailable' enabled,
  guaranteeing execution even if the PC was powered down or updating during scheduled intervals.

.PARAMETER TaskName
  Name of the Windows Scheduled Task to create or update.

.PARAMETER IntervalHours
  Supervision repetition interval in hours.

.PARAMETER WorkspaceRoot
  Root directory of the LCM multi-repository workspace.

.PARAMETER Help
  Displays this synopsis and usage screen.

.EXAMPLE
  pwsh -File HaSSD06/tools/Register-BleSupervisionTask.ps1
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Name of the Windows Scheduled Task to create or update.')]
  [string]$TaskName = 'HaSSD06_BLE_Supervision',

  [Parameter(Mandatory = $false, HelpMessage = 'Supervision repetition interval in hours.')]
  [int]$IntervalHours = 4,

  [Parameter(Mandatory = $false, HelpMessage = 'Root directory of the LCM multi-repository workspace.')]
  [string]$WorkspaceRoot = 'D:\Git_Repositories',

  [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
  [Alias('h', '?')]
  [switch]$Help
)

if ($Help) {
  Write-Host "Register-BleSupervisionTask.ps1 - Register Windows Scheduled Task for BLE fleet supervision." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File Register-BleSupervisionTask.ps1 [-TaskName <string>] [-IntervalHours <int>] [-WorkspaceRoot <path>] [-Help]"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -TaskName      Scheduled task name (default: HaSSD06_BLE_Supervision)."
  Write-Host "  -IntervalHours Repetition interval in hours (default: 4)."
  Write-Host "  -WorkspaceRoot Root directory of the LCM workspace (default: D:\Git_Repositories)."
  Write-Host "  -Help (-h, -?) Displays this help message."
  exit 0
}

$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $WorkspaceRoot 'HaSSD06\scratch\verify_ble_stability.py'
$pythonExe = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
if (-not $pythonExe) {
  $pythonExe = 'D:\Tools\Python314\python.exe'
}

Write-Host "Registering Permanent Scheduled Task: $TaskName" -ForegroundColor Cyan
Write-Host "  Python Binary : $pythonExe"
Write-Host "  Script Path   : $scriptPath"
Write-Host "  Interval      : Every $IntervalHours hours (with StartWhenAvailable)"

# Define Action
$action = New-ScheduledTaskAction -Execute $pythonExe -Argument "$scriptPath 240" -WorkingDirectory $WorkspaceRoot

# Define Triggers: Once repeating every 4 hours for 365 days + At Logon
$trigger1 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) -RepetitionDuration (New-TimeSpan -Days 365)
$trigger2 = New-ScheduledTaskTrigger -AtLogOn

# Define Settings: Allow start when available, wake to run if possible, run missed tasks
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 15)

# Register or update task
try {
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($trigger1, $trigger2) -Settings $settings -Force | Out-Null
  Write-Host "✓ Windows Scheduled Task '$TaskName' registered successfully." -ForegroundColor Green
  
  # Output current status
  Get-ScheduledTask -TaskName $TaskName | Format-Table -AutoSize
} catch {
  Write-Warning "PowerShell Register-ScheduledTask failed ($($_.Exception.Message)), attempting fallback via schtasks.exe..."
  $schCmd = "schtasks /Create /TN `"$TaskName`" /TR `"`"$pythonExe`" `"$scriptPath`" 240`" /SC HOURLY /MO $IntervalHours /F"
  cmd.exe /c $schCmd
}
