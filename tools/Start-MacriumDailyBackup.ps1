<#
.SYNOPSIS
  Produces today's Macrium Reflect backup image at operator discretion with optional mounting.
.DESCRIPTION
  Module: tools/Start-MacriumDailyBackup.ps1
  Purpose: Standalone automation atom to initiate and await completion of the configured
  Macrium Reflect backup definition. Decoupled from GoodMorning start-of-session checks.
  Carries over LCM baseline telemetry (MRMTimeStamp) and optionally delegates to the
  baseline mounting atom (-Mount) to mount the newly generated backup as the writable BCR baseline.
  Path: LCM_Inventory/tools/Start-MacriumDailyBackup.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-11-09 17:15:00
.NOTES
  Elevated Operations:
    - Set-LcmRegistryValue: Persists baseline telemetry to HKLM:\SOFTWARE\LCM\MacriumBaseline.
    - Mount-MacriumBaseline: Mounts completed Macrium backup image via elevated worker or daemon.
.PARAMETER Mount
  Mounts the newly created backup image as the writable BCR baseline partition upon completion.
.PARAMETER ForceNewBackup
  Forces execution of a fresh backup definition even if a completed image exists for today.
.PARAMETER ReviewScope
  Active CRP or BUG identifier to associate with the Beyond Compare window title if -Mount is set.
.PARAMETER CandidateDrives
  List or delimited string of acceptable drive letters for mounting (Default: F;G;H;I).
.PARAMETER NoLaunchReview
  When -Mount is set, mounts the baseline and records registry telemetry without opening Beyond Compare.
.PARAMETER BackupDefinitionPath
  Path to the Macrium Reflect backup definition XML file.
.PARAMETER BackupDirectory
  Path to the directory containing completed .mrimgx backup images.
.PARAMETER PollSeconds
  Interval in seconds between completion polls (Default: 5).
.PARAMETER TimeoutMinutes
  Maximum wait time in minutes for backup completion (Default: 45).
.PARAMETER MountTimeoutSeconds
  Timeout in seconds for drive mount dialog interaction and volume appearance (Default: 120).
.PARAMETER WhatIf
  Simulates execution without launching Macrium or altering drive mounts.
.PARAMETER Help
  Displays comprehensive usage instructions, parameter references, and copy-paste examples.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [switch]$Mount,

  [switch]$ForceNewBackup,

  [string]$ReviewScope = '',

  [Parameter(Mandatory = $false)]
  [object]$CandidateDrives = @('F', 'G', 'H', 'I'),

  [switch]$NoLaunchReview,

  [ValidateNotNullOrEmpty()]
  [string]$BackupDefinitionPath = 'D:\OneDrive\Documents\Reflect\@B_D4P3+4-WDB850-AD.xml',

  [ValidateNotNullOrEmpty()]
  [string]$BackupDirectory = 'B:\Backups\D4P3+4-WDB850-AD',

  [ValidateRange(1, 60)]
  [int]$PollSeconds = 5,

  [ValidateRange(1, 180)]
  [int]$TimeoutMinutes = 45,

  [ValidateRange(30, 600)]
  [int]$MountTimeoutSeconds = 120,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Approved elevated operations for this tool (RULE-ELEV-007)
New-Variable -Name ElevatedOperations -Value ([string[]]@(
  'Set-LcmRegistryValue',
  'Mount-MacriumBaseline'
)) -Option ReadOnly -Scope Script -Force

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " MACRIUM DAILY BACKUP GENERATION ATOM" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Produces today's Macrium Reflect backup image at operator discretion with"
  Write-Host "  optional mounting as writable BCR baseline partition."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Start-MacriumDailyBackup.ps1 [-Mount] [-ForceNewBackup] [-ReviewScope <CRP|BUG>] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Mount                 : Mounts the newly generated backup immediately as BCR baseline."
  Write-Host "  -ForceNewBackup        : Initiates a new backup even if one already completed today."
  Write-Host "  -ReviewScope <CRP|BUG> : Sets the proposal review scope in Beyond Compare window title."
  Write-Host "  -NoLaunchReview        : Suppresses opening Beyond Compare when -Mount is specified."
  Write-Host "  -CandidateDrives <list>: Acceptable drive letters for mounting (Default: F;G;H;I)."
  Write-Host "  -TimeoutMinutes <int>  : Backup polling timeout in minutes (Default: 45)."
  Write-Host "  -h, -Help              : Displays this documentation."
  return
}

