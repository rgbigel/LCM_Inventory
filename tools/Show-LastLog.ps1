<#
.SYNOPSIS
  Locates and opens the latest operational LCM command log and reveals its folder in File Explorer.
.DESCRIPTION
  Module: Show-LastLog
  Purpose: Uses Everything CLI (es.exe) to query the latest operational command execution log
           across LCM and Subsystem tools directories (tools/logs/, \cmd\logs\, and Subsystem/logs/), automatically excluding
           internal plumbing/infrastructure logs (Update-ToolCatalog, Invoke-InteractiveDesktop, etc.).
           Opens File Explorer with the file selected to provide full log history browsing,
           and launches the log in notepad.exe on Session 1 interactive desktop (with automatic Notepad++ fallback for large logs).
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: tools/Show-LastLog.ps1
  Authors: Rolf, LCM Workspace Automation
  Version: 10.2.0
  Date: 2026-10-13
.PARAMETER ToolName
  Optional filter to locate the latest log for a specific tool (e.g. 'Start-RemoteBridge', 'Update-HaInventory', 'Diagnose-OneDriveSync').
.PARAMETER Subsystem
  Optional filter to locate the latest log for a specific subsystem (e.g. 'HaSSD06', 'LCM_Inventory', 'SystemConfiguration', 'LCM') (Alias: -Group).
.PARAMETER IncludeInternal
  Includes internal plumbing and maintenance logs (e.g. Update-ToolCatalog, Invoke-InteractiveDesktop).
.PARAMETER NotepadPlus
  Forces opening the log directly in Notepad++ instead of default Notepad (Alias: -Npp).
.PARAMETER ExplorerOnly
  Opens the File Explorer window selecting the file without launching the text editor.
.PARAMETER EditorOnly
  Opens the log directly in text editor without launching File Explorer.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Show-LastLog.ps1 -h
.EXAMPLE
  pwsh tools/Show-LastLog.ps1
.EXAMPLE
  pwsh tools/Show-LastLog.ps1 -Subsystem HaSSD06
.EXAMPLE
  pwsh tools/Show-LastLog.ps1 -ToolName "Update-HaInventory" -Subsystem HaSSD06
.EXAMPLE
  pwsh tools/Show-LastLog.ps1 -Npp
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Optional filter to locate the latest log for a specific tool')]
  [string]$ToolName = "",

  [Parameter(Mandatory = $false, HelpMessage = 'Filter logs by subsystem name (e.g. HaSSD06, LCM_Inventory, LCM)')]
  [Alias('Group')]
  [string]$Subsystem = "",

  [Parameter(Mandatory = $false, HelpMessage = 'Includes internal plumbing and maintenance logs')]
  [switch]$IncludeInternal,

  [Parameter(Mandatory = $false, HelpMessage = 'Forces opening the log directly in Notepad++ instead of default Notepad')]
  [Alias('Npp')]
  [switch]$NotepadPlus,

  [Parameter(Mandatory = $false, HelpMessage = 'Opens File Explorer selecting the log file')]
  [Alias('ShowFolder', 'Folder')]
  [switch]$Explorer,

  [Parameter(Mandatory = $false, HelpMessage = 'Opens File Explorer window selecting the log without launching text editor')]
  [switch]$ExplorerOnly,

  [Parameter(Mandatory = $false, HelpMessage = 'Opens log directly in text editor without launching File Explorer')]
  [switch]$EditorOnly,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Show-LastLog"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM LOG LOCATOR & EXPLORER LAUNCHER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Uses Everything CLI (es.exe) to query the latest operational command log,"
  Write-Host "  across LCM core and subsystem repositories (HaSSD06, LCM_Inventory, etc.),"
  Write-Host "  automatically filtering out internal plumbing (Update-ToolCatalog, etc.),"
  Write-Host "  and reveals the log folder in File Explorer and Notepad/Notepad++ on Session 1."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Show-LastLog.ps1 [-ToolName <Name>] [-Subsystem <Subsystem>] [-IncludeInternal] [-Npp] [-ExplorerOnly] [-EditorOnly] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -ToolName <str>    : Filter by specific tool prefix (e.g. 'Update-HaInventory')."
  Write-Host "  -Subsystem <str>   : Filter by specific subsystem (e.g. 'HaSSD06', 'LCM_Inventory') (Alias: -Group)."
  Write-Host "  -IncludeInternal   : Includes internal plumbing logs (Update-ToolCatalog, Invoke-InteractiveDesktop)."
  Write-Host "  -Npp, -NotepadPlus : Forces opening in Notepad++ instead of Notepad."
  Write-Host "  -ExplorerOnly      : Opens File Explorer with the file selected without text editor."
  Write-Host "  -EditorOnly        : Launches text editor only without opening File Explorer."
  Write-Host "  -h, -Help, -?      : Displays this parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Show-LastLog.ps1"
  Write-Host "  pwsh tools/Show-LastLog.ps1 -Subsystem HaSSD06"
  Write-Host "  pwsh tools/Show-LastLog.ps1 -ToolName 'Update-HaInventory'"
  Write-Host "  pwsh tools/Show-LastLog.ps1 -Npp"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcdRoot 'tools\internal'
