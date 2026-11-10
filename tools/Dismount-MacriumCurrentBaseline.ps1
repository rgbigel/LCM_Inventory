<#
.SYNOPSIS
  Detaches the current Macrium BCR baseline from F: through I:.
.DESCRIPTION
  Detaches only local volumes with the expected Macrium volume label and waits
  until each targeted drive letter is unavailable.
  Path: LCM_Inventory/tools/Dismount-MacriumCurrentBaseline.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.3
  Date: 2026-11-10 20:30:00
.NOTES
  Elevated Operations:
    - Dismount-MacriumBaseline: Detaches baseline candidate drive via elevated worker or daemon.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [ValidateSet('F', 'G', 'H', 'I', '')]
  [string]$DriveLetter = '',

  [ValidateNotNullOrEmpty()]
  [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D',

  [ValidateRange(30, 600)]
  [int]$DetachTimeoutSeconds = 120,

  [switch]$ConfirmDetach,

  [switch]$Force,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Approved elevated operations for this tool (RULE-ELEV-007)
New-Variable -Name ElevatedOperations -Value ([string[]]@('Dismount-MacriumBaseline')) -Option ReadOnly -Scope Script -Force

if ($Help) {
  Write-Host 'Dismount-MacriumCurrentBaseline.ps1 [-DriveLetter <F|G|H|I>] [-ConfirmDetach] [-Force] [-h]'
  Write-Host '  Detaches only the expected Macrium BCR baseline. -ConfirmDetach is required.'
  Write-Host '  -Force: Bypasses the modification check if uncommitted baseline changes exist.'
  return
}
if (-not $ConfirmDetach -and -not $WhatIfPreference) {
  throw 'Detaching a writable Macrium baseline requires explicit -ConfirmDetach.'
}

if (-not [string]::IsNullOrWhiteSpace($DriveLetter)) {
  $DriveLetter = $DriveLetter.TrimEnd(':')
}

# In-script elevation self-governance (RULE-ELEV-005)
$isAdmin = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  $lcmCmd = Join-Path (Split-Path $PSScriptRoot -Parent) 'Cmd\lcm.cmd'
  if (Test-Path -LiteralPath $lcmCmd) {
    Write-Verbose "Standard user context detected. Delegating to elevated daemon via $lcmCmd..."
    $delegatedArgs = @('do', 'DismountMacriumBaseline')
    if (-not [string]::IsNullOrWhiteSpace($DriveLetter)) { $delegatedArgs += @('-DriveLetter', $DriveLetter) }
    if ($ConfirmDetach) { $delegatedArgs += '-ConfirmDetach' }
    if ($Force) { $delegatedArgs += '-Force' }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedVolumeLabel)) { $delegatedArgs += @('-ExpectedVolumeLabel', $ExpectedVolumeLabel) }
    & $lcmCmd @delegatedArgs
    exit $LASTEXITCODE
  }
}

# Baseline Modification Detection & Interactive Choice Guardrail (RULE-REV-013)
$letters = if ([string]::IsNullOrWhiteSpace($DriveLetter)) { @('F', 'G', 'H', 'I') } else { @($DriveLetter) }
$atomsModule = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LcmMacriumAtoms.psm1'
if (Test-Path -LiteralPath $atomsModule) {
  Import-Module -Name $atomsModule -Force
  $modCheck = Test-LcmBaselineModifications -CandidateDrives $letters -ExpectedVolumeLabel $ExpectedVolumeLabel
  if ($modCheck.HasModifications) {
    if ($Force) {
      Write-Warning "[RULE-REV-013] Baseline modifications detected on mounted volume ($($modCheck.TotalModifiedFiles) file(s)), proceeding with dismount due to -Force."
    } elseif ([Environment]::UserInteractive) {
      Write-Host '======================================================================' -ForegroundColor Yellow
      Write-Host ' [RULE-REV-013 WARNING] Baseline Drive Contains Modified Content!' -ForegroundColor Yellow
      Write-Host '======================================================================' -ForegroundColor Yellow
      foreach ($mr in $modCheck.ModifiedRepositories) {
        Write-Host " - $($mr.RepositoryName) on $($mr.DriveLetter): ($($mr.Count) modified/untracked file(s))" -ForegroundColor Yellow
      }
      Write-Host ''
      Write-Host 'Dismounting will PERMANENTLY DISCARD these review markers or sandbox modifications!' -ForegroundColor Red
      Write-Host '======================================================================' -ForegroundColor Yellow

      $caption = 'Baseline Modifications Detected (RULE-REV-013)'
      $message = 'Do you want to discard these baseline modifications and proceed with dismounting?'
      $choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
        [System.Management.Automation.Host.ChoiceDescription]::new('&Yes', 'Discard modifications and dismount volume'),
        [System.Management.Automation.Host.ChoiceDescription]::new('&No', 'Cancel dismount to preserve modifications')
      )
      $selected = $host.UI.PromptForChoice($caption, $message, $choices, 1)
      if ($selected -ne 0) {
        Write-Host '[RULE-REV-013] Dismount cancelled by operator to preserve baseline content.' -ForegroundColor Cyan
        return
      }
    } else {
      throw "[RULE-REV-013] Baseline drive contains $($modCheck.TotalModifiedFiles) modified/untracked file(s). Specify -Force to discard modifications and dismount."
    }
  }
}

$reflectPath = 'C:\Program Files\Macrium\Reflect\Reflect.exe'
if (-not (Test-Path -LiteralPath $reflectPath -PathType Leaf)) {
  throw "Macrium Reflect executable was not found: $reflectPath"
}

$letters = if ([string]::IsNullOrWhiteSpace($DriveLetter)) { @('F', 'G', 'H', 'I') } else { @($DriveLetter) }
$detached = [System.Collections.Generic.List[string]]::new()
foreach ($letter in $letters) {
  $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
  if ($null -eq $disk -or $disk.DriveType -ne 3 -or $disk.VolumeName -ne $ExpectedVolumeLabel) {
    continue
  }

  if ($WhatIfPreference) {
    Write-Host "WhatIf: would detach ${letter}: with expected label '$ExpectedVolumeLabel'."
    continue
  }

  Write-Verbose "Detaching $letter`: with expected label '$ExpectedVolumeLabel'."
  & $reflectPath "$letter`:" '-u'
  $detachExitCode = if (Test-Path variable:global:LASTEXITCODE) { $global:LASTEXITCODE } else { 0 }
  if ($detachExitCode -ne 0) {
    throw "Macrium detach failed for ${letter}: with exit code $detachExitCode."
  }

  $deadline = (Get-Date).AddSeconds($DetachTimeoutSeconds)
  do {
    Start-Sleep -Milliseconds 250
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$letter`:'" -ErrorAction SilentlyContinue
  } while ($null -ne $disk -and (Get-Date) -lt $deadline)
  if ($null -ne $disk) {
    throw "Macrium did not detach ${letter}: within $DetachTimeoutSeconds seconds."
  }
  $detached.Add("$letter`:")
}

if ($detached.Count -eq 0) {
  if ($WhatIfPreference) {
    return
  }
  throw "No '$ExpectedVolumeLabel' Macrium baseline was mounted in $($letters -join ', ')."
}

[pscustomobject]@{
  DetachedDrives = @($detached)
  ExpectedVolumeLabel = $ExpectedVolumeLabel
  ConfirmedUnavailable = $true
}
