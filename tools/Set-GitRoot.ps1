<#
.SYNOPSIS
  Configures the Git_Root environment variable and system PATH for LCM command trampolines.
.DESCRIPTION
  Module: Set-GitRoot
  Purpose: Establishes the Git_Root environment variable (D:\Git_Repositories) at User,
           Process, and Machine scopes, and ensures D:\Git_Repositories\LCM_Inventory\Cmd is present
           in the Environment PATH ahead of legacy D:\OneDrive\cmd.
           Scrubs obsolete and deprecated tool paths from PATH.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: LCM_Inventory/tools/Set-GitRoot.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
.PARAMETER RootPath
  Container root directory for Git repositories. Defaults to D:\Git_Repositories.
.PARAMETER Force
  Forces re-application of environment variables and PATH ordering even if already present.
.PARAMETER ShowAll
  Displays full detailed registry and environment evaluation logs.
.PARAMETER LogFile
  Custom log file destination. Defaults to LCM_Inventory/data/logs/lcm/Set-GitRoot-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh LCM_Inventory/tools/Set-GitRoot.ps1 -h
.EXAMPLE
  pwsh LCM_Inventory/tools/Set-GitRoot.ps1
.EXAMPLE
  SetGitRoot
#>

[CmdletBinding()]
param(
  [string]$RootPath = 'D:\Git_Repositories',
  [switch]$Force,
  [switch]$ShowAll,
  [string]$LogFile = "",
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Set-GitRoot"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " GIT ROOT & LCM PATH CONFIGURATION TOOL (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Configures the Git_Root environment variable and ensures"
  Write-Host "  $RootPath\LCM_Inventory\Cmd is present in PATH ahead of legacy D:\OneDrive\cmd."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Set-GitRoot.ps1 [-RootPath <path>] [-Force] [-ShowAll] [-LogFile <path>] [-h]"
  Write-Host "  SetGitRoot"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -RootPath <str> : Git repositories root container (Default: D:\Git_Repositories)."
  Write-Host "  -Force          : Re-applies and re-broadcasts configuration."
  Write-Host "  -ShowAll        : Exposes granular registry evaluation logs."
  Write-Host "  -LogFile <str>  : Custom log file destination."
  Write-Host "  -h, -Help, -?   : Displays this comprehensive parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  SetGitRoot"
  Write-Host "  pwsh LCM_Inventory/tools/Set-GitRoot.ps1 -ShowAll"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Initialize Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = $RootPath.TrimEnd('\', '/')
$lcmRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcmRoot 'tools\internal'
$logDir = Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm'
if (-not (Test-Path -Path $logDir)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $LogFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"
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
      "ERROR"   { Write-Error $Message }
      "DEBUG"   { if ($script:ShowDetails) { Write-Host "  [DEBUG] $Message" -ForegroundColor DarkGray } }
      "ACTION"  { Write-Host "  -> $Message" -ForegroundColor Green }
      "SUMMARY" { Write-Host $Message -ForegroundColor Cyan }
      default   { Write-Host $Message }
    }
  }
}

Write-ToolLog -Message "==========================================================================" -Level INFO
Write-ToolLog -Message " GIT ROOT & LCM PATH CONFIGURATION TOOL (v$($scriptVersion))" -Level INFO
Write-ToolLog -Message " Git_Root Target: $workspaceRoot" -Level INFO
Write-ToolLog -Message " Command Hub    : $workspaceRoot\LCM_Inventory\Cmd in PATH" -Level INFO
Write-ToolLog -Message " Audit Log      : $LogFile" -Level INFO
Write-ToolLog -Message "==========================================================================" -Level INFO

$lcmCmdPath = Join-Path $workspaceRoot 'LCM_Inventory\Cmd'
$allLcmPaths = @($lcmCmdPath)
$execStatus = "COMPLETED"

try {
  $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  $isElevated = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

  # 1. Update Machine Environment Git_Root and PATH (Requires Elevation)
  if ($isElevated) {
    Write-ToolLog -Message "Running with Administrator privileges. Updating Machine Git_Root and PATH..." -Level INFO
    [Environment]::SetEnvironmentVariable('Git_Root', $workspaceRoot, 'Machine')
    [Environment]::SetEnvironmentVariable('Git_Root', $workspaceRoot, 'Process')
    Write-ToolLog -Message "Machine Git_Root set to $workspaceRoot." -Level ACTION

    # Scrub redundant User-scope Git_Root (Machine-scope is exclusive canonical)
    # Note: [Environment]::SetEnvironmentVariable('Git_Root', $null, 'User') coerces $null to "" in PowerShell,
    # leaving an empty registry key. Use explicit Registry DeleteValue / Remove-ItemProperty instead.
    try {
      Remove-ItemProperty -Path 'HKCU:\Environment' -Name 'Git_Root' -ErrorAction SilentlyContinue
    } catch {}
    try {
      $envRegKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
      if ($envRegKey) {
        $envRegKey.DeleteValue('Git_Root', $false)
        $envRegKey.Close()
      }
    } catch {}
    Write-ToolLog -Message "Physically scrubbed redundant User-scope Git_Root registry value (Machine scope is exclusive canonical)." -Level ACTION

    # Scrub obsolete paths from User Environment PATH
    Write-ToolLog -Message "Scrubbing obsolete LCM/tools paths from User Environment PATH..." -Level INFO
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $legacyPaths = @(
      'D:\Git_Repositories\LCM_Tools\Cmd',
      'D:\Git_Repositories\LCM_Tools',
      'D:\Git_Repositories\.tools\Cmd',
      'D:\Git_Repositories\.tools',
      'D:\Git_Repositories\.lcm\tools\cmd',
      'D:\Git_Repositories\.lcm\tools\Cmd',
      'D:\Git_Repositories\.lcm\Cmd',
      'D:\Git_Repositories\LCM_AI\tools',
      'D:\Git_Repositories\.lcd\Cmd'
    )
    $allPathsToRemove = $allLcmPaths + $legacyPaths

    $userParts = @($userPath -split ';' | Where-Object { [string]::IsNullOrWhiteSpace($_) -eq $false -and ($allPathsToRemove -notcontains $_.TrimEnd('\')) })

    $newUserPathString = ($userParts -join ';')
    if ($userPath -ne $newUserPathString) {
      [Environment]::SetEnvironmentVariable('Path', $newUserPathString, 'User')
      Write-ToolLog -Message "User PATH registry updated: stripped obsolete tool paths." -Level ACTION
    } else {
      Write-ToolLog -Message "User PATH already clean." -Level INFO
    }

    # Update Machine PATH
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $pathParts = @($machinePath -split ';' | Where-Object { [string]::IsNullOrWhiteSpace($_) -eq $false -and ($allPathsToRemove -notcontains $_.TrimEnd('\')) })

    $newParts = [System.Collections.Generic.List[string]]::new()
    $inserted = $false

    foreach ($p in $pathParts) {
      if ($p.TrimEnd('\') -eq 'D:\OneDrive\cmd' -and -not $inserted) {
        foreach ($lp in $allLcmPaths) { $newParts.Add($lp) }
        $inserted = $true
      }
      $newParts.Add($p)
    }

    if (-not $inserted) {
      for ($i = $allLcmPaths.Count - 1; $i -ge 0; $i--) {
        $newParts.Insert(0, $allLcmPaths[$i])
      }
    }

    # External tools declared in docs\Requisites\external-tools.json (appended, never ahead of the LCM Cmd path)
    $reqFile = Join-Path $workspaceRoot 'docs\Requisites\external-tools.json'
    if (Test-Path -LiteralPath $reqFile) {
      $req = Get-Content -LiteralPath $reqFile -Raw | ConvertFrom-Json
      foreach ($tool in @($req.tools)) {
        if (-not $tool.addToPath) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $tool.dir $tool.probe))) {
          Write-ToolLog -Message "External tool $($tool.name) not found at $($tool.dir); PATH entry skipped." -Level WARN
          continue
        }
        $known = @($newParts | Where-Object { $_.TrimEnd('\') -ieq $tool.dir.TrimEnd('\') })
        if ($known.Count -eq 0) {
          $newParts.Add($tool.dir)
          Write-ToolLog -Message "Machine PATH: added external tool $($tool.name) ($($tool.dir))." -Level ACTION
        }
      }
    } else {
      Write-ToolLog -Message "Requisites manifest not found: $reqFile" -Level WARN
    }

    $newPathString = ($newParts -join ';')
    [Environment]::SetEnvironmentVariable('Path', $newPathString, 'Machine')
    Write-ToolLog -Message "Machine PATH registry updated with LCM command path ($lcmCmdPath)." -Level ACTION
  } else {
    Write-ToolLog -Message "Administrator privileges required to configure Machine Git_Root and system PATH." -Level ERROR
    throw "Set-GitRoot requires elevated Administrator privileges. Git_Root is strictly a Machine-level variable and cannot be set in standard user context."
  }

  # 4. Broadcast environment change to system
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class EnvBroadcaster {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
  $HWND_BROADCAST = [IntPtr]0xffff
  $WM_SETTINGCHANGE = 0x001A
  $result = [UIntPtr]::Zero
  [EnvBroadcaster]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result) | Out-Null
  Write-ToolLog -Message "Broadcast WM_SETTINGCHANGE signal dispatched to Windows shell." -Level ACTION

  # 5. Update current process PATH
  $env:PATH = "$lcmCmdPath;$env:PATH"
  Write-ToolLog -Message "Active process environment updated immediately." -Level INFO

} catch {
  $execStatus = "FAILED"
  Write-ToolLog -Message "Error configuring Git_Root and system PATH: $_" -Level ERROR
} finally {
  $now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  Write-ToolLog -Message "" -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
  Write-ToolLog -Message " [SUMMARY] $scriptName (v$($scriptVersion))" -Level SUMMARY
  Write-ToolLog -Message " Status    : $execStatus" -Level SUMMARY
  Write-ToolLog -Message " Git_Root  : $workspaceRoot" -Level SUMMARY
  Write-ToolLog -Message " Timestamp : $now" -Level SUMMARY
  Write-ToolLog -Message " Log File  : $LogFile" -Level SUMMARY
  Write-ToolLog -Message " Path Entry: $lcmCmdPath" -Level SUMMARY
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
}
