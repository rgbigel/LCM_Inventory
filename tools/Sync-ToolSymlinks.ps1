<#
.SYNOPSIS
  Synchronizes in-process NTFS symbolic links for all LCM tools into D:\Git_Repositories\LCM_Tools dynamically from the tool catalog.
.DESCRIPTION
  Module: Sync-ToolSymlinks
  Purpose: Dynamically discovers all child repository tools via tool_catalog.json (and tools/modules/LcmToolCatalog.psm1),
           and creates/maintains direct NTFS symbolic links in D:\Git_Repositories\LCM_Tools pointing to their canonical locations.
           Automatically purges orphaned or stale symlinks, and keeps LCM_Inventory/Cmd/ trampolines synchronized.
           Zero static precompiled tables — fully dynamic, self-healing, and 100% catalog-driven.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: D:\Git_Repositories\LCM_Tools\Sync-ToolSymlinks.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-10-13
.PARAMETER Force
  Overwrites or replaces existing symbolic links without confirmation.
.PARAMETER ShowAll
  Displays detailed diagnostic inspection for every evaluated link.
.PARAMETER LogFile
  Custom log file destination. Defaults to D:\Git_Repositories\LCM_Tools\logs\Sync-ToolSymlinks-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Sync-ToolSymlinks.ps1 -h
.EXAMPLE
  SyncSymlinks
.EXAMPLE
  pwsh tools/Sync-ToolSymlinks.ps1 -ShowAll
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$Force,
  [switch]$ShowAll,
  [string]$LogFile = "",
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Sync-ToolSymlinks"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " DYNAMIC TOOL SYMLINK SYNCHRONIZER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Dynamically discovers child repository tools via tool_catalog.json and synchronizes"
  Write-Host "  NTFS symbolic links directly into D:\Git_Repositories\LCM_Tools for instant shell access."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  SyncSymlinks [-Force] [-ShowAll] [-h]"
  Write-Host "  pwsh tools/Sync-ToolSymlinks.ps1 [-Force] [-ShowAll] [-LogFile <path>] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Force         : Forces re-creation of all symbolic links."
  Write-Host "  -ShowAll       : Exposes verbose evaluation logs for every link target."
  Write-Host "  -LogFile <str> : Custom log file destination."
  Write-Host "  -h, -Help, -?  : Displays this comprehensive parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  SyncSymlinks"
  Write-Host "  pwsh tools/Sync-ToolSymlinks.ps1 -ShowAll"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Initialize Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
$inventoryRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$internalDir = Join-Path $inventoryRoot 'tools'
$linksDir = Join-Path $inventoryRoot 'tools'
$modulesDir = Join-Path $inventoryRoot 'modules'
$logDir = Join-Path $inventoryRoot 'data\logs\lcm'
$configDir = Join-Path $inventoryRoot 'config'

