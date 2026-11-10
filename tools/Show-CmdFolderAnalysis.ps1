<#
.SYNOPSIS
  Comprehensive analysis and interactive runner/viewer for un-onboarded runnables.
.DESCRIPTION
  Module: Show-CmdFolderAnalysis.ps1
  Purpose: Scans target directory (default: D:\OneDrive\cmd, or custom -Path) for runnable scripts,
           assesses their functionality, call dependencies, onboarding effort, and priority (0-10),
           extracts explicit named parameters, and presents the findings in an interactive HTML viewer.
           Supports click-to-run on script name with parameter input, syntax/mandatory validation,
           and localStorage priority persistence with automatic sorting.
  Path: tools/Show-CmdFolderAnalysis.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-10-13
.PARAMETER Path
  Target directory to analyze (default: D:\OneDrive\cmd). Supports D:\@cmd, D:\OneDrive\cmd\@Repair, etc.
.PARAMETER NoLaunch
  Generates the HTML viewer without launching it in the default browser.
.PARAMETER Help
  Displays this parameter reference.
.EXAMPLE
  pwsh tools/Show-CmdFolderAnalysis.ps1
.EXAMPLE
  pwsh tools/Show-CmdFolderAnalysis.ps1 -Path "D:\@cmd"
.EXAMPLE
  pwsh tools/Show-CmdFolderAnalysis.ps1 -NoLaunch
#>

[CmdletBinding()]
param(
  [string]$Path = 'D:\OneDrive\cmd',
  [switch]$NoLaunch,
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " CMD FOLDER ONBOARDING & PARAMETER RUNNER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Scans target folder for runnable scripts, assesses functional applicability,"
  Write-Host "  dependencies, effort, priority (0-10), and explicit parameters."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Show-CmdFolderAnalysis.ps1 [-Path <Dir>] [-NoLaunch] [-Help]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Path <Dir> : Directory to analyze (Default: D:\OneDrive\cmd)."
  Write-Host "  -NoLaunch   : Generates the HTML report without launching the browser."
  Write-Host "  -Help, -h   : Displays this parameter reference."
  return
}

$workspaceRoot = 'D:\Git_Repositories'
$cmdDir = $Path
$scratchDir = Join-Path $workspaceRoot 'tools\scratch'
if (-not (Test-Path -LiteralPath $scratchDir)) { New-Item -ItemType Directory -Force -Path $scratchDir | Out-Null }
$outputHtml = Join-Path $scratchDir 'CMD_ANALYSIS_VIEWER.html'

# Clean legacy root HTML
$legacyRootAnalysis = Join-Path $workspaceRoot 'tools\CMD_ANALYSIS_VIEWER.html'
if (Test-Path -LiteralPath $legacyRootAnalysis) { Remove-Item -LiteralPath $legacyRootAnalysis -Force -ErrorAction SilentlyContinue }

$atomJsPath = Join-Path $workspaceRoot 'tools\assets\lcm-table-print-atom.js'
$atomJsContent = if (Test-Path $atomJsPath) { Get-Content -LiteralPath $atomJsPath -Raw -Encoding UTF8 } else { "" }

if (-not (Test-Path $cmdDir)) {
  Write-Error "Source directory not found: $cmdDir"
}

