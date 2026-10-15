<#
.SYNOPSIS
  Displays or explicitly detaches a Macrium Reflect mounted image drive.

.DESCRIPTION
  A temporary operator-review probe for CRP-277. Without -Execute, it only
  validates the requested drive and prints the documented Macrium command.
  Detachment requires both -Execute and PowerShell confirmation.

.PARAMETER DriveLetter
  Mounted image drive letter to inspect or detach. Allowed values are F through
  I because all other drive letters are reserved. Defaults to F.

.PARAMETER Execute
  Allows the documented Reflect.exe detach command to be invoked.

.PARAMETER ExpectedVolumeLabel
  Required label of the mounted Macrium image. Defaults to D4P3-WDB850-D.

.PARAMETER BCompareSessionName
  Saved Beyond Compare profile that compares the mounted image. Its active
  Folder Compare window is closed before detach when -Execute is supplied.

.EXAMPLE
  pwsh -File Invoke-MacriumImageDetachProbe.ps1 -DriveLetter F

.EXAMPLE
  pwsh -File Invoke-MacriumImageDetachProbe.ps1 -DriveLetter F -Execute
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
  [ValidateSet('F', 'G', 'H', 'I', IgnoreCase = $true)]
  [string]$DriveLetter = 'F',

  [ValidateNotNullOrEmpty()]
  [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D',

  [ValidateNotNullOrEmpty()]
  [string]$BCompareSessionName = '_LCM',

  [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$reflectPath = 'C:\Program Files\Macrium\Reflect\Reflect.exe'
if (-not (Test-Path -LiteralPath $reflectPath -PathType Leaf)) {
  throw "Macrium Reflect executable was not found: $reflectPath"
}

$normalizedDrive = $DriveLetter.ToUpperInvariant()
$driveRoot = "$normalizedDrive`:\"
$logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$normalizedDrive`:'"
if ($null -eq $logicalDisk) {
  throw "Drive '$normalizedDrive`:' is not mounted."
}
if ($logicalDisk.DriveType -ne 3) {
  throw "Drive '$normalizedDrive`:' is not a local mounted volume."
}
if ($logicalDisk.VolumeName -ne $ExpectedVolumeLabel) {
  throw "Drive '$normalizedDrive`:' has volume label '$($logicalDisk.VolumeName)', not the required Macrium image label '$ExpectedVolumeLabel'."
}

$plannedCommand = "`"$reflectPath`" $normalizedDrive -u"
$result = [PSCustomObject]@{
  DriveLetter = "$normalizedDrive`:"
  DriveRoot = $driveRoot
  VolumeName = $logicalDisk.VolumeName
  FileSystem = $logicalDisk.FileSystem
  DriveType = $logicalDisk.DriveType
  PlannedCommand = $plannedCommand
  Executed = $false
}

if (-not $Execute) {
  Write-Host "Dry-run only. No Macrium action was invoked." -ForegroundColor Yellow
  $result
  return
}

$openBcompareProcesses = @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue)
$mountedImageCompareProcesses = @($openBcompareProcesses | Where-Object {
  $_.MainWindowTitle -and
  $_.MainWindowTitle.StartsWith("$BCompareSessionName - Folder Compare", [System.StringComparison]::OrdinalIgnoreCase)
})
foreach ($bcompareProcess in $mountedImageCompareProcesses) {
  if (-not $PSCmdlet.ShouldProcess(
      "Beyond Compare PID $($bcompareProcess.Id)",
      "Close mounted-image profile '$BCompareSessionName' before detaching $normalizedDrive`:"
    )) {
    throw "Closing the mounted-image Beyond Compare session was not confirmed."
  }
  if (-not $bcompareProcess.CloseMainWindow()) {
    throw "Beyond Compare PID $($bcompareProcess.Id) did not accept a graceful close request."
  }
}

if ($mountedImageCompareProcesses.Count -gt 0) {
  $deadline = (Get-Date).AddSeconds(15)
  do {
    Start-Sleep -Milliseconds 250
    $remainingMountedImageSessions = @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue | Where-Object {
      $_.MainWindowTitle -and
      $_.MainWindowTitle.StartsWith("$BCompareSessionName - Folder Compare", [System.StringComparison]::OrdinalIgnoreCase)
    })
  } while ($remainingMountedImageSessions.Count -gt 0 -and (Get-Date) -lt $deadline)

  if ($remainingMountedImageSessions.Count -gt 0) {
    $processIds = $remainingMountedImageSessions.Id -join ', '
    throw "Mounted-image Beyond Compare session '$BCompareSessionName' remained open (PID(s): $processIds); detach was not attempted."
  }
}

if (-not $PSCmdlet.ShouldProcess(
    "$normalizedDrive`: ($($logicalDisk.VolumeName))",
    "Detach mounted Macrium image with $plannedCommand"
  )) {
  Write-Host "Macrium image detach was not confirmed." -ForegroundColor Yellow
  $result
  return
}

& $reflectPath $normalizedDrive '-u'
if ($LASTEXITCODE -ne 0) {
  throw "Macrium Reflect detach command failed with exit code $LASTEXITCODE."
}

$result.Executed = $true
$result
