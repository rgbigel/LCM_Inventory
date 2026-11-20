<#
.SYNOPSIS
  Protocol handler for lcm:// URI execution from web browsers.
.DESCRIPTION
  Module: Invoke-LcmProtocol
  Purpose: Intercepts and parses lcm://run URI requests from HTML explorers and dispatches
           tools to the interactive desktop session (Session 1) with appropriate privilege elevation
           via Invoke-InteractiveDesktop.ps1.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: tools/Invoke-LcmProtocol.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.2
  Date: 2026-11-20
  Implementation Choices (CRP-366): .py targets start on the registered interpreter (RULE-PY-010).
.PARAMETER Uri
  The incoming lcm:// URI string (e.g. lcm://run?tool=Kill-LogitechUpdate.ps1&elevated=true).
.PARAMETER Help
  Displays parameter reference and usage instructions.
#>

[CmdletBinding()]
param(
  [Parameter(Position = 0, Mandatory = $true)]
  [string]$Uri,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Invoke-LcmProtocol"

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM PROTOCOL HANDLER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS: Dispatches URI requests to the interactive user desktop."
  return
}

$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcdRoot 'tools'
$logDir = Join-Path $lcdRoot 'data\logs\lcm'
if (-not (Test-Path -Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
$logFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"

function Write-ToolLog {
  param([string]$Message = "", [string]$Level = "INFO")
  $timeHeader = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  "[$timeHeader] [$Level] $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Write-ToolLog -Message "Received URI: $Uri" -Level INFO

try {
  # Clean up protocol prefix and decode URL
  $raw = [System.Uri]::UnescapeDataString($Uri)
  $raw = $raw -replace '^lcm:///?', ''
  $raw = $raw -replace '^run/?', ''
  $raw = $raw.TrimStart('?')

  $toolName = ""
  $elevated = $false
  $noExit = $null

  if ($raw -match 'tool=([^&]+)') {
    $toolName = $Matches[1]
  } elseif ($raw -match '^([^&?]+)') {
    $toolName = $Matches[1]
  }

  if ($raw -match 'elevated=(true|1|yes)') {
    $elevated = $true
  }

  if ($raw -match 'noexit=(false|0|no)') {
    $noExit = $false
  } elseif ($raw -match 'noexit=(true|1|yes)') {
    $noExit = $true
  }

  if ([string]::IsNullOrWhiteSpace($toolName)) {
    throw "No tool specified in URI: $Uri"
  }

  $toolPath = Join-Path $toolsDir $toolName
  $catalogModule = Join-Path $lcdRoot 'modules\LcmToolCatalog.psm1'  # CRP-358: tools.db
  if (Test-Path -LiteralPath $catalogModule) {
    Import-Module -Name $catalogModule
    $catalog = @(Get-LcmToolStoreDocument -Store catalog)
    $item = $catalog | Where-Object { $_.Name -eq $toolName } | Select-Object -First 1
    if ($item) {
      if (-not (Test-Path -LiteralPath $toolPath)) {
        $toolPath = Join-Path $workspaceRoot $item.RelativePath
      }
      $X = $item; if ([int]$(if ($X.Admin -is [bool]) { if ($X.Admin) { 3 } else { 1 } } elseif ($null -ne $X.Admin -and "$($X.Admin)" -match '^[0-3]$') { [int]"$($X.Admin)" } else { 0 }) -eq 3) { $elevated = $true }  # CRP-343: level 3 only
      if ($null -eq $noExit -and $null -ne $item.NoExit) {
        $noExit = [bool]$item.NoExit
      }
    }
  }

  if ($null -eq $noExit) { $noExit = $true }

  Write-ToolLog -Message "Parsed Tool: $toolName | Elevated: $elevated | NoExit: $noExit" -Level ACTION

  if (-not (Test-Path -LiteralPath $toolPath)) {
    throw "Target tool file not found: $toolName"
  }

  $ext = [System.IO.Path]::GetExtension($toolPath).ToLowerInvariant()
  $execCmd = ""

  if ($ext -eq '.ps1') {
    $noExitFlag = if ($noExit) { "-NoExit " } else { "" }
    $execCmd = "start `"$toolName`" pwsh.exe $($noExitFlag)-ExecutionPolicy Bypass -File `"$toolPath`""
  } elseif ($ext -in @('.cmd', '.bat')) {
    $kFlag = if ($noExit) { "/k" } else { "/c" }
    $execCmd = "start `"$toolName`" cmd.exe $kFlag `"$toolPath`""
  } elseif ($ext -eq '.py') {
    $kFlag = if ($noExit) { "/k" } else { "/c" }
    Import-Module -Name (Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LcmRuntimeAtoms.psm1') -Force
    $protocolPython = Get-LcmRuntimePath -Key 'python'
    $execCmd = "start `"$toolName`" cmd.exe $kFlag `"`"$protocolPython`" `"$toolPath`"`""
  } else {
    $execCmd = "start `"$toolName`" `"$toolPath`""
  }

  Write-ToolLog -Message "Dispatch Command: $execCmd" -Level ACTION

  $dispatcher = Join-Path $toolsDir 'Invoke-InteractiveDesktop.ps1'
  if ($elevated) {
    & $dispatcher -Command $execCmd -Elevated
  } else {
    & $dispatcher -Command $execCmd
  }

  Write-ToolLog -Message "Successfully dispatched $toolName." -Level SUMMARY
} catch {
  Write-ToolLog -Message "Dispatch error: $_" -Level ERROR
}