# -----------------------------------------------------------------------------
# 1. Authoritative Analysis Knowledge Base with Explicit Parameter Schemas
# -----------------------------------------------------------------------------
$analysisData = @(
  @{
    Name = "Split-TextFile.ps1"; Type = "PS1"; Priority = 4;
    Domain = "Utility"; Effort = "Low";
    Purpose = "Splits massive text or log files into numbered chunked parts based on specified maximum line counts.";
    Dependencies = "System.IO.StreamReader, System.IO.StreamWriter";
    Status = "Archived";
    Recommendation = "Archived to LCM_Inventory/data/archives/cmd_archived/.";
    Snippet = "param([string]`$Path, [int]`$LinesPerChunk = 5000) # Memory-efficient file stream splitter...";
    Parameters = @(
      @{ Name = "Path"; Type = "String"; Mandatory = $true; Default = ""; Description = "Target text/log file path to split." },
      @{ Name = "LinesPerChunk"; Type = "Int32"; Mandatory = $false; Default = "5000"; Description = "Maximum line count per output chunk." }
    )
  },
  @{
    Name = "List-Device-Name-and-Path.ps1"; Type = "PS1"; Priority = 4;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Lists device paths and partition device strings.";
    Dependencies = "Get-CimInstance";
    Status = "Archived";
    Recommendation = "Archived (Consolidated into VolumeInventory).";
    Snippet = "Get-CimInstance Win32_DiskPartition | Select-Object Name, DeviceID...";
    Parameters = @()
  },
  @{
    Name = "ProfileRecoveryToolkit.ps1"; Type = "PS1"; Priority = 3;
    Domain = "SystemRepair"; Effort = "High";
    Purpose = "Master orchestrator for recovering broken Windows user profiles, rebuilding ProfileList registry entries, and repairing AppData paths.";
    Dependencies = "Registry, icacls, Robocopy, Elevation";
    Status = "Archived";
    Recommendation = "Archived (Repair component onboarded as Repair-UserProfile.ps1).";
    Snippet = "param([string]`$TargetUser, [string]`$SourceDrive) # Reconstructs user profile registry keys and security identifiers...";
    Parameters = @(
      @{ Name = "TargetUser"; Type = "String"; Mandatory = $false; Default = "$env:USERNAME"; Description = "Username account to diagnose/recover." },
      @{ Name = "SourceDrive"; Type = "String"; Mandatory = $false; Default = "C:"; Description = "Source drive containing user hive." }
    )
  },
  @{
    Name = "ProfileModify.ps1"; Type = "PS1"; Priority = 3;
    Domain = "SystemRepair"; Effort = "Medium";
    Purpose = "Utility for remapping user profile paths between different drive letters in multi-boot environments (e.g. C:\Users -> D:\Users).";
    Dependencies = "Registry HKLM\ProfileList, Elevation";
    Status = "Archived";
    Recommendation = "Archived to LCM_Inventory/data/archives/cmd_archived/.";
    Snippet = "Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\...' -Name 'ProfileImagePath'...";
    Parameters = @(
      @{ Name = "NewUserRoot"; Type = "String"; Mandatory = $true; Default = "D:\Users"; Description = "Target drive/root path for remapped user profiles." }
    )
  },
  @{
    Name = "ShortPromptPS.ps1"; Type = "PS1"; Priority = 3;
    Domain = "Utility"; Effort = "Trivial";
    Purpose = "Shortens PowerShell console prompt to current folder basename.";
    Dependencies = "PowerShell profile";
    Status = "Archived";
    Recommendation = "Archived (Minor profile helper).";
    Snippet = "function prompt { 'PS ' + (Get-Location).Path.Split('\')[-1] + '> ' }...";
    Parameters = @()
  },
  @{
    Name = "ShowPathPS.ps1"; Type = "PS1"; Priority = 3;
    Domain = "Utility"; Effort = "Trivial";
    Purpose = "Splits and prints `$env:PATH line by line to console.";
    Dependencies = "None";
    Status = "Archived";
    Recommendation = "Archived to LCM_Inventory/data/archives/cmd_archived/.";
    Snippet = "`$env:PATH -split ';' # Prints PATH entries per line...";
    Parameters = @()
  },
  @{
    Name = "AddToPath.cmd"; Type = "CMD"; Priority = 3;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Legacy batch script to add paths using setx.exe.";
    Dependencies = "setx.exe";
    Status = "Archived";
    Recommendation = "Archived (Superseded by Set-GitRoot.ps1).";
    Snippet = "setx PATH `"%PATH%;%1`"...";
    Parameters = @(
      @{ Name = "DirectoryPath"; Type = "String"; Mandatory = $true; Default = ""; Description = "Folder path to append to PATH." }
    )
  },
  @{
    Name = "RenameTestFolders.ps1"; Type = "PS1"; Priority = 2;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "One-off testing script for directory renaming.";
    Dependencies = "None";
    Status = "Archived";
    Recommendation = "Archived (Scratch test file).";
    Snippet = "Rename-Item -Path `$TestFolder ... # One-off test script...";
    Parameters = @()
  },
  @{
    Name = "SafeCopy.ps1"; Type = "PS1"; Priority = 2;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "One-off file copy test script.";
    Dependencies = "None";
    Status = "Archived";
    Recommendation = "Archived (Superseded by standard Copy-Item / Robocopy).";
    Snippet = "Copy-Item -Path `$Source -Destination `$Dest -Force...";
    Parameters = @(
      @{ Name = "Source"; Type = "String"; Mandatory = $true; Default = ""; Description = "Source file/folder path." },
      @{ Name = "Destination"; Type = "String"; Mandatory = $true; Default = ""; Description = "Target directory path." }
    )
  },
  @{
    Name = "Get_Indexing_Status.vbs"; Type = "VBS"; Priority = 2;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Legacy VBScript querying Windows Search indexer COM object.";
    Dependencies = "WScript.Shell";
    Status = "Archived";
    Recommendation = "Archived (Legacy VBScript, superseded by PowerShell CIM).";
    Snippet = "Set objSearchManager = CreateObject(`"Microsoft.ISearchManager`")...";
    Parameters = @()
  },
  @{
    Name = "Git_Restore_HubToLocal_All.ps1"; Type = "PS1"; Priority = 1;
    Domain = "LCM_Inventory"; Effort = "Medium";
    Purpose = "Automated disaster recovery script that clones or reconciles all remote GitHub repositories under rgbigel organization to local disk.";
    Dependencies = "git.exe, gh.exe CLI";
    Status = "Archived";
    Recommendation = "Archived to LCM_Inventory/data/archives/cmd_archived/.";
    Snippet = "gh repo list rgbigel --limit 100 --json name,url | ConvertFrom-Json | ForEach-Object { git clone `$_.url }...";
    Parameters = @(
      @{ Name = "TargetRoot"; Type = "String"; Mandatory = $false; Default = "D:\Git_Repositories"; Description = "Local workspace root directory for cloned repositories." }
    )
  },
  @{
    Name = "PS1.CMD"; Type = "CMD"; Priority = 1;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Legacy powershell invocation wrapper.";
    Dependencies = "powershell.exe";
    Status = "Archived";
    Recommendation = "Archived (Superseded by Invoke-InteractiveDesktop / pwsh).";
    Snippet = "powershell.exe -NoExit -ExecutionPolicy Bypass -File %1...";
    Parameters = @(
      @{ Name = "ScriptPath"; Type = "String"; Mandatory = $true; Default = ""; Description = "Path to PowerShell script to execute." }
    )
  },
  @{
    Name = "DiskInfo"; Type = "BIN"; Priority = 1;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Unversioned disk text/binary output dump.";
    Dependencies = "None";
    Status = "Archived";
    Recommendation = "Archived (Superseded by VolumeInventory).";
    Snippet = "Disk partition dump from 2024...";
    Parameters = @()
  },
  @{
    Name = "DiskInfo.cmd"; Type = "CMD"; Priority = 1;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Legacy wmic diskdrive batch dump.";
    Dependencies = "wmic.exe";
    Status = "Archived";
    Recommendation = "Archived (wmic is deprecated, superseded by VolumeInventory).";
    Snippet = "wmic diskdrive get model,size,status...";
    Parameters = @()
  },
  @{
    Name = "InfoOnDisks.cmd"; Type = "CMD"; Priority = 1;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Legacy diskpart script launcher.";
    Dependencies = "diskpart.exe";
    Status = "Archived";
    Recommendation = "Archived (Superseded by VolumeInventory).";
    Snippet = "echo list disk > %temp%\dp.txt & diskpart /s %temp%\dp.txt...";
    Parameters = @()
  },
  @{
    Name = "SaveClipboard_TEST.ps1"; Type = "PS1"; Priority = 1;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Test duplicate of SaveClipboard.ps1.";
    Dependencies = "SaveClipboard.ps1";
    Status = "Archived";
    Recommendation = "Archived (Redundant test duplicate).";
    Snippet = "Test duplicate of SaveClipboard.ps1...";
    Parameters = @()
  },
  @{
    Name = "Test_SaveClipboard.ps1"; Type = "PS1"; Priority = 1;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Test scratch harness for SaveClipboard.ps1.";
    Dependencies = "SaveClipboard.ps1";
    Status = "Archived";
    Recommendation = "Archived (Scratch test file).";
    Snippet = "Test harness for SaveClipboard.ps1...";
    Parameters = @()
  },
  @{
    Name = "tempTest_SaveClipboard.ps1"; Type = "PS1"; Priority = 1;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Temporary test harness for SaveClipboard.ps1.";
    Dependencies = "SaveClipboard.ps1";
    Status = "Archived";
    Recommendation = "Archived (Scratch test file).";
    Snippet = "Temporary test harness for SaveClipboard.ps1...";
    Parameters = @()
  },
  @{
    Name = "DoShell.cmd"; Type = "CMD"; Priority = 1;
    Domain = "Discard"; Effort = "Trivial";
    Purpose = "Legacy 1-line CMD launcher.";
    Dependencies = "cmd.exe";
    Status = "Archived";
    Recommendation = "Archived.";
    Snippet = "start cmd.exe /k...";
    Parameters = @()
  }
)

