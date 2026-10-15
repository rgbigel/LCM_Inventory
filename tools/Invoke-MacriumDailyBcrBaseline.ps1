<#
.SYNOPSIS
  Prepares today's Macrium image as the writable Beyond Compare baseline.
.DESCRIPTION
  Module: tools/Invoke-MacriumDailyBcrBaseline.ps1
  Purpose: Finds today's completed Macrium image, optionally starts the configured
  definition when today's image is absent, clears only known F:-I: image mounts,
  mounts D: as F: with the required GUI options, and opens the operator-owned
  _LCM Beyond Compare profile.
  Path: LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-15
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
  [ValidateNotNullOrEmpty()]
  [string]$BackupDefinitionPath = 'D:\OneDrive\Documents\Reflect\@B_D4P3+4-WDB850-AD.xml',

  [ValidateNotNullOrEmpty()]
  [string]$BackupDirectory = 'B:\Backups\D4P3+4-WDB850-AD',

  [ValidateNotNullOrEmpty()]
  [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D',

  [ValidateSet('F', 'G', 'H', 'I', IgnoreCase = $true)]
  [string]$MountDriveLetter = 'F',

  [ValidateRange(1, 240)]
  [int]$PollSeconds = 60,

  [ValidateRange(1, 1440)]
  [int]$TimeoutMinutes = 240,

  [string]$ReviewScope = '',

  [switch]$StartBackupIfMissing,

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
$workspaceRoot = Split-Path $inventoryRoot -Parent
$logDirectory = Join-Path $inventoryRoot 'logs'
$reflectPath = 'C:\Program Files\Macrium\Reflect\Reflect.exe'
$bcompareCandidates = @(
  'C:\Program Files\Beyond Compare 5\BCompare.exe',
  'D:\Tools\Beyond Compare 5\BCompare.exe'
)
$bcomparePath = @($bcompareCandidates | Where-Object { Test-Path -LiteralPath $_ })[0]

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
    [string]$MountedDrive = ''
  )

  if ([string]::IsNullOrWhiteSpace($ReceiptPath)) {
    return
  }
  [pscustomobject]@{
    Succeeded = $Succeeded
    Message = $Message
    ImagePath = $ImagePath
    MountedDrive = $MountedDrive
    Timestamp = (Get-Date).ToString('o')
  } | ConvertTo-Json | Set-Content -LiteralPath $ReceiptPath -Encoding utf8
}

function Get-CompletedTodayImage {
  $reportDirectory = 'C:\ProgramData\Macrium\Reflect'
  if (-not (Test-Path -LiteralPath $reportDirectory)) {
    throw "Macrium report directory was not found: $reportDirectory"
  }
  if (-not (Test-Path -LiteralPath $BackupDirectory)) {
    throw "Macrium backup directory was not found: $BackupDirectory"
  }

  $today = (Get-Date).Date
  $reports = @(Get-ChildItem -LiteralPath $reportDirectory -Filter '*.html' -File |
    Where-Object { $_.LastWriteTime.Date -eq $today } |
    Sort-Object LastWriteTime -Descending)
  foreach ($report in $reports) {
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

function Resolve-BaselineReviewScope {
  if (-not [string]::IsNullOrWhiteSpace($ReviewScope)) {
    return $ReviewScope
  }

  $proposalLedger = Join-Path $inventoryRoot 'data\proposals\proposals.json'
  if (-not (Test-Path -LiteralPath $proposalLedger)) {
    return 'BCR-BASELINE-DUMMY'
  }
  $ledger = Get-Content -LiteralPath $proposalLedger -Raw | ConvertFrom-Json
  $activeProposals = @($ledger.proposals | Where-Object {
    $_.state -in @('in_progress', 'in_review', 'approved', 'verified')
  } | Sort-Object updated_at -Descending)
  if ($activeProposals.Count -eq 0) {
    return 'BCR-BASELINE-DUMMY'
  }
  return $activeProposals[0].crp_id
}

function Close-MountedImageReview {
  $sessions = @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowTitle -and
    $_.MainWindowTitle.StartsWith('_LCM - Folder Compare', [System.StringComparison]::OrdinalIgnoreCase)
  })
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
    $remaining = @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue | Where-Object {
      $_.MainWindowTitle -and
      $_.MainWindowTitle.StartsWith('_LCM - Folder Compare', [System.StringComparison]::OrdinalIgnoreCase)
    })
  } while ($remaining.Count -gt 0 -and (Get-Date) -lt $deadline)

  if ($remaining.Count -gt 0) {
    throw "The _LCM Beyond Compare session remained open (PID(s): $($remaining.Id -join ', ')); mounted-image cleanup was not attempted."
  }
}

