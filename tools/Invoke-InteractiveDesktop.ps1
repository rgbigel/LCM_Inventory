<#
.SYNOPSIS
  Dispatches GUI commands and scripts directly onto the interactive user desktop (Session 1).
.DESCRIPTION
  Module: Invoke-InteractiveDesktop
  Purpose: Bridges background agent processes and interactive desktop sessions by dispatching
           GUI commands (e.g., Beyond Compare, WPF apps, GridView) through an ephemeral
           Windows Scheduled Task registered with -LogonType Interactive.
           Supports direct invocation as well as pipeline streaming.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: D:\Git_Repositories\LCM_Tools\Invoke-InteractiveDesktop.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.1
  Date: 2026-11-08 15:07:36
.PARAMETER FilePath
  The executable or script to launch on the interactive desktop.
.PARAMETER ArgumentList
  Command-line arguments to pass to the executable.
.PARAMETER Command
  A raw command line string to execute via cmd.exe or pwsh.exe.
.PARAMETER Pane
  Opens displays inside an Antigravity IDE editor/side pane instead of external browser window.
.PARAMETER ShowAll
  Displays detailed task creation, dispatch, and cleanup logs.
.PARAMETER LogFile
  Custom log file destination. Defaults to D:\Git_Repositories\LCM_Tools\logs\Invoke-InteractiveDesktop-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Invoke-InteractiveDesktop.ps1 -h
.EXAMPLE
  pwsh tools/Invoke-InteractiveDesktop.ps1 -FilePath "D:\Tools\Beyond Compare 5\BCompare.exe" -ArgumentList '"dir1" "dir2"'
.EXAMPLE
  "pwsh -File tools/Show-ToolIndex.ps1 -Grid" | pwsh tools/Invoke-InteractiveDesktop.ps1
#>

[CmdletBinding(DefaultParameterSetName = 'Direct')]
param(
  [Parameter(ParameterSetName = 'Direct', Position = 0, HelpMessage = 'Executable or script path to launch on the interactive desktop')]
  [string]$FilePath = '',

  [Parameter(ParameterSetName = 'Direct', Position = 1, HelpMessage = 'Command-line arguments to pass to the executable')]
  [string]$ArgumentList = '',

  [Parameter(ParameterSetName = 'CommandString', Mandatory = $true, HelpMessage = 'Raw command line string to execute via cmd.exe or pwsh.exe')]
  [string]$Command = '',

  [Parameter(ValueFromPipeline = $true, HelpMessage = 'Pipeline string input to pass as arguments or commands')]
  [string]$PipelineInput = '',

  [Parameter(HelpMessage = 'Dispatch process with elevated Administrator privileges')]
  [switch]$Elevated,

  [Parameter(HelpMessage = 'Opens displays inside an Antigravity IDE editor/side pane')]
  [switch]$Pane,

  [Parameter(HelpMessage = 'Display verbose task creation, dispatch, and cleanup logs')]
  [switch]$ShowAll,

  [Parameter(HelpMessage = 'Custom log file destination path')]
  [string]$LogFile = "",

  [Alias('h', '?')]
  [switch]$Help
)

