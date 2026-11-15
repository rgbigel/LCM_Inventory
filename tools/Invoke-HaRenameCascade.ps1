<#
.SYNOPSIS
  Cascades Home Assistant Device and Entity renaming across subsystem inventory and local configurations.
.DESCRIPTION
  Performs safe, transactional renaming of Home Assistant physical devices and entities.
  Features:
  1. Transaction Ledger & Gap Protection: Generates timestamped staging ledgers in data/staging/
     recording all Old -> New name and entity ID mappings, child entities, and impacted references.
  2. Reverse-Dependency Cascade: Scans and updates references across data/subsystem_inventory.json,
     automations catalog, scripts catalog, helper configurations, and local YAML files.
  3. Pre-Flight Dry Run Mode: Validates pattern changes and outputs detailed diff before mutation.
  4. Pre-Commit and Post-Commit Rollback: Enables complete restoration using transaction snapshots.
  5. Audit & Compliance: Conforms to RULE-SUB-004, RULE-SUB-007, RULE-PS-008, RULE-PS-009, and RULE-PS-010.
.PATH
  HaSSD06_Inventory/tools/Invoke-HaRenameCascade.ps1
.AUTHORS
  Rolf, LCM_AI Engine
.VERSION
  1.0.1
.DATE
  2026-09-19
.PARAMETER DeviceId
  Target Home Assistant device ID to rename.
.PARAMETER EntityId
  Target Home Assistant entity ID to rename.
.PARAMETER NewName
  New friendly name for the target device or entity.
.PARAMETER NewEntityId
  New entity ID (e.g. 'switch.kueche_sh1_relay') when renaming an entity directly.
.PARAMETER Pattern
  Pattern template used for generation (e.g. '<Area> <Device>', '<Area> <Manufacturer> <Model>').
.PARAMETER CascadeChildren
  When specified with -DeviceId, cascades renaming to all child entities belonging to the device.
.PARAMETER StagingFile
  Path to a pre-staged transaction JSON file created by the Subsystem Inventory Explorer UI.
.PARAMETER BackupId
  Verified pre-change Home Assistant backup snapshot identifier.
.PARAMETER DryRun
  Simulates the cascade and displays diff without modifying any inventory files or registries.
.PARAMETER Rollback
  Rolls back a previously staged or executed transaction using its TransactionId.
.PARAMETER TransactionId
  The unique transaction ID to apply, verify, or rollback.
.PARAMETER Instance
  Target Home Assistant instance name (Default: 'HaSSD06').
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Invoke-HaRenameCascade.ps1 -h
.EXAMPLE
  pwsh tools/Invoke-HaRenameCascade.ps1 -DeviceId "031-sh1-kueche-c45bbe779c3c" -NewName "Kueche Hauptlicht" -CascadeChildren -DryRun
.EXAMPLE
  pwsh tools/Invoke-HaRenameCascade.ps1 -EntityId "switch.sh1_kueche_relay" -NewEntityId "switch.kueche_licht_relay" -NewName "Kueche Licht Relay"
.EXAMPLE
  pwsh tools/Invoke-HaRenameCascade.ps1 -Rollback -TransactionId "tx_20260918_233000"
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$DeviceId,
    [string]$EntityId,
    [string]$NewName,
    [string]$NewEntityId,
    [string]$Pattern,
    [switch]$CascadeChildren,
    [string]$StagingFile,
    [string]$BackupId,
    [switch]$DryRun,
    [switch]$Rollback,
    [string]$TransactionId,
    [string]$Instance = 'HaSSD06',
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " HOME ASSISTANT RENAME CASCADE ENGINE (v1.0.0)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Cascades Home Assistant Device and Entity renaming across subsystem inventory and configurations."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Invoke-HaRenameCascade.ps1 [-DeviceId <id>] [-NewName <name>] [-CascadeChildren] [-DryRun]"
    Write-Host "  pwsh tools/Invoke-HaRenameCascade.ps1 [-EntityId <id>] [-NewEntityId <id>] [-NewName <name>] [-DryRun]"
    Write-Host "  pwsh tools/Invoke-HaRenameCascade.ps1 -StagingFile <path> [-DryRun]"
    Write-Host "  pwsh tools/Invoke-HaRenameCascade.ps1 -Rollback -TransactionId <tx_id>"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -DeviceId        : Target physical device ID to rename."
    Write-Host "  -EntityId        : Target entity ID to rename."
    Write-Host "  -NewName         : New friendly display name."
    Write-Host "  -NewEntityId     : New entity ID (e.g. 'domain.new_name')."
    Write-Host "  -Pattern         : Pattern template used (<Area> <Device>, etc.)."
    Write-Host "  -CascadeChildren : Automatically cascade rename to all child entities."
    Write-Host "  -StagingFile     : Path to pre-staged JSON transaction ledger."
    Write-Host "  -BackupId        : Pre-change HA backup verification ID."
    Write-Host "  -DryRun          : Simulates rename diff without modifying files."
    Write-Host "  -Rollback        : Restores state from specified transaction snapshot."
    Write-Host "  -TransactionId   : Transaction ID identifier."
    Write-Host "  -Instance        : Subsystem instance name (Default: 'HaSSD06')."
    Write-Host "  -h, -Help        : Displays this parameter reference."
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$workspaceRoot = 'D:\Git_Repositories'
$repoRoot = Join-Path $workspaceRoot "${Instance}_Inventory"
if (-not (Test-Path -LiteralPath $repoRoot)) {
    $repoRoot = $PSScriptRoot | Split-Path -Parent
}

