<#
.SYNOPSIS
  Modular automation atoms for Macrium Reflect baseline management.
.DESCRIPTION
  Module: LcmMacriumAtoms
  Purpose: Decomposes monolithic Macrium baseline operations into discrete, reusable
  automation atoms for inspection, status querying, backup launching, mounting, and dismounting.
  Path: LCM_Inventory/modules/LcmMacriumAtoms.psm1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.3
  Date: 2026-11-10 20:30:00
.NOTES
  Caveats: Drive mounting and dismounting require administrative elevation and Session 1
  interactive desktop access when automated through Macrium UI Automation. Telemetry and
  read-only inspection atoms execute non-elevated.
#>

Set-StrictMode -Version Latest

function ConvertTo-LcmCandidateDrives {
  <#
  .SYNOPSIS
    Normalizes candidate drive letters from various input types.
  .DESCRIPTION
    Converts arrays, lists, or delimited strings of drive letters into a cleaned,
    uppercase array of drive letters without trailing colons.
  .PARAMETER Drives
    Input drive collection or delimited string (semicolon or comma).
  .NOTES
    Part of LcmMacriumAtoms.
  #>
  param(
    [Parameter(Mandatory = $false, HelpMessage = 'Input drive letters or delimited string')]
    [object]$Drives
  )
  $list = [System.Collections.Generic.List[string]]::new()
  if ($null -eq $Drives) {
    return @('F', 'G', 'H', 'I')
  }
  if ($Drives -is [string]) {
    $split = $Drives -split '[;,]'
    foreach ($s in $split) {
      $clean = $s.Trim().TrimEnd('\', '/').TrimEnd(':').ToUpperInvariant()
      if (-not [string]::IsNullOrWhiteSpace($clean)) { $list.Add($clean) }
    }
  } elseif ($Drives -is [System.Collections.IEnumerable]) {
    foreach ($item in $Drives) {
      $clean = [string]$item.Trim().TrimEnd('\', '/').TrimEnd(':').ToUpperInvariant()
      if (-not [string]::IsNullOrWhiteSpace($clean)) { $list.Add($clean) }
    }
  }
  if ($list.Count -lt 1) {
    throw 'The candidate drives list must have a length >= 1.'
  }
  return @($list)
}

function Get-MacriumBaselineState {
  <#
  .SYNOPSIS
    Fast, read-only inspection of Macrium BCR baseline telemetry and physical drive mounts.
  .DESCRIPTION
    Inspects registry keys in HKLM:\SOFTWARE\LCM\MacriumBaseline (and HKLM:\SOFTWARE\LCM),
    queries candidate drives for the expected volume label, verifies the Git_Repositories
    container, and extracts snapshot timestamps from ACTIVE_CONTEXT.md and cm_activity.log.
  .PARAMETER CandidateDrives
    Candidate drive letters to evaluate for mounted baseline partition (Default: F, G, H, I).
  .PARAMETER ExpectedVolumeLabel
    Expected volume label of the mounted baseline image (Default: D4P3-WDB850-D).
  .NOTES
    Zero administrative elevation required. Safe to call unconditionally in GoodMorning.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false, HelpMessage = 'Candidate drive letters to evaluate')]
    [object]$CandidateDrives = @('F', 'G', 'H', 'I'),

    [Parameter(Mandatory = $false, HelpMessage = 'Expected volume label')]
    [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D'
  )

  $normalizedDrives = ConvertTo-LcmCandidateDrives -Drives $CandidateDrives

  # Registry telemetry inspection
  $regBaseKey = 'HKLM:\SOFTWARE\LCM\MacriumBaseline'
  $regLcmKey = 'HKLM:\SOFTWARE\LCM'

  $mrmTimeStamp = ''
  $mrmDrive = ''
  $actMTimeStamp = ''
  $actMDrive = ''
  $mrPushTimeStamp = ''

  if (Test-Path -LiteralPath $regBaseKey) {
    try {
      $props = Get-ItemProperty -Path $regBaseKey -ErrorAction SilentlyContinue
      if ($null -ne $props) {
        if ($props.PSObject.Properties['MRMTimeStamp']) { $mrmTimeStamp = [string]$props.MRMTimeStamp }
        if ($props.PSObject.Properties['MRMdrive']) { $mrmDrive = [string]$props.MRMdrive }
        if ($props.PSObject.Properties['ActMTimeStamp']) { $actMTimeStamp = [string]$props.ActMTimeStamp }
        if ($props.PSObject.Properties['actMdrive']) { $actMDrive = [string]$props.actMdrive }
      }
    } catch { }
  }

  if (Test-Path -LiteralPath $regLcmKey) {
    try {
      $propsLcm = Get-ItemProperty -Path $regLcmKey -ErrorAction SilentlyContinue
      if ($null -ne $propsLcm) {
        if ([string]::IsNullOrWhiteSpace($mrmTimeStamp) -and $propsLcm.PSObject.Properties['MRMTimeStamp']) {
          $mrmTimeStamp = [string]$propsLcm.MRMTimeStamp
        }
        if ([string]::IsNullOrWhiteSpace($mrmDrive) -and $propsLcm.PSObject.Properties['MRMdrive']) {
          $mrmDrive = [string]$propsLcm.MRMdrive
        }
        if ($propsLcm.PSObject.Properties['MRPushTimeStamp']) {
          $mrPushTimeStamp = [string]$propsLcm.MRPushTimeStamp
        }
      }
    } catch { }
  }

  # Physical mount probe
  $mountedCandidates = [System.Collections.Generic.List[PSCustomObject]]::new()
  foreach ($letter in $normalizedDrives) {
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
    if ($null -eq $disk -or $disk.DriveType -ne 3 -or $disk.VolumeName -ne $ExpectedVolumeLabel) {
      continue
    }

    $workspacePath = "$letter`:\Git_Repositories"
    $contextPath = Join-Path $workspacePath 'LCM_AI\.agents\ACTIVE_CONTEXT.md'
    $activityPath = Join-Path $workspacePath 'LCM_Inventory\logs\cm_activity.log'
    $savedAt = ''
    if (Test-Path -LiteralPath $contextPath -PathType Leaf) {
      try {
        $context = Get-Content -LiteralPath $contextPath -Raw -Encoding utf8
        $savedMatch = [regex]::Match($context, '(?m)^Saved:\s*(.+)$')
        if ($savedMatch.Success) {
          $savedAt = $savedMatch.Groups[1].Value.Trim()
        }
      } catch { }
    }

    $goodNight = $false
    if (Test-Path -LiteralPath $activityPath -PathType Leaf) {
      try {
        $goodNight = [bool](Select-String -LiteralPath $activityPath -Pattern '\[GOOD_NIGHT\].*SAVE_ALL_AND_GOOD_NIGHT' -Quiet)
      } catch { }
    }

    $mountedCandidates.Add([pscustomobject]@{
      MountedDrive = "$letter`:"
      VolumeLabel = $disk.VolumeName
      WorkspacePath = $workspacePath
      Plausible = (Test-Path -LiteralPath $workspacePath -PathType Container)
      SnapshotSavedAt = $savedAt
      GoodNightObserved = $goodNight
    })
  }

  $primaryMount = if ($mountedCandidates.Count -gt 0) { $mountedCandidates[0] } else { $null }

  return [pscustomobject]@{
    Plausible = ($null -ne $primaryMount -and $primaryMount.Plausible)
    MountedDrive = if ($null -ne $primaryMount) { $primaryMount.MountedDrive } else { '' }
    VolumeLabel = if ($null -ne $primaryMount) { $primaryMount.VolumeLabel } else { '' }
    WorkspacePath = if ($null -ne $primaryMount) { $primaryMount.WorkspacePath } else { '' }
    SnapshotSavedAt = if ($null -ne $primaryMount) { $primaryMount.SnapshotSavedAt } else { '' }
    GoodNightObserved = if ($null -ne $primaryMount) { $primaryMount.GoodNightObserved } else { $false }
    RegistryMRMTimeStamp = $mrmTimeStamp
    RegistryMRMdrive = $mrmDrive
    RegistryActMTimeStamp = $actMTimeStamp
    RegistryActMdrive = $actMDrive
    RegistryMRPushTimeStamp = $mrPushTimeStamp
    CandidateDrives = @($normalizedDrives)
    CandidateCount = $mountedCandidates.Count
  }
}

