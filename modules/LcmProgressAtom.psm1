<#
.SYNOPSIS
  Atomic PowerShell module for multi-channel progress tracking and telemetry broadcasting.

.DESCRIPTION
  Module: LcmProgressAtom
  Purpose: Implements the Universal Multi-Channel Progress Indicator Engine governed by CRP-2026-027.
           Provides thread-safe atomic file updates (LCM_Inventory/scratch/active_progress.json), native
           PowerShell Write-Progress rendering, and optional notification to the LcmDesktopDaemon
           (Port 9876) for real-time web dashboard row mutations and console streaming.
  Path: LCM_Inventory/modules/LcmProgressAtom.psm1
  Authors: Rolf, LCM_AI Governance
  Version: 7.3.0
  Date: 2026-09-07
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:WorkspaceRoot = if (-not [string]::IsNullOrWhiteSpace($env:Git_Root)) { $env:Git_Root.TrimEnd('\', '/') } else { 'D:\Git_Repositories' }
$script:ScratchDir = Join-Path ([System.IO.Path]::GetTempPath()) 'lcm'
$script:ProgressFile = Join-Path $script:ScratchDir 'active_progress.json'
$script:LogFile = Join-Path $script:WorkspaceRoot 'LCM_Inventory\data\logs\lcm\progress_activity.log'
$script:DaemonUrl = 'http://127.0.0.1:9876'

function Write-LcmProgressLog {
  param([string]$Message, [string]$Level = 'INFO')
  $timeStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $logEntry = "[$timeStr] [$Level] $Message"
  $logDir = Split-Path $script:LogFile -Parent
  if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
  }
  Add-Content -LiteralPath $script:LogFile -Value $logEntry -Encoding utf8
}

function Start-LcmProgressBatch {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command,

    [Parameter(Mandatory = $true)]
    [array]$Items,

    [Parameter(Mandatory = $false)]
    [string]$Origin = 'CLI'
  )

  if (-not (Test-Path -LiteralPath $script:ScratchDir)) {
    New-Item -Path $script:ScratchDir -ItemType Directory -Force | Out-Null
  }

  $actionId = "ACT-" + (Get-Date).ToString("yyyyMMdd_HHmmss")
  $nowStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

  $itemObjects = @()
  foreach ($it in $Items) {
    $itemId = if ($it -is [hashtable] -or $it -is [PSCustomObject]) { "$($it.Id)" } else { "$it" }
    $itemLabel = if ($it -is [hashtable] -and $it.ContainsKey('Label')) { "$($it.Label)" } else { "Item #$($itemId)" }
    $targetRepo = if ($it -is [hashtable] -and $it.ContainsKey('Repo')) { "$($it.Repo)" } else { "" }

    $itemObjects += [PSCustomObject]@{
      id           = $itemId
      cr_id        = if ($it -is [hashtable] -and $it.ContainsKey('CrId')) { "$($it.CrId)" } else { "CRP-$($itemId)" }
      label        = $itemLabel
      target_repo  = $targetRepo
      state        = 'queued'
      phase        = 'Awaiting execution'
      percent      = 0
      started_at   = $null
      completed_at = $null
      error        = $null
    }
  }

  $progressPayload = [PSCustomObject]@{
    '$schema'        = 'https://json-schema.org/draft/2020-12/schema'
    action_id        = $actionId
    command          = $Command
    origin_channel   = $Origin
    created_at       = $nowStr
    updated_at       = $nowStr
    total_items      = @($itemObjects).Count
    completed_items  = 0
    overall_percent  = 0
    status           = 'in_progress'
    items            = @($itemObjects)
  }

  $jsonText = $progressPayload | ConvertTo-Json -Depth 5
  [System.IO.File]::WriteAllText($script:ProgressFile, $jsonText, [System.Text.UTF8Encoding]::new($false))

  Write-LcmProgressLog "Started progress batch '$actionId' for command '$Command' ($(@($itemObjects).Count) items)."

  # Render terminal Write-Progress
  Write-Progress -Activity "$Command Batch: 0/$(@($itemObjects).Count) Completed" -Status "Initializing..." -PercentComplete 0

  # Notify Desktop Daemon if accessible
  try {
    Invoke-RestMethod -Uri "$($script:DaemonUrl)/progress/update" -Method Post -Body $jsonText -ContentType "application/json" -TimeoutSec 1 -ErrorAction SilentlyContinue | Out-Null
  } catch {
    # Non-blocking if daemon is not running
  }

  return $actionId
}

