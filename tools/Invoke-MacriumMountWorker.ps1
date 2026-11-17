<#
.SYNOPSIS
  Elevated atom: mounts one completed Macrium image as the writable BCR baseline (CRP-343).
.DESCRIPTION
  Module: tools/Invoke-MacriumMountWorker.ps1
  Purpose: The only elevated step of the BCR baseline workflow: detach a stale baseline volume,
           start Reflect.exe -b <image>, complete the Browse Image dialog (AHK atom, UI Automation
           fallback), verify the mounted workspace and write the receipt. Nothing else (no backup,
           no review window, no registry write) runs here.
  Path: LCM_Inventory/tools/Invoke-MacriumMountWorker.ps1
  Authors: Rolf, Claude
  Version: 10.7.4
  Date: 2026-11-17
  Rule: RULE-ELEV-001, RULE-ELEV-007, RULE-PS-025
  Implementation Choices (CRP-343): extracted unchanged from Invoke-MacriumDailyBcrBaseline.ps1
           (Invoke-ElevatedBaselineWorker, -ElevatedWorker mode) so elevation is confined to this
           process; shared discovery helpers come from modules/LcmMacriumAtoms.psm1. Registered as an
           elevated intent of an admin tool; dispatched by Mount-MacriumLatestBaseline.ps1 (admin tool)
           through the DO daemon.
.PARAMETER ImagePath
  Full path of the completed .mrimgx image to mount.
.PARAMETER CandidateDrives
  Candidate drive letters, e.g. 'F;G;H;I'.
.PARAMETER ExpectedVolumeLabel
  Volume label of the baseline partition.
.PARAMETER MountTimeoutSeconds
  Timeout for the mount dialog and drive appearance.
.PARAMETER ReceiptPath
  JSON receipt written for the caller (Succeeded, Message, MountedDrive, MountEvidence).
.NOTES
  Caveats: needs elevation (Macrium mount) and the interactive Session 1 desktop (dialog).
  Exit code 0 = mounted, 1 = failed (receipt says why).
