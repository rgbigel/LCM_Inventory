<#
.SYNOPSIS
  Mounts the latest completed same-day Macrium image as the writable BCR baseline.
.DESCRIPTION
  Requires explicit confirmation, then delegates to the canonical Macrium
  baseline workflow. It never starts another backup; absent a completed daily
  image, it fails and reports that fact.
  With -ImagePath it is the admin dispatcher of the elevated mount atom
  (CRP-343): it sends tools/Invoke-MacriumMountWorker.ps1 for exactly that image to
  the DO daemon (authenticated with the daemon key) and waits for its receipt.
  Path: LCM_Inventory/tools/Mount-MacriumLatestBaseline.ps1
  Authors: Rolf, LCM_AI Engine, Claude
  Version: 10.2.3
  Date: 2026-11-17
  Implementation Choices (CRP-343): this admin tool runs non-elevated; only the atom it
  dispatches runs elevated (non-admin tool -> admin tool -> elevated atom). Without
  -ImagePath the behaviour is unchanged (canonical workflow, which calls back here with
  -ImagePath for the mount step only). Daemon offline: the atom is started with a visible
  UAC prompt (RULE-ELEV-005 transparent arguments).
.NOTES
  Elevated Operations:
    - Mount-MacriumBaseline: elevated atom tools/Invoke-MacriumMountWorker.ps1 via the DO daemon.
  Caveats: the daemon fallback (-Verb RunAs) needs an interactive operator for the UAC prompt.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [switch]$ConfirmMount,

  [string]$ReviewScope = '',

  [Parameter(Mandatory = $false)]
  [object]$CandidateDrives = @('F', 'G', 'H', 'I'),

  [ValidateRange(30, 600)]
  [int]$MountTimeoutSeconds = 120,

  [switch]$NoLaunchReview,

  [string]$ImagePath = '',

  [string]$ExpectedVolumeLabel = 'D4P3-WDB850-D',

  [string]$ReceiptPath = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Approved elevated operations for this tool (RULE-ELEV-007)
New-Variable -Name ElevatedOperations -Value ([string[]]@('Mount-MacriumBaseline')) -Option ReadOnly -Scope Script -Force

if ($Help) {
  Write-Host 'Mount-MacriumLatestBaseline.ps1 -ConfirmMount [-ReviewScope <CRP|BUG>] [-NoLaunchReview] [-h]'
  Write-Host '  Mounts the latest completed same-day Macrium image. -ConfirmMount is required.'
  Write-Host 'Mount-MacriumLatestBaseline.ps1 -ConfirmMount -ImagePath <mrimgx> [-CandidateDrives F;G;H;I] [-ExpectedVolumeLabel <label>] [-MountTimeoutSeconds <n>] [-ReceiptPath <json>]'
  Write-Host '  Dispatcher mode (CRP-343): runs only the elevated mount atom Invoke-MacriumMountWorker.ps1 through the DO daemon.'
  return
}
if (-not $ConfirmMount -and -not $WhatIfPreference) {
  throw 'Mounting a writable Macrium baseline requires explicit -ConfirmMount.'
}

if ([string]::IsNullOrWhiteSpace($ImagePath)) {
  $baselineTool = Join-Path $PSScriptRoot 'Invoke-MacriumDailyBcrBaseline.ps1'
  if (-not (Test-Path -LiteralPath $baselineTool -PathType Leaf)) {
    throw "Canonical Macrium baseline tool was not found: $baselineTool"
  }
  & $baselineTool -NewBaseline -CandidateDrives $CandidateDrives -ReviewScope $ReviewScope -MountTimeoutSeconds $MountTimeoutSeconds -NoLaunchReview:$NoLaunchReview -Confirm:$false -WhatIf:$WhatIfPreference
  return
}

# --- Dispatcher mode (CRP-343): only the elevated atom runs elevated ---------------
$inventoryRoot = Split-Path $PSScriptRoot -Parent
Import-Module -Name (Join-Path $inventoryRoot 'modules\LcmMacriumAtoms.psm1') -Force
Import-Module -Name (Join-Path $inventoryRoot 'modules\LcmDoClient.psm1') -Force
$atom = Join-Path $PSScriptRoot 'Invoke-MacriumMountWorker.ps1'
if (-not (Test-Path -LiteralPath $atom -PathType Leaf)) {
  throw "Elevated mount atom was not found: $atom"
}
if ([string]::IsNullOrWhiteSpace($ReceiptPath)) {
  $ReceiptPath = Join-Path $env:TEMP ('Invoke-MacriumMountWorker-{0}.json' -f [guid]::NewGuid().ToString('N'))
}
$drives = (@(ConvertTo-LcmCandidateDrives -Drives $CandidateDrives) -join ';')
$atomArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $atom, '-ImagePath', $ImagePath, '-CandidateDrives', $drives, '-ExpectedVolumeLabel', $ExpectedVolumeLabel, '-MountTimeoutSeconds', [string]$MountTimeoutSeconds, '-ReceiptPath', $ReceiptPath)

if ($WhatIfPreference) {
  Write-Host ('WhatIf: would dispatch the elevated atom: pwsh {0}' -f ($atomArgs -join ' '))
  return
}

$dispatched = $false
try {
  $quoted = @($atomArgs | ForEach-Object { "'" + ([string]$_).Replace("'", "''") + "'" }) -join ' '
  $command = '& pwsh ' + $quoted
  $resp = Invoke-LcmDaemonCommand -Command $command -Sync -Elevated -TimeoutSeconds ($MountTimeoutSeconds + 30)
  Write-Host ('[INFO] DO daemon: {0} (exit {1}); {2}' -f $resp.status, $resp.exitCode, $resp.elevationDecision)
  $dispatched = Test-Path -LiteralPath $ReceiptPath
} catch {
  Write-Host ('[WARN] DO daemon dispatch unavailable ({0}); falling back to a visible UAC prompt.' -f $_.Exception.Message)
}

if (-not $dispatched) {
  Write-Host ('[ACTION] {0:yyyy-MM-dd HH:mm:ss} Elevated start (UAC): pwsh {1}' -f (Get-Date), ($atomArgs -join ' '))
  $proc = Start-Process -FilePath 'pwsh.exe' -ArgumentList $atomArgs -Verb RunAs -PassThru -Wait
  if (-not (Test-Path -LiteralPath $ReceiptPath)) {
    throw ('The elevated mount atom exited with code {0} without a receipt.' -f $proc.ExitCode)
  }
}
$receipt = Get-Content -LiteralPath $ReceiptPath -Raw | ConvertFrom-Json
if (-not $receipt.Succeeded) {
  exit 1
}
exit 0
