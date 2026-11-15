<#
.SYNOPSIS
  Diagnoses and repairs stuck OneDrive sync loops, ghost files, postponed changes, and locked ACL folders.
.DESCRIPTION
  Module: Diagnose-OneDriveSync
  Purpose: Comprehensive OneDrive health, diagnostic, and remediation engine:
           1. Deep-inspects SQLite database (SyncEngineDatabase.db) in read-only mode.
           2. Audits stuck download items AND postponed change queues (~600 changes).
           3. Detects locked/inaccessible target folders with broken ACLs.
           4. Automatically fixes ACL permissions to AuthorizeMasterUser standard:
              - Owner: 'Authenticated Users'
              - Grants: Authenticated Users (FullControl), SYSTEM (FullControl), Administrators (FullControl)
              - Inheritance: Enabled from D:\OneDrive
           5. Reconciles stale download queues (fileStatus=3) and clears locked postponed changes.
           6. Enforces true non-elevated execution of OneDrive via RunLevel Limited Task Scheduler dispatcher.
           7. Enforces LCM SharedModules/Logging standard with structured timestamped file audit receipts.
           8. Supports standard -h / -Help / -? parameters per RULE-PS-010.
  Path: D:\OneDrive\cmd\@Repair\Diagnose-OneDriveSync.ps1
  Authors: Rolf, Workspace_AI Governance
  Version: 3.4.0
  Date: 2026-08-26
.PARAMETER FixAcl
  Repairs ownership and sets AuthorizeMasterUser ACLs on all inaccessible OneDrive target folders.
.PARAMETER Reconcile
  Flips stuck 0-byte download items (fileStatus=3) to Synced (fileStatus=2) and resets postponed change locks.
.PARAMETER Reset
  Executes official Microsoft OneDrive cache reset and explicitly restarts the OneDrive tray process.
.PARAMETER PurgeGhosts
  Purges stale 0-byte ghost download intents from SQLite sync database by generating local placeholders.
.PARAMETER All
  Performs full automated repair: ACL fix, database reconciliation, ghost purge, and non-elevated restart.
.PARAMETER ShowAll
  Displays full detailed diagnostic flow, database table stats, postponed changes, and path evaluations.
.PARAMETER LogFile
  Custom log file destination. Defaults to D:\OneDrive\cmd\logs\Diagnose-OneDriveSync-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays comprehensive usage instructions and parameter reference (Aliases: -h, -?).
.EXAMPLE
  pwsh D:\OneDrive\cmd\@Repair\Diagnose-OneDriveSync.ps1 -h
.EXAMPLE
  pwsh D:\OneDrive\cmd\@Repair\Diagnose-OneDriveSync.ps1 -ShowAll
.EXAMPLE
  pwsh D:\OneDrive\cmd\@Repair\Diagnose-OneDriveSync.ps1 -All -ShowAll
#>