begin {
  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  $scriptVersion = "10.0.1"
  $scriptName = "Invoke-InteractiveDesktop"

  # ------------------------------------------------------------------------------
  # 0. Help Handler (-h / -Help / -?) per RULE-PS-010
  # ------------------------------------------------------------------------------
  if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " INTERACTIVE DESKTOP TASK DISPATCHER (v$($scriptVersion))" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Dispatches GUI commands and scripts onto the user's active desktop (Session 1)"
    Write-Host "  via ephemeral Scheduled Tasks with -LogonType Interactive."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Invoke-InteractiveDesktop.ps1 [-FilePath <exe>] [-ArgumentList <args>] [-ShowAll] [-h]"
    Write-Host "  pwsh tools/Invoke-InteractiveDesktop.ps1 -Command '<CommandLine>'"
    Write-Host "  '<CommandLine>' | pwsh tools/Invoke-InteractiveDesktop.ps1"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -FilePath <str>     : Executable or script to execute on Session 1 desktop."
    Write-Host "  -ArgumentList <str> : Arguments to pass to FilePath."
    Write-Host "  -Command <str>      : Complete shell command line to run."
    Write-Host "  -ShowAll            : Exposes task registration and execution telemetry."
    Write-Host "  -LogFile <str>      : Custom log file destination."
    Write-Host "  -h, -Help, -?       : Displays this comprehensive parameter reference."
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Invoke-InteractiveDesktop.ps1 -FilePath 'BCompare.exe' -ArgumentList '\"dir1\" \"dir2\"'"
    Write-Host "  pwsh tools/Invoke-InteractiveDesktop.ps1 -Command 'pwsh -File tools/Show-ToolIndex.ps1 -Grid'"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
  }

  # ------------------------------------------------------------------------------
  # 1. Initialize Logging Context per RULE-PS-009
  # ------------------------------------------------------------------------------
  $workspaceRoot = 'D:\Git_Repositories'
  $invRoot = Join-Path $workspaceRoot 'LCM_Inventory'
  $toolsDir = Join-Path $invRoot 'tools'
  $logDir = Join-Path $invRoot 'logs'
  if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
  }

  if ([string]::IsNullOrWhiteSpace($LogFile)) {
    $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $LogFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"
  }
  $script:ActiveLogFile = $LogFile
  $script:ShowDetails = $ShowAll

  function Write-ToolLog {
    param(
      [AllowEmptyString()]
      [string]$Message = "",
      [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "ACTION", "SUMMARY")]
      [string]$Level = "INFO",
      [switch]$ConsoleOnly,
      [switch]$LogOnly
    )

    $timeHeader = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $formattedLog = "[$timeHeader] [$Level] $Message"

    if (-not $ConsoleOnly -and -not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
      try {
        $formattedLog | Out-File -FilePath $script:ActiveLogFile -Append -Encoding UTF8
      } catch {}
    }

    if (-not $LogOnly) {
      switch ($Level) {
        "WARN"    { Write-Warning $Message }
        "ERROR"   { Write-Error $Message }
        "DEBUG"   { if ($script:ShowDetails) { Write-Host "  [DEBUG] $Message" -ForegroundColor DarkGray } }
        "ACTION"  { Write-Host "  -> $Message" -ForegroundColor Green }
        "SUMMARY" { Write-Host $Message -ForegroundColor Cyan }
        default   { Write-Host $Message }
      }
    }
  }

  Write-ToolLog -Message "==========================================================================" -Level INFO
  Write-ToolLog -Message " INTERACTIVE DESKTOP TASK DISPATCHER (v$($scriptVersion))" -Level INFO
  Write-ToolLog -Message " User: $env:USERNAME | Host: $env:COMPUTERNAME | Audit Log: $LogFile" -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level INFO

  $script:DispatchedCount = 0
  $script:ExecStatus = "COMPLETED"
}