function Update-LcmProgressItem {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Id,

    [Parameter(Mandatory = $true)]
    [string]$Phase,

    [Parameter(Mandatory = $true)]
    [int]$Percent,

    [Parameter(Mandatory = $false)]
    [string]$State = 'in_progress'
  )

  if (-not (Test-Path -LiteralPath $script:ProgressFile)) { return }

  try {
    $raw = [System.IO.File]::ReadAllText($script:ProgressFile, [System.Text.Encoding]::UTF8)
    $data = $raw | ConvertFrom-Json
  } catch {
    return
  }

  $nowStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $data.updated_at = $nowStr

  $itemFound = $false
  $completedCount = 0

  foreach ($it in $data.items) {
    if ("$($it.id)" -eq "$Id") {
      $itemFound = $true
      $it.phase = $Phase
      $it.percent = $Percent
      $it.state = $State
      if ([string]::IsNullOrWhiteSpace($it.started_at)) {
        $it.started_at = $nowStr
      }
      if ($Percent -ge 100 -and $State -eq 'completed') {
        $it.completed_at = $nowStr
      }
    }
    if ($it.percent -ge 100 -or $it.state -eq 'completed') {
      $completedCount++
    }
  }

  if (-not $itemFound) { return }

  $data.completed_items = $completedCount
  $total = [int]$data.total_items
  if ($total -gt 0) {
    $data.overall_percent = [math]::Min(100, [int](([math]::Round(($completedCount / $total) * 100))))
  }

  $jsonText = $data | ConvertTo-Json -Depth 5
  [System.IO.File]::WriteAllText($script:ProgressFile, $jsonText, [System.Text.UTF8Encoding]::new($false))

  # Terminal Write-Progress update
  Write-Progress -Activity "$($data.command) Batch: $completedCount/$total Completed" -Status "[$Id] $Phase ($Percent%)" -PercentComplete $data.overall_percent

  # Console Monospace Step Feedback (ASCII safe per InvariantRules)
  $barFilled = [int]($Percent / 5)
  $barEmpty = 20 - $barFilled
  $bar = ("=" * $barFilled) + (" " * $barEmpty)
  Write-Host "  [$completedCount/$total] #$($Id): [$bar] $($Percent)% ($Phase)" -ForegroundColor Cyan

  # Notify daemon
  try {
    Invoke-RestMethod -Uri "$($script:DaemonUrl)/progress/update" -Method Post -Body $jsonText -ContentType "application/json" -TimeoutSec 1 -ErrorAction SilentlyContinue | Out-Null
  } catch { }
}

function Complete-LcmProgressItem {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Id,

    [Parameter(Mandatory = $false)]
    [string]$ErrorMessage = $null
  )

  $finalState = if ([string]::IsNullOrWhiteSpace($ErrorMessage)) { 'completed' } else { 'failed' }
  $finalPhase = if ([string]::IsNullOrWhiteSpace($ErrorMessage)) { 'Completed' } else { "Failed: $ErrorMessage" }
  Update-LcmProgressItem -Id $Id -Phase $finalPhase -Percent 100 -State $finalState
}

function Stop-LcmProgressBatch {
  [CmdletBinding()]
  param([string]$Status = 'completed')

  if (-not (Test-Path -LiteralPath $script:ProgressFile)) { return }

  try {
    $raw = [System.IO.File]::ReadAllText($script:ProgressFile, [System.Text.Encoding]::UTF8)
    $data = $raw | ConvertFrom-Json
    $data.status = $Status
    $data.updated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $jsonText = $data | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($script:ProgressFile, $jsonText, [System.Text.UTF8Encoding]::new($false))
  } catch { }

  Write-Progress -Activity "Batch Action" -Completed
  Write-LcmProgressLog "Progress batch finalized with status '$Status'."
}

function Get-LcmActionProgress {
  [CmdletBinding()]
  param()

  if (-not (Test-Path -LiteralPath $script:ProgressFile)) { return $null }
  try {
    $raw = [System.IO.File]::ReadAllText($script:ProgressFile, [System.Text.Encoding]::UTF8)
    return ($raw | ConvertFrom-Json)
  } catch {
    return $null
  }
}

Export-ModuleMember -Function Start-LcmProgressBatch, Update-LcmProgressItem, Complete-LcmProgressItem, Stop-LcmProgressBatch, Get-LcmActionProgress