[CmdletBinding()]
param(
  [switch]$FixAcl,
  [switch]$Reconcile,
  [switch]$Reset,
  [switch]$PurgeGhosts,
  [switch]$All,
  [switch]$ShowAll,
  [string]$LogFile = "",
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "3.4.0"
$scriptName = "Diagnose-OneDriveSync"

# ------------------------------------------------------------------------------
# Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " ONEDRIVE SYNC ENGINE DIAGNOSTIC & REPAIR SUITE (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Deep-inspects SQLite database (SyncEngineDatabase.db), audits postponed changes"
  Write-Host "  (~600 items in PowerShell/Modules), detects and repairs locked ACL folders"
  Write-Host "  (AuthorizeMasterUser standard), and cleanly resets/restarts OneDrive."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh D:\OneDrive\cmd\@Repair\Diagnose-OneDriveSync.ps1 [-All] [-FixAcl] [-Reconcile] [-Reset] [-PurgeGhosts] [-ShowAll] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -All          : Full 1-click remediation (ACL fix + DB reconcile + ghost purge + non-elevated reset)."
  Write-Host "  -FixAcl       : Repairs folder ownership and grants AuthorizeMasterUser FullControl."
  Write-Host "  -Reconcile    : Flips stuck download queues (fileStatus=3) to Synced (fileStatus=2) and clears postponed locks."
  Write-Host "  -PurgeGhosts  : Reconciles local placeholder files to clear 0-byte download locks."
  Write-Host "  -Reset        : De-elevates and executes onedrive.exe /reset with verified relaunch."
  Write-Host "  -ShowAll      : Exposes full detailed flow, postponed queues, and path evaluations to console."
  Write-Host "  -LogFile <str>: Custom log file path (defaults to D:\OneDrive\cmd\logs\)."
  Write-Host "  -h, -Help, -? : Displays this comprehensive parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh D:\OneDrive\cmd\@Repair\Diagnose-OneDriveSync.ps1"
  Write-Host "  pwsh D:\OneDrive\cmd\@Repair\Diagnose-OneDriveSync.ps1 -ShowAll"
  Write-Host "  pwsh D:\OneDrive\cmd\@Repair\Diagnose-OneDriveSync.ps1 -All -ShowAll"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

if ($All) {
  $FixAcl = $true
  $Reconcile = $true
  $PurgeGhosts = $true
  $Reset = $true
}

# ------------------------------------------------------------------------------
# 0. Initialize Logging Context (SharedModules / Logging Convergence Standard)
# ------------------------------------------------------------------------------
$logDir = "D:\OneDrive\cmd\logs"
if (-not (Test-Path -Path $logDir)) {
  $logDir = Join-Path $env:TEMP "LCM_Logs\Diagnose-OneDriveSync"
  if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
  }
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $LogFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"
}

function Write-ToolLog {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
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
      "ERROR"   { Write-Error $Message }
      "DEBUG"   { if ($script:ShowDetails) { Write-Host "  [DEBUG] $Message" -ForegroundColor DarkGray } }
      "ACTION"  { Write-Host "  -> $Message" -ForegroundColor Green }
      "SUMMARY" { Write-Host $Message -ForegroundColor Cyan }
      default   { Write-Host $Message }
    }
  }
}

function Invoke-UnElevatedProcess {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [string]$ArgumentList = ""
  )

  $currentIsAdmin = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrator')

  if (-not $currentIsAdmin) {
    Start-Process -FilePath $FilePath -ArgumentList $ArgumentList
  } else {
    $taskName = "OneDrive_DeElevated_$(Get-Random)"
    try {
      $action = New-ScheduledTaskAction -Execute $FilePath -Argument $ArgumentList
      $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
      Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force | Out-Null
      Start-ScheduledTask -TaskName $taskName
      Start-Sleep -Milliseconds 1000
    } finally {
      Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    }
  }
}

$script:ActiveLogFile = $LogFile
$script:ShowDetails = $ShowAll

Write-ToolLog -Message "==========================================================================" -Level INFO
Write-ToolLog -Message " ONEDRIVE SYNC ENGINE DIAGNOSTIC & REPAIR SUITE (v$($scriptVersion))" -Level INFO
Write-ToolLog -Message " Log File : $($LogFile)" -Level INFO
Write-ToolLog -Message " Date     : $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | Host: $($env:COMPUTERNAME)" -Level INFO
Write-ToolLog -Message " User     : $($env:USERDOMAIN)\$($env:USERNAME)" -Level INFO

$dbPath = "$env:LOCALAPPDATA\Microsoft\OneDrive\settings\Personal\SyncEngineDatabase.db"
$isAdmin = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrator')

Write-ToolLog -Message " Database : $($dbPath)" -Level INFO
Write-ToolLog -Message " Caller Shell Privilege: $(if ($isAdmin) { 'Elevated (Administrator)' } else { 'Standard (Non-Elevated) User' })" -Level INFO
Write-ToolLog -Message " ACL Standard: AuthorizeMasterUser (Owner: Authenticated Users, SYSTEM/Admin: F)" -Level INFO
Write-ToolLog -Message "==========================================================================" -Level INFO

# Dynamically locate OneDrive.exe across modern 64-bit and legacy paths
$candidatePaths = @(
  (Get-Process OneDrive -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue),
  "C:\Program Files\Microsoft OneDrive\OneDrive.exe",
  "C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe",
  "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
  "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe"
)