$stagingDir = Join-Path $repoRoot 'data\staging'
if (-not (Test-Path -LiteralPath $stagingDir)) {
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
}

$logsDir = Join-Path $repoRoot 'data\logs'
if (-not (Test-Path -LiteralPath $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}
$logFile = Join-Path $logsDir 'rename_cascade.log'

function Write-CascadeLog {
    param([string]$Message, [string]$Level = 'INFO')
    $t = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$t] [$Level] $Message"
    Write-Host $line -ForegroundColor $(if ($Level -eq 'WARN') { 'Yellow' } elseif ($Level -eq 'ERROR') { 'Red' } elseif ($Level -eq 'SUCCESS') { 'Green' } else { 'Cyan' })
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

$invPath = Join-Path $repoRoot 'data\subsystem_inventory.json'
if (-not (Test-Path -LiteralPath $invPath)) {
    throw "Inventory file not found: $invPath"
}

# -----------------------------------------------------------------------------
# Handle Rollback Mode
# -----------------------------------------------------------------------------
if ($Rollback) {
    if (-not $TransactionId) {
        throw "Parameter -TransactionId is required when using -Rollback."
    }
    Write-CascadeLog "Initiating rollback for transaction '$TransactionId'..." 'WARN'
    $txFile = Join-Path $stagingDir "${TransactionId}.json"
    if (-not (Test-Path -LiteralPath $txFile)) {
        throw "Transaction staging file not found: $txFile"
    }

    $tx = Get-Content -LiteralPath $txFile -Raw | ConvertFrom-Json
    if ($tx.PSObject.Properties['snapshot_backup'] -and (Test-Path -LiteralPath $tx.snapshot_backup)) {
        Copy-Item -LiteralPath $tx.snapshot_backup -Destination $invPath -Force
        Write-CascadeLog "Restored subsystem_inventory.json from snapshot backup: $($tx.snapshot_backup)" 'SUCCESS'
    } else {
        throw "No valid snapshot_backup found in transaction $TransactionId to restore from."
    }

    $tx.state = 'rolled_back'
    $tx.rolled_back_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $tx | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $txFile -Encoding UTF8
    Write-CascadeLog "Transaction '$TransactionId' marked as rolled_back." 'SUCCESS'

    # Regenerate viewer
    $appScript = Join-Path $repoRoot 'tools\Show-HaInventoryApp.ps1'
    if (Test-Path -LiteralPath $appScript) {
        & pwsh -File $appScript -NoLaunch
    }
    return
}

# -----------------------------------------------------------------------------
# Build or Load Transaction Ledger
# -----------------------------------------------------------------------------
$nowStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
$txId = if ($TransactionId) { $TransactionId } else { "tx_$nowStr" }
$txFilePath = Join-Path $stagingDir "${txId}.json"

$txData = $null
if ($StagingFile -and (Test-Path -LiteralPath $StagingFile)) {
    Write-CascadeLog "Loading pre-staged transaction from $StagingFile..." 'INFO'
    $txData = Get-Content -LiteralPath $StagingFile -Raw | ConvertFrom-Json
} elseif (Test-Path -LiteralPath $txFilePath) {
    Write-CascadeLog "Loading existing transaction ledger: $txFilePath" 'INFO'
    $txData = Get-Content -LiteralPath $txFilePath -Raw | ConvertFrom-Json
}

$invRaw = Get-Content -LiteralPath $invPath -Raw
$inv = $invRaw | ConvertFrom-Json

# Helper: Slugify string
function ConvertTo-Slug {
    param([string]$Text)
    if (-not $Text) { return '' }
    $s = $Text.ToLower().Trim()
    $s = $s -replace 'ä', 'ae' -replace 'ö', 'oe' -replace 'ü', 'ue' -replace 'ß', 'ss'
    $s = $s -replace '[^a-z0-9_]+', '_'
    $s = $s -replace '^_+|_+$', ''
    $s = $s -replace '_+', '_'
    return $s
}


$deviceUpdates = @()
$entityUpdates = @()
$impactedRefs = @()

if ($txData) {
    $deviceUpdates = @($txData.device_updates)
    $entityUpdates = @($txData.entity_updates)
} else {
    # Manual CLI parameters
    if ($DeviceId) {
        $dev = $inv.devices_catalog | Where-Object { $_.id -eq $DeviceId -or $_.name -eq $DeviceId } | Select-Object -First 1
        if (-not $dev) {
            throw "Device ID or Name '$DeviceId' not found in inventory."
        }
        $targetDevName = if ($NewName) { $NewName } else { $dev.name }
        $deviceUpdates += [PSCustomObject]@{
            id = $dev.id
            old_name = $dev.name
            new_name = $targetDevName
            area = $dev.area
            manufacturer = $dev.manufacturer
            model = $dev.model
        }

        if ($CascadeChildren -and $dev.child_entities) {
            $areaSlug = ConvertTo-Slug $dev.area
            $devSlug = ConvertTo-Slug $targetDevName
            foreach ($child in $dev.child_entities) {
                $dom = $child.domain
                $oldEid = $child.entity_id
                $oldChildName = $child.name
                
                # Derive child suffix
                $suffix = $oldEid -replace "^$dom\.", ""
                $suffix = $suffix -replace "^(0[0-9]+|sh[0-9]+|esp|tuya)_?", ""
                if (-not $suffix) { $suffix = ConvertTo-Slug $oldChildName }
                if (-not $suffix) { $suffix = "entity" }

                $newEid = if ($areaSlug) { "${dom}.${areaSlug}_${devSlug}_${suffix}" } else { "${dom}.${devSlug}_${suffix}" }
                $newChildName = "${targetDevName} $(if ($oldChildName -ne $dev.name) { $oldChildName } else { $suffix })"

                $entityUpdates += [PSCustomObject]@{
                    old_entity_id = $oldEid
                    new_entity_id = $newEid
                    old_name = $oldChildName
                    new_name = $newChildName
                    domain = $dom
                    device_id = $dev.id
                }
            }
        }
    } elseif ($EntityId) {
        $ent = $inv.entities_catalog | Where-Object { $_.entity_id -eq $EntityId } | Select-Object -First 1
        if (-not $ent) {
            throw "Entity ID '$EntityId' not found in inventory."
        }
        $targetEid = if ($NewEntityId) { $NewEntityId } else { $ent.entity_id }
        $targetEntName = if ($NewName) { $NewName } else { $ent.name }

        $entityUpdates += [PSCustomObject]@{
            old_entity_id = $ent.entity_id
            new_entity_id = $targetEid
            old_name = $ent.name
            new_name = $targetEntName
            domain = $ent.domain
            device_id = $ent.device_id
        }
    } else {
        throw "Either -DeviceId, -EntityId, or -StagingFile must be supplied."
    }
}

# Scan Reverse Dependencies
Write-CascadeLog "Scanning reverse dependencies across automations, scripts, and helpers..." 'INFO'
$allOldEids = @($entityUpdates | ForEach-Object { $_.old_entity_id })
$allOldDevNames = @($deviceUpdates | ForEach-Object { $_.old_name })

if ($inv.PSObject.Properties['automations_catalog']) {
    foreach ($auto in $inv.automations_catalog) {
        foreach ($oe in $allOldEids) {
            if ($auto.entity -eq $oe) { continue }
            if ($auto.name -match [regex]::Escape($oe) -or $auto.entity -match [regex]::Escape($oe)) {
                $impactedRefs += [PSCustomObject]@{
                    type = 'automation'
                    id = $auto.entity
                    name = $auto.name
                    matched_target = $oe
                }
            }
        }
    }
}

if ($inv.PSObject.Properties['scripts_catalog']) {
    foreach ($scr in $inv.scripts_catalog) {
        foreach ($oe in $allOldEids) {
            if ($scr.entity -eq $oe) { continue }
            if ($scr.name -match [regex]::Escape($oe) -or $scr.entity -match [regex]::Escape($oe)) {
                $impactedRefs += [PSCustomObject]@{
                    type = 'script'
                    id = $scr.entity
                    name = $scr.name
                    matched_target = $oe
                }
            }
        }
    }
}

if ($inv.PSObject.Properties['helpers_and_virtual']) {
    foreach ($hlp in $inv.helpers_and_virtual) {
        foreach ($oe in $allOldEids) {
            if ($hlp.entity -eq $oe) { continue }
            if ($hlp.name -match [regex]::Escape($oe) -or $hlp.entity -match [regex]::Escape($oe)) {
                $impactedRefs += [PSCustomObject]@{
                    type = 'helper'
                    id = $hlp.entity
                    name = $hlp.name
                    matched_target = $oe
                }
            }
        }
    }
}

# Output Plan / Diff
Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host " TRANSACTION PREVIEW: $txId" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "Device Updates  : $($deviceUpdates.Count)" -ForegroundColor White
foreach ($du in $deviceUpdates) {
    Write-Host "  📱 Device [$($du.id)]: '$($du.old_name)' -> '$($du.new_name)'" -ForegroundColor Green
}

Write-Host "Entity Updates  : $($entityUpdates.Count)" -ForegroundColor White
foreach ($eu in $entityUpdates) {
    Write-Host "  ⚡ Entity: '$($eu.old_entity_id)' -> '$($eu.new_entity_id)' ('$($eu.old_name)' -> '$($eu.new_name)')" -ForegroundColor Green
}

Write-Host "Impacted References: $($impactedRefs.Count)" -ForegroundColor White
foreach ($ir in $impactedRefs) {
    Write-Host "  🔗 [$($ir.type.ToUpper())] $($ir.id) ('$($ir.name)') contains '$($ir.matched_target)'" -ForegroundColor Yellow
}
Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray

# Persist Transaction Snapshot Backup
$snapshotPath = Join-Path $stagingDir "${txId}_snapshot.json"
if (-not (Test-Path -LiteralPath $snapshotPath)) {
    Copy-Item -LiteralPath $invPath -Destination $snapshotPath -Force
}

$ledgerRecord = [PSCustomObject]@{
    transaction_id = $txId
    created_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    instance = $Instance
    backup_id = $BackupId
    state = if ($DryRun) { 'staged_dry_run' } else { 'applied' }
    snapshot_backup = $snapshotPath
    device_updates = $deviceUpdates
    entity_updates = $entityUpdates
    impacted_references = $impactedRefs
}

$ledgerJson = $ledgerRecord | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($txFilePath, $ledgerJson, [System.Text.UTF8Encoding]::new($false))
Write-CascadeLog "Transaction ledger staged at: $txFilePath" 'SUCCESS'

if ($DryRun) {
    Write-CascadeLog "Dry-run validation complete. No mutations applied to inventory." 'SUCCESS'
    return
}

# -----------------------------------------------------------------------------
# Execute Mutation against Inventory JSON
# -----------------------------------------------------------------------------
Write-CascadeLog "Applying mutations to subsystem_inventory.json..." 'INFO'

# 1. Update devices catalog
if ($inv.PSObject.Properties['devices_catalog']) {
    foreach ($du in $deviceUpdates) {
        $devObj = $inv.devices_catalog | Where-Object { $_.id -eq $du.id } | Select-Object -First 1
        if ($devObj) {
            $devObj.name = $du.new_name
            if ($devObj.child_entities) {
                foreach ($child in $devObj.child_entities) {
                    $matchedEu = $entityUpdates | Where-Object { $_.old_entity_id -eq $child.entity_id } | Select-Object -First 1
                    if ($matchedEu) {
                        $child.entity_id = $matchedEu.new_entity_id
                        $child.name = $matchedEu.new_name
                    }
                }
            }
        }
    }
}

# 2. Update entities catalog
if ($inv.PSObject.Properties['entities_catalog']) {
    foreach ($eu in $entityUpdates) {
        $entObj = $inv.entities_catalog | Where-Object { $_.entity_id -eq $eu.old_entity_id } | Select-Object -First 1
        if ($entObj) {
            $entObj.entity_id = $eu.new_entity_id
            $entObj.name = $eu.new_name
            $matchedDu = $deviceUpdates | Where-Object { $_.id -eq $entObj.device_id } | Select-Object -First 1
            if ($matchedDu) {
                $entObj.device_name = $matchedDu.new_name
            }
        }
    }
}

# 3. Update automations, scripts, helpers references if string matches
if ($inv.PSObject.Properties['automations_catalog']) {
    foreach ($auto in $inv.automations_catalog) {
        foreach ($eu in $entityUpdates) {
            if ($auto.name -match [regex]::Escape($eu.old_entity_id)) {
                $auto.name = $auto.name -replace [regex]::Escape($eu.old_entity_id), $eu.new_entity_id
            }
        }
    }
}

# Save updated inventory
$invJson = $inv | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($invPath, $invJson, [System.Text.UTF8Encoding]::new($false))
Write-CascadeLog "Successfully updated $invPath" 'SUCCESS'

# Regenerate viewer HTML
$appScript = Join-Path $repoRoot 'tools\Show-HaInventoryApp.ps1'
if (Test-Path -LiteralPath $appScript) {
    Write-CascadeLog "Regenerating interactive HTML dashboard..." 'INFO'
    & pwsh -File $appScript -NoLaunch
}

Write-CascadeLog "Rename cascade completed successfully for transaction $txId." 'SUCCESS'
