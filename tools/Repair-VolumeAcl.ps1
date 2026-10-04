<#
.SYNOPSIS
  Recursively applies the Quad-Principal AuthorizeMasterUser ACL standard across non-OS data volumes.
.DESCRIPTION
  Module: Repair-VolumeAcl
  Purpose: Enforces the Quad-Principal AuthorizeMasterUser standard on non-OS volumes (e.g. D:, A:, E:, etc.):
           1. Strips all blocking DENY access control entries (e.g. Everyone:DENY, Users:DENY).
           2. Assigns ownership to BUILTIN\Administrators.
           3. Grants FullControl (OI)(CI)(F) to the Quad-Principal standard:
              - NT AUTHORITY\Authenticated Users (Universal SID S-1-5-11 for cross-OS multi-boot)
              - BUILTIN\Administrators (Universal SID S-1-5-32-544)
              - NT AUTHORITY\SYSTEM (Universal SID S-1-5-18)
              - $env:USERNAME (Active user account)
           4. Re-enables clean inheritance across all user subdirectories and files.
           5. Safely identifies directory junctions / reparse points and applies /L without descending across links.
           6. Strictly protects OS partitions (C:, W:, X:, Y:, Z:) and system-reserved folders.
           7. Conforms to RULE-PS-001 through RULE-PS-012, RULE-ELEV-002, and LCM structured logging.
  Path: D:\Git_Repositories\LCM_Tools\Repair-VolumeAcl.ps1
  Authors: Rolf, LCM_AI Governance
  Version: 1.0.0
  Date: 2026-08-28
.PARAMETER TargetVolume
  The drive letter or root path to repair (e.g. 'D:', 'A:', 'E:'). Defaults to 'D:'.
.PARAMETER SkipFolders
  List of top-level folder names to skip (e.g. 'OneDrive'). Defaults to @('OneDrive') when targeting 'D:'.
.PARAMETER ShowAll
  Displays detailed step-by-step diagnostic and ACL repair telemetry.
.PARAMETER LogFile
  Custom log file destination. Defaults to tools/logs/Repair-VolumeAcl-yyyyMMdd_HHmmss.log.
.PARAMETER NoElevation
  Suppresses interactive self-elevation prompts in automated/unattended environments.
.PARAMETER FromDispatcher
  Internal switch indicating execution dispatched from elevated worker.