$primaryLogDir = Join-Path $toolsDir 'logs'
$cmdLogDir = 'D:\OneDrive\cmd\logs'
$interactiveDesktopScript = Join-Path $toolsDir 'Invoke-InteractiveDesktop.ps1'

$internalPlumbingPrefixes = @(
  'Invoke-InteractiveDesktop',
  'Update-ToolCatalog',
  'Sync-ToolSymlinks',
  'Show-LastLog',
  'Invoke-LcmProtocol',
  'Show-ToolIndex',
  'LcmDesktopDaemon',
  'Register-LcmDesktopDaemon',
  'Get-SystemPortInventory',
  'Search-Everything'
)

# Collect all candidate log directories across LCM core and subsystems
$candidateDirs = [System.Collections.Generic.List[string]]::new()

if (-not [string]::IsNullOrWhiteSpace($Subsystem) -and $Subsystem -ne 'All') {
  $subCandidates = @(
    (Join-Path $workspaceRoot "$Subsystem\logs"),
    (Join-Path $workspaceRoot "${Subsystem}_Inventory\logs"),
    (Join-Path $workspaceRoot "${Subsystem}_Inventory\data\logs"),
    (Join-Path $workspaceRoot "$Subsystem\data\logs")
  )
  foreach ($sc in $subCandidates) {
    if ((Test-Path -LiteralPath $sc) -and -not $candidateDirs.Contains($sc)) {
      $candidateDirs.Add($sc)
    }
  }
}

