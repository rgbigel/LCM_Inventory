<#
Module: LcmDaemon/LcmDaemon.psm1
Purpose: Root module loader dot-sourcing atomized classes for LCM Desktop Daemon.
Path: LCM_Inventory/modules/LcmDaemon/LcmDaemon.psm1
Authors: Rolf, LCM_AI Engine
Version: 10.0.1
Date: 2026-11-08 15:17:24
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleRoot = $PSScriptRoot
$classesDir = Join-Path $moduleRoot 'Classes'

# Strict Dependency Loading Order: DTOs -> TokenVault -> SecurityGateway -> Environment -> Controller
. (Join-Path $classesDir 'DaemonDto.ps1')
. (Join-Path $classesDir 'LcmTokenVault.ps1')
. (Join-Path $classesDir 'LcmSecurityGateway.ps1')
. (Join-Path $classesDir 'DaemonEnvironment.ps1')
. (Join-Path $classesDir 'DaemonActionController.ps1')

Export-ModuleMember -Function @(
  'Send-DaemonJsonResponse'
)