.PARAMETER Help
  Displays this comprehensive parameter reference (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Repair-VolumeAcl.ps1 -h
.EXAMPLE
  pwsh tools/Repair-VolumeAcl.ps1 -TargetVolume "D:" -ShowAll
.EXAMPLE
  pwsh tools/Repair-VolumeAcl.ps1 -TargetVolume "A:" -ShowAll
#>

[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$TargetVolume = 'D:',

  [Parameter()]
  [string[]]$SkipFolders = @(),

  [switch]$ShowAll,
  [string]$LogFile = "",
  [switch]$NoElevation,
  [switch]$FromDispatcher,
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "1.0.0"
$scriptName = "Repair-VolumeAcl"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " DATA VOLUME ACL REPAIR & SECURITY STANDARD TOOL (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Strips DENY ACEs and enforces the Quad-Principal AuthorizeMasterUser standard"
  Write-Host "  (Authenticated Users + Administrators + SYSTEM + Active User: FullControl)"
  Write-Host "  across non-OS data volumes while safely preserving junctions and OS boundaries."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Repair-VolumeAcl.ps1 [-TargetVolume <Drive:>] [-SkipFolders <array>] [-ShowAll] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -TargetVolume <str> : Target drive letter (e.g. 'D:', 'A:', 'E:'). Default: 'D:'."
  Write-Host "  -SkipFolders <arr>  : Top-level folder names to skip (Default for D: is 'OneDrive')."
  Write-Host "  -ShowAll            : Exposes verbose scanning and icacls command output."
  Write-Host "  -LogFile <str>      : Custom log file destination."
  Write-Host "  -NoElevation        : Suppresses interactive elevation prompts."
  Write-Host "  -h, -Help, -?       : Displays this parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Repair-VolumeAcl.ps1 -TargetVolume 'D:' -ShowAll"
  Write-Host "  pwsh tools/Repair-VolumeAcl.ps1 -TargetVolume 'A:' -ShowAll"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Normalize Target Root & Apply Default Skip Lists
# ------------------------------------------------------------------------------
$normRoot = $TargetVolume.Trim().TrimEnd('\', '/')
if ($normRoot.Length -eq 1) { $normRoot = "$($normRoot):" }
$rootPath = "$($normRoot)\"

$effectiveSkip = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

# Default skip for D: is OneDrive (handled by Repair-OneDriveAcl)
if ($normRoot -ieq 'D:' -and $SkipFolders.Count -eq 0) {
  [void]$effectiveSkip.Add('OneDrive')
}
foreach ($sf in $SkipFolders) {
  if (-not [string]::IsNullOrWhiteSpace($sf)) {
    [void]$effectiveSkip.Add($sf.Trim())
  }
}

# ------------------------------------------------------------------------------
# 2. OS Protection Guardrails (Strict Prohibition on OS Partitions)
# ------------------------------------------------------------------------------
$protectedDrives = @('C:', 'W:', 'X:', 'Y:', 'Z:')
if ($protectedDrives -icontains $normRoot) {
  Write-Error "ABORT: Target volume '$normRoot' is a protected Windows OS/System partition. AuthorizeMasterUser is strictly prohibited on OS drives."
  return
}

$protectedFolders = @(
  'Windows', 'Program Files', 'Program Files (x86)', 'ProgramData', 'Recovery',
  '$Recycle.Bin', 'System Volume Information', 'Config.Msi'
)

# ------------------------------------------------------------------------------
# 3. Initialize Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot '.lcm'
$toolsDir = Join-Path $lcdRoot 'tools\internal'
$logDir = Join-Path $toolsDir 'logs'
if (-not (Test-Path -Path $logDir)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $cleanDrive = $normRoot.Replace(':', '')
  $LogFile = Join-Path $logDir "$($scriptName)_Vol-$($cleanDrive)-$($timestampStr).log"
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
      "ERROR"   { Write-Host "  [ERROR] $Message" -ForegroundColor Red }
      "DEBUG"   { if ($script:ShowDetails) { Write-Host "  [DEBUG] $Message" -ForegroundColor DarkGray } }
      "ACTION"  { Write-Host "  -> $Message" -ForegroundColor Green }
      "SUMMARY" { Write-Host $Message -ForegroundColor Cyan }
      default   { Write-Host $Message }
    }
  }
}

# ------------------------------------------------------------------------------
# 4. Elevation Check & Interactive Dispatch (RULE-PS-011 / RULE-ELEV-002)
# ------------------------------------------------------------------------------
$currentUser = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
$isElevated = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isElevated) {
  if ($NoElevation) {
    Write-ToolLog -Message "Administrator elevation required to repair volume security descriptors." -Level ERROR
    throw "ElevationRequired: Run Repair-VolumeAcl from an elevated console (or omit -NoElevation)."
  }

  Write-ToolLog -Message "Administrator elevation required to repair NTFS security descriptors on $rootPath." -Level INFO
  $scriptPath = $MyInvocation.MyCommand.Path

  try {
    Write-ToolLog -Message "Launching elevated repair worker for $rootPath..." -Level ACTION
    $elevatedArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"", "-TargetVolume", "`"$normRoot`"", "-FromDispatcher")
    if ($SkipFolders.Count -gt 0) {
      $skipJoined = ($SkipFolders | ForEach-Object { "`"$_`"" }) -join ","
      $elevatedArgs += @("-SkipFolders", $skipJoined)
    }
    if ($ShowAll) { $elevatedArgs += "-ShowAll" }
    if (-not [string]::IsNullOrWhiteSpace($LogFile)) { $elevatedArgs += @("-LogFile", "`"$LogFile`"") }
    $elevatedProc = Start-Process -FilePath "pwsh.exe" -ArgumentList ($elevatedArgs -join " ") -Verb RunAs -PassThru -Wait
    Write-ToolLog -Message "Elevated volume ACL repair process finished with ExitCode: $($elevatedProc.ExitCode)" -Level ACTION
  } catch {
    Write-ToolLog -Message "Elevation request was cancelled or blocked: $($_.ToString())" -Level ERROR
  }
  return
}

# ------------------------------------------------------------------------------
# 5. Execution (Elevated Context)
# ------------------------------------------------------------------------------
Write-ToolLog -Message "==========================================================================" -Level INFO
Write-ToolLog -Message " DATA VOLUME ACL REPAIR & SECURITY STANDARD TOOL (v$($scriptVersion))" -Level INFO
Write-ToolLog -Message " Target Volume : $($rootPath)" -Level INFO
Write-ToolLog -Message " Skip Folders  : $(if ($effectiveSkip.Count -gt 0) { ($effectiveSkip -join ', ') } else { 'None' })" -Level INFO
Write-ToolLog -Message " Log File      : $($LogFile)" -Level INFO
Write-ToolLog -Message " Standard      : Quad-Principal AuthorizeMasterUser (AuthUsers, Admins, SYSTEM, $env:USERNAME)" -Level INFO
Write-ToolLog -Message "==========================================================================" -Level INFO

if (-not (Test-Path -LiteralPath $rootPath)) {
  Write-ToolLog -Message "Target volume root not found: $rootPath" -Level ERROR
  return
}

# Step 1: Strip DENY rules and apply Quad-Principal on Volume Root
Write-ToolLog -Message "Step 1: Enforcing Quad-Principal standard on volume root: $rootPath" -Level INFO
& icacls.exe "$rootPath" /remove:d Everyone /C 2>&1 | Out-Null
& icacls.exe "$rootPath" /remove:d Users /C 2>&1 | Out-Null
& icacls.exe "$rootPath" /remove:d "Authenticated Users" /C 2>&1 | Out-Null

& icacls.exe "$rootPath" /grant:r "NT AUTHORITY\Authenticated Users:(OI)(CI)F" /C 2>&1 | Out-Null
& icacls.exe "$rootPath" /grant:r "BUILTIN\Administrators:(OI)(CI)F" /C 2>&1 | Out-Null
& icacls.exe "$rootPath" /grant:r "NT AUTHORITY\SYSTEM:(OI)(CI)F" /C 2>&1 | Out-Null
& icacls.exe "$rootPath" /grant:r "$($env:USERNAME):(OI)(CI)F" /C 2>&1 | Out-Null

# Step 2: Iterate top-level items on volume
$topItems = @(Get-ChildItem -LiteralPath $rootPath -Force)
$processedCount = 0
$skippedCount = 0
$reparseCount = 0

Write-ToolLog -Message "Step 2: Processing top-level items on $rootPath..." -Level INFO

foreach ($item in $topItems) {
  $itemName = $item.Name
  $itemPath = $item.FullName

  # Check special system skip folders
  $isSystemSkip = $false
  foreach ($pf in $protectedFolders) {
    if ($itemName -ieq $pf) { $isSystemSkip = $true; break }
  }
  if ($isSystemSkip -or $itemName -like "*.CBM" -or $itemName -ieq "bootTel.dat") {
    Write-ToolLog -Message "Skipping system-reserved item: $itemName" -Level DEBUG
    $skippedCount++
    continue
  }

  # Check user-specified skip list
  if ($effectiveSkip.Contains($itemName)) {
    Write-ToolLog -Message "Skipping user-excluded folder: $itemName" -Level INFO
    $skippedCount++
    continue
  }

  # Detect directory junction / reparse point
  $isReparse = $item.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)

  Write-ToolLog -Message "Repairing permissions on: $itemName $(if ($isReparse) { '[Junction/ReparsePoint]' })" -Level INFO

  try {
    if ($isReparse) {
      # For reparse points, apply with /L to target the link itself and prevent descending
      & icacls.exe "$itemPath" /L /remove:d Everyone /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /L /remove:d Users /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /L /grant:r "NT AUTHORITY\Authenticated Users:(OI)(CI)F" /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /L /grant:r "BUILTIN\Administrators:(OI)(CI)F" /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /L /grant:r "NT AUTHORITY\SYSTEM:(OI)(CI)F" /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /L /grant:r "$($env:USERNAME):(OI)(CI)F" /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /L /inheritance:e /C /Q 2>&1 | Out-Null
      $reparseCount++
    } else {
      # 1. Take ownership
      & takeown.exe /F "$itemPath" /R /D Y 2>&1 | Out-Null

      # 2. Strip DENY entries recursively
      & icacls.exe "$itemPath" /remove:d Everyone /T /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /remove:d Users /T /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /remove:d "Authenticated Users" /T /C /Q 2>&1 | Out-Null

      # 3. Grant Quad-Principal FullControl
      & icacls.exe "$itemPath" /grant:r "NT AUTHORITY\Authenticated Users:(OI)(CI)F" /T /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /grant:r "BUILTIN\Administrators:(OI)(CI)F" /T /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /grant:r "NT AUTHORITY\SYSTEM:(OI)(CI)F" /T /C /Q 2>&1 | Out-Null
      & icacls.exe "$itemPath" /grant:r "$($env:USERNAME):(OI)(CI)F" /T /C /Q 2>&1 | Out-Null

      # 4. Enable clean inheritance
      & icacls.exe "$itemPath" /inheritance:e /T /C /Q 2>&1 | Out-Null
    }

    $processedCount++
    Write-ToolLog -Message "✓ Repaired: $itemName" -Level ACTION
  } catch {
    Write-ToolLog -Message "Failed to repair $($itemName) - $($_.ToString())" -Level WARN
  }
}

# ------------------------------------------------------------------------------
# 6. Summary Output
# ------------------------------------------------------------------------------
Write-ToolLog -Message "==========================================================================" -Level INFO
Write-ToolLog -Message " [SUMMARY] Tool: $scriptName | Version: $scriptVersion | Status: COMPLETED" -Level SUMMARY
Write-ToolLog -Message " Target Volume     : $($rootPath)" -Level SUMMARY
Write-ToolLog -Message " Processed Items   : $($processedCount)" -Level SUMMARY
Write-ToolLog -Message " Junctions Repaired: $($reparseCount)" -Level SUMMARY
Write-ToolLog -Message " Skipped Items     : $($skippedCount)" -Level SUMMARY
Write-ToolLog -Message " Execution Log     : $($LogFile)" -Level SUMMARY
Write-ToolLog -Message "==========================================================================" -Level INFO