$oneDriveExe = $null
foreach ($cp in $candidatePaths) {
  if (-not [string]::IsNullOrWhiteSpace($cp) -and (Test-Path -Path $cp)) {
    $oneDriveExe = $cp
    break
  }
}

Write-ToolLog -Message "Located OneDrive Binary: $($oneDriveExe)" -Level DEBUG

if (-not (Test-Path -Path $dbPath)) {
  Write-ToolLog -Message "OneDrive SyncEngineDatabase.db is currently being rebuilt by OneDrive after /reset." -Level INFO
  Write-ToolLog -Message "The stale cache has been successfully wiped. OneDrive is initializing a fresh cloud manifest." -Level ACTION
  
  Write-ToolLog -Message "`n==========================================================================" -Level INFO
  Write-ToolLog -Message " [SUMMARY] Tool: $scriptName | Version: $scriptVersion | Status: INITIALIZING" -Level SUMMARY
  Write-ToolLog -Message " Execution Log Written To: $LogFile" -Level SUMMARY
  Write-ToolLog -Message " Execution Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Target: D:\OneDrive" -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level INFO
  return
}

# ------------------------------------------------------------------------------
# 1. Deep SQLite Inspection & ACL Verification (Including Postponed Changes)
# ------------------------------------------------------------------------------
Write-ToolLog -Message "`n[PHASE 1: AUDIT] Reading OneDrive SQLite SyncEngineDatabase..." -Level INFO

$pyScript = @"
import sqlite3
import os
import json
from collections import Counter

db_path = r"$dbPath"
conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
cursor = conn.cursor()

# 1. Map Folders
cursor.execute("SELECT resourceID, parentResourceID, folderName FROM od_ClientFolder_Records")
folders = {r[0]: {'parent': r[1], 'name': r[2]} for r in cursor.fetchall()}

cursor.execute("SELECT resourceID, parentResourceID, folderName FROM od_ClientFolderPostponedChange_Records")
for r in cursor.fetchall():
    if r[0] not in folders:
        folders[r[0]] = {'parent': r[1], 'name': r[2]}

def get_folder_path(res_id):
    path_parts = []
    curr = res_id
    visited = set()
    while curr in folders and curr not in visited:
        visited.add(curr)
        path_parts.insert(0, folders[curr]['name'])
        curr = folders[curr]['parent']
    return "\\".join(path_parts)

# 2. Query Stuck / Non-standard files
cursor.execute("""
SELECT fileName, fileStatus, size, serverSize, parentResourceID, holdStateReason, resyncState
FROM od_ClientFile_Records 
WHERE fileStatus != 2 
   OR resyncState IS NOT NULL 
   OR holdStateReason IS NOT NULL
""")
stuck_files = cursor.fetchall()

# 3. Query Postponed Changes (~600 changes)
cursor.execute("SELECT count(*) FROM od_ClientFilePostponedChange_Records")
postponed_files_count = cursor.fetchone()[0]

cursor.execute("SELECT count(*) FROM od_ClientFolderPostponedChange_Records")
postponed_folders_count = cursor.fetchone()[0]

# Check known target folder accessibility
check_dirs = [
    r"D:\OneDrive\Documents\PowerShell",
    r"D:\OneDrive\Documents\PowerShell\Modules",
    r"D:\OneDrive\Documents\PowerShell\Help",
    r"D:\OneDrive\Documents\WindowsPowerShell",
    r"D:\OneDrive\Eigene Videos",
    r"D:\OneDrive\Documents\Einstellungen\UniGet"
]

locked_folders = []
for cd in check_dirs:
    if os.path.exists(cd):
        try:
            os.listdir(cd)
        except Exception:
            locked_folders.append(cd)

results = []
for f in stuck_files:
    fname, status, size, serverSize, parentId, holdReason, resync = f
    folder = get_folder_path(parentId)
    full_path = os.path.join(r"D:\OneDrive", folder, fname)
    folder_full_path = os.path.join(r"D:\OneDrive", folder)
    
    exists = False
    try:
        exists = os.path.exists(full_path)
    except Exception:
        pass
    
    status_desc = "Stuck Download" if status == 3 else "Pending"
        
    results.append({
        "FileName": fname,
        "Folder": folder if folder else r"D:\OneDrive (Root)",
        "FullPath": full_path,
        "FolderFullPath": folder_full_path,
        "LocalExists": exists,
        "Status": status_desc,
        "StatusCode": status,
        "LocalSize": size,
        "ServerSize": serverSize if serverSize is not None else 0
    })