function Get-MacriumBackupStatus {
  <#
  .SYNOPSIS
    Evaluates completed Macrium backup images and active backup process status.
  .DESCRIPTION
    Scans the designated backup directory for completed .mrimgx image files matching
    the backup definition timestamp requirements, and checks if Macrium Reflect is running.
  .PARAMETER BackupDefinitionPath
    Path to the Macrium backup definition XML file.
  .PARAMETER BackupDirectory
    Directory containing .mrimgx backup images.
  .PARAMETER NotBefore
    Cutoff timestamp; images completed prior to this time are ignored (Default: today at 00:00:00).
  .NOTES
    Part of LcmMacriumAtoms.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false, HelpMessage = 'Path to backup definition XML')]
    [string]$BackupDefinitionPath = 'D:\OneDrive\Documents\Reflect\@B_D4P3+4-WDB850-AD.xml',

    [Parameter(Mandatory = $false, HelpMessage = 'Directory containing .mrimgx images')]
    [string]$BackupDirectory = 'B:\Backups\D4P3+4-WDB850-AD',

    [Parameter(Mandatory = $false, HelpMessage = 'Earliest allowable image completion time')]
    [datetime]$NotBefore = (Get-Date).Date
  )

  $reflectRunning = $false
  try {
    $procs = @(Get-Process -Name 'Reflect' -ErrorAction SilentlyContinue)
    $reflectRunning = ($procs.Count -gt 0)
  } catch { }

  $latestImage = $null
  $latestTime = $null

  if (Test-Path -LiteralPath $BackupDirectory -PathType Container) {
    try {
      $images = @(Get-ChildItem -LiteralPath $BackupDirectory -Filter '*.mrimgx' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $NotBefore } |
        Sort-Object -Property LastWriteTime -Descending)

      if ($images.Count -gt 0) {
        $latestImage = $images[0].FullName
        $latestTime = $images[0].LastWriteTime
      }
    } catch { }
  }

  return [pscustomobject]@{
    CompletedToday = ($null -ne $latestImage)
    LatestImage = $latestImage
    CompletionTime = $latestTime
    ActiveBackupRunning = $reflectRunning
  }
}

