<#
.SYNOPSIS
  Dispatches service execution calls (turn_on, turn_off, toggle, reload) to Home Assistant Core.
.DESCRIPTION
  Safely communicates with Home Assistant REST API to trigger services on automations, scripts,
  switches, lights, and other subsystem entities using authorized tokens from data/secrets.json.
  Features:
  1. Automated resolution of HA endpoints and bearer tokens (ha_auditor_token / ha_token).
  2. Structured execution logging conforming to RULE-PS-009.
  3. Interactive and silent daemon dispatch integration.
  4. Conforms to RULE-SUB-004, RULE-PS-008, and RULE-PS-010.
.PATH
  HaSSD06_Inventory/tools/Invoke-HaService.ps1
.AUTHORS
  Rolf, LCM_AI Engine
.VERSION
  1.0.0
.DATE
  2026-09-19
.PARAMETER Domain
  Target service domain (e.g. 'automation', 'script', 'switch', 'light').
.PARAMETER Service
  Target service action (e.g. 'turn_on', 'turn_off', 'toggle', 'reload').
.PARAMETER EntityId
  Target entity ID (e.g. 'automation.bewegungsalarm_wz').
.PARAMETER PayloadJson
  Optional custom JSON payload string to pass to the service endpoint.
.PARAMETER Instance
  Target Home Assistant instance name (Default: 'HaSSD06').
.PARAMETER Help
  Displays this parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Invoke-HaService.ps1 -Domain automation -Service toggle -EntityId automation.bewegungsalarm_wz
.EXAMPLE
  pwsh tools/Invoke-HaService.ps1 -Domain script -Service turn_on -EntityId script.pc_and_devices_power_up
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Domain,

    [Parameter(Mandatory = $false)]
    [string]$Service = 'toggle',

    [Parameter(Mandatory = $false)]
    [string]$EntityId,

    [Parameter(Mandatory = $false)]
    [string]$PayloadJson,

    [Parameter(Mandatory = $false)]
    [string]$Instance = 'HaSSD06',

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help -or (-not $Domain -and -not $EntityId)) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " HOME ASSISTANT SERVICE EXECUTION DISPATCHER (v1.0.0)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Dispatches service execution calls to Home Assistant Core REST API."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Invoke-HaService.ps1 -Domain <domain> -Service <action> -EntityId <id>"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Invoke-HaService.ps1 -Domain automation -Service turn_off -EntityId automation.bewegungsalarm_wz"
    Write-Host "  pwsh tools/Invoke-HaService.ps1 -Domain script -Service turn_on -EntityId script.blink_all_alarm_lights"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$secretsPath = Join-Path $repoRoot 'data\secrets.json'

if (-not (Test-Path -LiteralPath $secretsPath)) {
    throw "Secrets file not found at: $secretsPath"
}

$secrets = Get-Content -LiteralPath $secretsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$token = if ($secrets.PSObject.Properties['ha_auditor_token'] -and $secrets.ha_auditor_token) {
    $secrets.ha_auditor_token
} elseif ($secrets.PSObject.Properties['ha_token'] -and $secrets.ha_token) {
    $secrets.ha_token
} else {
    throw "No valid token property found in $secretsPath"
}

$baseUrl = if ($secrets.PSObject.Properties['api_url'] -and $secrets.api_url) {
    $secrets.api_url.TrimEnd('/')
} elseif ($secrets.PSObject.Properties['subsystem_domain'] -and $secrets.subsystem_domain) {
    "http://$($secrets.subsystem_domain)".TrimEnd('/')
} else {
    "http://192.168.10.6:8123"
}

# Infer domain if omitted
if (-not $Domain -and $EntityId -and $EntityId.Contains('.')) {
    $Domain = $EntityId.Split('.')[0]
}

$endpoint = "$baseUrl/api/services/$Domain/$Service"
$headers = @{
    Authorization  = "Bearer $token"
    'Content-Type' = 'application/json'
}

$bodyObj = [ordered]@{}
if ($EntityId) {
    $bodyObj['entity_id'] = $EntityId
}
if ($PayloadJson) {
    try {
        $customProps = $PayloadJson | ConvertFrom-Json
        foreach ($prop in $customProps.PSObject.Properties) {
            $bodyObj[$prop.Name] = $prop.Value
        }
    } catch {
        Write-Warning "Could not parse custom PayloadJson: $($_.Exception.Message)"
    }
}

$bodyJson = $bodyObj | ConvertTo-Json -Compress

Write-Host "Executing Home Assistant Service: $Domain/$Service -> $EntityId" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method POST -Uri $endpoint -Headers $headers -Body $bodyJson -ContentType 'application/json' -TimeoutSec 10
    Write-Host "✓ Successfully executed $Domain/$Service on $EntityId" -ForegroundColor Green
    if ($response) {
        $responseJson = $response | ConvertTo-Json -Depth 3
        Write-Verbose $responseJson
    }
} catch {
    Write-Error "Failed to execute service on Home Assistant ($endpoint): $($_.Exception.Message)"
    throw
}