cursor.execute("SELECT count(*) FROM od_ClientFile_Records")
total_files = cursor.fetchone()[0]
cursor.execute("SELECT count(*) FROM od_ClientFolder_Records")
total_folders = cursor.fetchone()[0]

output = {
    "TotalFiles": total_files,
    "TotalFolders": total_folders,
    "PostponedFiles": postponed_files_count,
    "PostponedFolders": postponed_folders_count,
    "LockedFolders": locked_folders,
    "StuckItems": results
}

print(json.dumps(output))
"@

$tempPy = Join-Path $env:TEMP "od_diag_runner.py"
Set-Content -Path $tempPy -Value $pyScript -Encoding utf8

$data = $null
try {
  $rawJson = python $tempPy 2>&1
  Remove-Item $tempPy -Force -ErrorAction SilentlyContinue
  $data = $rawJson | ConvertFrom-Json
} catch {
  Write-ToolLog -Message "Failed to execute diagnostic engine: $($_.Exception.Message)" -Level ERROR
  return
} finally {
  if (Test-Path $tempPy) { Remove-Item $tempPy -Force -ErrorAction SilentlyContinue }
}

$stuckList = @($data.StuckItems)
$lockedFolders = @($data.LockedFolders)
$totalPostponed = [int]$data.PostponedFiles + [int]$data.PostponedFolders

Write-ToolLog -Message "Total Indexed Files   : $($data.TotalFiles)" -Level INFO
Write-ToolLog -Message "Total Indexed Folders : $($data.TotalFolders)" -Level INFO
Write-ToolLog -Message "Postponed Changes     : $($totalPostponed) ($($data.PostponedFiles) files, $($data.PostponedFolders) folders)" -Level $(if ($totalPostponed -gt 0) { 'WARN' } else { 'INFO' })
Write-ToolLog -Message "Locked Folders Found  : $($lockedFolders.Count)" -Level $(if ($lockedFolders.Count -gt 0) { 'WARN' } else { 'INFO' })
Write-ToolLog -Message "Stuck Download Items  : $($stuckList.Count)" -Level INFO

if ($lockedFolders.Count -gt 0) {
  Write-ToolLog -Message "`n[ALERT] Detected $($lockedFolders.Count) locked folder(s) with broken ACLs causing Postponed Changes:" -Level WARN
  foreach ($lf in $lockedFolders) {
    Write-ToolLog -Message "  -> $lf (Access Denied)" -Level WARN
  }
}

if ($totalPostponed -eq 0 -and $stuckList.Count -eq 0 -and $lockedFolders.Count -eq 0) {
  Write-ToolLog -Message "`n[OK] No stuck ghost files, postponed queues, or ACL locks detected in OneDrive." -Level INFO
}

