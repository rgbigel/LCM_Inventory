<#
.SYNOPSIS
  Shared catalog discovery locations for generation and display invalidation.
.NOTES
  Module: LcmToolScanLocations
  Purpose: Share canonical discovery locations between generation and invalidation.
  Path: modules/LcmToolScanLocations.psm1
  Authors: Rolf, Copilot
  Version: 10.2.1
  Date: 2026-10-21
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LcmToolScanLocations {
  [CmdletBinding()]
  param()
  @(
    @{ Group='LCM_Inventory'; Domain='LCM_Inventory'; Path='LCM_Inventory\tools'; Filter='*.ps1' }
    @{ Group='LCM_Inventory'; Domain='LCM_Inventory'; Path='LCM_Inventory\tools'; Filter='*.py' }
    @{ Group='LCM_Tools'; Domain='LCM_Tools'; Path='LCM_Tools\tools'; Filter='*.ps1' }
    @{ Group='SystemConfiguration'; Domain='SystemConfiguration'; Path='SystemConfiguration\Source'; Filter='@*' }
    @{ Group='SystemConfiguration'; Domain='SystemConfiguration'; Path='SystemConfiguration\Source'; Filter='$*' }
    @{ Group='SystemConfiguration'; Domain='SystemConfiguration'; Path='SystemConfiguration\Source'; Filter='*.ps1' }
    @{ Group='SystemConfiguration'; Domain='SystemConfiguration'; Path='SystemConfiguration\Source'; Filter='*.cmd' }
    @{ Group='SystemConfiguration'; Domain='SystemConfiguration'; Path='SystemConfiguration\Source\Invariants'; Filter='*.ps1' }
    @{ Group='SystemConfiguration'; Domain='SystemConfiguration'; Path='SystemConfiguration\Source\Customizations'; Filter='@*' }
    @{ Group='SystemConfiguration'; Domain='SystemConfiguration'; Path='SystemConfiguration\Source\Customizations'; Filter='*.ps1' }
    @{ Group='SystemConfiguration'; Domain='SystemConfiguration'; Path='SystemConfiguration\Source\Repair'; Filter='*.ps1' }
    @{ Group='SystemConfiguration'; Domain='SystemConfiguration'; Path='SystemConfiguration\Source\Repair'; Filter='*.cmd' }
    @{ Group='HaSSD06'; Domain='HaSSD06'; Path='HaSSD06\tools'; Filter='*.ps1' }
    @{ Group='HaSSD06'; Domain='HaSSD06'; Path='HaSSD06\tools'; Filter='*.py' }
    @{ Group='HaSSD06'; Domain='HaSSD06'; Path='HaSSD06\tools\subsystem'; Filter='*.ps1' }
    @{ Group='HaSSD06'; Domain='HaSSD06_Inventory'; Path='HaSSD06_Inventory\tools'; Filter='*.ps1' }
    @{ Group='HaSSD06'; Domain='HaSSD06_Inventory'; Path='HaSSD06_Inventory\tools'; Filter='*.py' }
    @{ Group='HaSSD06'; Domain='HaSSD06'; Path='HaSSD06'; Filter='*.py' }
    @{ Group='LCM_Supervision'; Domain='LCM_Supervision'; Path='LCM_Supervision\tools'; Filter='*.ps1' }
  )
}

Export-ModuleMember -Function Get-LcmToolScanLocations