function Test-LcmBcrProfile {
  $sessionRegistryPath = Join-Path $env:APPDATA 'Scooter Software\Beyond Compare 5\BCSessions.xml'
  if (-not (Test-Path -LiteralPath $sessionRegistryPath -PathType Leaf)) {
    throw "Beyond Compare session registry was not found: $sessionRegistryPath"
  }

  [xml]$sessionRegistry = Get-Content -LiteralPath $sessionRegistryPath
  $session = $sessionRegistry.SelectSingleNode("//TDirCompareSession[@Value='_LCM']")
  if ($null -eq $session) {
    throw 'The required _LCM Beyond Compare profile was not found.'
  }

  $expectedLeftPath = "$MountDriveLetter`:\Git_Repositories"
  $leftPath = $session.SelectSingleNode('./Specs/Left').GetAttribute('Value')
  $rightPath = $session.SelectSingleNode('./Specs/Right').GetAttribute('Value')
  $contentComparison = $session.SelectSingleNode('./Rules/UseContentComparison').GetAttribute('Value')
  $directoryHandling = $session.SelectSingleNode('./State/DirHandling').GetAttribute('Value')
  $nameFilter = $session.SelectSingleNode('./Filters/NameFilter').GetAttribute('Value')
  $readOnlyNodes = @($session.SelectNodes('.//*[@NoEdit]') | Where-Object {
    $_.GetAttribute('NoEdit') -eq 'True'
  })

  if ($leftPath -ne $expectedLeftPath -or $rightPath -ne 'D:\Git_Repositories') {
    throw "The _LCM profile paths are '$leftPath' and '$rightPath', not '$expectedLeftPath' and 'D:\Git_Repositories'."
  }
  if ($contentComparison -ne 'True') {
    throw 'The _LCM profile does not require content comparison.'
  }
  if ($directoryHandling -ne 'dirCompareFilesOnly') {
    throw "The _LCM profile directory handling is '$directoryHandling', not 'dirCompareFilesOnly'."
  }
  if ($nameFilter -notmatch '(?i)\.git\\hooks') {
    throw 'The _LCM profile does not preserve the required .git\hooks inclusion.'
  }
  if ($readOnlyNodes.Count -gt 0) {
    throw 'The _LCM profile contains a NoEdit=True setting and would not leave the LHS writable.'
  }

  return [pscustomobject]@{
    Name = '_LCM'
    LeftPath = $leftPath
    RightPath = $rightPath
    ContentComparison = $contentComparison
    DirectoryHandling = $directoryHandling
  }
}