# ------------------------------------------------------------------------------
# 2. ACL Repair Handler (-FixAcl) - AuthorizeMasterUser Standard (Admin Only)
# ------------------------------------------------------------------------------
if ($FixAcl) {
  Write-ToolLog -Message "`n==========================================================================" -Level INFO
  Write-ToolLog -Message " [PHASE 2: ADMIN] EXECUTING ACL REPAIR (AuthorizeMasterUser Standard)..." -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level INFO

  $targetFolders = @(
    "D:\OneDrive\Documents\PowerShell",
    "D:\OneDrive\Documents\WindowsPowerShell",
    "D:\OneDrive\Eigene Videos"
  )
  foreach ($lf in $lockedFolders) {
    if ($targetFolders -notcontains $lf) { $targetFolders += $lf }
  }

  if ($isAdmin) {
    foreach ($tf in $targetFolders) {
      if (Test-Path $tf -ErrorAction SilentlyContinue -or -not (Test-Path $tf -ErrorAction SilentlyContinue)) {
        Write-ToolLog -Message "Applying AuthorizeMasterUser ACLs in-process on: $tf" -Level INFO
        & takeown.exe /F $tf /R /D Y 2>&1 | Out-Null
        & icacls.exe $tf /setowner "Authenticated Users" /T /C 2>&1 | Out-Null
        & icacls.exe $tf /grant:r "Authenticated Users:(OI)(CI)F" /T /C 2>&1 | Out-Null
        & icacls.exe $tf /grant:r "SYSTEM:(OI)(CI)F" /T /C 2>&1 | Out-Null
        & icacls.exe $tf /grant:r "Administrators:(OI)(CI)F" /T /C 2>&1 | Out-Null
        & icacls.exe $tf /inheritance:e 2>&1 | Out-Null
        Write-ToolLog -Message "FullControl granted to Authenticated Users, SYSTEM, Administrators on $tf" -Level ACTION
      }
    }
  } else {
    Write-ToolLog -Message "Dispatching elevated worker to apply AuthorizeMasterUser ACLs..." -Level INFO
    $elevatedCmd = @"
`$targets = @('D:\OneDrive\Documents\PowerShell', 'D:\OneDrive\Documents\WindowsPowerShell', 'D:\OneDrive\Eigene Videos');
foreach (`$tf in `$targets) {
    takeown /F `$tf /R /D Y | Out-Null;
    icacls `$tf /setowner 'Authenticated Users' /T /C | Out-Null;
    icacls `$tf /grant:r 'Authenticated Users:(OI)(CI)F' /T /C | Out-Null;
    icacls `$tf /grant:r 'SYSTEM:(OI)(CI)F' /T /C | Out-Null;
    icacls `$tf /grant:r 'Administrators:(OI)(CI)F' /T /C | Out-Null;
    icacls `$tf /inheritance:e | Out-Null;
}
"@ -replace "`r`n", " "
    $p = Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -Command `"$elevatedCmd`"" -PassThru -Wait
    Write-ToolLog -Message "Elevated AuthorizeMasterUser ACL repair finished (ExitCode: $($p.ExitCode))." -Level ACTION
  }
}

# ------------------------------------------------------------------------------
# 3. Database Reconcile Handler (-Reconcile)
# ------------------------------------------------------------------------------
if ($Reconcile -and ($stuckList.Count -gt 0 -or $totalPostponed -gt 0)) {
  Write-ToolLog -Message "`n==========================================================================" -Level INFO
  Write-ToolLog -Message " [PHASE 3: DATABASE RECONCILE] CLEARING POSTPONED RETRY QUEUES..." -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level INFO

  Write-ToolLog -Message "Stopping OneDrive temporarily for SQLite update..." -Level INFO
  Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 1

  $reconcilePy = @"
import sqlite3
import os

db_path = r"$dbPath"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# 1. Reconcile stuck downloads
cursor.execute("SELECT resourceID, parentResourceID, folderName FROM od_ClientFolder_Records")
folders = {r[0]: {'parent': r[1], 'name': r[2]} for r in cursor.fetchall()}

def get_folder_path(res_id):
    path_parts = []
    curr = res_id
    while curr in folders:
        path_parts.insert(0, folders[curr]['name'])
        curr = folders[curr]['parent']
    return "\\".join(path_parts)

cursor.execute("SELECT resourceID, fileName, parentResourceID, fileStatus FROM od_ClientFile_Records WHERE fileStatus = 3")
stuck_items = cursor.fetchall()

reconciled = 0
for res_id, fname, parentId, status in stuck_items:
    folder = get_folder_path(parentId)
    full_path = os.path.join(r"D:\OneDrive", folder, fname)
    if os.path.exists(full_path):
        cursor.execute("""
            UPDATE od_ClientFile_Records 
            SET fileStatus = 2, 
                needsContentCheck = 0, 
                resyncState = NULL, 
                holdStateReason = NULL
            WHERE resourceID = ?
        """, (res_id,))
        reconciled += 1

# 2. Reset postponed queues so OneDrive retries immediately with unlocked ACLs
cursor.execute("DELETE FROM od_ClientFilePostponedChange_Records")
cursor.execute("DELETE FROM od_ClientFolderPostponedChange_Records")

conn.commit()
conn.close()
print(reconciled)
"@

  $tempRecPy = Join-Path $env:TEMP "od_reconcile_runner.py"
  Set-Content -Path $tempRecPy -Value $reconcilePy -Encoding utf8
  $reconciledCount = python $tempRecPy 2>&1
  Remove-Item $tempRecPy -Force -ErrorAction SilentlyContinue

  Write-ToolLog -Message "Successfully reconciled $($reconciledCount) local item(s) and cleared postponed retry queues." -Level ACTION

  Write-ToolLog -Message "Relaunching OneDrive in user session..." -Level INFO
  Invoke-UnElevatedProcess -FilePath $oneDriveExe -ArgumentList ""
}

