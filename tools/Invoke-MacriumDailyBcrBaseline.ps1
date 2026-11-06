<#
.SYNOPSIS
  Prepares today's Macrium image as the writable Beyond Compare baseline.
.DESCRIPTION
  Module: tools/Invoke-MacriumDailyBcrBaseline.ps1
  Purpose: Finds today's completed Macrium image, optionally starts the configured
  definition when today's image is absent, clears only known F:-I: image mounts,
  mounts D: within F:-I: with the required GUI options, and opens the operator-owned
  _LCM Beyond Compare profile. Reuses an existing mounted baseline by default unless -NewBaseline is set.
  Path: LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.4
  Date: 2026-11-06
#>
[CmdletBinding()]
param(
  [ValidateNotNullOrEmpty()]
  [string]$BackupDefinitionPath = 'D:\OneDrive\Documents\Reflect\@B_D4P3+4-WDB850-AD.xml',

  [ValidateNotNullOrEmpty()]
  [string]$BackupDirectory = 'B:\Backups\D4P3+4-WDB850-AD',

  [ValidateNotNullOrEmpty()]
  [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D',

  [Parameter(Mandatory = $false, HelpMessage = 'List or delimited string of acceptable drive letters (length >= 1)')]
  [object]$CandidateDrives = @('F', 'G', 'H', 'I'),

  [ValidateRange(1, 240)]
  [int]$PollSeconds = 60,

  [ValidateRange(1, 1440)]
  [int]$TimeoutMinutes = 240,

  [ValidateRange(30, 600)]
  [int]$MountTimeoutSeconds = 120,

  [string]$ReviewScope = '',

  [switch]$StartBackupIfMissing,

  [switch]$ForceNewBackup,

  [switch]$NewBaseline,

  [switch]$NoLaunchReview,

  [switch]$ElevatedWorker,

  [string]$ReceiptPath = '',

  [string]$ImagePath = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolName = Split-Path $PSCommandPath -LeafBase
$inventoryRoot = Split-Path $PSScriptRoot -Parent
$logDirectory = Join-Path $inventoryRoot 'logs'
$reflectPath = 'C:\Program Files\Macrium\Reflect\Reflect.exe'
$bcompareCandidates = @(
  'C:\Program Files\Beyond Compare 5\BCompare.exe',
  'D:\Tools\Beyond Compare 5\BCompare.exe'
)
$bcomparePath = @($bcompareCandidates | Where-Object { Test-Path -LiteralPath $_ })[0]
$MacriumRegistryKey = 'HKLM:\SOFTWARE\LCM\MacriumBaseline'
$LcmRootRegistryKey = 'HKLM:\SOFTWARE\LCM'

function Write-BaselineLog {
  param(
    [ValidateSet('INFO', 'WARN', 'ERROR')]
    [string]$Level,

    [string]$Message
  )

  $entry = '{0} [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message
  if ($WhatIfPreference) {
    Write-Host $entry
    return
  }
  if (-not (Test-Path -LiteralPath $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
  }
  $logPath = Join-Path $logDirectory ('{0}-{1}.log' -f $toolName, (Get-Date).ToString('yyyyMMdd_HHmmss'))
  Add-Content -LiteralPath $logPath -Value $entry -Encoding utf8
  Write-Host $entry
}

function Write-WorkerReceipt {
  param(
    [bool]$Succeeded,
    [string]$Message,
    [string]$ImagePath = '',
    [string]$MountedDrive = '',
    [object]$MountEvidence = $null
  )

  if ([string]::IsNullOrWhiteSpace($ReceiptPath)) {
    return
  }
  [pscustomobject]@{
    Succeeded = $Succeeded
    Message = $Message
    ImagePath = $ImagePath
    MountedDrive = $MountedDrive
    MountEvidence = $MountEvidence
    Timestamp = (Get-Date).ToString('o')
  } | ConvertTo-Json | Set-Content -LiteralPath $ReceiptPath -Encoding utf8
}

function Set-LcmReviewWindowTitle {
  param(
    [Parameter(Mandatory = $true)]
    [System.Diagnostics.Process]$Window,

    [Parameter(Mandatory = $true)]
    [string]$Scope
  )

  if (-not ('LcmBcrWindowTitle' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class LcmBcrWindowTitle
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SetWindowText(IntPtr hWnd, string lpString);
}
'@
  }

  $baseTitle = $Window.MainWindowTitle -replace '\s+\[(?:CRP|BUG|COH)-[^\]]+\]$', ''
  $title = '{0} [{1}]' -f $baseTitle, $Scope
  if (-not [LcmBcrWindowTitle]::SetWindowText($Window.MainWindowHandle, $title)) {
    throw "Could not set the Beyond Compare review title for PID $($Window.Id)."
  }

  Start-Sleep -Milliseconds 250
  $Window.Refresh()
  if ($Window.MainWindowTitle -ne $title) {
    throw "Beyond Compare did not retain the review title. Expected '$title'; actual '$($Window.MainWindowTitle)'."
  }
  return $title
}

function Get-CompletedTodayImage {
  param(
    [datetime]$NotBefore = [datetime]::MinValue
  )

  $reportDirectory = 'C:\ProgramData\Macrium\Reflect'
  if (-not (Test-Path -LiteralPath $reportDirectory)) {
    throw "Macrium report directory was not found: $reportDirectory"
  }
  if (-not (Test-Path -LiteralPath $BackupDirectory)) {
    Write-BaselineLog -Level WARN -Message "Macrium backup directory is unavailable: $BackupDirectory"
    return $null
  }

  $today = (Get-Date).Date
  $reports = @(Get-ChildItem -LiteralPath $reportDirectory -Filter '*.html' -File |
    Where-Object { $_.LastWriteTime.Date -eq $today } |
    Sort-Object LastWriteTime -Descending)
  foreach ($report in $reports) {
    if ($report.LastWriteTime -lt $NotBefore) {
      continue
    }
    $content = Get-Content -LiteralPath $report.FullName -Raw
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

function Get-AutomaticBackupStartReceiptPath {
  $directory = Join-Path $inventoryRoot 'data\artifacts'
  return Join-Path $directory 'macrium-automatic-backup-start.json'
}

function Test-AutomaticBackupAlreadyStartedToday {
  $receiptPath = Get-AutomaticBackupStartReceiptPath
  if (-not (Test-Path -LiteralPath $receiptPath)) {
    return $false
  }
  try {
    $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json
    return [string]$receipt.requested_date -eq (Get-Date).ToString('yyyy-MM-dd') -and
      [string]$receipt.backup_definition_path -eq $BackupDefinitionPath
  } catch {
    throw "Automatic Macrium backup-start receipt is unreadable: $receiptPath. Correct or remove it before retrying."
  }
}

function Save-AutomaticBackupStartReceipt {
  $receiptPath = Get-AutomaticBackupStartReceiptPath
  $directory = Split-Path $receiptPath -Parent
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  [ordered]@{
    requested_at = (Get-Date).ToString('o')
    requested_date = (Get-Date).ToString('yyyy-MM-dd')
    backup_definition_path = $BackupDefinitionPath
    backup_directory = $BackupDirectory
  } | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8
}

function Start-MacriumBackupAndWait {
  param(
    [switch]$Automatic
  )

  if ($Automatic -and (Test-AutomaticBackupAlreadyStartedToday)) {
    throw "An automatic Macrium backup was already requested today. Automatic baseline creation is limited to once per local calendar day; use -ForceNewBackup for an explicit additional baseline."
  }
  if ($WhatIfPreference) {
    Write-BaselineLog -Level INFO -Message 'WhatIf: would start the configured Macrium backup definition and wait for today''s completed Macrium report.'
    return $null
  }

  $requestedAt = Get-Date
  Write-BaselineLog -Level INFO -Message "Starting configured Macrium definition '$BackupDefinitionPath'."
  Start-Process -FilePath $reflectPath -ArgumentList @('-e', $BackupDefinitionPath) | Out-Null
  if ($Automatic) {
    Save-AutomaticBackupStartReceipt
  }

  $deadline = $requestedAt.AddMinutes($TimeoutMinutes)
  do {
    Start-Sleep -Seconds $PollSeconds
    $completedImage = Get-CompletedTodayImage -NotBefore $requestedAt
  } while ($null -eq $completedImage -and (Get-Date) -lt $deadline)
  if ($null -eq $completedImage) {
    throw "No completed Macrium backup for today was found within $TimeoutMinutes minute(s) of the request."
  }
  return $completedImage
}

function Resolve-BaselineReviewScope {
  if (-not [string]::IsNullOrWhiteSpace($ReviewScope)) {
    return $ReviewScope
  }
  $proposalFile = Join-Path $inventoryRoot 'data\proposals\proposals.json'
  if (-not (Test-Path -LiteralPath $proposalFile -PathType Leaf)) {
    return 'BCR-BASELINE-DUMMY'
  }
  $store = Get-Content -LiteralPath $proposalFile -Raw | ConvertFrom-Json
  $activeProposals = @($store.proposals | Where-Object {
    $_.state -in @('suggested', 'in_progress', 'verified', 'in_review')
  } | Sort-Object id)
  if ($activeProposals.Count -eq 0) {
    return 'BCR-BASELINE-DUMMY'
  }
  return $activeProposals[0].crp_id
}

function Set-LcmRegistryValue {
  param(
    [string]$KeyPath,
    [string]$Name,
    [object]$Value,
    [string]$PropertyType = 'String'
  )
  if ($WhatIfPreference) {
    Write-BaselineLog -Level INFO -Message "WhatIf: would set registry $KeyPath\$Name = '$Value'"
    return
  }
  try {
    if (-not (Test-Path -LiteralPath $KeyPath)) {
      New-Item -Path $KeyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $KeyPath -Name $Name -Value $Value -Type $PropertyType -Force | Out-Null
    Write-BaselineLog -Level INFO -Message "Registry updated: $KeyPath\$Name = '$Value'"
  } catch {
    Write-BaselineLog -Level WARN -Message "Failed to write registry $KeyPath\${Name}: $($_.Exception.Message)"
  }
}

function Get-LcmRegistryValue {
  param(
    [string]$KeyPath,
    [string]$Name
  )
  try {
    if (Test-Path -LiteralPath $KeyPath) {
      $prop = Get-ItemProperty -Path $KeyPath -Name $Name -ErrorAction SilentlyContinue
      if ($null -ne $prop -and $prop.PSObject.Properties[$Name]) {
        return $prop.$Name
      }
    }
  } catch {
    Write-Verbose "Could not read registry value: $_"
  }
  return $null
}

function ConvertTo-LcmCandidateDrive {
  param([object]$Drives)
  $list = [System.Collections.Generic.List[string]]::new()
  if ($null -eq $Drives) {
    return @('F', 'G', 'H', 'I')
  }
  if ($Drives -is [string]) {
    $split = $Drives -split '[;,]'
    foreach ($s in $split) {
      $clean = $s.Trim().TrimEnd(':').ToUpperInvariant()
      if (-not [string]::IsNullOrWhiteSpace($clean)) { $list.Add($clean) }
    }
  } elseif ($Drives -is [System.Collections.IEnumerable]) {
    foreach ($item in $Drives) {
      $clean = [string]$item.Trim().TrimEnd(':').ToUpperInvariant()
      if (-not [string]::IsNullOrWhiteSpace($clean)) { $list.Add($clean) }
    }
  }
  if ($list.Count -lt 1) {
    throw 'The candidate drives list must have a length >= 1.'
  }
  return @($list)
}
Set-Alias -Name Normalize-LcmCandidateDrives -Value ConvertTo-LcmCandidateDrive

function Find-MountedMacriumBaselineCandidates {
  param(
    [string[]]$Drives = @('F', 'G', 'H', 'I')
  )
  $candidates = [System.Collections.Generic.List[PSCustomObject]]::new()
  foreach ($letter in $Drives) {
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
    if ($null -eq $disk -or $disk.DriveType -ne 3 -or $disk.VolumeName -ne $ExpectedVolumeLabel) {
      continue
    }
    $workspacePath = "$letter`:\Git_Repositories"
    if (-not (Test-Path -LiteralPath $workspacePath -PathType Container)) {
      continue
    }
    $newestLogTime = $null
    $newestLogStr = ''
    $internalLogDir = Join-Path $workspacePath 'LCM_Inventory\data\logs\lcm-internal'
    if (Test-Path -LiteralPath $internalLogDir -PathType Container) {
      $logFiles = @(Get-ChildItem -LiteralPath $internalLogDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)
      if ($logFiles.Count -gt 0) {
        $newestLogTime = $logFiles[0].LastWriteTime
        $newestLogStr = $newestLogTime.ToString('yyyy-MM-dd HH:mm:ss')
      }
    }
    $candidates.Add([pscustomobject]@{
      DriveLetter = $letter
      MountedDrive = "$letter`:"
      WorkspacePath = $workspacePath
      NewestLogTimestamp = $newestLogStr
      NewestLogDate = $newestLogTime
    })
  }
  return @($candidates)
}

function Find-MountedMacriumBaseline {
  param(
    [string[]]$Drives = @('F', 'G', 'H', 'I')
  )
  $all = @(Find-MountedMacriumBaselineCandidates -Drives $Drives)
  if ($all.Count -gt 0) {
    return $all[0]
  }
  return $null
}

function Get-LcmReviewWindows {
  return @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowTitle -and
    ($_.MainWindowTitle -match '^_LCM\*?\s*-\s*Folder Compare')
  })
}

function Get-MountedBaselineEvidence {
  param(
    [Parameter(Mandatory)]
    [PSCustomObject]$MountedBaseline,

    [string[]]$DetachedDrives = @()
  )

  $contextPath = Join-Path $MountedBaseline.WorkspacePath 'LCM_AI\.agents\ACTIVE_CONTEXT.md'
  $activityPath = Join-Path $MountedBaseline.WorkspacePath 'LCM_Inventory\logs\cm_activity.log'
  $savedAt = ''
  $goodNightObserved = $false

  if (Test-Path -LiteralPath $contextPath -PathType Leaf) {
    $context = Get-Content -LiteralPath $contextPath -Raw -Encoding utf8
    $savedMatch = [regex]::Match($context, '(?m)^Saved:\s*(.+)$')
    if ($savedMatch.Success) {
      $savedAt = $savedMatch.Groups[1].Value.Trim()
    }
  }

  if (Test-Path -LiteralPath $activityPath -PathType Leaf) {
    $goodNightObserved = Select-String -LiteralPath $activityPath -Pattern '\[GOOD_NIGHT\].*SAVE_ALL_AND_GOOD_NIGHT' -Quiet
  }

  return [pscustomobject]@{
    DetachedDrives = @($DetachedDrives)
    ReappearedDrive = $MountedBaseline.MountedDrive
    WorkspacePath = $MountedBaseline.WorkspacePath
    SnapshotSavedAt = $savedAt
    GoodNightObserved = $goodNightObserved
  }
}

function Close-MountedImageReview {
  $sessions = @(Get-LcmReviewWindows)
  foreach ($session in $sessions) {
    if (-not $session.CloseMainWindow()) {
      throw "Beyond Compare PID $($session.Id) did not accept a graceful _LCM close request."
    }
  }
  if ($sessions.Count -eq 0) {
    return
  }

  $deadline = (Get-Date).AddSeconds(15)
  do {
    Start-Sleep -Milliseconds 250
    $remaining = @(Get-LcmReviewWindows)
  } while ($remaining.Count -gt 0 -and (Get-Date) -lt $deadline)

  if ($remaining.Count -gt 0) {
    throw "The _LCM Beyond Compare session remained open (PID(s): $($remaining.Id -join ', ')); mounted-image cleanup was not attempted."
  }
}

function Test-LcmBcrProfile {
  param(
    [ValidateSet('F', 'G', 'H', 'I')]
    [string]$MountedDriveLetter
  )
  $sessionRegistryPath = Join-Path $env:APPDATA 'Scooter Software\Beyond Compare 5\BCSessions.xml'
  if (-not (Test-Path -LiteralPath $sessionRegistryPath -PathType Leaf)) {
    throw "Beyond Compare session registry was not found: $sessionRegistryPath"
  }

  [xml]$sessionRegistry = Get-Content -LiteralPath $sessionRegistryPath
  $session = $sessionRegistry.SelectSingleNode("//TDirCompareSession[@Value='_LCM']")
  if ($null -eq $session) {
    throw 'The required _LCM Beyond Compare profile was not found.'
  }

  $expectedLeftPath = "$MountedDriveLetter`:\Git_Repositories"
  $leftPath = $session.SelectSingleNode('./Specs/Left').GetAttribute('Value')
  $rightPath = $session.SelectSingleNode('./Specs/Right').GetAttribute('Value')
  $contentComparison = $session.SelectSingleNode('./Rules/UseContentComparison').GetAttribute('Value')
  $directoryHandlingNode = $session.SelectSingleNode('./State/DirHandling')
  $directoryHandling = if ($null -eq $directoryHandlingNode) {
    'implicit default'
  } else {
    $directoryHandlingNode.GetAttribute('Value')
  }

  if ($leftPath -ne $expectedLeftPath) {
    throw "The _LCM Beyond Compare profile specifies left path '$leftPath'; expected '$expectedLeftPath'."
  }
  if ($rightPath -ne 'D:\Git_Repositories') {
    throw "The _LCM Beyond Compare profile specifies right path '$rightPath'; expected 'D:\Git_Repositories'."
  }
  if ($contentComparison -ne 'True') {
    throw "The _LCM Beyond Compare profile requires content comparison enabled; actual value is '$contentComparison'."
  }
  if ($null -ne $directoryHandlingNode -and $directoryHandling -ne 'dirCompareFilesOnly') {
    throw "The _LCM Beyond Compare profile specifies directory handling '$directoryHandling'; expected 'dirCompareFilesOnly' or omitted default."
  }

  return [pscustomobject]@{
    Name = '_LCM'
    LeftPath = $leftPath
    RightPath = $rightPath
    ContentComparison = ($contentComparison -eq 'True')
    DirectoryHandling = $directoryHandling
  }
}

function Invoke-ElevatedBaselineWorker {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath
  )

  if (-not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) {
    throw "The specified Macrium image file was not found: $ImagePath"
  }

  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class LcmMacriumMouse
{
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);
}
'@

  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes

  $workerDrives = ConvertTo-LcmCandidateDrive -Drives $CandidateDrives
  $detachedDrives = [System.Collections.Generic.List[string]]::new()
  foreach ($letter in $workerDrives) {
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
    if ($null -eq $disk) {
      continue
    }
    if ($disk.DriveType -ne 3 -or $disk.VolumeName -ne $ExpectedVolumeLabel) {
      continue
    }
    Write-BaselineLog -Level INFO -Message "Detaching existing volume at ${letter}: before mounting '$ImagePath'."
    $detachProcess = Start-Process -FilePath $reflectPath -ArgumentList @('-d', "$letter`:") -PassThru -Wait
    $detachExitCode = if ($null -ne $detachProcess -and $null -ne $detachProcess.ExitCode) {
      $detachProcess.ExitCode
    } else {
      0
    }
    if ($detachExitCode -ne 0) {
      throw "Macrium detach failed for ${letter}: with exit code $detachExitCode."
    }
    $deadline = (Get-Date).AddSeconds($MountTimeoutSeconds)
    do {
      Start-Sleep -Milliseconds 250
      $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
    } while ($null -ne $disk -and (Get-Date) -lt $deadline)
    if ($null -ne $disk) {
      throw "Macrium did not detach ${letter}: within $MountTimeoutSeconds seconds."
    }
    $detachedDrives.Add("$letter`:")
  }

  $existingReflectBinIds = @(Get-Process -Name 'ReflectBin' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
  Start-Process -FilePath $reflectPath -ArgumentList @('-b', $ImagePath) | Out-Null
  $deadline = (Get-Date).AddSeconds($MountTimeoutSeconds)
  $dialog = $null
  while ((Get-Date) -lt $deadline -and $null -eq $dialog) {
    $newReflectBinIds = @(Get-Process -Name 'ReflectBin' -ErrorAction SilentlyContinue |
      Where-Object { $_.Id -notin $existingReflectBinIds } |
      Select-Object -ExpandProperty Id)
    $candidateProcessIds = if ($newReflectBinIds.Count -gt 0) {
      $newReflectBinIds
    } else {
      @(Get-Process -Name 'ReflectBin' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
    }
    foreach ($processId in $candidateProcessIds) {
      $root = [System.Windows.Automation.AutomationElement]::RootElement
      $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
        $processId
      )
      $candidate = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
      if ($null -eq $candidate) {
        continue
      }
      $dPartition = $candidate.FindFirst(
        [System.Windows.Automation.TreeScope]::Descendants,
        (New-Object System.Windows.Automation.PropertyCondition(
          [System.Windows.Automation.AutomationElement]::NameProperty,
          'D4P3-WDB850-D (D:)'
        ))
      )
      if ($null -ne $dPartition) {
        $dialog = $candidate
        break
      }
    }
    Start-Sleep -Milliseconds 250
  }
  if ($null -eq $dialog) {
    throw "Macrium Browse Image dialog did not become ready within $MountTimeoutSeconds seconds."
  }

  $bounds = $dialog.Current.BoundingRectangle
  [LcmMacriumMouse]::SetCursorPos([int]($bounds.Left + 37), [int]($bounds.Top + 236)) | Out-Null
  [LcmMacriumMouse]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  [LcmMacriumMouse]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250

  foreach ($optionName in @(
    'Enable access to restricted folders',
    'Make writable. Note: Changes are temporary and will be discarded.'
  )) {
    $option = $dialog.FindFirst(
      [System.Windows.Automation.TreeScope]::Descendants,
      (New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        $optionName
      ))
    )
    if ($null -eq $option) {
      throw "Macrium mount option was not found: $optionName"
    }
    $toggle = [System.Windows.Automation.TogglePattern]$option.GetCurrentPattern(
      [System.Windows.Automation.TogglePattern]::Pattern
    )
    if ($toggle.Current.ToggleState -ne [System.Windows.Automation.ToggleState]::On) {
      $toggle.Toggle()
    }
    if ($toggle.Current.ToggleState -ne [System.Windows.Automation.ToggleState]::On) {
      throw "Macrium mount option was not enabled: $optionName"
    }
  }

  $ok = $dialog.FindFirst(
    [System.Windows.Automation.TreeScope]::Descendants,
    (New-Object System.Windows.Automation.PropertyCondition(
      [System.Windows.Automation.AutomationElement]::NameProperty,
      'OK'
    ))
  )
  if ($null -eq $ok -or -not $ok.Current.IsEnabled) {
    throw 'Macrium mount confirmation is not available.'
  }
  ([System.Windows.Automation.InvokePattern]$ok.GetCurrentPattern(
    [System.Windows.Automation.InvokePattern]::Pattern
  )).Invoke()

  $deadline = (Get-Date).AddSeconds($MountTimeoutSeconds)
  do {
    Start-Sleep -Milliseconds 250
    $mountedBaseline = Find-MountedMacriumBaseline -Drives $workerDrives
  } while ($null -eq $mountedBaseline -and (Get-Date) -lt $deadline)
  if ($null -eq $mountedBaseline) {
    throw "Macrium accepted the mount dialog, but no matching '$ExpectedVolumeLabel' volume appeared in the candidate drives ($($workerDrives -join ', ')) within $MountTimeoutSeconds seconds."
  }
  $mountEvidence = Get-MountedBaselineEvidence -MountedBaseline $mountedBaseline -DetachedDrives @($detachedDrives)
  Write-WorkerReceipt -Succeeded $true -Message 'Macrium baseline mounted.' -ImagePath $ImagePath -MountedDrive $mountedBaseline.MountedDrive -MountEvidence $mountEvidence
}

if ($Help) {
  Write-Host 'Invoke-MacriumDailyBcrBaseline.ps1 [-StartBackupIfMissing] [-ForceNewBackup] [-NewBaseline] [-CandidateDrives <list>] [-ReviewScope <CRP|BUG>] [-NoLaunchReview] [-WhatIf]'
  Write-Host '  Prepares today''s Macrium baseline for BCR, tracks metadata in registry, and validates drive candidates.'
  return
}

if (-not (Test-Path -LiteralPath $reflectPath -PathType Leaf)) {
  throw "Macrium Reflect executable was not found: $reflectPath"
}

$normalizedDrives = ConvertTo-LcmCandidateDrive -Drives $CandidateDrives

if ($NewBaseline) {
  Write-BaselineLog -Level INFO -Message "-NewBaseline specified. Dismounting any existing baseline in candidate drives ($($normalizedDrives -join ', '))..."
  $deadline = (Get-Date).AddSeconds($MountTimeoutSeconds)
  do {
    Start-Sleep -Milliseconds 250
    $remaining = @(Find-MountedMacriumBaselineCandidates -Drives $normalizedDrives)
  } while ($remaining.Count -gt 0 -and (Get-Date) -lt $deadline)
  $candidateList = @()
} else {
  $candidateList = @(Find-MountedMacriumBaselineCandidates -Drives $normalizedDrives)
  if ($candidateList.Count -gt 0) {
    $mrmTimestampStr = Get-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMTimeStamp'
    $mrmDate = [datetime]::MinValue
    $hasMrmDate = (-not [string]::IsNullOrWhiteSpace($mrmTimestampStr)) -and [datetime]::TryParse($mrmTimestampStr, [ref]$mrmDate)

    $chosen = $candidateList[0]
    foreach ($cand in $candidateList) {
      if ($null -ne $cand.NewestLogDate) {
        if ($hasMrmDate) {
          $diffDays = [math]::Abs(($cand.NewestLogDate - $mrmDate).TotalDays)
          if ($diffDays -gt 1.0) {
            Write-BaselineLog -Level WARN -Message "Candidate drive $($cand.MountedDrive) internal log timestamp ($($cand.NewestLogTimestamp)) drifts by $([math]::Round($diffDays, 1)) days from MRMTimeStamp ($mrmTimestampStr)."
          }
        }
      }
    }

    $sortedCandidates = @($candidateList | Sort-Object { if ($null -ne $_.NewestLogDate) { $_.NewestLogDate } else { [datetime]::MinValue } } -Descending)
    $chosen = $sortedCandidates[0]

    $mrPushTimestampStr = Get-LcmRegistryValue -KeyPath $LcmRootRegistryKey -Name 'MRPushTimeStamp'
    if (-not [string]::IsNullOrWhiteSpace($mrPushTimestampStr) -and $hasMrmDate) {
      $pDate = [datetime]::MinValue
      if ([datetime]::TryParse($mrPushTimestampStr, [ref]$pDate) -and $pDate -gt $mrmDate) {
        Write-Host "`n[NOTICE] Live repositories were pushed at $mrPushTimestampStr, which is newer than the mounted baseline ($mrmTimestampStr)." -ForegroundColor Yellow
        Write-Host "         You can re-run with: bcr -NewBaseline if you wish to refresh the baseline.`n" -ForegroundColor Yellow
        Write-BaselineLog -Level INFO -Message "Pushed remote state ($mrPushTimestampStr) is newer than mounted baseline ($mrmTimestampStr)."
      }
    }

    $mountedBaseline = $chosen
    if ($WhatIfPreference) {
      Write-BaselineLog -Level INFO -Message "WhatIf: would reuse writable $($mountedBaseline.MountedDrive) Macrium baseline for '$((Resolve-BaselineReviewScope))' via fast-path."
      return [pscustomobject]@{
        ImagePath = ''
        CompletionTime = $null
        MountedDrive = $mountedBaseline.MountedDrive
        ReviewScope = Resolve-BaselineReviewScope
        Profile = $null
        Launched = $false
        ReusedExistingReviewWindow = $false
        ReusedMountedBaseline = $true
        FastPath = $true
      }
    }

    Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'ActMTimeStamp' -Value $chosen.NewestLogTimestamp
    Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'actMdrive' -Value $chosen.MountedDrive

    $profileContract = if ($NoLaunchReview) { $null } else { Test-LcmBcrProfile -MountedDriveLetter $mountedBaseline.DriveLetter }
    $launchedReviewWindow = $false
    $reusedReviewWindow = $false
    if (-not $NoLaunchReview) {
      if ([string]::IsNullOrWhiteSpace($bcomparePath)) {
        throw 'Beyond Compare 5 executable was not found.'
      }
      $reviewWindows = @(Get-LcmReviewWindows)
      if ($reviewWindows.Count -gt 1) {
        throw "Multiple _LCM Folder Compare windows are open (PID(s): $($reviewWindows.Id -join ', ')); close duplicates before starting another BCR."
      }
      if ($reviewWindows.Count -eq 1) {
        $reusedReviewWindow = $true
      } else {
        Start-Process -FilePath $bcomparePath -ArgumentList @('/solo', '_LCM') | Out-Null
        $deadline = (Get-Date).AddSeconds(60)
        do {
          Start-Sleep -Milliseconds 250
          $reviewWindows = @(Get-LcmReviewWindows)
        } while ($reviewWindows.Count -eq 0 -and (Get-Date) -lt $deadline)
        if ($reviewWindows.Count -ne 1) {
          throw 'Beyond Compare did not expose exactly one _LCM Folder Compare window within 60 seconds.'
        }
        $launchedReviewWindow = $true
      }
      $reviewTitle = Set-LcmReviewWindowTitle -Window $reviewWindows[0] -Scope (Resolve-BaselineReviewScope)
      Write-BaselineLog -Level INFO -Message "Set Beyond Compare review title to '$reviewTitle'."
    }
    $windowDisposition = if ($reusedReviewWindow) { 'reused the existing _LCM review window (fast-path)' } elseif ($launchedReviewWindow) { 'opened one _LCM review window (fast-path)' } else { 'did not launch a review window' }
    Write-BaselineLog -Level INFO -Message "Reused writable $($mountedBaseline.MountedDrive) Macrium baseline for '$((Resolve-BaselineReviewScope))' via fast-path; $windowDisposition."
    return [pscustomobject]@{
      ImagePath = ''
      CompletionTime = $null
      MountedDrive = $mountedBaseline.MountedDrive
      ReviewScope = Resolve-BaselineReviewScope
      Profile = $profileContract
      Launched = $launchedReviewWindow
      ReusedExistingReviewWindow = $reusedReviewWindow
      ReusedMountedBaseline = $true
      FastPath = $true
    }
  }
}

if ($candidateList.Count -eq 0) {
  Write-BaselineLog -Level WARN -Message "No candidate volume matching '$ExpectedVolumeLabel' found in drives ($($normalizedDrives -join ', ')). Triggering ForceNewBackup..."
  $ForceNewBackup = $true
}

if ($ElevatedWorker) {
  try {
    Invoke-ElevatedBaselineWorker -ImagePath $ImagePath
    exit 0
  }
  catch {
    Write-WorkerReceipt -Succeeded $false -Message $_.Exception.Message
    exit 1
  }
}

$completedImage = if ($ForceNewBackup) { $null } else { Get-CompletedTodayImage }
if ($ForceNewBackup) {
  $completedImage = Start-MacriumBackupAndWait
} elseif ($null -eq $completedImage) {
  if (-not $StartBackupIfMissing) {
    throw 'No completed backup for today was found. Re-run with -StartBackupIfMissing to start the configured Macrium definition and poll for completion.'
  }
  $completedImage = Start-MacriumBackupAndWait -Automatic
}
if ($null -eq $completedImage) {
  return
}

$reviewIdentity = Resolve-BaselineReviewScope
if ($WhatIfPreference) {
  Write-BaselineLog -Level INFO -Message "WhatIf: would mount '$($completedImage.ImagePath)' at a Macrium-selected F:-I: drive and launch _LCM for '$reviewIdentity'."
  [pscustomobject]@{
    ImagePath = $completedImage.ImagePath
    CompletionTime = $completedImage.CompletionTime
    PlannedMountDrive = 'Macrium-selected (F:-I:)'
    ReviewScope = $reviewIdentity
    Launched = $false
  }
  return
}

Close-MountedImageReview
$receiptPath = Join-Path $env:TEMP ('{0}-{1}.json' -f $toolName, [guid]::NewGuid().ToString('N'))
try {
  $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
  $arguments = @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $PSCommandPath,
    '-ElevatedWorker',
    '-BackupDefinitionPath',
    $BackupDefinitionPath,
    '-BackupDirectory',
    $BackupDirectory,
    '-ExpectedVolumeLabel',
    $ExpectedVolumeLabel,
    '-CandidateDrives',
    ($normalizedDrives -join ';'),
    '-MountTimeoutSeconds',
    $MountTimeoutSeconds,
    '-ReceiptPath',
    $receiptPath,
    '-ImagePath',
    $completedImage.ImagePath
  )
  $worker = Start-Process -FilePath $pwshPath -ArgumentList $arguments -Verb RunAs -PassThru -Wait
  if (-not (Test-Path -LiteralPath $receiptPath)) {
    throw "The elevated Macrium worker exited with code $($worker.ExitCode) without a receipt."
  }
  $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
  if (-not $receipt.Succeeded) {
    throw "The elevated Macrium worker failed: $($receipt.Message)"
  }
}
finally {
  if (Test-Path -LiteralPath $receiptPath) {
    Remove-Item -LiteralPath $receiptPath -Force
  }
}

if (-not $NoLaunchReview) {
  if ([string]::IsNullOrWhiteSpace($bcomparePath)) {
    throw 'Beyond Compare 5 executable was not found.'
  }
  $profileContract = Test-LcmBcrProfile -MountedDriveLetter $receipt.MountedDrive.TrimEnd(':')
  Start-Process -FilePath $bcomparePath -ArgumentList @('/solo', '_LCM') | Out-Null
  $deadline = (Get-Date).AddSeconds(60)
  do {
    Start-Sleep -Milliseconds 250
    $reviewWindows = @(Get-LcmReviewWindows)
  } while ($reviewWindows.Count -eq 0 -and (Get-Date) -lt $deadline)
  if ($reviewWindows.Count -eq 0) {
    throw 'Beyond Compare did not expose the expected _LCM Folder Compare window within 60 seconds.'
  }
  $reviewTitle = Set-LcmReviewWindowTitle -Window $reviewWindows[0] -Scope $reviewIdentity
  Write-BaselineLog -Level INFO -Message "Set Beyond Compare review title to '$reviewTitle'."
}

$mountEvidence = $receipt.MountEvidence
$evidenceSummary = if ($null -eq $mountEvidence) {
  'No worker mount evidence was returned.'
} else {
  "detached=$(@($mountEvidence.DetachedDrives) -join ','); reappeared=$($mountEvidence.ReappearedDrive); snapshotSaved=$($mountEvidence.SnapshotSavedAt); goodNightObserved=$($mountEvidence.GoodNightObserved)"
}
Write-BaselineLog -Level INFO -Message "Mounted '$($completedImage.ImagePath)' at $($receipt.MountedDrive); $evidenceSummary; selected RHS review scope '$reviewIdentity' without rewriting the _LCM profile."

Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMTimeStamp' -Value ($completedImage.CompletionTime.ToString('yyyy-MM-dd HH:mm:ss'))
Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMdrive' -Value $receipt.MountedDrive

$freshCandidates = @(Find-MountedMacriumBaselineCandidates -Drives @($receipt.MountedDrive.TrimEnd(':')))
if ($freshCandidates.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($freshCandidates[0].NewestLogTimestamp)) {
  Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'ActMTimeStamp' -Value $freshCandidates[0].NewestLogTimestamp
  Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'actMdrive' -Value $freshCandidates[0].MountedDrive
}

[pscustomobject]@{
  ImagePath = $completedImage.ImagePath
  CompletionTime = $completedImage.CompletionTime
  MountedDrive = $receipt.MountedDrive
  ReviewScope = $reviewIdentity
  Profile = if ($NoLaunchReview) { $null } else { $profileContract }
  Launched = (-not $NoLaunchReview)
  MountEvidence = $mountEvidence
}