function Start-MacriumBackup {
  <#
  .SYNOPSIS
    Initiates Macrium Reflect backup execution using the configured definition.
  .DESCRIPTION
    Launches Reflect.exe with the specified XML definition in automated mode.
  .PARAMETER BackupDefinitionPath
    Path to the Macrium Reflect backup definition XML file.
  .PARAMETER ReflectPath
    Path to Reflect.exe executable.
  .PARAMETER Wait
    Whether to wait synchronously for Reflect execution to finish.
  .NOTES
    Part of LcmMacriumAtoms.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false, HelpMessage = 'Path to Macrium backup definition XML')]
    [string]$BackupDefinitionPath = 'D:\OneDrive\Documents\Reflect\@B_D4P3+4-WDB850-AD.xml',

    [Parameter(Mandatory = $false, HelpMessage = 'Path to Reflect.exe')]
    [string]$ReflectPath = 'C:\Program Files\Macrium\Reflect\Reflect.exe',

    [Parameter(Mandatory = $false, HelpMessage = 'Waits for process termination')]
    [switch]$Wait
  )

  if (-not (Test-Path -LiteralPath $ReflectPath -PathType Leaf)) {
    throw "Macrium Reflect executable was not found: $ReflectPath"
  }
  if (-not (Test-Path -LiteralPath $BackupDefinitionPath -PathType Leaf)) {
    throw "Macrium backup definition XML was not found: $BackupDefinitionPath"
  }

  $proc = Start-Process -FilePath $ReflectPath -ArgumentList @('-e', '-w', $BackupDefinitionPath) -PassThru
  if ($Wait) {
    $proc.WaitForExit()
  }
  return $proc
}