if (-not (Test-Path -LiteralPath $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

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
  $logEntry = "[$timeHeader] [$Level] $Message"

  if (-not $ConsoleOnly -and -not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
    try {
      Add-Content -LiteralPath $script:ActiveLogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
  }

  if (-not $LogOnly) {
    switch ($Level) {
      "ERROR"   { Write-Host "  [!] $Message" -ForegroundColor Red }
      "WARN"    { Write-Host "  [*] $Message" -ForegroundColor Yellow }
      "ACTION"  { Write-Host "  -> $Message" -ForegroundColor Cyan }
      "SUMMARY" { Write-Host "  [SUMMARY] $Message" -ForegroundColor Green }
      "DEBUG"   { if ($script:ShowDetails) { Write-Host "  [d] $Message" -ForegroundColor DarkGray } }
      default   { Write-Host $Message }
    }
  }
}

Write-ToolLog -Message "==========================================================================" -Level INFO
Write-ToolLog -Message " DYNAMIC TOOL SYMLINK SYNCHRONIZER (v$($scriptVersion))" -Level INFO
Write-ToolLog -Message " Workspace Root: $workspaceRoot" -Level INFO
Write-ToolLog -Message " Links Hub     : $linksDir" -Level INFO
Write-ToolLog -Message " Internal Hub  : $internalDir" -Level INFO
Write-ToolLog -Message " Audit Log     : $LogFile" -Level INFO
Write-ToolLog -Message " Mode          : Dynamic Catalog Discovery (Zero Static Tables)" -Level INFO
Write-ToolLog -Message "==========================================================================" -Level INFO

# ------------------------------------------------------------------------------
# 2. Dynamic Catalog Discovery
# ------------------------------------------------------------------------------
$modulePath = Join-Path $modulesDir 'LcmToolCatalog.psm1'
$catalogData = $null

if (Test-Path -LiteralPath $modulePath) {
  Import-Module -Name $modulePath -Force
  $catalogData = (Get-LcmToolCatalogData -ToolsDir $internalDir).Catalog
} else {
  $catalogJsonPath = Join-Path $configDir 'tool_catalog.json'
  if (Test-Path -LiteralPath $catalogJsonPath) {
    $catalogData = Get-Content -LiteralPath $catalogJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  }
}

if (-not $catalogData -or $catalogData.Count -eq 0) {
  Write-ToolLog -Message "Error: Unable to load tool catalog data. Running Update-ToolCatalog..." -Level WARN
  $updateScript = Join-Path $toolsDir 'Update-ToolCatalog.ps1'
  if (Test-Path -LiteralPath $updateScript) {
    & $updateScript -Silent
    $catalogJsonPath = Join-Path $configDir 'tool_catalog.json'
    $catalogData = Get-Content -LiteralPath $catalogJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  }
}

if (-not $catalogData) {
  Write-ToolLog -Message "Failed to obtain tool catalog. Aborting." -Level ERROR
  return
}

# ------------------------------------------------------------------------------
# 3. Process Dynamic Symlink Synchronization
# ------------------------------------------------------------------------------
$createdCount = 0
$skippedCount = 0
$purgedCount = 0
$execStatus = "COMPLETED"
$activeLinkNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

try {
  foreach ($tool in $catalogData) {
    if ([string]::IsNullOrWhiteSpace($tool.RelativePath) -or [string]::IsNullOrWhiteSpace($tool.Name)) { continue }

    $targetFullPath = Join-Path $workspaceRoot $tool.RelativePath
    $linkPath = Join-Path $linksDir $tool.Name
    $nativePath = Join-Path $internalDir $tool.Name

    # Skip tools that natively reside in LCM_Inventory/tools directory (not symlinks)
    if ($targetFullPath.ToLowerInvariant() -eq $nativePath.ToLowerInvariant()) {
      Write-ToolLog -Message "Native platform tool detected: $($tool.Name)" -Level DEBUG
      continue
    }

    if (-not (Test-Path -LiteralPath $targetFullPath)) {
      Write-ToolLog -Message "Target does not exist on disk: $targetFullPath (skipping $($tool.Name))" -Level WARN
      continue
    }

    $activeLinkNames.Add($tool.Name) | Out-Null

    $needsCreation = $true
    if (Test-Path -LiteralPath $linkPath) {
      $item = Get-Item -LiteralPath $linkPath -Force
      if ($item.LinkType -eq 'SymbolicLink') {
        $currentTarget = $item.Target
        if ($currentTarget -eq $targetFullPath -or $currentTarget -eq $tool.RelativePath) {
          $needsCreation = $false
          $skippedCount++
          Write-ToolLog -Message "Verified existing link: $($tool.Name) -> $($tool.RelativePath)" -Level DEBUG
        }
      }
      if ($needsCreation -and ($Force -or $item.LinkType -eq 'SymbolicLink')) {
        Remove-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
      }
    }

    if ($needsCreation) {
      if ($PSCmdlet.ShouldProcess($linkPath, "Create Symbolic Link -> $targetFullPath")) {
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetFullPath -Force | Out-Null
        Write-ToolLog -Message "Linked: $($tool.Name) -> $($tool.RelativePath)" -Level ACTION
        $createdCount++
      }
    }
  }

  # ----------------------------------------------------------------------------
  # 4. Clean up Orphaned Symlinks in LCM_Inventory/Cmd/
  # ----------------------------------------------------------------------------
  $existingSymlinks = @(Get-ChildItem -LiteralPath $linksDir -File -Force | Where-Object { $_.LinkType -eq 'SymbolicLink' })
  foreach ($symlink in $existingSymlinks) {
    $targetPath = $symlink.Target
    $targetExists = $false
    if ($targetPath) {
      if (Test-Path -LiteralPath $targetPath) {
        $targetExists = $true
      } elseif (Test-Path -LiteralPath (Join-Path $workspaceRoot $targetPath)) {
        $targetExists = $true
      }
    }

    if (-not $targetExists -or -not $activeLinkNames.Contains($symlink.Name)) {
      Write-ToolLog -Message "Purging orphaned/stale symlink: $($symlink.Name) (Target: $targetPath)" -Level ACTION
      Remove-Item -LiteralPath $symlink.FullName -Force -ErrorAction SilentlyContinue
      $purgedCount++
    }
  }

  # ----------------------------------------------------------------------------
  # 5. Synchronize LCM_Inventory/Cmd/ Short-Name Trampolines
  # ----------------------------------------------------------------------------
  $updateScript = Join-Path $internalDir 'Update-ToolCatalog.ps1'
  if (Test-Path -LiteralPath $updateScript) {
    Write-ToolLog -Message "Synchronizing LCM_Inventory/Cmd/ command trampolines and catalog metadata..." -Level ACTION
    & $updateScript -Silent
  }
} catch {
  $execStatus = "FAILED"
  Write-ToolLog -Message "Execution encountered an error: $_" -Level ERROR
} finally {
  $now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  Write-ToolLog -Message "" -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
  Write-ToolLog -Message " [SUMMARY] $scriptName (v$($scriptVersion))" -Level SUMMARY
  Write-ToolLog -Message " Status    : $execStatus" -Level SUMMARY
  Write-ToolLog -Message " Created   : $createdCount" -Level SUMMARY
  Write-ToolLog -Message " Unchanged : $skippedCount" -Level SUMMARY
  Write-ToolLog -Message " Purged    : $purgedCount" -Level SUMMARY
  Write-ToolLog -Message " Timestamp : $now" -Level SUMMARY
  Write-ToolLog -Message " Log File  : $LogFile" -Level SUMMARY
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
}