$inventoryRoot = Split-Path $PSScriptRoot -Parent
$reflectPath = 'C:\Program Files\Macrium\Reflect\Reflect.exe'
$MacriumRegistryKey = 'HKLM:\SOFTWARE\LCM\MacriumBaseline'

function Write-BackupLog {
  param(
    [ValidateSet('INFO', 'WARN', 'ERROR')]
    [string]$Level,
    [string]$Message
  )
  $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  Write-Host "[$Level] $timestamp - $Message"
}

function Get-CompletedTodayImage {
  param([datetime]$NotBefore = (Get-Date).Date)

  $reportDir = 'C:\ProgramData\Macrium\Reflect'
  if (-not (Test-Path -LiteralPath $reportDir -PathType Container)) {
    return $null
  }

  $reports = @(Get-ChildItem -LiteralPath $reportDir -Filter '*.html' -File |
    Where-Object { $_.LastWriteTime -ge $NotBefore } |
    Sort-Object -Property LastWriteTime -Descending)

  foreach ($report in $reports) {
    if (-not (Test-Path -LiteralPath $report.FullName -PathType Leaf)) {
      continue
    }
    try {
      $content = Get-Content -LiteralPath $report.FullName -Raw -ErrorAction Stop
    } catch {
      continue
    }
    if ($content -notmatch [regex]::Escape($BackupDefinitionPath)) {
      continue
    }
    $match = [regex]::Match($content, '(?i)[A-Z]:\\[^<>"'']+\.mrimgx')
    if (-not $match.Success) {
      continue
    }
    $imagePath = $match.Value
    if (-not $imagePath.StartsWith($BackupDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }
    if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
      continue
    }
    return [pscustomobject]@{
      ImagePath = $imagePath
      ReportPath = $report.FullName
      CompletionTime = $report.LastWriteTime
    }
  }
  return $null
}

function Set-BaselineRegistryTelemetry {
  param(
    [string]$KeyPath,
    [string]$Name,
    [string]$Value
  )
  if ($WhatIfPreference) {
    Write-BackupLog -Level INFO -Message "WhatIf: would set registry $KeyPath\$Name = '$Value'"
    return
  }
  try {
    $setScript = Join-Path $PSScriptRoot 'Set-LcmMachineRegistry.ps1'
    if (Test-Path -LiteralPath $setScript -PathType Leaf) {
      & $setScript -KeyPath $KeyPath -ValueName $Name -Value $Value | Out-Null
    } else {
      if (-not (Test-Path -LiteralPath $KeyPath)) {
        New-Item -Path $KeyPath -Force | Out-Null
      }
      Set-ItemProperty -Path $KeyPath -Name $Name -Value $Value -Type String -Force | Out-Null
    }
  } catch {
    Write-BackupLog -Level WARN -Message "Could not persist registry $KeyPath\$Name : $($_.Exception.Message)"
  }
}

# --- Execution ---

if (-not (Test-Path -LiteralPath $BackupDefinitionPath -PathType Leaf)) {
  throw "Macrium backup definition XML not found: $BackupDefinitionPath"
}

# Check if a completed image already exists for today
$existingImage = Get-CompletedTodayImage -NotBefore (Get-Date).Date
$imageToUse = $null

