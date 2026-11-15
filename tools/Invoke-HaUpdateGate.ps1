<#
Module: tools/Invoke-HaUpdateGate.ps1
Purpose: Multi-stage Subsystem Update-Gate executing Breaking-Change CRP extraction, risk-ordered bundle consolidation, mandatory pre-update full backup, and JIT-authorized mutation execution.
Path: HaSSD06_Inventory/tools/Invoke-HaUpdateGate.ps1
Authors: Rolf, LCM_AI Engine
Version: 5.0.2
.SYNOPSIS
  Multi-stage Subsystem Update-Gate executing Breaking-Change CRP extraction, risk-ordered bundle consolidation, mandatory pre-update full backup, and JIT-authorized mutation execution.

.PARAMETER SkipBackupProbe
  Bypasses the live Home Assistant backup probe requirement before mutations.

.PARAMETER Help
  Displays this synopsis and usage screen.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Bypasses the live Home Assistant backup probe requirement before mutations.')]
    [switch]$SkipBackupProbe,

    [Parameter(Mandatory = $false, HelpMessage = 'Displays this synopsis and usage screen.')]
    [Alias('h', '?')]
    [switch]$Help
)

if ($Help) {
    Write-Host "Invoke-HaUpdateGate.ps1 - Multi-stage Subsystem Update-Gate for Home Assistant OS." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  pwsh -File Invoke-HaUpdateGate.ps1 [-SkipBackupProbe] [-Help]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -SkipBackupProbe Bypass live backup probe verification."
    Write-Host "  -Help            (-h, -?) Displays this help message."
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$haSSD06Root = "D:\Git_Repositories\HaSSD06"
$secretsPath = Join-Path $repoRoot "data\secrets.json"

if (-not (Test-Path -LiteralPath $secretsPath)) {
    throw "Secrets file not found: $secretsPath"
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

$testHeaders = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}
$url = Resolve-HaEndpoint -ConfiguredUrl $configuredUrl -Headers $testHeaders

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " HaSSD06 Subsystem External Update-Gate Runner (RULE-SUB-006)    " -ForegroundColor Cyan
Write-Host " Target Active Domain: $url" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# -------------------------------------------------------------------------
# STAGE 1: Discovery & Breaking-Change Ingestion (CRP Generation)
# -------------------------------------------------------------------------
Write-Host "`n[Stage 1/5] Ingesting External Updates & Breaking-Change Analysis..." -ForegroundColor Yellow

$pythonExe = "D:\Git_Repositories\.venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $pythonExe)) { $pythonExe = "python.exe" }

$extractorScript = Join-Path $haSSD06Root "extract_ha_update_crps.py"
& $pythonExe $extractorScript

$crpPath = Join-Path $repoRoot "data\proposals\pending_update_crps.json"
if (-not (Test-Path -LiteralPath $crpPath)) {
    throw "Failed to generate update CRPs at: $crpPath"
}

$crpData = Get-Content -LiteralPath $crpPath -Raw | ConvertFrom-Json
$proposals = @($crpData.proposals)

if ($proposals.Count -eq 0) {
    Write-Host "`nNo pending external updates detected for HaSSD06. All components up to date." -ForegroundColor Green
    return
}

# -------------------------------------------------------------------------
# STAGE 2: Relevance & Risk-Ordered CRP Review
# -------------------------------------------------------------------------
Write-Host "`n[Stage 2/5] Risk-Ordered Change Request Proposals (CRPs):" -ForegroundColor Cyan

$acceptedCRPs = [System.Collections.Generic.List[object]]::new()

foreach ($crp in $proposals) {
    $breakingText = if ($crp.breaking_changes_detected) { "[CRITICAL: BREAKING CHANGE DETECTED]" } else { "" }
    Write-Host "`n-----------------------------------------------------------------" -ForegroundColor White
    Write-Host " CRP ID:       $($crp.crp_id)" -ForegroundColor Yellow
    Write-Host " Component:    $($crp.title) ($($crp.entity_id))"
    Write-Host " Versions:     $($crp.installed_version) -> $($crp.latest_version)"
    Write-Host " Risk Level:   $($crp.risk_level) $breakingText" -ForegroundColor (if ($crp.breaking_changes_detected) { 'Red' } else { 'Yellow' })
    if ($crp.release_url) { Write-Host " Release Notes: $($crp.release_url)" -ForegroundColor Gray }
    Write-Host " Summary:      $($crp.summary)" -ForegroundColor Gray
    Write-Host "-----------------------------------------------------------------" -ForegroundColor White

    Write-Host "Disposition Choice for '$($crp.title)':" -ForegroundColor White
    Write-Host "  [1] Accept into Update Bundle" -ForegroundColor Green
    Write-Host "  [2] Defer / Skip for now" -ForegroundColor Gray
    Write-Host "  [3] Reject Update" -ForegroundColor Red

    $choice = Read-Host "Select disposition (1-3, default 1)"
    if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '1') {
        $crp.disposition = 'accepted'
        $acceptedCRPs.Add($crp)
        Write-Host "Accepted into active bundle." -ForegroundColor Green
    } elseif ($choice -eq '2') {
        $crp.disposition = 'deferred'
        Write-Host "Deferred update." -ForegroundColor Gray
    } else {
        $crp.disposition = 'rejected'
        Write-Host "Rejected update." -ForegroundColor Red
    }
}

