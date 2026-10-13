<#
Module: LcmDaemon/LcmDaemon.psm1
Purpose: Root module loader dot-sourcing atomized classes for LCM Desktop Daemon.
Path: LCM_Inventory/modules/LcmDaemon/LcmDaemon.psm1
Authors: Rolf, LCM_AI Engine
Version: 10.0.0
Date: 2026-10-13
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleRoot = $PSScriptRoot
$classesDir = Join-Path $moduleRoot 'Classes'

# Strict Dependency Loading Order: DTOs -> Environment -> Controller
. (Join-Path $classesDir 'DaemonDto.ps1')
. (Join-Path $classesDir 'DaemonEnvironment.ps1')
. (Join-Path $classesDir 'DaemonActionController.ps1')

Export-ModuleMember -Function @(
  'Send-DaemonJsonResponse'
)

