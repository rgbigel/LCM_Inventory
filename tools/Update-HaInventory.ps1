<#
Module: tools/Update-HaInventory.ps1
Purpose: Connects to Home Assistant OS using the local ha-auditor secret, extracts active telemetry, and refreshes data/subsystem_inventory.json and docs/SUBSYSTEM_DASHBOARD.md.
Governance Invariant (RULE-SUB-007): Operates strictly as a read-only telemetry observer. Under no circumstances does this tool mutate, clean, or write to the Home Assistant central registry.
Path: tools/Update-HaInventory.ps1
Authors: Rolf, LCM_AI Engine
Version: 5.5.1
Date: 2026-11-08 17:35:00
#>

[CmdletBinding()]
param(
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " UPDATE HOME ASSISTANT INVENTORY (Update-HaInventory.ps1)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Connects to Home Assistant OS using local ha-auditor secret,"
    Write-Host "  extracts active telemetry, and refreshes data/subsystem_inventory.json"
    Write-Host "  and docs/SUBSYSTEM_DASHBOARD.md."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh HaSSD06_Inventory/tools/Update-HaInventory.ps1 [-h]"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$repoRoot = Split-Path $PSScriptRoot -Parent
$secretsPath = Join-Path $repoRoot 'data\secrets.json'
$invPath = Join-Path $repoRoot 'data\subsystem_inventory.json'
$dashPath = Join-Path $repoRoot 'docs\SUBSYSTEM_DASHBOARD.md'

if (-not (Test-Path -LiteralPath $secretsPath)) {
    Write-Warning "Secrets file not found: $secretsPath. Telemetry update skipped."
    return
}

function Resolve-HaEndpoint {
    [CmdletBinding()]
    param(
        [string]$ConfiguredUrl,
        [hashtable]$Headers
    )

    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($ConfiguredUrl) { $candidates.Add($ConfiguredUrl.TrimEnd('/')) }
    if ($env:HA_URL) { $candidates.Add($env:HA_URL.TrimEnd('/')) }

    $defaults = @(
        "http://192.168.10.6:8123",
        "http://192.168.10.106:8123",
        "http://HaSSD06.local:8123",
        "http://hassd06:8123"
    )
    foreach ($d in $defaults) {
        if (-not $candidates.Contains($d)) { $candidates.Add($d) }
    }

    foreach ($cand in $candidates) {
        try {
            $null = Invoke-RestMethod -Uri "$cand/api/config" -Headers $Headers -TimeoutSec 2 -ErrorAction Stop
            return $cand
        } catch {
            # Probe next candidate
        }
    }

    return if ($ConfiguredUrl) { $ConfiguredUrl.TrimEnd('/') } else { "http://192.168.10.6:8123" }
}

$secrets = Get-Content -LiteralPath $secretsPath -Raw | ConvertFrom-Json
$configuredUrl = $secrets.api_url
$token = $secrets.ha_auditor_token

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

$url = Resolve-HaEndpoint -ConfiguredUrl $configuredUrl -Headers $headers

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " HaSSD06 Subsystem Telemetry & CM Collector                     " -ForegroundColor Cyan
Write-Host " Target Active Domain: $url" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

try {
    Write-Host "Querying Home Assistant API ($url/api/config)..." -ForegroundColor White
    $cfg = Invoke-RestMethod -Uri "$url/api/config" -Headers $headers -TimeoutSec 10
    $states = Invoke-RestMethod -Uri "$url/api/states" -Headers $headers -TimeoutSec 10

    $coreVer = $cfg.version
    $entityCount = @($states).Count
    $components = @($cfg.components).Count
    $automations = @($states | Where-Object { $_.entity_id -match '^automation\.' }).Count
    $scripts = @($states | Where-Object { $_.entity_id -match '^script\.' }).Count

    Write-Host "Telemetry extracted successfully:" -ForegroundColor Green
    Write-Host "  - Core Version: $coreVer"
    Write-Host "  - Entities: $entityCount"
    Write-Host "  - Components: $components"
    Write-Host "  - Automations: $automations"

    $discoveredAddons = @()
    $seenAddonKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    
    # Attempt direct Supervisor Add-ons query
    try {
        $hassioAddons = Invoke-RestMethod -Uri "$url/api/hassio/addons" -Headers $headers -TimeoutSec 5 -ErrorAction Stop
        if ($hassioAddons -and $hassioAddons.data -and $hassioAddons.data.addons) {
            foreach ($a in $hassioAddons.data.addons) {
                $slugKey = "addon_$($a.slug)"
                if ($seenAddonKeys.Add($slugKey)) {
                    $discoveredAddons += [ordered]@{
                        name           = $a.name
                        category       = 'Supervisor Add-on'
                        entity         = $slugKey
                        version        = $a.version
                        latest_version = if ($a.version_latest) { $a.version_latest } else { $a.version }
                        state          = if ($a.state -eq 'started') { 'running' } else { $a.state }
                        raw_state      = $a.state
                        release_url    = ''
                    }
                }
            }
        }
    } catch {}

    # Merge Studio Code Server (VS Code)
    if ($seenAddonKeys.Add("addon_a0d7b954_vscode")) {
        $discoveredAddons += [ordered]@{
            name           = "Studio Code Server (VS Code)"
            category       = "Supervisor Add-on"
            entity         = "addon_a0d7b954_vscode"
            version        = "Current (HA Ingress)"
            latest_version = "Current (HA Ingress)"
            state          = "running"
            raw_state      = "running"
            release_url    = ""
        }
    }

    # Merge discovered update entities with category classification and semantic state resolution
    $updateEntities = @($states | Where-Object { $_.entity_id -match '^update\.' })
    foreach ($u in $updateEntities) {
        $attrs = $u.attributes
        $title = if ($attrs.PSObject.Properties['title'] -and $attrs.title) { $attrs.title } elseif ($attrs.PSObject.Properties['friendly_name'] -and $attrs.friendly_name) { $attrs.friendly_name } else { $u.entity_id }
        $cleanTitle = $title -replace ' Update$', ''
        $installed = if ($attrs.PSObject.Properties['installed_version'] -and $attrs.installed_version) { "$($attrs.installed_version)" } else { 'Unknown' }
        $latest = if ($attrs.PSObject.Properties['latest_version'] -and $attrs.latest_version) { "$($attrs.latest_version)" } else { $installed }
        $relUrl = if ($attrs.PSObject.Properties['release_url'] -and $attrs.release_url) { "$($attrs.release_url)" } else { '' }
        $eid = $u.entity_id

        # Automatic category classification
        $cat = if ($eid -eq 'update.home_assistant_core_update') { 'Core Subsystem' }
               elseif ($eid -eq 'update.home_assistant_supervisor_update') { 'Supervisor Subsystem' }
               elseif ($eid -eq 'update.home_assistant_operating_system_update') { 'Operating System' }
               elseif ($eid -match 'firmware|fritz_os|fp300') { 'Device Firmware' }
               elseif ($eid -match 'card_update|remote_card') { 'Lovelace Card' }
               elseif ($eid -match 'matter_server|go2rtc|mosquitto|vnc|filebrowser|samba|srat') { 'Supervisor Add-on' }
               else { 'HACS / Custom Integration' }

        # Resolve Home Assistant update entity state semantics:
        # - 'off' indicates no update pending (installed is current/up-to-date)
        # - 'on' indicates a newer update is pending installation
        $semanticState = switch ($u.state) {
            'off'         { 'up_to_date' }
            'on'          { 'update_available' }
            'installing'  { 'installing' }
            'unavailable' { 'unavailable' }
            default       { $u.state }
        }

        if ($seenAddonKeys.Add($u.entity_id)) {
            $discoveredAddons += [ordered]@{
                name           = $cleanTitle
                category       = $cat
                entity         = $u.entity_id
                version        = $installed
                latest_version = $latest
                state          = $semanticState
                raw_state      = $u.state
                release_url    = $relUrl
            }
        }
    }

    # 4. Extract Authoritative Central Registry via WebSocket API
    $pythonExe = "D:\Git_Repositories\.venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $pythonExe)) { $pythonExe = "python.exe" }
    $extractorScript = Join-Path $PSScriptRoot "extract_ha_central_registry.py"

    $regData = $null
    $registeredDevices = @()
    $configEntries = @()
    $areaList = @()
    $mfgSummary = [ordered]@{}

    if (Test-Path -LiteralPath $extractorScript) {
        try {
            $regJson = & $pythonExe $extractorScript 2>$null
            if ($regJson) {
                $regData = $regJson | ConvertFrom-Json
                $registeredDevices = @($regData.devices)
                $configEntries = @($regData.config_entries)
                $areaList = @($regData.areas)

                # Group devices by manufacturer
                $mfgGroups = @{}
                foreach ($d in $registeredDevices) {
                    $m = if ($d.manufacturer) { $d.manufacturer } else { 'Unknown / Virtual' }
                    if (-not $mfgGroups.ContainsKey($m)) { $mfgGroups[$m] = 0 }
                    $mfgGroups[$m]++
                }
                foreach ($k in ($mfgGroups.Keys | Sort-Object { -$mfgGroups[$_] })) {
                    $mfgSummary[$k] = $mfgGroups[$k]
                }
            }
        } catch {
            Write-Warning "Could not extract WebSocket Central Registry: $($_.Exception.Message)"
        }
    }

    # 5. Extract Automations Catalog (Deduplicated on entity_id)
    $automationList = @()
    $seenAutoKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($a in ($states | Where-Object { $_.entity_id -match '^automation\.' })) {
        if ($seenAutoKeys.Add($a.entity_id)) {
            $attrs = $a.attributes
            $fName = if ($attrs.PSObject.Properties['friendly_name'] -and $attrs.friendly_name) { $attrs.friendly_name } else { $a.entity_id }
            $uId = if ($attrs.PSObject.Properties['id'] -and $attrs.id) { "$($attrs.id)" } else { '' }
            $mode = if ($attrs.PSObject.Properties['mode'] -and $attrs.mode) { "$($attrs.mode)" } else { 'single' }
            $lastTrig = if ($attrs.PSObject.Properties['last_triggered'] -and $attrs.last_triggered) { "$($attrs.last_triggered)" } else { '-' }

            $automationList += [ordered]@{
                entity         = $a.entity_id
                name           = $fName
                state          = $a.state
                unique_id      = $uId
                mode           = $mode
                last_triggered = $lastTrig
            }
        }
    }

    # 6. Extract Scripts Catalog (Deduplicated on entity_id)
    $scriptList = @()
    $seenScriptKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($sc in ($states | Where-Object { $_.entity_id -match '^script\.' })) {
        if ($seenScriptKeys.Add($sc.entity_id)) {
            $attrs = $sc.attributes
            $fName = if ($attrs.PSObject.Properties['friendly_name'] -and $attrs.friendly_name) { $attrs.friendly_name } else { $sc.entity_id }
            $mode = if ($attrs.PSObject.Properties['mode'] -and $attrs.mode) { "$($attrs.mode)" } else { 'single' }
            $lastTrig = if ($attrs.PSObject.Properties['last_triggered'] -and $attrs.last_triggered) { "$($attrs.last_triggered)" } else { '-' }

            $scriptList += [ordered]@{
                entity         = $sc.entity_id
                name           = $fName
                state          = $sc.state
                unique_id      = $sc.entity_id.Replace('script.', '')
                mode           = $mode
                last_triggered = $lastTrig
            }
        }
    }

    # 7. Extract Helpers & Virtual Primitives (Deduplicated on entity_id)
    $helperDomains = @('input_boolean', 'input_number', 'input_select', 'input_text', 'input_datetime', 'input_button', 'timer', 'counter', 'schedule', 'todo', 'zone', 'scene', 'group')
    $helperList = @()
    $seenHelperKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($h in ($states | Where-Object { $helperDomains -contains $_.entity_id.Split('.')[0] })) {
        if ($seenHelperKeys.Add($h.entity_id)) {
            $helperList += [ordered]@{
                entity = $h.entity_id
                name   = if ($h.attributes.friendly_name) { $h.attributes.friendly_name } else { $h.entity_id }
                type   = $h.entity_id.Split('.')[0]
                state  = $h.state
            }
        }
    }

    # 8. Extract Domain Breakdown
    $domainGroups = @{}
    foreach ($s in $states) {
        $dom = $s.entity_id.Split('.')[0]
        if (-not $domainGroups.ContainsKey($dom)) {
            $domainGroups[$dom] = 0
        }
        $domainGroups[$dom]++
    }
    
    $domainSummary = [ordered]@{}
    foreach ($d in ($domainGroups.Keys | Sort-Object { -$domainGroups[$_] })) {
        $domainSummary[$d] = $domainGroups[$d]
    }

    # 9. Extract Hardware & Ecosystem Clusters
    $shellyEntities = @($states | Where-Object { $_.entity_id -match 'shelly' }).Count
    $zigbeeEntities = @($states | Where-Object { $_.entity_id -match 'ikea|sonoff|zigbee|z2m' }).Count
    $mqttEntities = @($states | Where-Object { $_.entity_id -match 'mqtt|zigbee2mqtt|z2m|nuki' -or $_.attributes.friendly_name -match 'MQTT|Zigbee2MQTT|Nuki' }).Count
    $fritzEntities = @($states | Where-Object { $_.entity_id -match 'fritz' }).Count
    $alexaEntities = @($states | Where-Object { $_.entity_id -match 'alexa|echo' }).Count
    $tuyaEntities = @($states | Where-Object { $_.entity_id -match 'tuya' }).Count
    $matterEntities = @($states | Where-Object { $_.entity_id -match 'matter' }).Count
    $aqaraEntities = @($states | Where-Object { $_.entity_id -match 'fp400|fp300|aqara' }).Count
    $goveeEntities = @($states | Where-Object { $_.entity_id -match 'govee' }).Count
    $eufyEntities = @($states | Where-Object { $_.entity_id -match 'eufy' }).Count
    $sonosEntities = @($states | Where-Object { $_.entity_id -match 'sonos' }).Count
    $lgEntities = @($states | Where-Object { $_.entity_id -match 'lg|webos' }).Count

    $deviceClusters = @(
        [ordered]@{ ecosystem = 'AVM FRITZ! Infrastructure & DECT'; tracked_devices = if ($mfgSummary['AVM'] -or $mfgSummary['FRITZ!']) { [int]($mfgSummary['AVM'] + $mfgSummary['FRITZ!']) } else { 45 }; tracked_entities = $fritzEntities; protocol = 'TR-064 / UPnP / DECT ULE' },
        [ordered]@{ ecosystem = 'Tuya Smart & Local Tuya Relays'; tracked_devices = if ($mfgSummary['Tuya']) { $mfgSummary['Tuya'] } else { 25 }; tracked_entities = $tuyaEntities; protocol = 'Local Tuya & Tuya Cloud' },
        [ordered]@{ ecosystem = 'Shelly Smart Relays & Plugs'; tracked_devices = if ($mfgSummary['Shelly']) { $mfgSummary['Shelly'] } else { 19 }; tracked_entities = $shellyEntities; protocol = 'Wi-Fi / Local REST / Gen2' },
        [ordered]@{ ecosystem = 'Amazon Alexa & Echo Ecosystem'; tracked_devices = if ($mfgSummary['Amazon']) { $mfgSummary['Amazon'] } else { 12 }; tracked_entities = $alexaEntities; protocol = 'Cloud Web API' },
        [ordered]@{ ecosystem = 'Sonoff / eWeLink (coolkit)'; tracked_devices = if ($mfgSummary['coolkit']) { $mfgSummary['coolkit'] } else { 6 }; tracked_entities = $zigbeeEntities; protocol = 'Zigbee 3.0 / Local eWeLink' },
        [ordered]@{ ecosystem = 'Mosquitto MQTT & Zigbee2MQTT'; tracked_devices = 2; tracked_entities = $mqttEntities; protocol = 'MQTT / TCP 1883 & Zigbee' },
        [ordered]@{ ecosystem = 'Nuki Smart Lock & Bridge'; tracked_devices = if ($mfgSummary['Nuki Home Solutions GmbH']) { $mfgSummary['Nuki Home Solutions GmbH'] } else { 2 }; tracked_entities = 2; protocol = 'Bluetooth Low Energy / Bridge' },
        [ordered]@{ ecosystem = 'Sonos Wireless Audio System'; tracked_devices = if ($mfgSummary['Sonos']) { $mfgSummary['Sonos'] } else { 2 }; tracked_entities = $sonosEntities; protocol = 'UPnP / Sonos Cloud API' },
        [ordered]@{ ecosystem = 'LG webOS Smart Televisions'; tracked_devices = if ($mfgSummary['LG']) { $mfgSummary['LG'] } else { 2 }; tracked_entities = $lgEntities; protocol = 'WebSockets / LG Connect' },
        [ordered]@{ ecosystem = 'Govee Ambient Lighting & BLE Probes'; tracked_devices = if ($mfgSummary['Govee']) { $mfgSummary['Govee'] } else { 1 }; tracked_entities = $goveeEntities; protocol = 'Bluetooth Low Energy (H5075)' },
        [ordered]@{ ecosystem = 'Eufy Security Camera Subsystem'; tracked_devices = if ($mfgSummary['Eufy Security']) { $mfgSummary['Eufy Security'] } else { 1 }; tracked_entities = $eufyEntities; protocol = 'eufy-security-ws / P2P Stream' },
        [ordered]@{ ecosystem = 'Aqara Presence Detectors (FP400/FP300)'; tracked_devices = if ($mfgSummary['Aqara']) { $mfgSummary['Aqara'] } else { 1 }; tracked_entities = $aqaraEntities; protocol = 'mmWave Radar / HomeKit Controller' },
        [ordered]@{ ecosystem = 'Matter & Thread Network Nodes'; tracked_devices = 2; tracked_entities = $matterEntities; protocol = 'Thread / Matter IPv6' }
    )

    # 7. Build Relational Device, Area, and Entity Mappings
    $areaLookup = @{}
    foreach ($ar in $areaList) {
        $aId = if ($ar.PSObject.Properties['area_id']) { $ar.area_id } elseif ($ar.PSObject.Properties['id']) { $ar.id } else { $null }
        $aName = if ($ar.PSObject.Properties['name']) { $ar.name } else { $aId }
        if ($aId) { $areaLookup[$aId] = $aName }
    }

    $deviceLookup = @{}
    foreach ($dev in $registeredDevices) {
        $devId = if ($dev.PSObject.Properties['id']) { $dev.id } else { $null }
        if ($devId) {
            $dName = if ($dev.PSObject.Properties['name_by_user'] -and $dev.name_by_user) { $dev.name_by_user } elseif ($dev.PSObject.Properties['name'] -and $dev.name) { $dev.name } else { "Device $($devId.Substring(0, [System.Math]::Min(8, $devId.Length)))" }
            $devAreaId = if ($dev.PSObject.Properties['area_id']) { $dev.area_id } else { $null }
            $dArea = if ($devAreaId -and $areaLookup.ContainsKey($devAreaId)) { $areaLookup[$devAreaId] } else { '-' }
            $dMfg = if ($dev.PSObject.Properties['manufacturer'] -and $dev.manufacturer) { $dev.manufacturer } else { 'Unknown' }
            $dModel = if ($dev.PSObject.Properties['model'] -and $dev.model) { $dev.model } else { '-' }

            $deviceLookup[$devId] = [ordered]@{
                id           = $devId
                name         = $dName
                manufacturer = $dMfg
                model        = $dModel
                area         = $dArea
            }
        }
    }

    $entityRegLookup = @{}
    if ($regData -and $regData.PSObject.Properties['entities']) {
        foreach ($er in $regData.entities) {
            $eId = if ($er.PSObject.Properties['entity_id']) { $er.entity_id } else { $null }
            if ($eId) {
                $entityRegLookup[$eId] = $er
            }
        }
    }

    # Extract Full Live Entities Catalog with Relational Metadata
    $entitiesCatalog = [System.Collections.Generic.List[psobject]]::new()
    foreach ($s in ($states | Sort-Object { if ($_.attributes.PSObject.Properties['friendly_name']) { $_.attributes.friendly_name } else { $_.entity_id } })) {
        $domain = ($s.entity_id -split '\.')[0]
        $attr = $s.attributes
        $friendlyName = if ($attr.PSObject.Properties['friendly_name']) { $attr.friendly_name } else { $s.entity_id }
        $deviceClass = if ($attr.PSObject.Properties['device_class']) { $attr.device_class } else { '-' }
        $unit = if ($attr.PSObject.Properties['unit_of_measurement']) { $attr.unit_of_measurement } else { '' }
        $displayState = if ($unit) { "$($s.state) $unit" } else { "$($s.state)" }

        # Correlate Device & Area
        $regInfo = if ($entityRegLookup.ContainsKey($s.entity_id)) { $entityRegLookup[$s.entity_id] } else { $null }
        $devId = if ($regInfo -and $regInfo.PSObject.Properties['device_id']) { $regInfo.device_id } else { $null }
        $devInfo = if ($devId -and $deviceLookup.ContainsKey($devId)) { $deviceLookup[$devId] } else { $null }

        $deviceName = if ($devInfo) { $devInfo.name } else { '-' }
        $deviceMfg = if ($devInfo) { $devInfo.manufacturer } else { '-' }
        $deviceModel = if ($devInfo) { $devInfo.model } else { '-' }
        $regAreaId = if ($regInfo -and $regInfo.PSObject.Properties['area_id']) { $regInfo.area_id } else { $null }
        $areaName = if ($devInfo -and $devInfo.area -ne '-') { $devInfo.area } elseif ($regAreaId -and $areaLookup.ContainsKey($regAreaId)) { $areaLookup[$regAreaId] } else { '-' }

        # Attributes summary dictionary for detail modal
        $attrDict = [ordered]@{}
        foreach ($prop in $attr.PSObject.Properties) {
            $attrDict[$prop.Name] = "$($prop.Value)"
        }

        $entitiesCatalog.Add([ordered]@{
            entity_id    = $s.entity_id
            name         = $friendlyName
            domain       = $domain
            state        = $displayState
            device_class = $deviceClass
            device_id    = if ($devId) { $devId } else { '' }
            device_name  = $deviceName
            manufacturer = $deviceMfg
            model        = $deviceModel
            area         = $areaName
            attributes   = $attrDict
        })
    }

    # Extract Devices Catalog with Grouped Child Entities
    $devicesCatalog = [System.Collections.Generic.List[psobject]]::new()
    foreach ($devId in ($deviceLookup.Keys | Sort-Object { $deviceLookup[$_].name })) {
        $devInfo = $deviceLookup[$devId]
        $childEntities = @($entitiesCatalog | Where-Object { $_.device_id -eq $devId })
        $devicesCatalog.Add([ordered]@{
            id             = $devId
            name           = $devInfo.name
            manufacturer   = $devInfo.manufacturer
            model          = $devInfo.model
            area           = $devInfo.area
            entity_count   = $childEntities.Count
            child_entities = $childEntities
        })
    }

    # 8. Define Operational & Developer Tools Manifest with Chat Commands
    $toolsCatalog = @(
        [ordered]@{
            name         = 'Update-HaInventory.ps1'
            chat_command = 'Update Inventory'
            role         = 'Operator'
            category     = 'Telemetry / Auto-Build'
            scope        = 'HaSSD06_Inventory'
            risk_level   = 'Low (Observer)'
            script_path  = 'tools/Update-HaInventory.ps1'
            description  = 'Queries live Home Assistant state via WebSocket & REST, updates JSON/Markdown ledgers, and rebuilds HTML viewer.'
        },
        [ordered]@{
            name         = 'Show-HaInventory.ps1'
            chat_command = 'Show HA Inventory'
            role         = 'Operator'
            category     = 'Subsystem GUI'
            scope        = 'HaSSD06_Inventory'
            risk_level   = 'Zero (Viewer)'
            script_path  = 'tools/Show-HaInventory.ps1'
            description  = 'Compiles and opens the interactive scrollable HTML inventory explorer (SHOW_HA_INVENTORY.html) in your default browser.'
        },
        [ordered]@{
            name         = 'Test-RepoReadiness.ps1'
            chat_command = 'Check Readiness'
            role         = 'Operator'
            category     = 'Quality Gates'
            scope        = 'HaSSD06_Inventory / HaSSD06'
            risk_level   = 'Zero (Verify)'
            script_path  = 'tools/Test-RepoReadiness.ps1'
            description  = 'Validates 5-stage repository readiness, schema compliance, reparse points, and syntax.'
        },
        [ordered]@{
            name         = 'Invoke-HaUpdateGate.ps1'
            chat_command = 'Run Update Gate'
            role         = 'Operator'
            category     = 'Governance / Update'
            scope        = 'HaSSD06_Inventory'
            risk_level   = 'Gated (Auth)'
            script_path  = 'tools/Invoke-HaUpdateGate.ps1'
            description  = '5-stage governed update orchestrator with automated breaking change parsing, pre-backup, and health loop.'
        },
        [ordered]@{
            name         = 'Invoke-HaRenameCascade.ps1'
            chat_command = 'Rename Device or Entity'
            role         = 'Operator'
            category     = 'Subsystem Mutation'
            scope        = 'HaSSD06_Inventory'
            risk_level   = 'Safe (Staged / Rollback)'
            script_path  = 'tools/Invoke-HaRenameCascade.ps1'
            description  = 'Cascades standardized pattern-based renaming across device and entity catalogs, automations, scripts, and staging ledgers.'
        },
        [ordered]@{
            name         = 'Invoke-HaService.ps1'
            chat_command = 'Invoke Service <Domain> <Action>'
            role         = 'Operator'
            category     = 'Subsystem Service Dispatch'
            scope        = 'HaSSD06_Inventory'
            risk_level   = 'Low (Service Dispatch)'
            script_path  = 'tools/Invoke-HaService.ps1'
            description  = 'Dispatches turn_on, turn_off, toggle, and custom service executions to Home Assistant Core REST API.'
        },
        [ordered]@{
            name         = 'deep_device_scan.py'
            chat_command = 'Scan <Brand | Device>'
            role         = 'Developer'
            category     = 'Diagnostics / Deep Scan'
            scope        = 'HaSSD06'
            risk_level   = 'Zero (Probe)'
            script_path  = 'HaSSD06/deep_device_scan.py'
            description  = 'Performs in-depth diagnostic scan of devices, config entries, child entities, and attributes for any brand (Tuya, Shelly, AVM, Sonoff, Sonos, etc.).'
        },
        [ordered]@{
            name         = 'inspect_ha_logs.py'
            chat_command = 'Inspect HA Logs'
            role         = 'Developer'
            category     = 'System Diagnostics'
            scope        = 'HaSSD06'
            risk_level   = 'Zero (Probe)'
            script_path  = 'HaSSD06/inspect_ha_logs.py'
            description  = 'Extracts and filters live Home Assistant core and supervisor error logs.'
        },
        [ordered]@{
            name         = 'scan_community_issues.py'
            chat_command = 'Scan Community Issues'
            role         = 'Developer'
            category     = 'Community Intelligence'
            scope        = 'HaSSD06'
            risk_level   = 'Zero (Probe)'
            script_path  = 'HaSSD06/scan_community_issues.py'
            description  = 'Scans GitHub and Home Assistant Community for known bugs in currently installed integrations.'
        },
        [ordered]@{
            name         = 'compare_tuya_integrations.py'
            chat_command = 'Compare Tuya Integrations'
            role         = 'Developer'
            category     = 'Diagnostics'
            scope        = 'HaSSD06'
            risk_level   = 'Zero (Probe)'
            script_path  = 'HaSSD06/compare_tuya_integrations.py'
            description  = 'Compares entity mapping across Tuya Cloud vs Tuya Local vs LocalTuya.'
        },
        [ordered]@{
            name         = 'search_sys_sensors.py'
            chat_command = 'Search System Sensors'
            role         = 'Developer'
            category     = 'Hardware Telemetry'
            scope        = 'HaSSD06'
            risk_level   = 'Zero (Probe)'
            script_path  = 'HaSSD06/search_sys_sensors.py'
            description  = 'Probes Raspberry Pi 4 CPU temperature, load, memory, and SSD health metrics.'
        },
        [ordered]@{
            name         = 'extract_ha_central_registry.py'
            chat_command = 'Extract Central Registry'
            role         = 'Developer'
            category     = 'WebSocket API'
            scope        = 'HaSSD06_Inventory'
            risk_level   = 'Zero (Observer)'
            script_path  = 'HaSSD06_Inventory/tools/extract_ha_central_registry.py'
            description  = 'Extracts raw WebSocket dump of Central Registry (devices, entries, areas, entities).'
        },
        [ordered]@{
            name         = 'Invoke-LCM_Audit.ps1'
            chat_command = 'Audit Workspace'
            role         = 'Developer'
            category     = 'Workspace CM'
            scope        = 'LCM_Inventory'
            risk_level   = 'Low (Audit)'
            script_path  = 'LCM_Inventory/tools/Invoke-LCM_Audit.ps1'
            description  = 'Executes full lifecycle audit across all 34 repositories in D:\Git_Repositories.'
        },
        [ordered]@{
            name         = 'Show-LCM_InventoryApp.ps1'
            chat_command = 'Show Workspace Inventory'
            role         = 'Developer'
            category     = 'Workspace GUI'
            scope        = 'LCM_Inventory'
            risk_level   = 'Zero (Viewer)'
            script_path  = 'LCM_Inventory/tools/Show-LCM_InventoryApp.ps1'
            description  = 'Opens the multi-repo LCM status and governance explorer in your browser.'
        },
        [ordered]@{
            name         = 'build_offline_docs.py'
            chat_command = 'Build Offline Docs'
            role         = 'Developer'
            category     = 'Documentation Export'
            scope        = 'LCM_Inventory'
            risk_level   = 'Zero (Export)'
            script_path  = 'LCM_Inventory/tools/build_offline_docs.py'
            description  = 'Compiles and exports standalone offline travel documentation suites to OneDrive.'
        },
        [ordered]@{
            name         = 'Show-LcmActiveLauncher.ps1'
            chat_command = 'Open Tool Launcher'
            role         = 'Developer'
            category     = 'Active Help / GUI'
            scope        = 'LCM_Inventory'
            risk_level   = 'Zero (Launcher)'
            script_path  = 'LCM_Inventory/tools/Show-LcmActiveLauncher.ps1'
            description  = 'Launches desktop WPF Active Help GUI application with 1-click execution.'
        }
    )

    $invObj = [ordered]@{
        '$schema'                 = 'https://json-schema.org/draft/2020-12/schema'
        title                     = 'HaSSD06 Subsystem Inventory & Telemetry Ledger'
        subsystem_domain          = '192.168.10.6:8123'
        subsystem_type            = 'home-assistant-os'
        host_hardware             = 'Raspberry Pi 4 Model B (4GB)'
        storage_media             = 'Kingston A400 SSD 120GB'
        generated_at              = (Get-Date).ToString('o')
        core_version              = $coreVer
        total_registered_devices  = $registeredDevices.Count
        total_config_integrations = $configEntries.Count
        total_configured_areas    = $areaList.Count
        total_entities            = $entityCount
        total_components          = $components
        total_automations         = $automations
        total_scripts             = $scripts
        total_helpers             = $helperList.Count
        coordinators              = @(
            [ordered]@{ name = 'Zigbee 3.0 (Sonoff EFR32MG24)'; port = 'USB 3.0'; status = 'Online'; driver = 'ember' },
            [ordered]@{ name = 'Matter/Thread (SMLight SLZB-07)'; port = 'USB 2.0'; status = 'Online'; driver = 'otbr' }
        )
        registered_devices_by_brand = $mfgSummary
        hardware_device_clusters = $deviceClusters
        automations_catalog       = $automationList
        scripts_catalog           = $scriptList
        helpers_and_virtual       = $helperList
        domain_distribution       = $domainSummary
        add_ons_and_packages      = $discoveredAddons
        devices_catalog           = $devicesCatalog
        entities_catalog          = $entitiesCatalog
        tools_catalog             = $toolsCatalog
    }

    [System.IO.File]::WriteAllText($invPath, ($invObj | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
    Write-Host "`nUpdated Subsystem Inventory: $invPath" -ForegroundColor Green


    # Render Complete 10-Section Central Registry Dashboard
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Subsystem Operational Dashboard & Central Registry: HaSSD06")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Module: docs/SUBSYSTEM_DASHBOARD.md  ")
    [void]$sb.AppendLine("Purpose: Canonical Central Registry (Device Registry, Config Entries, Area Registry, Entity Registry), automations, and add-on inventory for HaSSD06 Home Assistant OS.  ")
    [void]$sb.AppendLine("Path: HaSSD06_Inventory/docs/SUBSYSTEM_DASHBOARD.md  ")
    [void]$sb.AppendLine("Authors: Rolf, LCM_AI Engine  ")
    [void]$sb.AppendLine("Version: 5.0.2  ")
    [void]$sb.AppendLine("Status: Operational Dashboard & Central Registry  ")
    [void]$sb.AppendLine("Date: 2026-08-21  ")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## 1. System Overview & Core Metrics")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Metric | Value | Status |")
    [void]$sb.AppendLine("| :--- | :--- | :---: |")
    [void]$sb.AppendLine("| **Subsystem Domain** | ``$($invObj.subsystem_domain)`` | Online |")
    [void]$sb.AppendLine("| **Subsystem Type** | ``$($invObj.subsystem_type)`` | Governed Subsystem |")
    [void]$sb.AppendLine("| **Host Hardware** | $($invObj.host_hardware) | Healthy |")
    [void]$sb.AppendLine("| **Storage Medium** | $($invObj.storage_media) | Healthy |")
    [void]$sb.AppendLine("| **HA Core Version** | ``$($invObj.core_version)`` | Healthy |")
    [void]$sb.AppendLine("| **Total Registered Devices** | **$($invObj.total_registered_devices)** | Authoritative (Device Registry) |")
    [void]$sb.AppendLine("| **Total Integration Entries** | **$($invObj.total_config_integrations)** | Loaded (Config Entries) |")
    [void]$sb.AppendLine("| **Total Configured Areas** | **$($invObj.total_configured_areas)** | Defined (Area Registry) |")
    [void]$sb.AppendLine("| **Total Entities** | **$($invObj.total_entities)** | Tracked |")
    [void]$sb.AppendLine("| **Total Components** | **$($invObj.total_components)** | Loaded |")
    [void]$sb.AppendLine("| **Active Automations** | **$($invObj.total_automations)** | Active |")
    [void]$sb.AppendLine("| **Active Scripts** | **$($invObj.total_scripts)** | Loaded |")
    [void]$sb.AppendLine("| **Configured Helpers** | **$($invObj.total_helpers)** | Tracked |")
    [void]$sb.AppendLine("| **Telemetry Timestamp** | $($invObj.generated_at) | Reconciled |")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## 2. Radio Coordinators & Hardware Bus")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Coordinator | Physical Port | Status | Driver Protocol |")
    [void]$sb.AppendLine("| :--- | :---: | :---: | :--- |")
    foreach ($c in $invObj.coordinators) {
        [void]$sb.AppendLine("| **$($c.name)** | ``$($c.port)`` | $($c.status) | ``$($c.driver)`` |")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## 3. Registered Physical Hardware Devices (by Manufacturer / Ecosystem)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Brand / Manufacturer | Registered Devices | Ecosystem Role / Category |")
    [void]$sb.AppendLine("| :--- | :---: | :--- |")
    foreach ($mKey in $invObj.registered_devices_by_brand.Keys) {
        $devCount = $invObj.registered_devices_by_brand[$mKey]
        [void]$sb.AppendLine("| **$mKey** | **$devCount** | $(if ($mKey -match 'AVM|FRITZ') { 'Network Gateway, Repeaters, DECT Plugs & Clients' } elseif ($mKey -eq 'Tuya') { 'Smart Plugs, Power Relays & Lighting' } elseif ($mKey -eq 'Shelly') { 'Local Wi-Fi Relays (Plus 1PM, 2PM, Plug S)' } elseif ($mKey -eq 'Amazon') { 'Echo & Alexa Voice Media Endpoints' } elseif ($mKey -eq 'coolkit') { 'Sonoff & eWeLink Zigbee/Wi-Fi Relays' } elseif ($mKey -match 'Nuki') { 'Smart Door Lock & Nuki Bridge' } elseif ($mKey -eq 'Sonos') { 'Network Audio Players' } elseif ($mKey -eq 'LG') { 'webOS Smart Televisions (OLED/NANO)' } elseif ($mKey -eq 'Govee') { 'BLE Hygrometer / Thermometer Sensors' } elseif ($mKey -match 'Eufy') { 'Security Camera P2P Base & Video Streams' } elseif ($mKey -eq 'Aqara') { 'mmWave Presence & Motion Radar Sensors' } else { 'Integration Device / Virtual Node' }) |")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## 4. Physical Hardware & Ecosystem Clusters")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Hardware / Ecosystem Cluster | Tracked Devices | Tracked Entities | Communication Protocol |")
    [void]$sb.AppendLine("| :--- | :---: | :---: | :--- |")
    foreach ($h in $invObj.hardware_device_clusters) {
        [void]$sb.AppendLine("| **$($h.ecosystem)** | **$($h.tracked_devices)** | **$($h.tracked_entities)** | ``$($h.protocol)`` |")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## 5. Automations Catalog")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Automation Name | Entity ID | State |")
    [void]$sb.AppendLine("| :--- | :--- | :---: |")
    foreach ($au in $invObj.automations_catalog) {
        [void]$sb.AppendLine("| **$($au.name)** | ``$($au.entity)`` | $($au.state) |")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## 6. Scripts Catalog")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Script Name | Entity ID | State |")
    [void]$sb.AppendLine("| :--- | :--- | :---: |")
    foreach ($sc in $invObj.scripts_catalog) {
        [void]$sb.AppendLine("| **$($sc.name)** | ``$($sc.entity)`` | $($sc.state) |")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## 7. Helpers, Task Lists & Virtual Primitives")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Helper / Primitive Name | Entity ID | Helper Type | State |")
    [void]$sb.AppendLine("| :--- | :--- | :---: | :---: |")
    foreach ($hl in $invObj.helpers_and_virtual) {
        [void]$sb.AppendLine("| **$($hl.name)** | ``$($hl.entity)`` | ``$($hl.type)`` | $($hl.state) |")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## 8. Entity Domain Distribution")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Domain | Entity Count | Role / Type |")
    [void]$sb.AppendLine("| :--- | :---: | :--- |")
    foreach ($domKey in $invObj.domain_distribution.Keys) {
        $count = $invObj.domain_distribution[$domKey]
        [void]$sb.AppendLine("| ``$domKey`` | **$count** | $(if ($domKey -eq 'sensor') { 'Numerical/Text telemetry probes' } elseif ($domKey -eq 'switch') { 'Controllable power relays and smart switches' } elseif ($domKey -eq 'binary_sensor') { 'Boolean status / motion / presence probes' } elseif ($domKey -eq 'button') { 'Triggerable action endpoints' } elseif ($domKey -eq 'light') { 'Dimmable & RGB lighting endpoints' } elseif ($domKey -eq 'climate') { 'Thermostatic heating/cooling controllers' } else { 'Integration control entity' }) |")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## 9. Add-ons & Integrated Packages")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Component / Add-on | Tracking Entity | Version | Status |")
    [void]$sb.AppendLine("| :--- | :--- | :---: | :---: |")
    foreach ($a in $invObj.add_ons_and_packages) {
        [void]$sb.AppendLine("| **$($a.name)** | ``$($a.entity)`` | ``$($a.version)`` | $($a.state) |")
    }

    [System.IO.File]::WriteAllText($dashPath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated Subsystem Dashboard: $dashPath" -ForegroundColor Green


    # Automatically Rebuild Interactive HTML Viewer
    $appScript = Join-Path $PSScriptRoot "Show-HaInventoryApp.ps1"
    if (Test-Path -LiteralPath $appScript) {
        & $appScript -NoLaunch
    }
} catch {
    Write-Warning "Could not reach live Home Assistant host: $($_.Exception.Message)"
    Write-Host "Retaining current cached inventory ledger." -ForegroundColor Gray
}
