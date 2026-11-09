<#
.SYNOPSIS
  Opens Standard Displays exclusively through the existing local HTTP daemon.
.NOTES
  Module: LcmStandardDisplay
  Purpose: Recover the existing daemon and open verified HTTP displays without file fallbacks.
  Path: modules/LcmStandardDisplay.psm1
  Authors: Rolf, Copilot
  Version: 10.0.1
  Date: 2026-11-08 17:34:00
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Open-LcmStandardDisplay {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateSet('tools','rules','inventory','hub','dates','failure-analysis','snapshot')][string]$DisplayId,
    [ValidatePattern('^[a-f0-9]{32}$')][string]$SnapshotId,
    [hashtable]$Parameters = @{},
    [ValidateRange(1,300)][int]$TimeoutSeconds = 120,
    [Alias('Panel')]
    [switch]$Pane
  )
  $origin = 'http://127.0.0.1:9876'
  $root = Split-Path $PSScriptRoot -Parent
  if ($DisplayId -in @('failure-analysis','snapshot') -and -not $SnapshotId) { throw 'A retained snapshot ID is required for evidence viewing.' }
  try {
    $daemon = Invoke-RestMethod -Uri "$origin/ping" -TimeoutSec 2 -ErrorAction Stop
  } catch {
    Write-Warning "Port 9876 is unavailable; attempting existing daemon recovery: $($_.Exception.Message)"
    & (Join-Path $root 'tools\LcmDesktopDaemon.ps1') -Background -Port 9876 | Out-Null
    $recoveryDeadline = [datetime]::UtcNow.AddSeconds(15)
    do {
      try {
        $daemon = Invoke-RestMethod -Uri "$origin/ping" -TimeoutSec 2 -ErrorAction Stop
        break
      } catch {
        if ([datetime]::UtcNow -ge $recoveryDeadline) { throw "Port 9876 daemon recovery failed: $($_.Exception.Message). No file fallback is permitted." }
        Start-Sleep -Milliseconds 250
      }
    } while ($true)
  }
  if (-not $daemon.PSObject.Properties['standardDisplays'] -or $daemon.standardDisplays -ne 1) {
    throw 'The port 9876 daemon must be restarted to load Standard Display delivery support. No file fallback is permitted.'
  }
  if ($DisplayId -in @('failure-analysis','snapshot')) {
    $prefix = if ($DisplayId -eq 'snapshot') { 'snapshots' } else { 'failure-analysis' }
    $url = "$origin/$prefix/$SnapshotId/index.html"
  } else {
    $status = Invoke-RestMethod -Uri "$origin/displays/refresh/$DisplayId" -Method Post -TimeoutSec 5 -ErrorAction Stop
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($status.state -ne 'Current') {
      if ($status.state -eq 'Failed') { throw "Display publication failed: $($status.error)" }
      if ([datetime]::UtcNow -ge $deadline) { throw "Display '$DisplayId' publication timed out. No local-file fallback is permitted." }
      Start-Sleep -Milliseconds 250
      $status = Invoke-RestMethod -Uri "$origin/displays/status/$DisplayId" -TimeoutSec 5 -ErrorAction Stop
    }
    $url = "$origin/$DisplayId"
  }
  if ($Parameters.Count) {
    $query = foreach ($key in @($Parameters.Keys | Sort-Object)) {
      if ([string]$key -notmatch '^[a-zA-Z][a-zA-Z0-9_-]*$') { throw "Invalid display parameter name: $key" }
      '{0}={1}' -f [Uri]::EscapeDataString([string]$key), [Uri]::EscapeDataString([string]$Parameters[$key])
    }
    $url += '?' + ($query -join '&')
  }
  $page = Invoke-WebRequest -Uri $url -TimeoutSec 5 -ErrorAction Stop
  if ($page.StatusCode -ne 200 -or $page.Headers['Content-Type'] -notmatch 'text/html') { throw "Standard Display is unavailable: $url" }
  $dispatcher = Join-Path $root 'tools\Invoke-InteractiveDesktop.ps1'
  if (-not (Test-Path -LiteralPath $dispatcher -PathType Leaf)) { throw "Interactive desktop dispatcher not found: $dispatcher" }
  & $dispatcher -FilePath $url -Pane:$Pane
  Write-Host "[ACTION] Standard Display: $url"
}

function Publish-LcmEvidenceSnapshot {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  $html = [IO.File]::ReadAllText($Path)
  if ($html -notmatch '(?i)<html\b' -or $html -match '(?i)(?:src|href)\s*=\s*["'']file:') { throw 'Invalid evidence snapshot or browser-facing file dependency.' }
  $id = [guid]::NewGuid().ToString('N')
  $directory = Join-Path (Split-Path $PSScriptRoot -Parent) "data\artifacts\snapshots\$id"
  $null = [IO.Directory]::CreateDirectory($directory)
  [IO.File]::WriteAllText((Join-Path $directory 'index.html'), $html, [Text.UTF8Encoding]::new($false))
  $id
}

Export-ModuleMember -Function Open-LcmStandardDisplay, Publish-LcmEvidenceSnapshot
