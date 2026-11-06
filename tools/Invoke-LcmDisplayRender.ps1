<#
.SYNOPSIS
  Runs one allowlisted standard display renderer without launching a browser.
.NOTES
  Module: Invoke-LcmDisplayRender
  Purpose: Run an internal allowlisted display renderer with auditable completion.
  Path: tools/Invoke-LcmDisplayRender.ps1
  Authors: Rolf, Copilot
  Version: 10.0.1
  Date: 2026-10-21
#>
[CmdletBinding()]
param(
  [ValidateSet('tools','rules','inventory','hub','dates')][string]$DisplayId,
  [string]$LogPath,
  [switch]$ShowAll,
  [Alias('h','?')][switch]$Help
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Help) {
  Write-Host 'Invoke-LcmDisplayRender.ps1 - Internal Standard Display renderer'
  Write-Host 'Usage: Invoke-LcmDisplayRender.ps1 -DisplayId <tools|rules|inventory|hub|dates> -LogPath <absolute log file> [-ShowAll]'
  Write-Host 'DisplayId selects a fixed renderer; LogPath records its output. ShowAll prints the detailed operation log.'
  Write-Host 'Example: Invoke-LcmDisplayRender.ps1 -DisplayId rules -LogPath D:\Git_Repositories\LCM_Inventory\data\logs\lcm\rules-render.log'
  return
}
if (-not $DisplayId -or -not $LogPath) { throw 'DisplayId and LogPath are required. Use -Help for usage.' }
$root = Split-Path $PSScriptRoot -Parent
Import-Module -Name (Join-Path $root 'modules\LcmDisplayDependencies.psm1') -Force
$status = 'FAILED'
try {
  & {
    if ($DisplayId -eq 'tools') {
      & (Join-Path $PSScriptRoot 'Update-ToolCatalog.ps1') -Silent
      if (-not $?) { throw 'Catalog synchronization failed before display rendering.' }
    }
    $definitions = Get-LcmDisplayDefinitions -WorkspaceRoot (Split-Path $root -Parent)
    $arguments = @{ NoLaunch = $true }
    if ($DisplayId -eq 'dates') { $arguments.DatesMode = $true }
    & $definitions[$DisplayId].Renderer @arguments
    if (-not $?) { throw "Renderer '$DisplayId' reported an unsuccessful exit." }
  } *> $LogPath
  $status = 'COMPLETED'
} catch {
  $_ | Out-String | Add-Content -LiteralPath $LogPath -Encoding UTF8
  exit 1
} finally {
  $summary = "[SUMMARY] Invoke-LcmDisplayRender.ps1 v10.0.1 Status=$status Log=$LogPath Time=$([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))"
  Add-Content -LiteralPath $LogPath -Value $summary -Encoding UTF8
  if ($ShowAll) { Get-Content -LiteralPath $LogPath | Write-Output }
  Write-Output $summary
}