if ($null -ne $existingImage -and -not $ForceNewBackup) {
  Write-Host "`n[INFO] A completed Macrium backup already exists for today ($(Get-Date -Format 'yyyy-MM-dd')):" -ForegroundColor Green
  Write-Host "       Image: $($existingImage.ImagePath)" -ForegroundColor Green
  Write-Host "       Completed: $($existingImage.CompletionTime.ToString('yyyy-MM-dd HH:mm:ss'))`n" -ForegroundColor Green
  $imageToUse = $existingImage
} else {
  if (-not (Test-Path -LiteralPath $reflectPath -PathType Leaf)) {
    throw "Macrium Reflect executable not found: $reflectPath"
  }

  if ($WhatIfPreference) {
    Write-BackupLog -Level INFO -Message "WhatIf: would execute Macrium definition '$BackupDefinitionPath' and await completion in '$BackupDirectory'."
    $imageToUse = [pscustomobject]@{
      ImagePath = (Join-Path $BackupDirectory 'SIMULATED-BACKUP.mrimgx')
      ReportPath = 'SIMULATED-REPORT.html'
      CompletionTime = (Get-Date)
    }
  } else {
    $requestedAt = Get-Date
    Write-BackupLog -Level INFO -Message "Initiating Macrium Reflect backup: '$BackupDefinitionPath'..."
    Write-Host "`n[INFO] Starting Macrium Reflect backup execution..." -ForegroundColor Cyan
    Start-Process -FilePath $reflectPath -ArgumentList @('-e', $BackupDefinitionPath) | Out-Null

    $deadline = $requestedAt.AddMinutes($TimeoutMinutes)
    $completed = $null
    do {
      Start-Sleep -Seconds $PollSeconds
      $completed = Get-CompletedTodayImage -NotBefore $requestedAt
    } while ($null -eq $completed -and (Get-Date) -lt $deadline)

    if ($null -eq $completed) {
      throw "Macrium backup did not complete within $TimeoutMinutes minute(s) of request."
    }
    Write-Host "`n[SUCCESS] Macrium backup completed successfully!" -ForegroundColor Green
    Write-Host "          Image: $($completed.ImagePath)" -ForegroundColor Green
    Write-Host "          Completed: $($completed.CompletionTime.ToString('yyyy-MM-dd HH:mm:ss'))`n" -ForegroundColor Green
    $imageToUse = $completed
  }
}

# Carry over LCM baseline registry telemetry
if ($null -ne $imageToUse) {
  Set-BaselineRegistryTelemetry -KeyPath $MacriumRegistryKey -Name 'MRMTimeStamp' -Value ($imageToUse.CompletionTime.ToString('yyyy-MM-dd HH:mm:ss'))
}

# Option to mount newly generated backup/baseline
$mountResult = $null
if ($Mount -and $null -ne $imageToUse) {
  Write-Host "[INFO] Delegating to baseline mounting atom (-Mount specified)..." -ForegroundColor Cyan
  $mountTool = Join-Path $PSScriptRoot 'Mount-MacriumLatestBaseline.ps1'
  if (Test-Path -LiteralPath $mountTool -PathType Leaf) {
    $mountParams = @{
      ConfirmMount = $true
      CandidateDrives = $CandidateDrives
      MountTimeoutSeconds = $MountTimeoutSeconds
      NoLaunchReview = $NoLaunchReview
    }
    if (-not [string]::IsNullOrWhiteSpace($ReviewScope)) {
      $mountParams['ReviewScope'] = $ReviewScope
    }
    if ($WhatIfPreference) {
      $mountParams['WhatIf'] = $true
    }
    $mountResult = & $mountTool @mountParams
  } else {
    Write-BackupLog -Level WARN -Message "Mount-MacriumLatestBaseline.ps1 not found at '$mountTool'."
  }
}

[pscustomobject]@{
  ImagePath = if ($null -ne $imageToUse) { $imageToUse.ImagePath } else { '' }
  CompletionTime = if ($null -ne $imageToUse) { $imageToUse.CompletionTime } else { $null }
  Mounted = ($Mount -and $null -ne $mountResult)
  MountResult = $mountResult
}