function Invoke-ElevatedBaselineWorker {
  param(
    [Parameter(Mandatory)]
    [string]$ImagePath
  )

  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LcmMacriumMouse
{
  [DllImport("user32.dll")]
  public static extern bool SetCursorPos(int x, int y);

  [DllImport("user32.dll")]
  public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
}
'@

  $mountedDrives = @(
    foreach ($letter in 'F', 'G', 'H', 'I') {
      $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
      if ($null -ne $disk -and $disk.DriveType -eq 3 -and $disk.VolumeName -eq $ExpectedVolumeLabel) {
        $letter
      }
    }
  )
  foreach ($letter in $mountedDrives) {
    & $reflectPath $letter '-u'
    if ($LASTEXITCODE -ne 0) {
      throw "Macrium detach failed for ${letter}: with exit code $LASTEXITCODE."
    }
    $deadline = (Get-Date).AddSeconds(30)
    do {
      Start-Sleep -Milliseconds 250
      $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
    } while ($null -ne $disk -and (Get-Date) -lt $deadline)
    if ($null -ne $disk) {
      throw "Macrium did not detach ${letter}: within 30 seconds."
    }
  }

  if (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$MountDriveLetter`:'" -ErrorAction SilentlyContinue) {
    throw "The requested mount letter ${MountDriveLetter}: is assigned after cleanup."
  }

  $existingReflectBinIds = @(Get-Process -Name 'ReflectBin' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
  Start-Process -FilePath $reflectPath -ArgumentList @($ImagePath, '-b') | Out-Null
  $deadline = (Get-Date).AddSeconds(30)
  $dialog = $null
  while ((Get-Date) -lt $deadline -and $null -eq $dialog) {
    $newReflectBinIds = @(Get-Process -Name 'ReflectBin' -ErrorAction SilentlyContinue |
      Where-Object { $_.Id -notin $existingReflectBinIds } |
      Select-Object -ExpandProperty Id)
    foreach ($processId in $newReflectBinIds) {
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
    throw 'Macrium Browse Image dialog did not become ready within 30 seconds.'
  }

  $bounds = $dialog.Current.BoundingRectangle
  [LcmMacriumMouse]::SetCursorPos([int]($bounds.Left + 37), [int]($bounds.Top + 236)) | Out-Null
  [LcmMacriumMouse]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  [LcmMacriumMouse]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 250

  $expectedDriveName = "$MountDriveLetter`:"
  $assignedDrive = $dialog.FindFirst(
    [System.Windows.Automation.TreeScope]::Descendants,
    (New-Object System.Windows.Automation.PropertyCondition(
      [System.Windows.Automation.AutomationElement]::NameProperty,
      $expectedDriveName
    ))
  )
  if ($null -eq $assignedDrive) {
    throw "Macrium did not propose the required ${MountDriveLetter}: assignment. No alternate letter was accepted."
  }

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

  $deadline = (Get-Date).AddSeconds(30)
  do {
    Start-Sleep -Milliseconds 250
    $mounted = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$MountDriveLetter`:'" -ErrorAction SilentlyContinue
  } while ($null -eq $mounted -and (Get-Date) -lt $deadline)
  if ($null -eq $mounted) {
    throw "Macrium accepted the mount dialog, but ${MountDriveLetter}: did not appear within 30 seconds."
  }
  if ($mounted.VolumeName -ne $ExpectedVolumeLabel) {
    throw "Mounted ${MountDriveLetter}: label '$($mounted.VolumeName)' does not match '$ExpectedVolumeLabel'."
  }
  $workspacePath = "$MountDriveLetter`:\Git_Repositories"
  if (-not (Test-Path -LiteralPath $workspacePath -PathType Container)) {
    throw "Mounted ${MountDriveLetter}: does not contain the expected Git_Repositories root."
  }
  Write-WorkerReceipt -Succeeded $true -Message 'Macrium baseline mounted.' -ImagePath $ImagePath -MountedDrive "$MountDriveLetter`:"
}

if ($Help) {
  Write-Host 'Invoke-MacriumDailyBcrBaseline.ps1 [-StartBackupIfMissing] [-ReviewScope <CRP|BUG>] [-NoLaunchReview] [-WhatIf]'
  Write-Host '  Prepares today''s Macrium D: image at F: and opens the unchanged _LCM profile.'
  return
}

if (-not (Test-Path -LiteralPath $reflectPath -PathType Leaf)) {
  throw "Macrium Reflect executable was not found: $reflectPath"
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

$completedImage = Get-CompletedTodayImage
if ($null -eq $completedImage) {
  if (-not $StartBackupIfMissing) {
    throw 'No completed backup for today was found. Re-run with -StartBackupIfMissing to start the configured Macrium definition and poll for completion.'
  }
  if (-not $PSCmdlet.ShouldProcess($BackupDefinitionPath, 'Start the configured Macrium backup definition')) {
    Write-BaselineLog -Level INFO -Message 'WhatIf: would start the configured backup definition and wait for today''s completed Macrium report.'
    return
  }
  Write-BaselineLog -Level INFO -Message "Starting configured Macrium definition '$BackupDefinitionPath'."
  Start-Process -FilePath $reflectPath -ArgumentList @('-e', $BackupDefinitionPath) | Out-Null
  $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
  do {
    Start-Sleep -Seconds $PollSeconds
    $completedImage = Get-CompletedTodayImage
  } while ($null -eq $completedImage -and (Get-Date) -lt $deadline)
  if ($null -eq $completedImage) {
    throw "No completed Macrium backup for today was found within $TimeoutMinutes minute(s)."
  }
}

$reviewIdentity = Resolve-BaselineReviewScope
if (-not $PSCmdlet.ShouldProcess(
    "$($completedImage.ImagePath) -> ${MountDriveLetter}:",
    'Close _LCM, detach matching F:-I: image mounts, and mount the current Macrium baseline'
  )) {
  Write-BaselineLog -Level INFO -Message "WhatIf: would mount '$($completedImage.ImagePath)' at ${MountDriveLetter}: and launch _LCM for '$reviewIdentity'."
  [pscustomobject]@{
    ImagePath = $completedImage.ImagePath
    CompletionTime = $completedImage.CompletionTime
    PlannedMountDrive = "$MountDriveLetter`:"
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
    '-MountDriveLetter',
    $MountDriveLetter,
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
  $profileContract = Test-LcmBcrProfile
  Start-Process -FilePath $bcomparePath -ArgumentList @('/solo', '_LCM') | Out-Null
  $deadline = (Get-Date).AddSeconds(15)
  do {
    Start-Sleep -Milliseconds 250
    $reviewWindows = @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue | Where-Object {
      $_.MainWindowTitle -and
      $_.MainWindowTitle.StartsWith('_LCM - Folder Compare', [System.StringComparison]::OrdinalIgnoreCase)
    })
  } while ($reviewWindows.Count -eq 0 -and (Get-Date) -lt $deadline)
  if ($reviewWindows.Count -eq 0) {
    throw 'Beyond Compare did not expose the expected _LCM Folder Compare window.'
  }
}

Write-BaselineLog -Level INFO -Message "Mounted '$($completedImage.ImagePath)' at ${MountDriveLetter}:; selected RHS review scope '$reviewIdentity' without rewriting the _LCM profile."
[pscustomobject]@{
  ImagePath = $completedImage.ImagePath
  CompletionTime = $completedImage.CompletionTime
  MountedDrive = "$MountDriveLetter`:"
  ReviewScope = $reviewIdentity
  Profile = if ($NoLaunchReview) { $null } else { $profileContract }
  Launched = (-not $NoLaunchReview)
}
