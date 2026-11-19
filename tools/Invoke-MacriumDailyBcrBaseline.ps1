<#
.SYNOPSIS
  Prepares today's Macrium image as the writable Beyond Compare baseline with AutoHotkey (AHK) automation.
.DESCRIPTION
  Module: tools/Invoke-MacriumDailyBcrBaseline.ps1
  Purpose: Finds today's completed Macrium image, optionally starts the configured
  definition when today's image is absent, verifies and unmounts only known baseline candidates,
  mounts D: within candidate drive letters with AutoHotkey (AHK) UI automation for restricted folders
  and temporary write permissions, and opens the operator-owned _LCM Beyond Compare profile.
  Reuses an existing mounted baseline by default unless -NewBaseline is set.
  Implementation Choices (CRP-346 revision): the review window record is matched by start time as an instant
  (Test-LcmSameProcessStart); before, the JSON date conversion made it never match.
  Implementation Choices (CRP-307 / CRP-308): Uses dynamic CandidateDrives evaluation instead of hardcoded
  drive ranges; persists baseline telemetry in registry (MRMdrive, MRMTimeStamp, actMdrive, ActMTimeStamp);
  reuses existing healthy baseline to eliminate redundant unmount/remount cycles.
  Implementation Choices (BUG-341): baseline currency is decided by the mounted image identity
  (registry MRMImagePath equals today's completed image and MRMdrive equals the candidate drive);
  the newest lcm-internal log date inside the image is only the fallback heuristic. Before, an image
  whose internal logs predate its completion by more than 36 h was judged stale on every call and
  remounted again (6 remounts for one cohort BCR on 2026-11-16).
  Path: LCM_Inventory/tools/Invoke-MacriumDailyBcrBaseline.ps1
  Authors: Rolf, LCM_AI Engine, Claude
  Implementation Choices (CRP-346): BCR records the review window it starts (process ID, start time, handle,
  mounted drive) in scratch/BC_Review/review-window.json and tags only that window. A later run - also after
  a remount of a newer image on the same drive - refreshes its _LCM tab through the registered AHK tab atom
  instead of launching; a new window is launched only when no reusable window or no _LCM tab exists. Windows
  started before CRP-346 are adopted when exactly one window shows the _LCM tab.
  Version: 10.2.10
  Date: 2026-11-19
  Implementation Choices (BUG-367): the directory handling of the _LCM profile (e.g. dirShowAll) is the operator's view
  choice; it is logged, never enforced (operator 2026-11-19). Left path, right path and content comparison stay checked.
.NOTES
  Caveats: Drive mounting requires administrative elevation (delegated to elevated worker via Invoke-ElevatedTest.ps1
  or Port 9876 daemon); Macrium Reflect UI automation requires Session 1 interactive desktop access. Mount operations
  time out after MountTimeoutSeconds (default: 120s).
  BUG-341: the identity check trusts the registry written by this tool's own mount; an image mounted
  manually on the same drive letter outside this tool is not detected (use -NewBaseline).
  Elevated Operations:
    - Set-LcmRegistryValue: Persists baseline telemetry to HKLM:\SOFTWARE\LCM\MacriumBaseline.
    - Mount-MacriumBaseline: Mounts completed Macrium backup image via elevated worker or daemon.
    - Dismount-MacriumBaseline: Detaches baseline candidate drive via elevated worker or daemon.
.PARAMETER BackupDefinitionPath
  Path to the Macrium Reflect XML backup definition file to monitor or execute.
.PARAMETER BackupDirectory
  Directory containing the completed Macrium .mrimgx backup images.
.PARAMETER ExpectedVolumeLabel
  Expected volume label for the mounted baseline partition (default: D4P3-WDB850-D).
.PARAMETER CandidateDrives
  List or delimited string of acceptable drive letters for mounting (length >= 1).
.PARAMETER PollSeconds
  Polling interval in seconds when awaiting Macrium backup completion.
.PARAMETER TimeoutMinutes
  Maximum wait time in minutes before timing out an in-progress Macrium backup.
.PARAMETER MountTimeoutSeconds
  Timeout in seconds for drive mount dialog interaction and volume appearance.
.PARAMETER ReviewScope
  Active CRP or BUG identifier to associate with the Beyond Compare window title.
.PARAMETER StartBackupIfMissing
  Automatically initiates the configured backup definition if today's image is not found.
.PARAMETER ForceNewBackup
  Forces execution of a fresh Macrium backup definition regardless of same-day images.
.PARAMETER NewBaseline
  Forces unmounting existing baselines and mounting a new Macrium image (fast-path is default).
.PARAMETER NoLaunchReview
  Mounts the baseline image and sets registry telemetry without opening Beyond Compare.
.PARAMETER ElevatedWorker
  Internal switch executed under administrative elevation to perform drive mounting.
.PARAMETER ReceiptPath
  Temporary JSON receipt path used by the elevated worker process.
.PARAMETER ImagePath
  Explicit path to the .mrimgx image to mount when executing as the elevated worker.
.PARAMETER Confirm
  Suppresses confirmation dialogs or provides explicit approval for baseline operations.
.PARAMETER Help
  Displays comprehensive usage instructions, parameter references, and copy-paste examples.
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

  [Parameter(Mandatory = $false, HelpMessage = 'Suppresses confirmation dialogs')]
  [switch]$Confirm,

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

# Shared Macrium discovery helpers and DO client (CRP-343)
Import-Module -Name (Join-Path $inventoryRoot 'modules\LcmMacriumAtoms.psm1') -Force
Import-Module -Name (Join-Path $inventoryRoot 'modules\LcmDoClient.psm1') -Force

$ahkModulePath = Join-Path $inventoryRoot 'modules\LcmAhkAtoms.psm1'
if (Test-Path -LiteralPath $ahkModulePath -PathType Leaf) {
  Import-Module -Name $ahkModulePath -Force -ErrorAction SilentlyContinue
}

# Approved elevated operations for this tool (RULE-ELEV-007)
New-Variable -Name ElevatedOperations -Value ([string[]]@(
  'Set-LcmRegistryValue',
  'Mount-MacriumBaseline',
  'Dismount-MacriumBaseline'
)) -Option ReadOnly -Scope Script -Force

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

  $deadline = (Get-Date).AddSeconds(5)
  do {
    [void][LcmBcrWindowTitle]::SetWindowText($Window.MainWindowHandle, $title)
    Start-Sleep -Milliseconds 250
    $Window.Refresh()
  } while ($Window.MainWindowTitle -ne $title -and (Get-Date) -lt $deadline)

  if ($Window.MainWindowTitle -ne $title -and -not [string]::IsNullOrWhiteSpace($Window.MainWindowTitle)) {
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
    if ([string]::IsNullOrWhiteSpace($content) -or $content -notmatch [regex]::Escape($BackupDefinitionPath)) {
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

  # Legitimacy validation (RULE-ELEV-007)
  $isLcmKey = $KeyPath -match '^(?i)HKLM:\\SOFTWARE\\LCM(?:\\[^\\]+)*$' -or
              $KeyPath -match '^(?i)HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment$'
  if (-not $isLcmKey) {
    throw "Registry write rejected: '$KeyPath' is outside legitimate LCM namespaces (RULE-ELEV-007)."
  }

  # Skip write if registry already holds this exact value
  $currentVal = Get-LcmRegistryValue -KeyPath $KeyPath -Name $Name
  if ($null -ne $currentVal -and [string]$currentVal -eq [string]$Value) {
    return
  }

  # Check if current process is elevated
  $isElevated = $false
  try {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
    $isElevated = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch {}

  if ($isElevated) {
    try {
      if (-not (Test-Path -LiteralPath $KeyPath)) {
        New-Item -Path $KeyPath -Force | Out-Null
      }
      Set-ItemProperty -Path $KeyPath -Name $Name -Value $Value -Type $PropertyType -Force | Out-Null
      Write-BaselineLog -Level INFO -Message "Registry updated (in-process elevated): $KeyPath\$Name = '$Value'"
      return
    } catch {
      Write-BaselineLog -Level WARN -Message "Failed to write registry $KeyPath\${Name}: $($_.Exception.Message)"
      return
    }
  }

  # Un-elevated execution: Verify operation is in immutable allowlist
  if ('Set-LcmRegistryValue' -notin $script:ElevatedOperations) {
    throw "Operation 'Set-LcmRegistryValue' is not in the approved `$ElevatedOperations allowlist for this tool."
  }

  # Atomic delegation to Port 9876 Elevated Desktop Daemon
  $daemonPort = if ($env:LCM_DAEMON_PORT -match '^\d+$') { [int]$env:LCM_DAEMON_PORT } else { 9876 }
  $daemonUrl = "http://127.0.0.1:$daemonPort/execute"
  try {
    # CRP-343: the write runs in the registered elevated atom Set-LcmMachineRegistry.ps1 (admin tool),
    # authenticated with the daemon key (LcmDoClient.psm1); an inline command is never elevated.
    $registryAtom = Join-Path $PSScriptRoot 'Set-LcmMachineRegistry.ps1'
    $regCmd = "& pwsh -NoProfile -ExecutionPolicy Bypass -File '$registryAtom' -KeyPath '$KeyPath' -Name '$Name' -Value '$Value' -PropertyType '$PropertyType'"
    Write-Verbose ('Registry atom via daemon {0}' -f $daemonUrl)
    $res = Invoke-LcmDaemonCommand -Command $regCmd -Sync -Elevated -TimeoutSeconds 30
    if ($res.status -in @('COMPLETED', 'DISPATCHED') -or $res.exitCode -eq 0) {
      Write-BaselineLog -Level INFO -Message "Registry updated (atomic daemon delegation): $KeyPath\$Name = '$Value'"
      return
    }
    Write-BaselineLog -Level WARN -Message "Atomic elevation delegation failed for $KeyPath\${Name}: $($res.stderr)"
  } catch {
    Write-BaselineLog -Level WARN -Message "Atomic elevation delegation unreachable for $KeyPath\${Name}: $($_.Exception.Message)"
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

function ConvertTo-LcmCandidateDrives {
  param([object]$Drives)
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
Set-Alias -Name Normalize-LcmCandidateDrives -Value ConvertTo-LcmCandidateDrives
Set-Alias -Name ConvertTo-LcmCandidateDrive -Value ConvertTo-LcmCandidateDrives

# Find-MountedMacriumBaselineCandidates: moved (CRP-343) - shared helper in modules/LcmMacriumAtoms.psm1

# Find-MountedMacriumBaseline: moved (CRP-343) - shared helper in modules/LcmMacriumAtoms.psm1

function Get-LcmReviewWindows {
  return @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowTitle -and
    ($_.MainWindowTitle -match '^_LCM\*?\s*-\s*Folder Compare')
  })
}

# CRP-346: BCR owns the review window it starts. The record identifies it by process ID, process start time and
# window handle (not by title, which shows only the active tab); the mounted drive is the compare root of the
# _LCM session (F:\Git_Repositories against D:\Git_Repositories); the folder focused below the roots is irrelevant.
$script:ReviewWindowRecordPath = Join-Path $PSScriptRoot '..\scratch\BC_Review\review-window.json'

function Save-LcmReviewWindowRecord {
  param(
    [Parameter(Mandatory = $true)] [System.Diagnostics.Process]$Window,
    [Parameter(Mandatory = $true)] [string]$MountedDrive,
    [string]$Scope = ''
  )
  $record = [ordered]@{
    ProcessId    = $Window.Id
    StartTime    = $Window.StartTime.ToString('o')
    Handle       = [int64]$Window.MainWindowHandle
    MountedDrive = $MountedDrive.TrimEnd(':').ToUpperInvariant() + ':'
    ReviewScope  = $Scope
    RecordedAt   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  }
  $dir = Split-Path $script:ReviewWindowRecordPath -Parent
  if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
  $record | ConvertTo-Json | Set-Content -LiteralPath $script:ReviewWindowRecordPath -Encoding UTF8
}

function Test-LcmSameProcessStart {
  # CRP-346: ConvertFrom-Json returns the recorded ISO start time as a DateTime; [string] cut it to seconds, so the
  # record never matched and reuse depended on the active-tab fallback. Compare both as instants (UTC, 1 ms).
  param([Parameter(Mandatory = $true)] $Recorded, [Parameter(Mandatory = $true)] [datetime]$Actual)
  try {
    $recordedUtc = if ($Recorded -is [datetime]) { ([datetime]$Recorded).ToUniversalTime() } else { [datetimeoffset]::Parse([string]$Recorded, [Globalization.CultureInfo]::InvariantCulture).UtcDateTime }
  } catch {
    return $false
  }
  return [math]::Abs(($recordedUtc - $Actual.ToUniversalTime()).TotalMilliseconds) -lt 1
}

function Find-LcmReusableReviewWindow {
  param([Parameter(Mandatory = $true)] [string]$MountedDrive)
  $drive = $MountedDrive.TrimEnd(':').ToUpperInvariant() + ':'
  if (Test-Path -LiteralPath $script:ReviewWindowRecordPath) {
    try {
      $record = Get-Content -LiteralPath $script:ReviewWindowRecordPath -Raw | ConvertFrom-Json
      $window = Get-Process -Id ([int]$record.ProcessId) -ErrorAction SilentlyContinue
      if ($null -ne $window -and $window.ProcessName -eq 'BCompare' -and $window.MainWindowHandle -ne 0 -and
          (Test-LcmSameProcessStart -Recorded $record.StartTime -Actual $window.StartTime)) {
        if ([string]$record.MountedDrive -eq $drive) { return $window }
        Write-BaselineLog -Level INFO -Message "Recorded review window (PID $($window.Id)) compares $($record.MountedDrive), not $drive; a new window is needed."
        return $null
      }
    } catch {
      Write-BaselineLog -Level WARN -Message "Review window record unreadable ($($_.Exception.Message)); falling back to title search."
    }
  }
  # Windows started before CRP-346 have no record: adopt exactly one window whose active tab is _LCM.
  $legacy = @(Get-LcmReviewWindows)
  if ($legacy.Count -eq 1) { return $legacy[0] }
  return $null
}

function Invoke-LcmReviewWindowRefresh {
  param([Parameter(Mandatory = $true)] [System.Diagnostics.Process]$Window)
  try {
    Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmAhkAtoms.psm1') -Force
    $result = Invoke-LcmAhkAtom -Intent 'select-beyondcomparetab' -ArgumentList @([string][int64]$Window.MainWindowHandle, 'refresh', '_LCM') -TimeoutSeconds 30
    foreach ($line in @(([string]$result.Output) -split "`r?`n" | Where-Object { $_ })) { Write-BaselineLog -Level INFO -Message "[AHK] $line" }
    # CRP-346: 0 refreshed, 3 no _LCM tab (launch allowed); anything else is a failure that must not cause a relaunch.
    return $(if ($result.ExitCode -eq 0) { 'Refreshed' } elseif ($result.ExitCode -eq 3) { 'NoLcmTab' } else { 'Failed' })
  } catch {
    Write-BaselineLog -Level WARN -Message "Tab refresh atom failed ($($_.Exception.Message))."
    return 'Failed'
  }
}

function Open-LcmReviewWindow {
  param(
    [Parameter(Mandatory = $true)] [string]$BComparePath,
    [Parameter(Mandatory = $true)] [string]$MountedDrive,
    [string]$Scope = ''
  )
  $existing = Find-LcmReusableReviewWindow -MountedDrive $MountedDrive
  if ($null -ne $existing) {
    $refreshStatus = Invoke-LcmReviewWindowRefresh -Window $existing
    if ($refreshStatus -eq 'Failed') {
      Write-BaselineLog -Level WARN -Message "Could not refresh the review window (PID $($existing.Id)); no new window is launched. Press Ctrl+F5 (Full Refresh) in its _LCM tab."
      return [pscustomobject]@{ Launched = $false; Reused = $true }
    }
    if ($refreshStatus -eq 'Refreshed') {
      $existing.Refresh()
      Save-LcmReviewWindowRecord -Window $existing -MountedDrive $MountedDrive -Scope $Scope
      $reviewTitle = Set-LcmReviewWindowTitle -Window $existing -Scope $Scope
      Write-BaselineLog -Level INFO -Message "Refreshed the _LCM tab of the existing review window (PID $($existing.Id)) instead of launching; title '$reviewTitle'."
      return [pscustomobject]@{ Launched = $false; Reused = $true }
    }
    Write-BaselineLog -Level INFO -Message "Existing review window (PID $($existing.Id)) has no _LCM tab; launching a new review window."
  }
  $before = @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
  Start-LcmBCompareProcess -BComparePath $BComparePath -Arguments @('/solo', '_LCM')
  $deadline = (Get-Date).AddSeconds(60)
  $window = $null
  do {
    Start-Sleep -Milliseconds 250
    $window = @(Get-Process -Name 'BCompare' -ErrorAction SilentlyContinue | Where-Object { $_.Id -notin $before -and $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match '^_LCM' }) | Select-Object -First 1
  } while ($null -eq $window -and (Get-Date) -lt $deadline)
  if ($null -ne $window) {
    Save-LcmReviewWindowRecord -Window $window -MountedDrive $MountedDrive -Scope $Scope
    $reviewTitle = Set-LcmReviewWindowTitle -Window $window -Scope $Scope
    Write-BaselineLog -Level INFO -Message "Set Beyond Compare review title to '$reviewTitle' (own window, PID $($window.Id))."
  } else {
    Write-BaselineLog -Level INFO -Message 'Beyond Compare launched; the new window did not appear within 60 s, so it was not recorded or tagged.'
  }
  return [pscustomobject]@{ Launched = $true; Reused = $false }
}

function Start-LcmBCompareProcess {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BComparePath,
    [string[]]$Arguments = @('/solo', '_LCM')
  )

  # RULE-DSP-007 / RULE-PS-008: Always dispatch BCompare to Session 1 via Desktop Daemon
  # This guarantees the GUI opens on the interactive desktop without elevated token poisoning.
  $daemonUrl = 'http://127.0.0.1:9876/execute'
  $argListArray = @($Arguments | ForEach-Object { "'$_'" }) -join ', '
  $dispatchedViaDaemon = $false

  try {
    $ping = Invoke-RestMethod -Uri 'http://127.0.0.1:9876/ping' -TimeoutSec 1 -ErrorAction Stop
    if ($ping.status -eq 'ONLINE') {
      $body = @{
        command  = "Start-Process -FilePath `"$BComparePath`" -ArgumentList @($argListArray)"
        elevated = $false
        sync     = $false
      } | ConvertTo-Json
      $resp = Invoke-RestMethod -Uri $daemonUrl -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 5 -ErrorAction Stop
      if ($resp.status -eq 'DISPATCHED') {
        $dispatchedViaDaemon = $true
        Write-BaselineLog -Level INFO -Message 'Dispatched Beyond Compare 5 to Session 1 via Desktop Daemon.'
      }
    }
  } catch {
    Write-BaselineLog -Level WARN -Message "Desktop Daemon dispatch unavailable ($($_.Exception.Message)); falling back to local Start-Process."
  }

  if (-not $dispatchedViaDaemon) {
    Start-Process -FilePath $BComparePath -ArgumentList $Arguments | Out-Null
  }
}

function Remove-OrphanedBCompareProcesses {
  # RULE-REV-012 Window Non-Interference: Automated tools must not kill initializing or existing BCompare instances.
}

# Get-MountedBaselineEvidence: moved (CRP-343) - shared helper in modules/LcmMacriumAtoms.psm1

function Close-MountedImageReview {
  # RULE-REV-012: Non-interference with operator BC windows. Do not forcefully close operator sessions.
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
    $leftDrive = ($leftPath -split ':')[0].Trim().ToUpperInvariant()
    if ($leftDrive -in @('F', 'G', 'H', 'I')) {
      $session.SelectSingleNode('./Specs/Left').SetAttribute('Value', $expectedLeftPath)
      $sessionRegistry.Save($sessionRegistryPath)
      Write-BaselineLog -Level INFO -Message "Synchronized _LCM Beyond Compare profile left path from '$leftPath' to '$expectedLeftPath'."
      $leftPath = $expectedLeftPath
    } else {
      throw "The _LCM Beyond Compare profile specifies left path '$leftPath'; expected '$expectedLeftPath'."
    }
  }
  if ($rightPath -ne 'D:\Git_Repositories') {
    throw "The _LCM Beyond Compare profile specifies right path '$rightPath'; expected 'D:\Git_Repositories'."
  }
  if ($contentComparison -ne 'True') {
    throw "The _LCM Beyond Compare profile requires content comparison enabled; actual value is '$contentComparison'."
  }
  # BUG-367: directory handling is the operator's view choice; reported, never enforced.
  if ($null -ne $directoryHandlingNode -and $directoryHandling -ne 'dirCompareFilesOnly') {
    Write-BaselineLog -Level INFO -Message "_LCM Beyond Compare profile directory handling is '$directoryHandling' (operator choice, BUG-367)."
  }

  return [pscustomobject]@{
    Name = '_LCM'
    LeftPath = $leftPath
    RightPath = $rightPath
    ContentComparison = ($contentComparison -eq 'True')
    DirectoryHandling = $directoryHandling
  }
}

# Invoke-ElevatedBaselineWorker: moved (CRP-343) - now the elevated atom tools/Invoke-MacriumMountWorker.ps1

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " MACRIUM DAILY BCR BASELINE MOUNT & VALIDATOR ENGINE" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Prepares today's Macrium Reflect backup as the writable Beyond Compare baseline,"
  Write-Host "  validates candidate drive labels, tracks host registry telemetry, and opens _LCM."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Invoke-MacriumDailyBcrBaseline.ps1 [-CandidateDrives <list>] [-NewBaseline] [-ForceNewBackup] [-StartBackupIfMissing] [-ReviewScope <CRP|BUG>] [-NoLaunchReview] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -CandidateDrives <list>   : List/delimited string of drive letters to check (Default: F;G;H;I)."
  Write-Host "  -NewBaseline              : Forces unmounting and preparing a fresh mount (Fast-path is default)."
  Write-Host "  -ForceNewBackup           : Forces starting a new Macrium backup even if one exists today."
  Write-Host "  -StartBackupIfMissing     : Automatically starts backup if no completed report exists today."
  Write-Host "  -ExpectedVolumeLabel <str>: Expected volume label on candidate drives (Default: D4P3-WDB850-D)."
  Write-Host "  -BackupDefinitionPath <str>: Path to Macrium XML backup definition."
  Write-Host "  -BackupDirectory <str>    : Path to backup storage folder containing .mrimgx files."
  Write-Host "  -ReviewScope <CRP|BUG>    : Proposal identifier to stamp into Beyond Compare title."
  Write-Host "  -NoLaunchReview           : Mounts baseline and records registry without opening Beyond Compare."
  Write-Host "  -MountTimeoutSeconds <int>: Timeout in seconds for drive mount operations (Default: 120)."
  Write-Host "  -h, -Help, -?             : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

if (-not (Test-Path -LiteralPath $reflectPath -PathType Leaf)) {
  throw "Macrium Reflect executable was not found: $reflectPath"
}

$normalizedDrives = ConvertTo-LcmCandidateDrives -Drives $CandidateDrives

# 1. Resolve today's completed backup image upfront (RULE-REV-012)
$completedToday = if ($ForceNewBackup) { $null } else { Get-CompletedTodayImage }

$reuseCandidate = $null
if ($NewBaseline) {
  Write-BaselineLog -Level INFO -Message "-NewBaseline specified. Will detach existing baseline and mount fresh image via elevated worker."
  $candidateList = @()
} else {
  $candidateList = @(Find-MountedMacriumBaselineCandidates -Drives $normalizedDrives -ExpectedVolumeLabel $ExpectedVolumeLabel)
  if ($candidateList.Count -gt 0) {
    $sortedCandidates = @($candidateList | Sort-Object { if ($null -ne $_.NewestLogDate) { $_.NewestLogDate } else { [datetime]::MinValue } } -Descending)
    $chosen = $sortedCandidates[0]

    # Verify baseline currency against today's backup
    $isCandidateCurrent = $false
    # BUG-341: the mounted image identity decides currency; the newest internal log date is only a fallback.
    $mountedImagePath = [string](Get-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMImagePath')
    $mountedImageDrive = [string](Get-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMdrive')
    $isSameImage = $null -ne $completedToday -and
      -not [string]::IsNullOrWhiteSpace($mountedImagePath) -and
      [string]::Equals($mountedImagePath, [string]$completedToday.ImagePath, [System.StringComparison]::OrdinalIgnoreCase) -and
      [string]::Equals($mountedImageDrive, [string]$chosen.MountedDrive, [System.StringComparison]::OrdinalIgnoreCase)
    if ($isSameImage) {
      $isCandidateCurrent = $true
      Write-BaselineLog -Level INFO -Message "Mounted image at $($chosen.MountedDrive) is today's completed image '$mountedImagePath' (registry identity); no remount."
    } elseif ($null -ne $completedToday -and $null -ne $chosen.NewestLogDate) {
      if ($chosen.NewestLogDate.Date -eq $completedToday.CompletionTime.Date) {
        $isCandidateCurrent = $true
      } elseif ($chosen.NewestLogDate -le $completedToday.CompletionTime -and ($completedToday.CompletionTime - $chosen.NewestLogDate).TotalHours -le 36) {
        $isCandidateCurrent = $true
      }
    }

    if ($isCandidateCurrent) {
      # Candidate is confirmed from today's backup
      $reuseCandidate = $chosen
      Write-BaselineLog -Level INFO -Message "Mounted candidate at $($chosen.MountedDrive) ($($chosen.NewestLogTimestamp)) matches today's completed backup ($($completedToday.ImagePath)). Reusing via fast-path."
    } elseif ($null -ne $completedToday) {
      # Candidate is stale; newer image exists for today
      Write-BaselineLog -Level INFO -Message "Found newer completed Macrium image for today: '$($completedToday.ImagePath)' ($($completedToday.CompletionTime.ToString('yyyy-MM-dd HH:mm:ss'))). Mounted baseline at $($chosen.MountedDrive) ($($chosen.NewestLogTimestamp)) is stale. Proceeding to mount today's backup."
      Write-Host "`n[INFO] Found today's completed Macrium image: $($completedToday.ImagePath)" -ForegroundColor Green
      Write-Host "       Mounted baseline at $($chosen.MountedDrive) is stale ($($chosen.NewestLogTimestamp)). Refreshing baseline to today's image...`n" -ForegroundColor Cyan
      $reuseCandidate = $null
    } else {
      # No completed backup found for today; reuse prior candidate as fallback with explicit notice
      $reuseCandidate = $chosen
      Write-Host "`n[NOTICE] No completed Macrium backup image was found for today ($(Get-Date -Format 'yyyy-MM-dd')). Reusing existing baseline from $($chosen.NewestLogTimestamp) at $($chosen.MountedDrive).`n" -ForegroundColor Yellow
      Write-BaselineLog -Level WARN -Message "No completed backup for today. Reusing prior mounted baseline at $($chosen.MountedDrive) ($($chosen.NewestLogTimestamp))."
    }

    if ($null -ne $reuseCandidate) {
      $mrmTimestampStr = Get-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMTimeStamp'
      $mrmDate = [datetime]::MinValue
      $hasMrmDate = (-not [string]::IsNullOrWhiteSpace($mrmTimestampStr)) -and [datetime]::TryParse($mrmTimestampStr, [ref]$mrmDate)

      $mrPushTimestampStr = Get-LcmRegistryValue -KeyPath $LcmRootRegistryKey -Name 'MRPushTimeStamp'
      if (-not [string]::IsNullOrWhiteSpace($mrPushTimestampStr) -and $hasMrmDate) {
        $pDate = [datetime]::MinValue
        if ([datetime]::TryParse($mrPushTimestampStr, [ref]$pDate) -and $pDate -gt $mrmDate) {
          Write-Host "`n[NOTICE] Live repositories were pushed at $mrPushTimestampStr, which is newer than the mounted baseline ($mrmTimestampStr)." -ForegroundColor Yellow
          Write-Host "         You can re-run with: bcr -NewBaseline if you wish to refresh the baseline.`n" -ForegroundColor Yellow
          Write-BaselineLog -Level INFO -Message "Pushed remote state ($mrPushTimestampStr) is newer than mounted baseline ($mrmTimestampStr)."
        }
      }

      $mountedBaseline = $reuseCandidate
      $resolvedImagePath = if ($null -ne $completedToday -and -not [string]::IsNullOrWhiteSpace($completedToday.ImagePath)) {
        [string]$completedToday.ImagePath
      } else {
        $regImg = Get-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMImagePath'
        if (-not [string]::IsNullOrWhiteSpace($regImg)) { $regImg } else { '' }
      }
      $resolvedImageLeaf = if (-not [string]::IsNullOrWhiteSpace($resolvedImagePath)) {
        Split-Path $resolvedImagePath -Leaf
      } else {
        $regLeaf = Get-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMImageLeaf'
        if (-not [string]::IsNullOrWhiteSpace($regLeaf)) { $regLeaf } else { 'Unknown' }
      }

      if ($WhatIfPreference) {
        Write-BaselineLog -Level INFO -Message "WhatIf: would reuse writable $($mountedBaseline.MountedDrive) Macrium baseline ($resolvedImageLeaf) for '$((Resolve-BaselineReviewScope))' via fast-path."
        return [pscustomobject]@{
          ImagePath = $resolvedImagePath
          ImageFileName = $resolvedImageLeaf
          CompletionTime = if ($null -ne $completedToday) { $completedToday.CompletionTime } else { $null }
          MountedDrive = $mountedBaseline.MountedDrive
          ReviewScope = Resolve-BaselineReviewScope
          Profile = $null
          Launched = $false
          ReusedExistingReviewWindow = $false
          ReusedMountedBaseline = $true
          FastPath = $true
        }
      }

      Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'ActMTimeStamp' -Value $reuseCandidate.NewestLogTimestamp
      Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'actMdrive' -Value $reuseCandidate.MountedDrive
      if (-not [string]::IsNullOrWhiteSpace($resolvedImagePath)) {
        Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'actMImagePath' -Value $resolvedImagePath
        Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'actMImageLeaf' -Value $resolvedImageLeaf
        # Backfill MRMImagePath if absent
        $currentMrmImg = Get-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMImagePath'
        if ([string]::IsNullOrWhiteSpace($currentMrmImg)) {
          Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMImagePath' -Value $resolvedImagePath
          Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMImageLeaf' -Value $resolvedImageLeaf
        }
      }

      Write-Host "`n[BASELINE] Reusing mounted Macrium baseline ($($mountedBaseline.MountedDrive)): $resolvedImageLeaf" -ForegroundColor Green
      if (-not [string]::IsNullOrWhiteSpace($resolvedImagePath)) {
        Write-Host "           Full Path: $resolvedImagePath`n" -ForegroundColor Green
      }

      $profileContract = if ($NoLaunchReview) { $null } else { Test-LcmBcrProfile -MountedDriveLetter $mountedBaseline.DriveLetter }
      $launchedReviewWindow = $false
      $reusedReviewWindow = $false
      if (-not $NoLaunchReview) {
        if ([string]::IsNullOrWhiteSpace($bcomparePath)) {
          throw 'Beyond Compare 5 executable was not found.'
        }
        # RULE-REV-012 / CRP-346: refresh the own review window; launch only when none is reusable.
        $windowResult = Open-LcmReviewWindow -BComparePath $bcomparePath -MountedDrive $mountedBaseline.MountedDrive -Scope (Resolve-BaselineReviewScope)
        $launchedReviewWindow = $windowResult.Launched
        $reusedReviewWindow = $windowResult.Reused
      }
      $windowDisposition = if ($reusedReviewWindow) { 'reused the existing _LCM review window (fast-path)' } elseif ($launchedReviewWindow) { 'opened one _LCM review window (fast-path)' } else { 'did not launch a review window' }
      Write-BaselineLog -Level INFO -Message "Reused writable $($mountedBaseline.MountedDrive) Macrium baseline for '$((Resolve-BaselineReviewScope))' via fast-path; $windowDisposition."
      return [pscustomobject]@{
        ImagePath = $resolvedImagePath
        ImageFileName = $resolvedImageLeaf
        CompletionTime = if ($null -ne $completedToday) { $completedToday.CompletionTime } else { $null }
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
}

if ($ElevatedWorker) {
  # CRP-343: legacy entry point; the elevated worker is the atom tools/Invoke-MacriumMountWorker.ps1.
  $legacyDrives = (@(ConvertTo-LcmCandidateDrives -Drives $CandidateDrives) -join ';')
  & (Join-Path $PSScriptRoot 'Invoke-MacriumMountWorker.ps1') -ImagePath $ImagePath -CandidateDrives $legacyDrives -ExpectedVolumeLabel $ExpectedVolumeLabel -MountTimeoutSeconds $MountTimeoutSeconds -ReceiptPath $ReceiptPath
  exit $LASTEXITCODE
}

$completedImage = if ($ForceNewBackup) {
  Start-MacriumBackupAndWait
} elseif ($null -ne $completedToday) {
  $completedToday
} else {
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
  # CRP-343: the elevated mount runs only in the atom Invoke-MacriumMountWorker.ps1, dispatched through
  # the DO daemon by the admin tool Mount-MacriumLatestBaseline.ps1, started here as a child process
  # (non-admin tool -> admin tool -> elevated atom). This tool and Beyond Compare stay non-elevated.
  $mountTool = Join-Path $PSScriptRoot 'Mount-MacriumLatestBaseline.ps1'
  Write-BaselineLog -Level INFO -Message "Mounting '$($completedImage.ImagePath)' through $mountTool (elevated atom Invoke-MacriumMountWorker.ps1)."
  & $pwshPath -NoProfile -ExecutionPolicy Bypass -File $mountTool -ConfirmMount -ImagePath $completedImage.ImagePath -CandidateDrives ($normalizedDrives -join ';') -ExpectedVolumeLabel $ExpectedVolumeLabel -MountTimeoutSeconds $MountTimeoutSeconds -ReceiptPath $receiptPath
  $mountExit = $LASTEXITCODE
  if (-not (Test-Path -LiteralPath $receiptPath)) {
    throw "The Macrium mount atom exited with code $mountExit without a receipt."
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
  # Strict allocation gate: Verify the baseline drive and repository container are fully ready before launching BCR
  $baselineWorkspacePath = "$($receipt.MountedDrive)\Git_Repositories"
  if (-not (Test-Path -LiteralPath $baselineWorkspacePath -PathType Container)) {
    throw "Mounted baseline at $($receipt.MountedDrive) does not contain a verified Git_Repositories container. Aborting Beyond Compare launch to prevent review locks."
  }
  # RULE-REV-012 / CRP-346 R6: after a remount the own review window is refreshed; launch only when none is reusable.
  $profileContract = Test-LcmBcrProfile -MountedDriveLetter $receipt.MountedDrive.TrimEnd(':')
  $freshWindowResult = Open-LcmReviewWindow -BComparePath $bcomparePath -MountedDrive $receipt.MountedDrive -Scope $reviewIdentity
}

$mountEvidence = $receipt.MountEvidence
$evidenceSummary = if ($null -eq $mountEvidence) {
  'No worker mount evidence was returned.'
} else {
  "detached=$(@($mountEvidence.DetachedDrives) -join ','); reappeared=$($mountEvidence.ReappearedDrive); snapshotSaved=$($mountEvidence.SnapshotSavedAt); goodNightObserved=$($mountEvidence.GoodNightObserved)"
}
$completedLeaf = Split-Path $completedImage.ImagePath -Leaf
Write-Host "`n[BASELINE] Mounted Macrium baseline image: $completedLeaf" -ForegroundColor Green
Write-Host "           Full Path: $($completedImage.ImagePath)" -ForegroundColor Green
Write-Host "           Drive    : $($receipt.MountedDrive)`n" -ForegroundColor Green

Write-BaselineLog -Level INFO -Message "Mounted '$($completedImage.ImagePath)' ($completedLeaf) at $($receipt.MountedDrive); $evidenceSummary; selected RHS review scope '$reviewIdentity' without rewriting the _LCM profile."

Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMTimeStamp' -Value ($completedImage.CompletionTime.ToString('yyyy-MM-dd HH:mm:ss'))
Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMdrive' -Value $receipt.MountedDrive
Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMImagePath' -Value $completedImage.ImagePath
Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'MRMImageLeaf' -Value $completedLeaf
Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'actMImagePath' -Value $completedImage.ImagePath
Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'actMImageLeaf' -Value $completedLeaf

$freshCandidates = @(Find-MountedMacriumBaselineCandidates -Drives @($receipt.MountedDrive.TrimEnd(':')) -ExpectedVolumeLabel $ExpectedVolumeLabel)
if ($freshCandidates.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($freshCandidates[0].NewestLogTimestamp)) {
  Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'ActMTimeStamp' -Value $freshCandidates[0].NewestLogTimestamp
  Set-LcmRegistryValue -KeyPath $MacriumRegistryKey -Name 'actMdrive' -Value $freshCandidates[0].MountedDrive
}

[pscustomobject]@{
  ImagePath = $completedImage.ImagePath
  ImageFileName = $completedLeaf
  CompletionTime = $completedImage.CompletionTime
  MountedDrive = $receipt.MountedDrive
  ReviewScope = $reviewIdentity
  Profile = if ($NoLaunchReview) { $null } else { $profileContract }
  Launched = if ($NoLaunchReview) { $false } else { [bool]$freshWindowResult.Launched }
  ReusedExistingReviewWindow = if ($NoLaunchReview) { $false } else { [bool]$freshWindowResult.Reused }
  MountEvidence = $mountEvidence
}
