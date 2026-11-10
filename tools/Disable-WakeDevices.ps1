<#
.SYNOPSIS
    Disables Wake-on-LAN and Mouse wake triggers in Windows.
.DESCRIPTION
    Path: D:\Git_Repositories\LCM_Inventory\tools\Disable-WakeDevices.ps1
    Authors: Rolf, Antigravity
    Version: 10.2.0
    Date: 2026-10-13
#>

[CmdletBinding()]
param(
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM SYSTEM POWER & WAKE ENFORCEMENT (Disable-WakeDevices)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Disables Wake-on-LAN and Mouse wake triggers in Windows power configuration."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh LCM_Inventory/tools/Disable-WakeDevices.ps1 [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -Help (-h, -?) : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM SYSTEM POWER & WAKE ENFORCEMENT ENGINE" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

# 1. Query currently wake-armed devices
$armed = @(powercfg /devicequery wake_armed)
Write-Host "`n[1/3] Currently wake-armed devices:" -ForegroundColor Yellow
$armed | ForEach-Object { Write-Host "  [!] $_" }

# 2. Disable wake on all mouse and network devices
Write-Host "`n[2/3] Disabling wake on network adapters and pointing devices..." -ForegroundColor Yellow
foreach ($dev in $armed) {
    if ([string]::IsNullOrWhiteSpace($dev)) { continue }
    
    if ($dev -like "*mouse*" -or $dev -like "*Ethernet*" -or $dev -like "*Intel*" -or $dev -like "*Realtek*" -or $dev -like "*Wi-Fi*") {
        Write-Host "  --> Disabling wake on: $dev" -ForegroundColor Green
        powercfg /devicedisablewake "$dev"
    }
}

# 3. Disable Wake on Pattern & Wake on Magic Packet in Registry for Intel Network Adapters
Write-Host "`n[3/3] Disabling WoL/Pattern matching in Intel NIC driver properties..." -ForegroundColor Yellow
$netClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
if (Test-Path $netClassPath) {
    Get-ChildItem -Path $netClassPath | ForEach-Object {
        $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        if ($props.DriverDesc -like "*Intel*" -or $props.DriverDesc -like "*Ethernet*") {
            Write-Host "  --> Disabling WoL/Pattern wake on: $($props.DriverDesc)" -ForegroundColor Green
            Set-ItemProperty -Path $_.PSPath -Name "*WakeOnPattern" -Value "0" -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $_.PSPath -Name "*WakeOnMagicPacket" -Value "0" -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $_.PSPath -Name "WakeOnMagicPacketFromS5" -Value "0" -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $_.PSPath -Name "EnablePME" -Value "0" -Type String -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " FINAL VERIFICATION: REMAINING WAKE-ARMED DEVICES" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
$postArmed = @(powercfg /devicequery wake_armed)
if ($postArmed.Count -eq 0 -or ($postArmed.Count -eq 1 -and [string]::IsNullOrWhiteSpace($postArmed[0]))) {
    Write-Host "  [OK] Zero devices are wake-armed. PC will not wake automatically." -ForegroundColor Green
} else {
    Write-Host "  Remaining wake-armed devices:" -ForegroundColor Cyan
    $postArmed | ForEach-Object { Write-Host "  • $_" -ForegroundColor Cyan }
}
Write-Host "==========================================================================" -ForegroundColor Cyan