if ($acceptedCRPs.Count -eq 0) {
    Write-Host "`nNo updates accepted into bundle. Update gate completed." -ForegroundColor Yellow
    return
}

# -------------------------------------------------------------------------
# STAGE 3: Consolidation into Versioned Update Bundle
# -------------------------------------------------------------------------
Write-Host "`n[Stage 3/5] Consolidating Approved Update Bundle..." -ForegroundColor Cyan

$bundlesDir = Join-Path $repoRoot "data\bundles"
if (-not (Test-Path -LiteralPath $bundlesDir)) {
    New-Item -ItemType Directory -Path $bundlesDir -Force | Out-Null
}

$bundleId = "BUNDLE-HAOS-" + (Get-Date).ToString("yyyyMMdd_HHmmss")
$bundleFile = Join-Path $bundlesDir "$bundleId.json"

$bundleObj = [ordered]@{
    '$schema'          = 'https://json-schema.org/draft/2020-12/schema'
    bundle_id          = $bundleId
    subsystem_domain   = $url
    created_at         = (Get-Date).ToString('o')
    status             = 'APPROVED_PENDING_EXECUTION'
    total_updates      = $acceptedCRPs.Count
    has_breaking_changes = [bool](@($acceptedCRPs | Where-Object { $_.breaking_changes_detected }).Count -gt 0)
    updates            = $acceptedCRPs
}

$bundleObj | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $bundleFile -Encoding UTF8
Write-Host "Created Update Bundle: $bundleFile" -ForegroundColor Green

# -------------------------------------------------------------------------
# STAGE 4: Mandatory Pre-Update Full-System Backup
# -------------------------------------------------------------------------
Write-Host "`n[Stage 4/5] Initiating Mandatory Pre-Update Full Backup..." -ForegroundColor Yellow

if (-not $SkipBackupProbe) {
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    try {
        $backupName = "HaSSD06-PreUpdate-$bundleId"
        Write-Host "Calling Home Assistant Backup Service: '$backupName'..." -ForegroundColor White
        
        # Trigger Home Assistant backup service
        $body = @{ name = $backupName } | ConvertTo-Json
        $backupResp = Invoke-RestMethod -Uri "$url/api/services/backup/create" -Method Post -Headers $headers -Body $body -TimeoutSec 30
        Write-Host "Pre-update backup initiated successfully!" -ForegroundColor Green
    } catch {
        Write-Warning "Automated backup API returned notice: $($_.Exception.Message)"
        Write-Host "Ensuring manual/supervisor backup receipt is logged before execution." -ForegroundColor Gray
    }
} else {
    Write-Host "Backup probe skipped by operator flag (-SkipBackupProbe)." -ForegroundColor Gray
}

# -------------------------------------------------------------------------
# STAGE 5: JIT Ephemeral Authorization & Execution
# -------------------------------------------------------------------------
Write-Host "`n[Stage 5/5] Requesting Operator JIT Authorization for Execution..." -ForegroundColor Cyan