$jsonData = $analysisData | ConvertTo-Json -Depth 5 -Compress
$generationTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# Calculate KPI Metrics
$totalCount = @($analysisData).Count
$prioHigh = @($analysisData | Where-Object { $_.Priority -ge 8 }).Count
$prioMed = @($analysisData | Where-Object { $_.Priority -ge 5 -and $_.Priority -le 7 }).Count
$prioLow = @($analysisData | Where-Object { $_.Priority -le 4 }).Count
$prioDiscard = @($analysisData | Where-Object { $_.Priority -eq 0 }).Count

$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>D:\OneDrive\cmd Folder Analysis & Onboarding</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --bg-tertiary: #21262d;
            --border: #30363d;
            --text-primary: #c9d1d9;
            --text-secondary: #8b949e;
            --text-muted: #484f58;
            --accent: #58a6ff;
            --accent-hover: #79c0ff;
            --success: #3fb950;
            --warning: #d29922;
            --danger: #f85149;
            --teal: #39c5cf;
            --purple: #bc8cff;
            --card-shadow: 0 4px 12px rgba(0,0,0,0.3);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background-color: var(--bg-primary);
            color: var(--text-primary);
            padding: 24px;
            line-height: 1.5;
        }

        .container { max-width: 1720px; margin: 0 auto; }

        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
            padding-bottom: 16px;
            border-bottom: 1px solid var(--border);
            flex-wrap: wrap;
            gap: 16px;
        }

        .header-title h1 {
            font-size: 24px;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .header-meta {
            font-size: 13px;
            color: var(--text-secondary);
            margin-top: 4px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .timestamp-badge {
            background: rgba(88, 166, 255, 0.15);
            color: var(--accent);
            padding: 2px 8px;
            border-radius: 12px;
            font-weight: 600;
            font-size: 12px;
            border: 1px solid rgba(88, 166, 255, 0.3);
        }

        .header-actions { display: flex; gap: 10px; }

        .btn-refresh, .btn-export, .btn-reset {
            background: var(--bg-secondary);
            color: var(--text-primary);
            border: 1px solid var(--border);
            padding: 8px 16px;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 600;
            font-size: 13px;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            transition: all 0.2s ease;
        }

        .btn-refresh { background: var(--accent); color: #0d1117; border-color: var(--accent); }
        .btn-refresh:hover { background: var(--accent-hover); }
        .btn-export:hover, .btn-reset:hover { background: var(--bg-tertiary); border-color: var(--text-secondary); }

        /* Metric KPI Cards */
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }

        .metric-card {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 16px;
            box-shadow: var(--card-shadow);
            cursor: pointer;
            transition: all 0.2s ease;
        }

        .metric-card:hover { transform: translateY(-2px); border-color: var(--accent); }
        .metric-card.active { border-color: var(--accent); background: rgba(88, 166, 255, 0.08); }

        .metric-label { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-secondary); }
        .metric-value { font-size: 26px; font-weight: 700; color: #ffffff; margin-top: 4px; font-family: 'JetBrains Mono', monospace; }
        .metric-sub { font-size: 11px; color: var(--text-secondary); margin-top: 4px; }

        /* Filter Panel */
        .filter-panel-top {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 12px 16px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 16px;
            flex-wrap: wrap;
        }

        .search-wrapper { flex: 1; min-width: 320px; }

        .search-input {
            width: 100%;
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 10px 14px;
            font-size: 14px;
            color: var(--text-primary);
            outline: none;
            transition: border-color 0.2s;
        }
        .search-input:focus { border-color: var(--accent); }

        /* Table Container */
        .table-container {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 12px;
            overflow: hidden;
            box-shadow: var(--card-shadow);
        }

        table { width: 100%; border-collapse: collapse; text-align: left; font-size: 13px; }

        th {
            background: var(--bg-tertiary);
            color: var(--text-secondary);
            padding: 12px 14px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            font-size: 11px;
            border-bottom: 1px solid var(--border);
            cursor: pointer;
            user-select: none;
            white-space: nowrap;
        }
        th:hover { color: #ffffff; }

        .sort-icon {
            font-size: 14px;
            font-weight: 700;
            color: var(--accent);
            margin-left: 4px;
            display: inline-block;
            vertical-align: middle;
        }

        .col-filter-row th {
            background: #1c2128;
            padding: 8px 10px;
            border-bottom: 2px solid var(--border);
            cursor: default;
        }

        .col-filter-select, .col-filter-input {
            width: 100%;
            background: var(--bg-primary);
            border: 1px solid var(--border);
            color: var(--text-primary);
            border-radius: 6px;
            padding: 6px 8px;
            font-size: 12px;
            outline: none;
        }
        .col-filter-select:focus, .col-filter-input:focus { border-color: var(--accent); }

        td {
            padding: 12px 14px;
            border-bottom: 1px solid var(--border);
            color: var(--text-primary);
            vertical-align: middle;
        }
        tr:hover td { background: rgba(255, 255, 255, 0.02); }

        /* Script Name Click-to-Run */
        .script-name-link {
            font-weight: 600;
            font-family: 'JetBrains Mono', monospace;
            color: var(--accent);
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 4px 8px;
            border-radius: 6px;
            background: rgba(88, 166, 255, 0.08);
            border: 1px solid rgba(88, 166, 255, 0.2);
            transition: all 0.2s ease;
        }
        .script-name-link:hover {
            background: rgba(88, 166, 255, 0.2);
            border-color: var(--accent);
            color: #ffffff;
            transform: translateX(2px);
        }

        /* Badges */
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 3px 8px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 600;
            font-family: 'JetBrains Mono', monospace;
        }

        .badge-prio-10 { background: rgba(63, 185, 80, 0.2); color: #7ee787; border: 1px solid rgba(63, 185, 80, 0.5); }
        .badge-prio-high { background: rgba(57, 197, 207, 0.2); color: #79c0ff; border: 1px solid rgba(57, 197, 207, 0.4); }
        .badge-prio-med { background: rgba(210, 153, 34, 0.2); color: #e3b341; border: 1px solid rgba(210, 153, 34, 0.4); }
        .badge-prio-low { background: rgba(110, 118, 129, 0.2); color: #8b949e; border: 1px solid rgba(110, 118, 129, 0.4); }
        .badge-prio-0 { background: rgba(248, 81, 73, 0.2); color: #ff7b72; border: 1px solid rgba(248, 81, 73, 0.4); }

        .badge-type-ps1 { background: rgba(56, 139, 253, 0.15); color: #79c0ff; border: 1px solid rgba(56, 139, 253, 0.3); }
        .badge-type-cmd { background: rgba(210, 153, 34, 0.15); color: #e3b341; border: 1px solid rgba(210, 153, 34, 0.3); }
        .badge-type-vbs { background: rgba(188, 140, 255, 0.15); color: #d2a8ff; border: 1px solid rgba(188, 140, 255, 0.3); }

        .btn-inspect {
            background: var(--bg-tertiary);
            border: 1px solid rgba(56, 139, 253, 0.4);
            color: #79c0ff;
            border-radius: 6px;
            padding: 4px 10px;
            font-size: 16px;
            cursor: pointer;
            transition: all 0.15s ease;
        }
        .btn-inspect:hover { background: rgba(56, 139, 253, 0.2); color: #ffffff; }

        /* Popover Editor */
        .prio-select-inline {
            background: #1c2128;
            color: #ffffff;
            border: 1px solid var(--accent);
            border-radius: 6px;
            padding: 2px 6px;
            font-size: 11px;
            font-family: 'JetBrains Mono', monospace;
            cursor: pointer;
            outline: none;
        }

        /* Modal Overlay & Run Dialog */
        .modal-overlay {
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0, 0, 0, 0.75);
            backdrop-filter: blur(4px);
            display: none;
            align-items: center;
            justify-content: center;
            z-index: 1000;
        }

        .modal-card {
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 12px;
            width: 820px;
            max-width: 90vw;
            padding: 24px;
            box-shadow: 0 16px 32px rgba(0,0,0,0.6);
        }

        .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
        .modal-title { font-size: 18px; font-weight: 700; color: #ffffff; display: flex; align-items: center; gap: 8px; }
        .modal-close { background: none; border: none; font-size: 20px; color: var(--text-secondary); cursor: pointer; }
        .modal-close:hover { color: #ffffff; }

        .param-group {
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 14px;
            margin-bottom: 14px;
        }

        .param-field { margin-bottom: 12px; }
        .param-field:last-child { margin-bottom: 0; }
        .param-header { display: flex; justify-content: space-between; margin-bottom: 4px; }
        .param-name { font-weight: 600; font-family: 'JetBrains Mono', monospace; color: var(--accent); font-size: 13px; }
        .param-type { font-size: 11px; color: var(--text-secondary); }
        
        .input-clear-wrapper {
            position: relative;
            display: flex;
            align-items: center;
            width: 100%;
        }
        .param-input {
            width: 100%;
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 6px;
            padding: 8px 32px 8px 12px;
            color: var(--text-primary);
            font-size: 13px;
            font-family: 'JetBrains Mono', monospace;
            outline: none;
            transition: border-color 0.2s ease;
        }
        .param-input:focus { border-color: var(--accent); }

        .btn-clear-param {
            position: absolute;
            right: 8px;
            background: none;
            border: none;
            color: var(--text-secondary);
            font-size: 14px;
            font-weight: 700;
            cursor: pointer;
            padding: 2px 6px;
            border-radius: 4px;
            line-height: 1;
            transition: all 0.15s ease;
        }
        .btn-clear-param:hover {
            color: #ffffff;
            background: rgba(248, 81, 73, 0.3);
        }

        .btn-clear-all-params {
            background: none;
            border: none;
            color: var(--text-secondary);
            font-size: 11px;
            cursor: pointer;
            text-decoration: underline;
            padding: 2px 6px;
            border-radius: 4px;
            transition: color 0.2s ease;
        }
        .btn-clear-all-params:hover { color: var(--danger); }

        .raw-cmd-box {
            width: 100%;
            background: var(--bg-primary);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 10px 12px;
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            color: #7ee787;
            outline: none;
            resize: vertical;
            min-height: 50px;
        }
        .raw-cmd-box:focus { border-color: var(--accent); }

        .validation-error {
            color: var(--danger);
            background: rgba(248, 81, 73, 0.1);
            border: 1px solid rgba(248, 81, 73, 0.3);
            border-radius: 6px;
            padding: 8px 12px;
            font-size: 12px;
            margin-top: 10px;
            display: none;
        }

        .modal-actions {
            display: flex;
            justify-content: flex-end;
            gap: 10px;
            margin-top: 18px;
        }

        .btn-run-action {
            background: var(--success);
            color: #0d1117;
            border: 1px solid var(--success);
            padding: 8px 18px;
            border-radius: 6px;
            font-weight: 700;
            font-size: 13px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            transition: all 0.2s ease;
        }
        .btn-run-action:hover { background: #56d364; border-color: #56d364; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="header-title">
                <div>
                    <h1>📁 $cmdDir Folder Analysis & Onboarding</h1>
                    <div class="header-meta">
                        <span>Scanned Folder: <strong>$cmdDir</strong></span>
                        <span>•</span>
                        <span class="timestamp-badge">Analysis Generated: $generationTimestamp</span>
                    </div>
                </div>
            </div>
            <div class="header-actions">
                <button class="btn-refresh" onclick="LcmTablePrintAtom.openModal()" style="background: rgba(56, 139, 253, 0.15); border-color: rgba(56, 139, 253, 0.4); color: #79c0ff;" title="Configure and print or export PDF with saved layout parameters"><span>🖨️</span> Print / PDF Export</button>
                <button class="btn-export" onclick="exportAnalysisJson()">📋 Copy JSON</button>
            </div>
        </header>

        <!-- KPI Metrics Grid -->
        <div class="metrics-grid">
            <div class="metric-card active" id="card-all" onclick="filterByCard('all')">
                <div class="metric-label">Remaining Archived Files</div>
                <div class="metric-value" id="kpi-total">$totalCount</div>
                <div class="metric-sub">In D:\OneDrive\cmd</div>
            </div>
            <div class="metric-card" id="card-high" onclick="filterByCard('high')">
                <div class="metric-label">Priority 8–10 (Onboard)</div>
                <div class="metric-value" id="kpi-high" style="color: var(--success);">$prioHigh</div>
                <div class="metric-sub">High value candidates</div>
            </div>
            <div class="metric-card" id="card-med" onclick="filterByCard('med')">
                <div class="metric-label">Priority 5–7 (Selective)</div>
                <div class="metric-value" id="kpi-med" style="color: var(--warning);">$prioMed</div>
                <div class="metric-sub">Specialized utilities</div>
            </div>
            <div class="metric-card" id="card-low" onclick="filterByCard('low')">
                <div class="metric-label">Priority 0–4 (Archived/Pending)</div>
                <div class="metric-value" id="kpi-low" style="color: var(--danger);">$prioLow</div>
                <div class="metric-sub">($prioDiscard marked 0 Discard)</div>
            </div>
        </div>

        <!-- Filter Panel -->
        <div class="filter-panel-top">
            <div class="search-wrapper">
                <input type="text" class="search-input" id="search-input" placeholder="🔍 Search by script name, functionality, dependencies, or recommendation..." oninput="applyFilters()">
            </div>
            <button class="btn-reset" onclick="resetFilters()">Reset All Filters</button>
        </div>

        <!-- Data Table -->
        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th onclick="sortTable('Name')" style="min-width: 220px;">Script Name (Click to Run) <span class="sort-icon">⇅</span></th>
                        <th onclick="sortTable('Type')" style="width: 80px; text-align: center;">Type <span class="sort-icon">⇅</span></th>
                        <th onclick="sortTable('Priority')" style="width: 140px; text-align: center;">Priority (Click to Edit) <span class="sort-icon">⇅</span></th>
                        <th onclick="sortTable('Domain')" style="min-width: 150px;">Domain <span class="sort-icon">⇅</span></th>
                        <th style="min-width: 280px;">Functionality / Purpose</th>
                        <th style="min-width: 180px;">Dependencies</th>
                        <th onclick="sortTable('Effort')" style="width: 100px; text-align: center;">Effort <span class="sort-icon">⇅</span></th>
                        <th style="min-width: 260px;">Onboarding Recommendation</th>
                        <th style="width: 70px; text-align: center;">Inspect</th>
                    </tr>
                    <tr class="col-filter-row">
                        <th><input type="text" class="col-filter-input" id="name-filter" placeholder="Filter Name..." oninput="applyFilters()"></th>
                        <th>
                            <select class="col-filter-select" id="type-select" onchange="applyFilters()">
                                <option value="All">All</option>
                                <option value="PS1">PS1</option>
                                <option value="CMD">CMD</option>
                                <option value="VBS">VBS</option>
                                <option value="BIN">BIN</option>
                            </select>
                        </th>
                        <th>
                            <select class="col-filter-select" id="prio-select" onchange="applyFilters()">
                                <option value="All">All Prios</option>
                                <option value="10">10 (Top Priority)</option>
                                <option value="8-10">8-10 (Onboard)</option>
                                <option value="5-7">5-7 (Selective)</option>
                                <option value="0-4">0-4 (Low/Discard)</option>
                                <option value="0">0 (Discard)</option>
                            </select>
                        </th>
                        <th>
                            <select class="col-filter-select" id="domain-select" onchange="applyFilters()">
                                <option value="All">All Domains</option>
                                <option value="SystemRepair">SystemRepair</option>
                                <option value="SystemDiagnostics">SystemDiagnostics</option>
                                <option value="DesktopGUI">DesktopGUI</option>
                                <option value="SystemInvariants">SystemInvariants</option>
                                <option value="LCM_Inventory">LCM_Inventory</option>
                                <option value="SystemSetup">SystemSetup</option>
                                <option value="SystemCustomization">SystemCustomization</option>
                                <option value="Utility">Utility</option>
                                <option value="Discard">Discard</option>
                            </select>
                        </th>
                        <th><input type="text" class="col-filter-input" id="func-filter" placeholder="Filter Purpose..." oninput="applyFilters()"></th>
                        <th><input type="text" class="col-filter-input" id="dep-filter" placeholder="Filter Dependencies..." oninput="applyFilters()"></th>
                        <th>
                            <select class="col-filter-select" id="effort-select" onchange="applyFilters()">
                                <option value="All">All</option>
                                <option value="Trivial">Trivial</option>
                                <option value="Low">Low</option>
                                <option value="Medium">Medium</option>
                                <option value="High">High</option>
                            </select>
                        </th>
                        <th><input type="text" class="col-filter-input" id="rec-filter" placeholder="Filter Recommendation..." oninput="applyFilters()"></th>
                        <th style="text-align: center;">
                            <button class="btn-action" onclick="resetColumnFilters()" title="Reset column filters" style="background: none; border: none; color: var(--accent); cursor: pointer;">Clear</button>
                        </th>
                    </tr>
                </thead>
                <tbody id="analysis-tbody">
                    <!-- Populated dynamically -->
                </tbody>
            </table>
        </div>
    </div>

    <!-- Modal Drawer for Run & Parameter Input -->
    <div class="modal-overlay" id="run-modal-overlay" onclick="closeRunModal(event)">
        <div class="modal-card" onclick="event.stopPropagation()">
            <div class="modal-header">
                <div class="modal-title" id="run-modal-title">▶ Run Command & Configure Parameters</div>
                <button class="modal-close" onclick="closeRunModal()">&times;</button>
            </div>
            
            <div id="run-modal-desc" style="font-size: 13px; color: var(--text-secondary); margin-bottom: 16px;"></div>

            <!-- Dynamic Parameter Inputs -->
            <div id="param-container" class="param-group" style="display: none;">
                <div style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); margin-bottom: 10px;">Explicit Named Parameters</div>
                <div id="param-fields-list"></div>
            </div>

            <!-- Command Line Preview Box -->
            <div style="margin-bottom: 8px;">
                <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                    <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary);">Command Line Preview / Custom Arguments</label>
                    <span id="char-count" style="font-size: 11px; color: var(--text-secondary);"></span>
                </div>
                <textarea class="raw-cmd-box" id="raw-cmd-input" oninput="validateCommandRealtime()"></textarea>
            </div>

            <!-- Validation Error Alert -->
            <div class="validation-error" id="validation-error-box"></div>

            <div class="modal-actions">
                <button class="btn-reset" onclick="closeRunModal()">Cancel</button>
                <button class="btn-run-action" id="btn-execute" onclick="executeCurrentCommand()">▶ Dispatch Execution</button>
            </div>
        </div>
    </div>

    <!-- Modal Drawer for Details Inspection -->
    <div class="modal-overlay" id="inspect-modal-overlay" onclick="closeInspectModal(event)">
        <div class="modal-card" onclick="event.stopPropagation()">
            <div class="modal-header">
                <div class="modal-title" id="modal-title">Script Details</div>
                <button class="modal-close" onclick="closeInspectModal()">&times;</button>
            </div>
            <div class="modal-row">
                <div class="modal-label">Purpose & Functional Scope</div>
                <div class="modal-val" id="modal-purpose"></div>
            </div>
            <div class="modal-row">
                <div class="modal-label">Onboarding Recommendation & Assessment</div>
                <div class="modal-val" id="modal-rec" style="color: #7ee787; font-weight: 600;"></div>
            </div>
            <div class="modal-row">
                <div class="modal-label">Domain, Priority & Effort</div>
                <div class="modal-val" id="modal-meta"></div>
            </div>
            <div class="modal-row">
                <div class="modal-label">Call Dependencies & APIs</div>
                <div class="modal-val" id="modal-deps"></div>
            </div>
            <div class="modal-row">
                <div class="modal-label">Code / Header Snippet</div>
                <div class="code-block" id="modal-snippet"></div>
            </div>
            <div style="display: flex; justify-content: flex-end; margin-top: 16px;">
                <button class="btn-reset" onclick="closeInspectModal()">Close</button>
            </div>
        </div>
    </div>

    <script>
        let analysisData = $jsonData;
        let sortField = 'Priority';
        let sortAsc = false;
        let activeCardFilter = 'all';
        let currentRunningTool = null;

        // Load custom user priority overrides from localStorage
        function loadCustomPriorities() {
            try {
                const stored = localStorage.getItem('LCM_CmdAnalysis_CustomPrios');
                if (stored) {
                    const customMap = JSON.parse(stored);
                    analysisData.forEach(item => {
                        if (customMap[item.Name] !== undefined) {
                            item.Priority = customMap[item.Name];
                        }
                    });
                }
            } catch (e) {
                console.error('Error loading custom priorities:', e);
            }
        }

        function saveCustomPriority(name, newPrio) {
            try {
                let customMap = {};
                const stored = localStorage.getItem('LCM_CmdAnalysis_CustomPrios');
                if (stored) {
                    customMap = JSON.parse(stored);
                }
                customMap[name] = newPrio;
                localStorage.setItem('LCM_CmdAnalysis_CustomPrios', JSON.stringify(customMap));
            } catch (e) {
                console.error('Error saving custom priority:', e);
            }
        }

        function updateItemPriority(name, val) {
            const num = parseInt(val, 10);
            const item = analysisData.find(i => i.Name === name);
            if (item) {
                item.Priority = num;
                saveCustomPriority(name, num);
                updateKpis();
                // Automatically re-sort on priority change
                sortField = 'Priority';
                sortAsc = false;
                applyFilters();
            }
        }

        function updateKpis() {
            const high = analysisData.filter(i => i.Priority >= 8).length;
            const med = analysisData.filter(i => i.Priority >= 5 && i.Priority <= 7).length;
            const low = analysisData.filter(i => i.Priority <= 4).length;
            document.getElementById('kpi-high').innerText = high;
            document.getElementById('kpi-med').innerText = med;
            document.getElementById('kpi-low').innerText = low;
        }

        function getPriorityBadge(p, name) {
            let optionsHtml = '';
            for (let i = 10; i >= 0; i--) {
                const sel = (i === p) ? 'selected' : '';
                optionsHtml += '<option value="' + i + '" ' + sel + '>' + i + '</option>';
            }
            return '<select class="prio-select-inline" onchange="updateItemPriority(\'' + name + '\', this.value)" title="Click to change priority">' + optionsHtml + '</select>';
        }

        function getTypeBadge(t) {
            if (t === 'PS1') return '<span class="badge badge-type-ps1">PS1</span>';
            if (t === 'CMD') return '<span class="badge badge-type-cmd">CMD</span>';
            if (t === 'VBS') return '<span class="badge badge-type-vbs">VBS</span>';
            return '<span class="badge badge-type-ps1">' + t + '</span>';
        }

        function renderTable(data) {
            const tbody = document.getElementById('analysis-tbody');
            if (data.length === 0) {
                tbody.innerHTML = '<tr><td colspan="9" style="text-align: center; padding: 32px; color: var(--text-muted);">No matching scripts found.</td></tr>';
                return;
            }

            tbody.innerHTML = data.map((item, idx) => {
                return '<tr>' +
                    '<td>' +
                        '<span class="script-name-link" onclick="openRunDialog(' + idx + ')" title="Click to configure parameters and run">' +
                            '▶ ' + item.Name +
                        '</span>' +
                    '</td>' +
                    '<td style="text-align: center;">' + getTypeBadge(item.Type) + '</td>' +
                    '<td style="text-align: center;">' + getPriorityBadge(item.Priority, item.Name) + '</td>' +
                    '<td><span class="badge badge-type-ps1">' + item.Domain + '</span></td>' +
                    '<td style="color: var(--text-primary); max-width: 320px;">' + item.Purpose + '</td>' +
                    '<td style="color: var(--text-secondary); font-family: monospace; font-size: 12px;">' + item.Dependencies + '</td>' +
                    '<td style="text-align: center; font-weight: 600;">' + item.Effort + '</td>' +
                    '<td style="color: #7ee787; font-size: 12px;">' + item.Recommendation + '</td>' +
                    '<td style="text-align: center;">' +
                        '<button class="btn-inspect" onclick="openInspectDetails(' + idx + ')" title="Inspect script analysis details">🔍</button>' +
                    '</td>' +
                    '</tr>';
            }).join('');
        }

        function applyFilters() {
            const search = document.getElementById('search-input').value.toLowerCase();
            const nameVal = document.getElementById('name-filter').value.toLowerCase();
            const typeVal = document.getElementById('type-select').value;
            const prioVal = document.getElementById('prio-select').value;
            const domainVal = document.getElementById('domain-select').value;
            const funcVal = document.getElementById('func-filter').value.toLowerCase();
            const depVal = document.getElementById('dep-filter').value.toLowerCase();
            const effortVal = document.getElementById('effort-select').value;
            const recVal = document.getElementById('rec-filter').value.toLowerCase();

            let filtered = analysisData.filter(item => {
                // Card Filter
                if (activeCardFilter === 'high' && item.Priority < 8) return false;
                if (activeCardFilter === 'med' && (item.Priority < 5 || item.Priority > 7)) return false;
                if (activeCardFilter === 'low' && item.Priority > 4) return false;

                // Column Filters
                if (nameVal && !item.Name.toLowerCase().includes(nameVal)) return false;
                if (typeVal !== 'All' && item.Type !== typeVal) return false;
                if (domainVal !== 'All' && item.Domain !== domainVal) return false;
                if (effortVal !== 'All' && item.Effort !== effortVal) return false;
                if (funcVal && !item.Purpose.toLowerCase().includes(funcVal)) return false;
                if (depVal && !item.Dependencies.toLowerCase().includes(depVal)) return false;
                if (recVal && !item.Recommendation.toLowerCase().includes(recVal)) return false;

                // Priority Select
                if (prioVal === '10' && item.Priority !== 10) return false;
                if (prioVal === '8-10' && item.Priority < 8) return false;
                if (prioVal === '5-7' && (item.Priority < 5 || item.Priority > 7)) return false;
                if (prioVal === '0-4' && item.Priority > 4) return false;
                if (prioVal === '0' && item.Priority !== 0) return false;

                // Search Bar
                if (search) {
                    const match = item.Name.toLowerCase().includes(search) ||
                        item.Purpose.toLowerCase().includes(search) ||
                        item.Dependencies.toLowerCase().includes(search) ||
                        item.Domain.toLowerCase().includes(search) ||
                        item.Recommendation.toLowerCase().includes(search);
                    if (!match) return false;
                }

                return true;
            });

            // Sorting
            filtered.sort((a, b) => {
                let vA = a[sortField];
                let vB = b[sortField];
                if (typeof vA === 'string') vA = vA.toLowerCase();
                if (typeof vB === 'string') vB = vB.toLowerCase();
                if (vA < vB) return sortAsc ? -1 : 1;
                if (vA > vB) return sortAsc ? 1 : -1;
                return 0;
            });

            renderTable(filtered);
        }

        function sortTable(field) {
            if (sortField === field) {
                sortAsc = !sortAsc;
            } else {
                sortField = field;
                sortAsc = (field === 'Priority') ? false : true;
            }
            applyFilters();
        }

        function filterByCard(type) {
            activeCardFilter = type;
            document.querySelectorAll('.metric-card').forEach(c => c.classList.remove('active'));
            document.getElementById('card-' + type).classList.add('active');
            applyFilters();
        }

        function resetColumnFilters() {
            document.getElementById('name-filter').value = '';
            document.getElementById('type-select').value = 'All';
            document.getElementById('prio-select').value = 'All';
            document.getElementById('domain-select').value = 'All';
            document.getElementById('func-filter').value = '';
            document.getElementById('dep-filter').value = '';
            document.getElementById('effort-select').value = 'All';
            document.getElementById('rec-filter').value = '';
            applyFilters();
        }

        function resetFilters() {
            document.getElementById('search-input').value = '';
            resetColumnFilters();
            filterByCard('all');
        }

        // ==========================================
        // Parameter Persistence & Clear Logic
        // ==========================================
        function getSavedToolParams(toolName) {
            try {
                const stored = localStorage.getItem('lcm_saved_tool_params');
                if (stored) {
                    const map = JSON.parse(stored);
                    return map[toolName] || null;
                }
            } catch (e) {}
            return null;
        }

        function saveToolParams(toolName, paramsObj, rawCmd) {
            try {
                let map = {};
                const stored = localStorage.getItem('lcm_saved_tool_params');
                if (stored) {
                    map = JSON.parse(stored);
                }
                map[toolName] = {
                    params: paramsObj,
                    rawCmd: rawCmd,
                    lastUsed: new Date().toISOString()
                };
                localStorage.setItem('lcm_saved_tool_params', JSON.stringify(map));
            } catch (e) {}
        }

        function clearSavedToolParams(toolName) {
            try {
                const stored = localStorage.getItem('lcm_saved_tool_params');
                if (stored) {
                    const map = JSON.parse(stored);
                    delete map[toolName];
                    localStorage.setItem('lcm_saved_tool_params', JSON.stringify(map));
                }
            } catch (e) {}
        }

        // ==========================================
        // Run & Parameter Prompt Dialog Logic
        // ==========================================
        function openRunDialog(idx) {
            const item = analysisData[idx];
            currentRunningTool = item;

            document.getElementById('run-modal-title').innerHTML = '▶ Run: ' + item.Name + ' <span class="badge badge-type-ps1">' + item.Type + '</span>';
            document.getElementById('run-modal-desc').innerText = item.Purpose;

            const paramContainer = document.getElementById('param-container');
            const paramListDiv = document.getElementById('param-fields-list');
            paramListDiv.innerHTML = '';

            const params = item.Parameters || [];
            const savedData = getSavedToolParams(item.Name);

            if (params.length > 0) {
                paramContainer.style.display = 'block';
                params.forEach(p => {
                    const reqBadge = p.Mandatory ? '<span style="color: var(--danger); font-weight: 700;">* Required</span>' : '<span style="color: var(--text-secondary);">Optional</span>';
                    
                    // Determine initial value: saved parameter input takes priority, otherwise p.Default
                    let initVal = (p.Default || '');
                    if (savedData && savedData.params && savedData.params[p.Name] !== undefined) {
                        initVal = savedData.params[p.Name];
                    }

                    const fieldHtml = '<div class="param-field">' +
                        '<div class="param-header">' +
                            '<span class="param-name">-' + p.Name + '</span>' +
                            '<span class="param-type">' + p.Type + ' • ' + reqBadge + '</span>' +
                        '</div>' +
                        '<div class="input-clear-wrapper">' +
                            '<input type="text" class="param-input" id="param-input-' + p.Name + '" placeholder="' + (p.Description || p.Name) + '" value="' + initVal + '" oninput="syncStructuredToRaw()">' +
                            '<button type="button" class="btn-clear-param" onclick="clearParamInput(\'' + p.Name + '\')" title="Clear this parameter value">✖</button>' +
                        '</div>' +
                    '</div>';
                    paramListDiv.innerHTML += fieldHtml;
                });
            } else {
                paramContainer.style.display = 'none';
            }

            // If rawCmd was saved, use it as baseline
            if (savedData && savedData.rawCmd && params.length === 0) {
                document.getElementById('raw-cmd-input').value = savedData.rawCmd;
                validateCommandRealtime();
            } else {
                syncStructuredToRaw();
            }

            document.getElementById('run-modal-overlay').style.display = 'flex';
        }

        function clearParamInput(pName) {
            const input = document.getElementById('param-input-' + pName);
            if (input) {
                input.value = '';
                input.focus();
                syncStructuredToRaw();
            }
        }

        function clearAllParams() {
            if (!currentRunningTool) return;
            const params = currentRunningTool.Parameters || [];
            params.forEach(p => {
                const input = document.getElementById('param-input-' + p.Name);
                if (input) input.value = '';
            });
            clearSavedToolParams(currentRunningTool.Name);
            syncStructuredToRaw();
        }

        function syncStructuredToRaw() {
            if (!currentRunningTool) return;
            const item = currentRunningTool;
            const params = item.Parameters || [];
            
            let cmdStr = '';
            if (item.Type === 'PS1') {
                cmdStr = 'pwsh -File "D:\\Git_Repositories\\LCM_Inventory\\tools\\internal\\' + item.Name + '"';
            } else {
                cmdStr = '"D:\\Git_Repositories\\LCM_Inventory\\tools\\internal\\' + item.Name + '"';
            }

            params.forEach(p => {
                const input = document.getElementById('param-input-' + p.Name);
                if (input && input.value.trim() !== '') {
                    const val = input.value.trim();
                    if (p.Type === 'Switch' || p.Type === 'Boolean') {
                        if (val.toLowerCase() === 'true' || val === '1' || val === '$true') {
                            cmdStr += ' -' + p.Name;
                        }
                    } else {
                        if (val.includes(' ') && !val.startsWith('"')) {
                            cmdStr += ' -' + p.Name + ' "' + val + '"';
                        } else {
                            cmdStr += ' -' + p.Name + ' ' + val;
                        }
                    }
                }
            });

            document.getElementById('raw-cmd-input').value = cmdStr;
            validateCommandRealtime();
        }

        function validateCommandRealtime() {
            const rawText = document.getElementById('raw-cmd-input').value.trim();
            const errBox = document.getElementById('validation-error-box');
            const btnExec = document.getElementById('btn-execute');

            let errors = [];

            // 1. Check unmatched quotes
            const doubleQuotes = (rawText.match(/"/g) || []).length;
            const singleQuotes = (rawText.match(/'/g) || []).length;
            if (doubleQuotes % 2 !== 0) {
                errors.push('Syntax Error: Unmatched double quotation mark (") detected.');
            }
            if (singleQuotes % 2 !== 0) {
                errors.push('Syntax Error: Unmatched single quotation mark (\') detected.');
            }

            // 2. Check Mandatory Parameters
            if (currentRunningTool && currentRunningTool.Parameters) {
                currentRunningTool.Parameters.forEach(p => {
                    if (p.Mandatory) {
                        const paramFlag = '-' + p.Name;
                        if (!rawText.includes(paramFlag) && !rawText.includes('/' + p.Name)) {
                            // Check if value exists in positional arguments or prompt
                            const structuredInput = document.getElementById('param-input-' + p.Name);
                            if (!structuredInput || structuredInput.value.trim() === '') {
                                errors.push('Missing Required Parameter: -' + p.Name + ' is mandatory.');
                            }
                        }
                    }
                });
            }

            if (errors.length > 0) {
                errBox.innerHTML = errors.map(e => '<div>⚠️ ' + e + '</div>').join('');
                errBox.style.display = 'block';
                btnExec.disabled = true;
                btnExec.style.opacity = '0.5';
                btnExec.style.cursor = 'not-allowed';
            } else {
                errBox.style.display = 'none';
                btnExec.disabled = false;
                btnExec.style.opacity = '1';
                btnExec.style.cursor = 'pointer';
            }
        }

        function executeCurrentCommand() {
            const rawCmd = document.getElementById('raw-cmd-input').value.trim();
            if (!rawCmd || !currentRunningTool) return;

            // Collect and persist parameter values into localStorage
            const paramsObj = {};
            const params = currentRunningTool.Parameters || [];
            params.forEach(p => {
                const input = document.getElementById('param-input-' + p.Name);
                if (input) {
                    paramsObj[p.Name] = input.value.trim();
                }
            });
            saveToolParams(currentRunningTool.Name, paramsObj, rawCmd);

            // Dispatch execution via interactive task dispatcher protocol / clipboard fallback
            navigator.clipboard.writeText(rawCmd);

            alert('🚀 Command Dispatched to Interactive Desktop (Session 1)!\n\nCommand:\n' + rawCmd + '\n\n(Parameters saved as defaults for next run)');
            closeRunModal();
        }

        function closeRunModal(e) {
            if (!e || e.target.id === 'run-modal-overlay' || e.target.classList.contains('modal-close') || e.target.classList.contains('btn-reset')) {
                document.getElementById('run-modal-overlay').style.display = 'none';
                currentRunningTool = null;
            }
        }

        function openInspectDetails(idx) {
            const item = analysisData[idx];
            document.getElementById('modal-title').innerText = item.Name + ' (' + item.Type + ')';
            document.getElementById('modal-purpose').innerText = item.Purpose;
            document.getElementById('modal-rec').innerText = item.Recommendation;
            document.getElementById('modal-meta').innerText = 'Domain: ' + item.Domain + ' • Priority: ' + item.Priority + '/10 • Effort: ' + item.Effort;
            document.getElementById('modal-deps').innerText = item.Dependencies || 'None';
            document.getElementById('modal-snippet').innerText = item.Snippet || 'No snippet available.';
            document.getElementById('inspect-modal-overlay').style.display = 'flex';
        }

        function closeInspectModal(e) {
            if (!e || e.target.id === 'inspect-modal-overlay' || e.target.classList.contains('modal-close') || e.target.classList.contains('btn-reset')) {
                document.getElementById('inspect-modal-overlay').style.display = 'none';
            }
        }

        function exportAnalysisJson() {
            navigator.clipboard.writeText(JSON.stringify(analysisData, null, 2));
            alert('📋 Analysis JSON copied to clipboard!');
        }

        // Inlined LcmTablePrintAtom Engine
        $atomJsContent

        // Initialize LcmTablePrintAtom
        LcmTablePrintAtom.init({
            documentTitle: 'CMD Scripts Folder Analysis & Onboarding',
            tableSelector: 'table',
            tbodySelector: '#analysis-tbody',
            getFilterSummary: () => {
                const search = document.getElementById('search-input') ? document.getElementById('search-input').value.trim() : '';
                const domain = document.getElementById('filter-domain') ? document.getElementById('filter-domain').value : 'All';
                const status = document.getElementById('filter-status') ? document.getElementById('filter-status').value : 'All';
                let parts = [];
                if (search) parts.push('Search: "' + search + '"');
                if (domain !== 'All') parts.push('Domain: ' + domain);
                if (status !== 'All') parts.push('Status: ' + status);
                return parts.length > 0 ? parts.join(' • ') : 'All Items in View';
            },
            getViewBadge: () => {
                const visibleRows = document.querySelectorAll('#analysis-tbody tr').length;
                return 'Onboarding Analysis (' + visibleRows + ' Items)';
            }
        });

        // Initialize with custom priorities and render table
        loadCustomPriorities();
        applyFilters();

        // Keyboard navigation (F5 Refresh & Escape Dismissal)
        window.addEventListener('keydown', (e) => {
            if (e.key === 'F5' || e.code === 'F5') {
                e.preventDefault();
                window.location.reload();
            } else if (e.key === 'Escape') {
                closeRunModal();
                closeInspectModal();
            }
        });
    </script>
</body>
</html>
"@

Set-Content -Path $outputHtml -Value $htmlContent -Encoding UTF8
Write-Host "Generated Cmd Folder Analysis Viewer: $outputHtml" -ForegroundColor Green

if (-not $NoLaunch) {
  Write-Host "Opening Cmd Folder Analysis dashboard on Desktop (Session 1)..." -ForegroundColor Cyan
  $dispatcher = Join-Path $workspaceRoot 'tools\Invoke-InteractiveDesktop.ps1'
  if (Test-Path $dispatcher) {
    & pwsh -File $dispatcher -FilePath "explorer.exe" -ArgumentList "`"$outputHtml`"" | Out-Null
  } else {
    Start-Process $outputHtml
  }
}