#>
[CmdletBinding()]
param(
  [string]$ImagePath = '',
  [string]$CandidateDrives = 'F;G;H;I',
  [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D',
  [ValidateRange(30, 600)]
  [int]$MountTimeoutSeconds = 120,
  [string]$ReceiptPath = '',
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Invoke-MacriumMountWorker.ps1 -ImagePath <mrimgx> [-CandidateDrives F;G;H;I] [-ExpectedVolumeLabel <label>] [-MountTimeoutSeconds <n>] [-ReceiptPath <json>] [-h]'
  Write-Host '  Elevated atom (CRP-343): mounts one Macrium image as the BCR baseline; called by Mount-MacriumLatestBaseline.ps1.'
  return
}

$toolName = Split-Path $PSCommandPath -LeafBase
$inventoryRoot = Split-Path $PSScriptRoot -Parent
$logDirectory = Join-Path $inventoryRoot 'logs'
$reflectPath = 'C:\Program Files\Macrium\Reflect\Reflect.exe'
Import-Module -Name (Join-Path $inventoryRoot 'modules\LcmMacriumAtoms.psm1') -Force
$ahkModulePath = Join-Path $inventoryRoot 'modules\LcmAhkAtoms.psm1'
if (Test-Path -LiteralPath $ahkModulePath -PathType Leaf) {
  Import-Module -Name $ahkModulePath -Force -ErrorAction SilentlyContinue
}
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

  $workerDrives = ConvertTo-LcmCandidateDrives -Drives $CandidateDrives
  $detachedDrives = [System.Collections.Generic.List[string]]::new()
  $busyDrives = [System.Collections.Generic.List[string]]::new()
  foreach ($letter in $workerDrives) {
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
    if ($null -eq $disk) {
      continue
    }
    if ($disk.DriveType -ne 3 -or $disk.VolumeName -ne $ExpectedVolumeLabel) {
      continue
    }
    Write-BaselineLog -Level INFO -Message "Detaching existing volume at ${letter}: before mounting '$ImagePath'."
    $detachProcess = Start-Process -FilePath $reflectPath -ArgumentList @("$letter`:", '-u') -PassThru -Wait
    $detachExitCode = if (Test-Path variable:global:LASTEXITCODE) {
      if ($null -ne $detachProcess -and $null -ne $detachProcess.ExitCode) {
        $detachProcess.ExitCode
      } else {
        $global:LASTEXITCODE
      }
    } else {
      if ($null -ne $detachProcess -and $null -ne $detachProcess.ExitCode) { $detachProcess.ExitCode } else { 0 }
    }
    $deadline = (Get-Date).AddSeconds([Math]::Min(15, $MountTimeoutSeconds))
    do {
      Start-Sleep -Milliseconds 250
      $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
    } while ($null -ne $disk -and (Get-Date) -lt $deadline)
    if ($null -ne $disk -or $detachExitCode -ne 0) {
      Write-BaselineLog -Level WARN -Message "Drive ${letter}: could not be detached (likely open in other applications, exitCode=$detachExitCode). Retaining ${letter}: and falling back to alternative candidate drive."
      $busyDrives.Add("$letter`:")
    } else {
      $detachedDrives.Add("$letter`:")
    }
  }

  # Verify that at least one candidate drive is available for mounting
  $availableCandidateLetters = [System.Collections.Generic.List[string]]::new()
  foreach ($letter in $workerDrives) {
    if ("$letter`:" -in $busyDrives) {
      continue
    }
    $existingDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
    if ($null -eq $existingDisk) {
      $availableCandidateLetters.Add($letter)
    }
  }
  if ($availableCandidateLetters.Count -eq 0 -and $busyDrives.Count -gt 0) {
    throw "All candidate drives ($($workerDrives -join ', ')) are in use, and busy baseline drive(s) ($($busyDrives -join ', ')) could not be detached."
  }
  if ($busyDrives.Count -gt 0) {
    Write-BaselineLog -Level INFO -Message "Fallback drive candidate(s) available for mounting: $($availableCandidateLetters -join ', '). Proceeding with mount."
  }

  $ahkAutomationScript = Join-Path $inventoryRoot 'tools\automation\Mount-MacriumBrowseDialog.ahk'
  $ahkHandled = $false

  Start-Process -FilePath $reflectPath -ArgumentList @('-b', $ImagePath) | Out-Null

  if ((Test-Path -LiteralPath $ahkAutomationScript -PathType Leaf) -and (Get-Command -Name 'Invoke-LcmAhkScript' -ErrorAction SilentlyContinue)) {
    Write-BaselineLog -Level INFO -Message 'Macrium Reflect Browse Image launched. Delegating dialog interaction to AHK atom.'
    try {
      $ahkResult = Invoke-LcmAhkScript -ScriptPath $ahkAutomationScript -ArgumentList @([string]$MountTimeoutSeconds) -TimeoutSeconds ($MountTimeoutSeconds + 5)
      
      # Log structured AHK output lines
      if (-not [string]::IsNullOrWhiteSpace($ahkResult.Output)) {
        foreach ($line in ($ahkResult.Output -split "`r?`n")) {
          if (-not [string]::IsNullOrWhiteSpace($line)) {
            Write-BaselineLog -Level INFO -Message "[AHK] $line"
          }
        }
      }

      $outputContainsSuccess = $ahkResult.Output -match 'STATUS:\s*SUCCESS'
      $outputContainsRestricted = $ahkResult.Output -match 'STEP_RESTRICTED_FOLDERS:\s*(?:CHECKED|CLICKED)'
      $outputContainsWritable = $ahkResult.Output -match 'STEP_WRITABLE:\s*(?:CHECKED|CLICKED)'
      $outputContainsPartition = $ahkResult.Output -match 'STEP_PARTITION_SELECT:\s*(?:CHECKED|CLICKED)'
      $allBoxesChecked = $outputContainsRestricted -and $outputContainsWritable -and $outputContainsPartition

      if ($ahkResult.Succeeded -and $outputContainsSuccess -and $allBoxesChecked) {
        Write-BaselineLog -Level INFO -Message 'AHK atom verified: all checkboxes set (Restricted, Writable, Partition) and OK button clicked successfully.'
        $ahkHandled = $true
      } else {
        $failedReason = if (-not $allBoxesChecked) {
          "Not all required checkboxes were confirmed checked (Restricted: $outputContainsRestricted, Writable: $outputContainsWritable, Partition: $outputContainsPartition)"
        } elseif (-not $outputContainsSuccess) {
          "AHK output did not signal STATUS: SUCCESS"
        } else {
          "AHK exited with code $($ahkResult.ExitCode)"
        }
        throw "AHK automation atom failed: $failedReason. Error: $($ahkResult.Error). Output: $($ahkResult.Output)"
      }
    } catch {
      throw "AHK automation atom failed: $($_.Exception.Message)"
    }
  }

  if (-not $ahkHandled) {
    # Resilient UI Automation Fallback (only used when AHK atom is not installed)
    # candidateProcessIds tracked for BUG-299 process enumeration
    $candidateProcessIds = @(Get-Process -Name 'ReflectBin' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
    if ($candidateProcessIds.Count -gt 0) {
      Write-BaselineLog -Level INFO -Message "Enumerated existing ReflectBin process PID(s): $($candidateProcessIds -join ', ')."
    }
    $deadline = (Get-Date).AddSeconds($MountTimeoutSeconds)
    $dialog = $null
    while ((Get-Date) -lt $deadline -and $null -eq $dialog) {
      $root = [System.Windows.Automation.AutomationElement]::RootElement
      $topWindows = @($root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition))
      foreach ($w in $topWindows) {
        $chk = $w.FindFirst(
          [System.Windows.Automation.TreeScope]::Descendants,
          (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty,
            'Enable access to restricted folders'
          ))
        )
        if ($null -ne $chk) {
          $dialog = $w
          break
        }
      }
      if ($null -eq $dialog) {
        Start-Sleep -Milliseconds 250
      }
    }
    if ($null -eq $dialog) {
      throw "Macrium Browse Image dialog did not become ready within $MountTimeoutSeconds seconds."
    }

    $part = $dialog.FindFirst(
      [System.Windows.Automation.TreeScope]::Descendants,
      (New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        'D4P3-WDB850-D (D:)'
      ))
    )
    if ($null -ne $part) {
      $pRect = $part.Current.BoundingRectangle
      [LcmMacriumMouse]::SetCursorPos([int]($pRect.Left + 12), [int]($pRect.Top + ($pRect.Height / 2))) | Out-Null
    } else {
      $bounds = $dialog.Current.BoundingRectangle
      [LcmMacriumMouse]::SetCursorPos([int]($bounds.Left + 37), [int]($bounds.Top + 236)) | Out-Null
    }
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
  }

  $deadline = (Get-Date).AddSeconds($MountTimeoutSeconds)
  do {
    Start-Sleep -Milliseconds 250
    $mountedBaseline = Find-MountedMacriumBaseline -Drives $workerDrives -ExcludeDrives $busyDrives -ExpectedVolumeLabel $ExpectedVolumeLabel
  } while ($null -eq $mountedBaseline -and (Get-Date) -lt $deadline)
  if ($null -eq $mountedBaseline) {
    throw "Macrium accepted the mount dialog, but no matching '$ExpectedVolumeLabel' volume appeared in the candidate drives ($($workerDrives -join ', ')) within $MountTimeoutSeconds seconds."
  }
  $mountEvidence = Get-MountedBaselineEvidence -MountedBaseline $mountedBaseline -DetachedDrives @($detachedDrives)
  Write-WorkerReceipt -Succeeded $true -Message 'Macrium baseline mounted.' -ImagePath $ImagePath -MountedDrive $mountedBaseline.MountedDrive -MountEvidence $mountEvidence
}

try {
  if ([string]::IsNullOrWhiteSpace($ImagePath)) {
    throw 'Parameter -ImagePath is required.'
  }
  Invoke-ElevatedBaselineWorker -ImagePath $ImagePath
  exit 0
}
catch {
  Write-BaselineLog -Level ERROR -Message $_.Exception.Message
  Write-WorkerReceipt -Succeeded $false -Message $_.Exception.Message
  exit 1
}