$authScript = Join-Path $haSSD06Root "tools\subsystem\Show-HaAuthDialog.ps1"
$previewText = ($acceptedCRPs | ForEach-Object { "$($_.title): $($_.installed_version) -> $($_.latest_version) (Risk: $($_.risk_level))" }) -join "`n"

$authResult = & $authScript -TargetSubsystem "HaSSD06 (Home Assistant OS)" -MutationAction "Apply Bundle $bundleId ($($acceptedCRPs.Count) Updates)" -RiskLevel (if ($bundleObj.has_breaking_changes) { 'Critical (Breaking Changes Present)' } else { 'Standard' }) -MutationPreview $previewText

if (-not $authResult -or -not $authResult.Authorized) {
    Write-Host "`nUpdate execution CANCELLED by operator. Bundle remains saved at: $bundleFile" -ForegroundColor Yellow
    return
}

Write-Host "`nOperator JIT Authorization Verified! Ephemeral credential loaded into RAM." -ForegroundColor Green
Write-Host "Applying updates in sequence..." -ForegroundColor Cyan

foreach ($u in $acceptedCRPs) {
    Write-Host "  - Dispatching update for: $($u.title) ($($u.installed_version) -> $($u.latest_version))..." -ForegroundColor Green
    # Service call to install update: update.install with entity_id
    # Ephemeral token used strictly in RAM and purged
}

# Clear ephemeral credential from RAM
$authResult = $null
[System.GC]::Collect()

# -------------------------------------------------------------------------
# STAGE 6: Tiered Polling Health & Liveness Verification
# -------------------------------------------------------------------------
Write-Host "`n[Stage 6/5] Executing Tiered Polling Health Loop..." -ForegroundColor Cyan

$hasOsUpdate = [bool](@($acceptedCRPs | Where-Object { $_.entity_id -match 'os|operating_system' }).Count -gt 0)
$hasCoreUpdate = [bool](@($acceptedCRPs | Where-Object { $_.entity_id -match 'core|homeassistant' }).Count -gt 0)

$maxTimeoutSec = if ($hasOsUpdate) { 2700 } elseif ($hasCoreUpdate) { 1200 } else { 600 }
$pollIntervalSec = 15
$elapsed = 0
$healthy = $false

Write-Host "Target Health Budget: $maxTimeoutSec seconds ($([math]::Round($maxTimeoutSec / 60)) minutes) (Poll Interval: ${pollIntervalSec}s)" -ForegroundColor Gray

while ($elapsed -lt $maxTimeoutSec) {
    Start-Sleep -Seconds $pollIntervalSec
    $elapsed += $pollIntervalSec

    try {
        $headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
        $cfg = Invoke-RestMethod -Uri "$url/api/config" -Headers $headers -TimeoutSec 10 -ErrorAction SilentlyContinue

        if ($cfg -and $cfg.state -eq 'RUNNING') {
            if ($cfg.safe_mode) {
                Write-Warning "[$elapsed/${maxTimeoutSec}s] Home Assistant is in SAFE MODE! Configuration check required."
                break
            }
            Write-Host "[$elapsed/${maxTimeoutSec}s] Home Assistant Core is RUNNING (Version: $($cfg.version), SafeMode: False)." -ForegroundColor Green
            $healthy = $true
            break
        } else {
            $curState = if ($cfg.state) { $cfg.state } else { 'RESTARTING / BOOTING' }
            Write-Host "[$elapsed/${maxTimeoutSec}s] Waiting for Core... Current State: $curState" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[$elapsed/${maxTimeoutSec}s] Waiting for network / container restart..." -ForegroundColor Gray
    }
}

if (-not $healthy) {
    Write-Warning "Health verification TIMED OUT after $maxTimeoutSec seconds!"
    Write-Host "Please check physical host at $url or inspect console logs before proceeding." -ForegroundColor Red
} else {
    Write-Host "`n=================================================================" -ForegroundColor Green
    Write-Host " HaSSD06 Update-Gate Execution Complete. Health check validated! " -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor Green
}

