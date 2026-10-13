<#
.SYNOPSIS
  Displays the interactive HTML dashboard for Home Assistant Subsystem Inventory.
.DESCRIPTION
  Direct runner for Show-HaInventoryApp.ps1. Displays the complete Home Assistant subsystem inventory (930+ entities & devices).
  Supports multi-instance selection via -Instance (Default: 'HaSSD06').
  Pass -Refresh to re-query live Home Assistant telemetry.
.PATH
  tools/Show-HaInventory.ps1
.VERSION
  10.0.0
.DATE
  2026-10-13
.PARAMETER Instance
  The target Home Assistant subsystem instance name (e.g. 'HaSSD06'). Defaults to 'HaSSD06' (Aliases: -Subsystem, -Name, -HaName).
.PARAMETER Refresh
  Queries live Home Assistant API to refresh data/subsystem_inventory.json before rendering.
.PARAMETER NoLaunch
  Generates the HTML dashboard file without automatically launching it in the web browser.
.PARAMETER Help
  Displays this parameter reference and usage instructions (Aliases: -h, -?).
#>

[CmdletBinding()]
param(
    [Alias('Subsystem', 'Name', 'HaName')]
    [string]$Instance = 'HaSSD06',
    [switch]$Refresh,
    [switch]$NoLaunch,
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
    $workspaceRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
}

$appScript = Join-Path $workspaceRoot "${Instance}_Inventory\tools\Show-HaInventoryApp.ps1"
if (-not (Test-Path -LiteralPath $appScript)) {
    $appScript = Join-Path $workspaceRoot "HaSSD06_Inventory\tools\Show-HaInventoryApp.ps1"
}
if (-not (Test-Path -LiteralPath $appScript)) {
    throw "Cannot locate Show-HaInventoryApp.ps1 for instance '${Instance}' at: $appScript"
}

$params = @{
    Instance = $Instance
}
if ($Refresh) { $params['Refresh'] = $true }
if ($NoLaunch) { $params['NoLaunch'] = $true }
if ($Help) { $params['Help'] = $true }

& pwsh -File $appScript @params
