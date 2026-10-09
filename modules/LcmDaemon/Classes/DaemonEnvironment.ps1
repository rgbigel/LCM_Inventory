<#
Module: LcmDaemon/Classes/DaemonEnvironment.ps1
Purpose: Strongly-typed runtime environment state and structured logging for LCM Desktop Daemon.
Path: LCM_Inventory/modules/LcmDaemon/Classes/DaemonEnvironment.ps1
Authors: Rolf, LCM_AI Engine
Version: 1.0.0
Date: 2026-08-30
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

class DaemonEnvironment {
  [string]$WorkspaceRoot
  [string]$ToolsDir
  [string]$LogDir
  [string]$LogFile
  [int]$Port
  [int]$Pid
  [int]$SessionId
  [string]$User
  [string]$Version
  [datetime]$StartTime

  DaemonEnvironment([string]$workspaceRoot, [int]$port, [string]$version, [string]$logFile) {
    $this.WorkspaceRoot = $workspaceRoot
    $this.ToolsDir = [System.IO.Path]::Combine($workspaceRoot, 'LCM_Inventory\tools')
    $this.LogDir = [System.IO.Path]::Combine($workspaceRoot, 'LCM_Inventory\logs')
    $this.Port = $port
    $this.Version = $version
    $this.LogFile = $logFile
    $this.StartTime = [System.DateTime]::Now
    $this.Pid = [System.Diagnostics.Process]::GetCurrentProcess().Id
    $this.SessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    $this.User = $env:USERNAME
  }

  [void] Log([string]$message, [string]$level = 'INFO') {
    $stamp = [System.DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss.fff")
    $line = "[$stamp] [$level] $message"
    if (-not [string]::IsNullOrWhiteSpace($this.LogFile)) {
      $dir = [System.IO.Path]::GetDirectoryName($this.LogFile)
      if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
      }
      [System.IO.File]::AppendAllText($this.LogFile, "$line`r`n", [System.Text.Encoding]::UTF8)
    }
    if ($level -eq 'ERROR') { Write-Host $line -ForegroundColor Red }
    elseif ($level -eq 'WARN') { Write-Host $line -ForegroundColor Yellow }
    elseif ($level -eq 'ACTION') { Write-Host $line -ForegroundColor Green }
    elseif ($level -eq 'DEBUG') { }
    else { Write-Host $line -ForegroundColor Gray }
  }
}