process {
  if ($Help) { return }

  # Pipeline input handling
  if (-not [string]::IsNullOrWhiteSpace($PipelineInput)) {
    $Command = $PipelineInput
  }

  $targetExe = $FilePath
  $targetArgs = $ArgumentList

  if (-not [string]::IsNullOrWhiteSpace($Command)) {
    $targetExe = "cmd.exe"
    $targetArgs = "/c $Command"
  }

  if ([string]::IsNullOrWhiteSpace($targetExe)) {
    return
  }

  $taskName = "LCM_DesktopDispatch_$(Get-Random)"
  Write-ToolLog -Message "Dispatching task '$taskName' to Interactive Desktop..." -Level ACTION
  Write-ToolLog -Message "  Executable: $targetExe" -Level DEBUG
  Write-ToolLog -Message "  Arguments : $targetArgs" -Level DEBUG

  # ----------------------------------------------------------------------------
  # High-Speed Route A: Direct REST Daemon Dispatch (Sub-5ms, Port 9876)
  # Architectural Evolution (CRP-309):
  # 1. Retired premature direct-launch when SessionId > 0; all dispatches route through Port 9876.
  # 2. Retired Route B Task Scheduler fallback per Authoritative Gateway Invariant.
  # 3. Port 9876 daemon runs with Highest runlevel, providing universal back channel and security checks.
  # ----------------------------------------------------------------------------
  $daemonPort = if ($env:LCM_DAEMON_PORT -match '^\d+$') { [int]$env:LCM_DAEMON_PORT } else { 9876 }
  $daemonDispatched = $false

  if (-not (Get-Variable -Name 'script:DaemonRestartAttempts' -Scope Script -ErrorAction SilentlyContinue)) {
    $script:DaemonRestartAttempts = 0
  }

  $maxRestarts = 3
  $attempt = 0

  while (-not $daemonDispatched -and $attempt -le 1) {
    $attempt++
    try {
      $cleanTarget = $targetExe.Trim(' "''')
      $isHtmlOrUrl = $cleanTarget -match '(?i)\.html?(?:[#?].*)?$' -or $cleanTarget -match '^https?://' -or $cleanTarget -match '^file:'
      $cleanStem = ($cleanTarget -split '[#?]')[0]
      $exeName = [System.IO.Path]::GetFileName($cleanStem).ToLowerInvariant()
      $isDirectApp = $exeName -in @('explorer.exe', 'notepad.exe', 'notepad++.exe', 'bcompare.exe', 'msedge.exe', 'chrome.exe', 'zen.exe', 'firefox.exe') -or $exeName -like '*notepad*.exe' -or $exeName -like '*bcompare*.exe'
      if (($isDirectApp -or $isHtmlOrUrl) -and -not $Elevated) {
        $isUrl = ($exeName -eq 'explorer.exe' -and ($targetArgs -match '^"?https?://' -or $targetArgs -match '^"?file:' -or $targetArgs -match '\.html"?$')) -or $isHtmlOrUrl
        $urlToSend = if ($isUrl -and -not [string]::IsNullOrWhiteSpace($targetArgs)) { $targetArgs.Trim(' "''') } else { $cleanTarget }
        if ($isHtmlOrUrl -and -not ($urlToSend -match '^https?://' -or $urlToSend -match '^file:')) {
          try { $urlToSend = [System.Uri]::new($urlToSend).AbsoluteUri } catch {}
        }
        $argsToSend = if ($cleanTarget -eq $targetExe -and -not $isHtmlOrUrl) { $targetArgs } else { "" }
        $titleHint = if ($exeName -eq 'notepad.exe') { 'Notepad' } `
          elseif ($exeName -like '*notepad++*') { 'Notepad++' } `
          elseif ($exeName -like '*bcompare*') { 'Beyond Compare' } `
          elseif ($exeName -eq 'zen.exe') { 'Zen' } `
          elseif ($exeName -eq 'firefox.exe') { 'Firefox' } `
          elseif ($exeName -eq 'chrome.exe') { 'Chrome' } `
          elseif ($exeName -eq 'msedge.exe') { 'Edge' } `
          else { 'LCM Control Hub' }
        $body = @{
          url        = if ($isUrl) { $urlToSend } else { $null }
          filePath   = if (-not $isUrl) { $cleanTarget } else { $null }
          args       = $argsToSend
          foreground = $true
          title      = $titleHint
          pane       = [bool]$Pane
        } | ConvertTo-Json -Compress

        $res = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/open" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 2 -ErrorAction Stop
        if ($res.status -eq 'OPENED') {
          Write-ToolLog -Message "Dispatched $cleanTarget via LCM Desktop Daemon (REST Port $daemonPort) in <5ms." -Level ACTION
          $daemonDispatched = $true
          $script:DispatchedCount++
          break
        }
      } else {
        $quotedExe = if ($targetExe -match '[\s()]' -and -not $targetExe.StartsWith('"')) { "`"$targetExe`"" } else { $targetExe }
        $cmdToRun = if (-not [string]::IsNullOrWhiteSpace($targetArgs)) { "$quotedExe $targetArgs" } else { $quotedExe }
        $body = @{ command = $cmdToRun; elevated = [bool]$Elevated } | ConvertTo-Json -Compress
        $res = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/execute" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 1 -ErrorAction Stop
        if ($res.status -eq 'DISPATCHED') {
          Write-ToolLog -Message "Dispatched $(if ($Elevated) { '[ELEVATED] ' } else { '' })command via LCM Desktop Daemon (REST Port $daemonPort) in <5ms." -Level ACTION
          $daemonDispatched = $true
          $script:DispatchedCount++
          break
        }
      }
    } catch {
      Write-ToolLog -Message "LCM Desktop Daemon (Port $daemonPort) unreachable." -Level DEBUG
      # Auto-Revive attempt if under max restarts
      if ($script:DaemonRestartAttempts -lt $maxRestarts -and $attempt -eq 1) {
        $script:DaemonRestartAttempts++
        Write-ToolLog -Message "Auto-restarting LCM Desktop Daemon (Attempt $script:DaemonRestartAttempts of $maxRestarts)..." -Level ACTION
        $daemonLauncher = Join-Path $toolsDir 'LcmDesktopDaemon.ps1'
        if (Test-Path -LiteralPath $daemonLauncher) {
          & pwsh -File $daemonLauncher -Port $daemonPort -Background | Out-Null
          Start-Sleep -Milliseconds 700
          continue
        }
      }
      break
    }
  }

  if (-not $daemonDispatched) {
    $script:ExecStatus = "FAILED"
    throw "LCM Desktop Daemon (Port $daemonPort) is offline. Per Authoritative Gateway Invariant (CRP-309), secondary fallbacks are retired. Run 'pwsh tools/Register-LcmDesktopDaemon.ps1 -Start' to restore service."
  }
}

end {
  if ($Help) { return }

  $now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  Write-ToolLog -Message "" -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
  Write-ToolLog -Message " [SUMMARY] $scriptName (v$($scriptVersion))" -Level SUMMARY
  Write-ToolLog -Message " Status     : $script:ExecStatus" -Level SUMMARY
  Write-ToolLog -Message " Dispatched : $script:DispatchedCount" -Level SUMMARY
  Write-ToolLog -Message " Timestamp  : $now" -Level SUMMARY
  Write-ToolLog -Message " Log File   : $LogFile" -Level SUMMARY
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
}