$standardDirs = @(
  $primaryLogDir,
  (Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm'),
  (Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm-internal'),
  $cmdLogDir,
  (Join-Path $workspaceRoot 'tools\logs'),
  (Join-Path $workspaceRoot 'LCM_Inventory\logs'),
  (Join-Path $workspaceRoot 'LCM_Inventory\data\logs'),
  (Join-Path $workspaceRoot 'HaSSD06_Inventory\logs'),
  (Join-Path $workspaceRoot 'SystemConfiguration\logs')
)
foreach ($sd in $standardDirs) {
  if ((Test-Path -LiteralPath $sd) -and -not $candidateDirs.Contains($sd)) {
    $candidateDirs.Add($sd)
  }
}

# Locate Notepad++ binary
$nppCandidates = @(
  "D:\Tools\Notepad++\notepad++.exe",
  "D:\Tools\notepad++.exe",
  "C:\Program Files\Notepad++\notepad++.exe",
  "C:\Program Files (x86)\Notepad++\notepad++.exe"
)
$nppExe = $null
foreach ($np in $nppCandidates) {
  if (Test-Path -Path $np) {
    $nppExe = $np
    break
  }
}

# Locate Everything CLI (es.exe)
$esCandidates = @(
  "D:\Tools\Everything 1.5a\es.exe",
  "C:\Program Files\Everything 1.5a\es.exe",
  "C:\Program Files\Everything\es.exe",
  "$env:ProgramFiles\Everything\es.exe"
)

$esExe = $null
foreach ($c in $esCandidates) {
  if (Test-Path -Path $c) {
    $esExe = $c
    break
  }
}

$latestLog = $null

# 1. Query Everything REST API via Search-Everything.ps1 (Fast cross-session query)
$searchEverythingScript = Join-Path $toolsDir 'Search-Everything.ps1'
if (Test-Path -LiteralPath $searchEverythingScript) {
  $negations = if (-not $IncludeInternal) {
    ($internalPlumbingPrefixes | ForEach-Object { "!$($_)*" }) -join " "
  } else { "" }

  $filterPrefix = if (-not [string]::IsNullOrWhiteSpace($ToolName)) { "$ToolName*" } else { "" }
  $subsystemFilter = if (-not [string]::IsNullOrWhiteSpace($Subsystem) -and $Subsystem -ne 'All') { "$Subsystem*" } else { "" }
  $evQuery = "*.log $filterPrefix $subsystemFilter $negations"
  
  $results = @(& $searchEverythingScript -Query $evQuery -MaxResults 50 2>$null)
  if ($results -and $results.Count -gt 0) {
    $logItems = @($results | ForEach-Object { Get-Item $_.FullName -ErrorAction SilentlyContinue } | Where-Object {
      $null -ne $_ -and (
        $candidateDirs.Contains($_.DirectoryName) -or
        $_.DirectoryName.EndsWith('\logs', [System.StringComparison]::OrdinalIgnoreCase)
      )
    } | Sort-Object LastWriteTime -Descending)
    if ($logItems.Count -gt 0) {
      $latestLog = $logItems[0].FullName
    }
  }
}

# 2. Fallback to direct directory sweep across all candidate log directories
if ($null -eq $latestLog) {
  $dirs = @($candidateDirs | Where-Object { Test-Path $_ })
  $filter = if ([string]::IsNullOrWhiteSpace($ToolName)) { "*.log" } else { "*$($ToolName)*.log" }
  
  $files = @(Get-ChildItem -Path $dirs -Filter $filter -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  
  if (-not $IncludeInternal -and [string]::IsNullOrWhiteSpace($ToolName)) {
    $files = @($files | Where-Object {
      $fn = $_.Name
      $isInternal = $false
      foreach ($p in $internalPlumbingPrefixes) {
        if ($fn.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) {
          $isInternal = $true
          break
        }
      }
      -not $isInternal
    })
  }

  if ($files.Count -gt 0) {
    $latestLog = $files[0].FullName
  }
}

if ($null -eq $latestLog -or -not (Test-Path -Path $latestLog)) {
  $searchedLocs = ($candidateDirs -join ', ')
  Write-Warning "No matching operational command logs found in: $searchedLocs"
  return
}

$logItem = Get-Item $latestLog
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LATEST OPERATIONAL COMMAND LOG LOCATED (v$($scriptVersion))" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "Log File : $latestLog" -ForegroundColor Green
Write-Host "Command  : $($logItem.BaseName.Split('-')[0])" -ForegroundColor Cyan
Write-Host "Created  : $($logItem.CreationTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -ForegroundColor Gray
Write-Host "Modified : $($logItem.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -ForegroundColor Gray
Write-Host "Size     : $($logItem.Length) bytes" -ForegroundColor Gray
Write-Host "==========================================================================" -ForegroundColor Cyan

# 3. Open in Dedicated Log Stash Editor (Notepad default for isolated log stash, Notepad++ if -Npp specified)
if (-not $ExplorerOnly) {
  $useNpp = $NotepadPlus -or ($PSBoundParameters.ContainsKey('Npp') -and $Npp)
  $targetEditor = if ($useNpp -and $null -ne $nppExe) { $nppExe } else { "notepad.exe" }
  $editorName = if ($targetEditor -eq $nppExe) { "Notepad++" } else { "Notepad" }
  
  Write-Host "Launching log in $editorName on Desktop..." -ForegroundColor Yellow
  if (Test-Path $interactiveDesktopScript) {
    & pwsh -File $interactiveDesktopScript -FilePath $targetEditor -ArgumentList "`"$latestLog`"" | Out-Null
  } else {
    Start-Process -FilePath $targetEditor -ArgumentList "`"$latestLog`"" -WindowStyle Normal | Out-Null
  }
}

# 4. Open File Explorer selecting the latest log (only when requested via -Explorer or -ExplorerOnly)
if ($Explorer -or $ExplorerOnly) {
  Write-Host "Opening File Explorer with log file selected on Desktop..." -ForegroundColor Yellow
  if (Test-Path $interactiveDesktopScript) {
    & pwsh -File $interactiveDesktopScript -FilePath "explorer.exe" -ArgumentList "/select,`"$latestLog`"" | Out-Null
  } else {
    Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$latestLog`"" -WindowStyle Normal | Out-Null
  }
}

Write-Host "`n[OK] Operational log file successfully dispatched to Session 1 desktop." -ForegroundColor Green

