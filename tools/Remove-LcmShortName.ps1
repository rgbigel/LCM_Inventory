<#
.SYNOPSIS
  Safely deletes a duplicate short-name trampoline (.cmd) while preserving the underlying script.

.DESCRIPTION
  Module: Remove-LcmShortName
  Purpose: Safely removes an extraneous or duplicate short-name command launcher from
           .lcm/Cmd/<ShortName>.cmd without deleting or altering the target source script (.ps1/.py).
           Enforces the Last-Alias Protection Invariant: strictly disallows removing a short-name
           if it is the only remaining launcher pointing to the long-named script file.
           Conforms to RULE-PS-001 through RULE-PS-014.
  Path: .lcm/tools/internal/Remove-LcmShortName.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 1.1.0
  Date: 2026-09-08

.PARAMETER ShortName
  The short-name command alias to remove (with or without .cmd extension).

.PARAMETER TargetScript
  Optional name or relative path of the target script file to verify against.

.PARAMETER Force
  Suppresses interactive confirmation in terminal mode.

.PARAMETER LogFile
  Custom log destination. Defaults to .lcm/logs/Remove-LcmShortName-yyyyMMdd.log.

.PARAMETER Help
  Displays parameter reference and usage instructions (Aliases: -h, -?).

.EXAMPLE
  pwsh .lcm/tools/internal/Remove-LcmShortName.ps1 -ShortName "ApplyAllCustomzations"
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ShortName,

  [Parameter(Mandatory = $false)]
  [string]$TargetScript = '',

  [switch]$Force,

  [string]$LogFile = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = '1.1.0'
$scriptName = 'Remove-LcmShortName'