function Mount-MacriumBaseline {
  <#
  .SYNOPSIS
    Mounts a completed Macrium Reflect image partition at an available candidate drive.
  .DESCRIPTION
    Delegates elevated image mounting to Invoke-MacriumDailyBcrBaseline.ps1 with worker parameters.
  .PARAMETER ImagePath
    Full path to the .mrimgx image to mount.
  .PARAMETER CandidateDrives
    Candidate drive letters to evaluate for mounting.
  .PARAMETER ExpectedVolumeLabel
    Expected volume label for the mounted baseline partition.
  .PARAMETER MountTimeoutSeconds
    Maximum timeout in seconds for mounting dialog completion.
  .PARAMETER ToolScriptPath
    Path to Invoke-MacriumDailyBcrBaseline.ps1.
  .NOTES
    Part of LcmMacriumAtoms.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, HelpMessage = 'Path to .mrimgx image to mount')]
    [string]$ImagePath,

    [Parameter(Mandatory = $false, HelpMessage = 'Candidate drive letters')]
    [object]$CandidateDrives = @('F', 'G', 'H', 'I'),

    [Parameter(Mandatory = $false, HelpMessage = 'Expected volume label')]
    [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D',

    [Parameter(Mandatory = $false, HelpMessage = 'Mount timeout in seconds')]
    [int]$MountTimeoutSeconds = 120,

    [Parameter(Mandatory = $false, HelpMessage = 'Path to Invoke-MacriumDailyBcrBaseline.ps1')]
    [string]$ToolScriptPath = ''
  )

  if ([string]::IsNullOrWhiteSpace($ToolScriptPath)) {
    $inventoryRoot = Split-Path $PSScriptRoot -Parent
    $ToolScriptPath = Join-Path $inventoryRoot 'tools\Invoke-MacriumDailyBcrBaseline.ps1'
  }

  if (-not (Test-Path -LiteralPath $ToolScriptPath -PathType Leaf)) {
    throw "Macrium daily baseline tool was not found at '$ToolScriptPath'."
  }

  & $ToolScriptPath -ImagePath $ImagePath -CandidateDrives $CandidateDrives -ExpectedVolumeLabel $ExpectedVolumeLabel -MountTimeoutSeconds $MountTimeoutSeconds -NewBaseline -Confirm:$false
}

function Dismount-MacriumBaseline {
  <#
  .SYNOPSIS
    Detaches Macrium baseline partitions mounted within candidate drive letters.
  .DESCRIPTION
    Invokes Reflect.exe -d across candidate drives matching ExpectedVolumeLabel, or
    delegates to Dismount-MacriumCurrentBaseline.ps1.
  .PARAMETER CandidateDrives
    Candidate drive letters to check and dismount.
  .PARAMETER ExpectedVolumeLabel
    Expected volume label of mounted partition.
  .PARAMETER DetachTimeoutSeconds
    Timeout in seconds for unmount operations.
  .PARAMETER ToolScriptPath
    Path to Dismount-MacriumCurrentBaseline.ps1.
  .NOTES
    Part of LcmMacriumAtoms.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false, HelpMessage = 'Candidate drive letters to dismount')]
    [object]$CandidateDrives = @('F', 'G', 'H', 'I'),

    [Parameter(Mandatory = $false, HelpMessage = 'Expected volume label')]
    [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D',

    [Parameter(Mandatory = $false, HelpMessage = 'Detach timeout in seconds')]
    [int]$DetachTimeoutSeconds = 120,

    [Parameter(Mandatory = $false, HelpMessage = 'Path to Dismount-MacriumCurrentBaseline.ps1')]
    [string]$ToolScriptPath = ''
  )

  if ([string]::IsNullOrWhiteSpace($ToolScriptPath)) {
    $inventoryRoot = Split-Path $PSScriptRoot -Parent
    $ToolScriptPath = Join-Path $inventoryRoot 'tools\Dismount-MacriumCurrentBaseline.ps1'
  }

  if (Test-Path -LiteralPath $ToolScriptPath -PathType Leaf) {
    & $ToolScriptPath -ExpectedVolumeLabel $ExpectedVolumeLabel -DetachTimeoutSeconds $DetachTimeoutSeconds -ConfirmDetach
  } else {
    $normalized = ConvertTo-LcmCandidateDrives -Drives $CandidateDrives
    $reflectPath = 'C:\Program Files\Macrium\Reflect\Reflect.exe'
    foreach ($letter in $normalized) {
      $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
      if ($null -ne $disk -and $disk.DriveType -eq 3 -and $disk.VolumeName -eq $ExpectedVolumeLabel) {
        if (Test-Path -LiteralPath $reflectPath -PathType Leaf) {
          Start-Process -FilePath $reflectPath -ArgumentList @("$letter`:", '-u') -Wait | Out-Null
        }
      }
    }
  }
}