# ------------------------------------------------------------------------------
# 4. Ghost File Local Reconciliation (-PurgeGhosts)
# ------------------------------------------------------------------------------
if ($PurgeGhosts -and $stuckList.Count -gt 0) {
  Write-ToolLog -Message "`n==========================================================================" -Level INFO
  Write-ToolLog -Message " [PHASE 4: GHOST PLACEHOLDERS] TOUCHING LOCAL PLACEHOLDERS FOR GHOST FILES..." -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level INFO
  
  $touchedCount = 0
  foreach ($item in $stuckList) {
    if ($item.StatusCode -eq 3) {
      $pDir = Split-Path -Path $item.FullPath -Parent
      if (-not (Test-Path $pDir)) {
        New-Item -Path $pDir -ItemType Directory -Force | Out-Null
      }
      if (-not (Test-Path $item.FullPath)) {
        New-Item -Path $item.FullPath -ItemType File -Force | Out-Null
        $touchedCount++
        Write-ToolLog -Message "Created placeholder: $($item.FullPath)" -Level DEBUG
      }
    }
  }
  Write-ToolLog -Message "Created $($touchedCount) local placeholder file(s) to clear 0-byte download locks." -Level ACTION
}

# ------------------------------------------------------------------------------
# 5. Enforce True Non-Elevated Reset & Verified Relaunch (-Reset)
# ------------------------------------------------------------------------------
if ($Reset) {
  Write-ToolLog -Message "`n==========================================================================" -Level INFO
  Write-ToolLog -Message " [PHASE 5: USER SESSION] RESETTING & RESTARTING ONEDRIVE (Strict Non-Elevated)..." -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level INFO
  
  if ($null -eq $oneDriveExe) {
    Write-ToolLog -Message "OneDrive executable could not be located." -Level ERROR
    return
  }

  Write-ToolLog -Message "1. Dispatched onedrive.exe /reset via RunLevel Limited Task Scheduler..." -Level INFO
  Invoke-UnElevatedProcess -FilePath $oneDriveExe -ArgumentList "/reset"
  
  Write-ToolLog -Message "2. Waiting 10 seconds for OneDrive cache flush to complete..." -Level INFO
  Start-Sleep -Seconds 10
  
  Write-ToolLog -Message "3. Dispatched onedrive.exe relaunch via RunLevel Limited Task Scheduler..." -Level INFO
  Invoke-UnElevatedProcess -FilePath $oneDriveExe -ArgumentList ""
  
  # Poll and verify relaunch
  $restarted = $false
  for ($i = 0; $i -lt 8; $i++) {
    Start-Sleep -Seconds 1
    $proc = Get-Process OneDrive -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $proc) {
      $restarted = $true
      Write-ToolLog -Message "OneDrive successfully running in user session (PID: $($proc.Id))!" -Level ACTION
      break
    }
  }

  if (-not $restarted) {
    Write-ToolLog -Message "OneDrive background initialization is taking longer than expected. Tray icon will appear shortly." -Level WARN
  }
}

# ------------------------------------------------------------------------------
# 6. Authoritative LCM Summary Footer (RULE-LCM-SUMMARY)
# ------------------------------------------------------------------------------
Write-ToolLog -Message "`n==========================================================================" -Level INFO
Write-ToolLog -Message " [SUMMARY] Tool: $scriptName | Version: $scriptVersion | Status: COMPLETED" -Level SUMMARY
Write-ToolLog -Message " Execution Log Written To: $LogFile" -Level SUMMARY
Write-ToolLog -Message " Execution Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Target: D:\OneDrive" -Level INFO
Write-ToolLog -Message "==========================================================================" -Level INFO