# ------------------------------------------------------------------------------
# 0. Help Handler per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM SHORT-NAME LAUNCHER REMOVAL ENGINE (v$scriptVersion)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Safely deletes a duplicate short-name trampoline (.cmd) while preserving the script."
  Write-Host "  Strictly enforces Last-Alias Protection (rejects if it is the only launcher)."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh .lcm/tools/internal/Remove-LcmShortName.ps1 -ShortName <name> [-TargetScript <script>] [-Force] [-h]"
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh .lcm/tools/internal/Remove-LcmShortName.ps1 -ShortName 'ApplyAllCustomzations'"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Environment & Logging Setup
# ------------------------------------------------------------------------------
$workspaceRoot = if (-not [string]::IsNullOrWhiteSpace($env:Git_Root)) { $env:Git_Root.TrimEnd('\', '/') } else { 'D:\Git_Repositories' }
$cmdDir = Join-Path $workspaceRoot '.lcm\Cmd'
$logDir = Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm'
if (-not (Test-Path -LiteralPath $logDir)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $dateStamp = (Get-Date).ToString("yyyyMMdd")
  $LogFile = Join-Path $logDir "$scriptName-$dateStamp.log"
}

function Write-ToolLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [ValidateSet('INFO', 'ACTION', 'WARN', 'ERROR')]
    [string]$Level = 'INFO'
  )
  $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  $line = "[$stamp] [$Level] $Message"
  Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

Write-ToolLog -Message "Invoked $scriptName with ShortName='$ShortName', TargetScript='$TargetScript'" -Level INFO

# Clean ShortName argument
$cleanShortName = $ShortName.Trim()
if ($cleanShortName.EndsWith('.cmd', [System.StringComparison]::OrdinalIgnoreCase)) {
  $cleanShortName = $cleanShortName.Substring(0, $cleanShortName.Length - 4)
}

$targetCmdFile = Join-Path $cmdDir "$cleanShortName.cmd"
if (-not (Test-Path -LiteralPath $targetCmdFile)) {
  $errMsg = "Launcher not found: $targetCmdFile"
  Write-ToolLog -Message $errMsg -Level ERROR
  Write-Error $errMsg
  return
}

# ------------------------------------------------------------------------------
# 2. Inspect Target Script Reference in Launcher Content
# ------------------------------------------------------------------------------
$content = Get-Content -LiteralPath $targetCmdFile -Raw -Encoding UTF8
$detectedScript = ''

if ($content -match '(?i)-File\s+["'']?([^"''\r\n]+)["'']?') {
  $detectedScript = $Matches[1].Trim()
} elseif ($content -match '(?i)(?:call|start|Invoke-InteractiveDesktop\.ps1 -FilePath)\s+["'']?([^"''\r\n]+)["'']?') {
  $detectedScript = $Matches[1].Trim()
} else {
  $lines = @($content -split '\r?\n' | Where-Object {
    $_ -notmatch '^\s*(@echo|setlocal|endlocal|if\s+not\s+defined|if\s+not\s+exist|\s*$)'
  })
  if ($lines.Count -gt 0) {
    $detectedScript = $lines[0].Trim()
  }
}

# Normalize target script name
$targetLeafName = [System.IO.Path]::GetFileName($detectedScript)
if ([string]::IsNullOrWhiteSpace($targetLeafName)) {
  $targetLeafName = [System.IO.Path]::GetFileName($TargetScript)
}

if ([string]::IsNullOrWhiteSpace($targetLeafName)) {
  $errMsg = "Could not resolve target script referenced by launcher: $cleanShortName.cmd"
  Write-ToolLog -Message $errMsg -Level ERROR
  Write-Error $errMsg
  return
}

Write-ToolLog -Message "Resolved target script for '$cleanShortName.cmd': $targetLeafName" -Level INFO

# ------------------------------------------------------------------------------
# 3. Enforce Last-Alias Protection Invariant
# ------------------------------------------------------------------------------
# Scan all launchers in .lcm/Cmd/*.cmd to find all that resolve to the same target script
$allCmdFiles = @(Get-ChildItem -Path $cmdDir -Filter '*.cmd' -File)
$matchingLaunchers = [System.Collections.Generic.List[string]]::new()

foreach ($cf in $allCmdFiles) {
  $raw = Get-Content -LiteralPath $cf.FullName -Raw -Encoding UTF8
  if ($raw -like "*$targetLeafName*") {
    $matchingLaunchers.Add([System.IO.Path]::GetFileNameWithoutExtension($cf.Name))
  }
}

Write-ToolLog -Message "Found $($matchingLaunchers.Count) launcher(s) targeting '$targetLeafName': $($matchingLaunchers -join ', ')" -Level INFO

if ($matchingLaunchers.Count -le 1) {
  $disallowedMsg = "DISALLOWED: '$cleanShortName' is the last remaining short-name launcher for '$targetLeafName'. Every script must retain at least one short-name launcher."
  Write-ToolLog -Message $disallowedMsg -Level WARN
  Write-Host "==========================================================================" -ForegroundColor Red
  Write-Host " ⚠️ LAST-ALIAS PROTECTION INVARIANT VIOLATION" -ForegroundColor Red
  Write-Host "==========================================================================" -ForegroundColor Red
  Write-Host " Target Script   : $targetLeafName" -ForegroundColor Yellow
  Write-Host " Active Launcher : $cleanShortName.cmd (Total Matching: $($matchingLaunchers.Count))" -ForegroundColor Yellow
  Write-Host " Result          : Operation rejected. You cannot delete the sole launcher for a script." -ForegroundColor Red
  Write-Host "==========================================================================" -ForegroundColor Red
  
  return [PSCustomObject]@{
    status = "DISALLOWED"
    error  = $disallowedMsg
    count  = $matchingLaunchers.Count
    target = $targetLeafName
  }
}

# ------------------------------------------------------------------------------
# 4. Perform Safe Deletion
# ------------------------------------------------------------------------------
  Remove-Item -LiteralPath $targetCmdFile -Force
  Write-ToolLog -Message "Successfully deleted launcher: $targetCmdFile" -Level ACTION
  
  $remaining = @($matchingLaunchers | Where-Object { $_ -ne $cleanShortName })



  # Prune from tool_catalog.json caches
  $catalogPaths = @(
    (Join-Path $workspaceRoot '.lcm\config\tool_catalog.json'),
    (Join-Path $workspaceRoot '.lcm\tools\internal\tool_catalog.json')
  )
  foreach ($cp in $catalogPaths) {
    if (Test-Path -LiteralPath $cp) {
      try {
        $catJson = Get-Content -LiteralPath $cp -Raw -Encoding UTF8 | ConvertFrom-Json
        $modified = $false
        foreach ($item in $catJson) {
          $isTarget = ($item.Name -eq $targetLeafName -or [System.IO.Path]::GetFileName($item.Name) -eq $targetLeafName)
          if ($isTarget -and $item.PSObject.Properties['ShortName'] -and $item.ShortName -eq $cleanShortName) {
            $newPrimary = if ($remaining.Count -gt 0) { $remaining[0] } else { $targetLeafName }
            $item.ShortName = $newPrimary
            if ($item.PSObject.Properties['Example'] -and $item.Example -eq $cleanShortName) {
              $item.Example = $newPrimary
            }
            $modified = $true
          }
          if ($item.PSObject.Properties['Aliases'] -and $item.Aliases -contains $cleanShortName) {
            $item.Aliases = @($item.Aliases | Where-Object { $_ -ne $cleanShortName })
            $modified = $true
          }
        }
        if ($modified) {
          $newCatRaw = $catJson | ConvertTo-Json -Depth 6
          [System.IO.File]::WriteAllText($cp, $newCatRaw, [System.Text.UTF8Encoding]::new($false))
          Write-ToolLog -Message "Pruned alias '$cleanShortName' from $cp" -Level ACTION
        }
      } catch {}
    }
  }
  Write-Host "==========================================================================" -ForegroundColor Green
  Write-Host " ✓ SHORT-NAME LAUNCHER REMOVED SAFELY" -ForegroundColor Green
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " Deleted Launcher: $cleanShortName.cmd" -ForegroundColor White
  Write-Host " Preserved Script: $targetLeafName (Retained intact)" -ForegroundColor Cyan
  Write-Host " Remaining Aliases: $($remaining -join ', ') ($($remaining.Count) remaining)" -ForegroundColor Yellow
  Write-Host "==========================================================================" -ForegroundColor Cyan

  return [PSCustomObject]@{
    status            = "DELETED"
    deletedShortName  = $cleanShortName
    targetScript      = $targetLeafName
    remainingCount    = $remaining.Count
    remainingAliases  = $remaining
  }