function Test-LcmBaselineModifications {
  <#
  .SYNOPSIS
    Detects modifications, untracked files, and review markers on the mounted baseline drive.
  .DESCRIPTION
    Scans child repositories on the mounted baseline volume using git status --porcelain.
    Returns a PSObject with HasModifications ($true/$false), TotalModifiedFiles, and ModifiedRepositories.
    Part of LcmMacriumAtoms (RULE-REV-013).
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false, HelpMessage = 'Candidate drive letters to inspect')]
    [object]$CandidateDrives = @('F', 'G', 'H', 'I'),

    [Parameter(Mandatory = $false, HelpMessage = 'Expected volume label for Macrium baseline')]
    [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D'
  )

  $normalized = ConvertTo-LcmCandidateDrives -Drives $CandidateDrives
  $results = @()
  $totalModCount = 0

  foreach ($letter in $normalized) {
    $driveRoot = "$letter`:"
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$driveRoot'" -ErrorAction SilentlyContinue
    if ($null -eq $disk -or $disk.DriveType -ne 3) { continue }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedVolumeLabel) -and $disk.VolumeName -ne $ExpectedVolumeLabel) { continue }

    $reposBase = Join-Path $driveRoot 'Git_Repositories'
    $repoDirs = if (Test-Path -LiteralPath $reposBase -PathType Container) {
      Get-ChildItem -LiteralPath $reposBase -Directory | Where-Object { Test-Path (Join-Path $_.FullName '.git') }
    } else {
      Get-ChildItem -LiteralPath $driveRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName '.git') }
    }

    foreach ($rd in $repoDirs) {
      $gitStatus = @(& git -C $rd.FullName status --porcelain 2>$null)
      if ($LASTEXITCODE -eq 0 -and $gitStatus.Count -gt 0) {
        $nonEmpty = @($gitStatus | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($nonEmpty.Count -gt 0) {
          $totalModCount += $nonEmpty.Count
          $results += [PSCustomObject]@{
            DriveLetter    = $letter
            RepositoryName = $rd.Name
            RepositoryPath = $rd.FullName
            ModifiedFiles  = $nonEmpty
            Count          = $nonEmpty.Count
          }
        }
      }
    }
  }

  return [PSCustomObject]@{
    HasModifications     = ($totalModCount -gt 0)
    TotalModifiedFiles   = $totalModCount
    ModifiedRepositories = $results
  }
}

Export-ModuleMember -Function @(
  'ConvertTo-LcmCandidateDrives',
  'Get-MacriumBaselineState',
  'Get-MacriumBackupStatus',
  'Start-MacriumBackup',
  'Mount-MacriumBaseline',
  'Dismount-MacriumBaseline',
  'Test-LcmBaselineModifications'
)
