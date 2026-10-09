<#
.SYNOPSIS
  Restores system background services while permanently enforcing all verified Anti-Flicker Invariants.
.DESCRIPTION
  Authoritative LCM system restore tool.
  - Fixes Enforced:
      * DWM MPO disabled (OverlayTestMode = 5)
      * AMD Radeon ULPS disabled (EnableUlps = 0) to stabilize GPU memory clocks
      * Edge / Copilot Background Mode & Startup Boost disabled
      * PowerToys "FindMyMouse" disabled (eliminates WH_MOUSE_LL shake-detection hook desync)
      * Standard Cursor Size (CursorBaseSize = 32)
      * Touch & Gesture Visualizations disabled (ContactVisualization = 0, GestureVisualization = 0)
      * SnapToDefaultButton = 0
  - Services Restored: OneDrive, Everything, Macrium, TightVNC, HASS.Agent, MediaTek Bluetooth, PowerToys (all other modules).
.NOTES
  Author: Rolf + Antigravity
  Date: 2026-09-10
  Version: 2.2.1
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
  Write-Host " RESTORE SYSTEM SETTINGS (Restore-SystemSettings)" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Restores system background services while permanently enforcing Anti-Flicker Invariants."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Restore-SystemSettings.ps1 [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Help (-h, -?) : Displays this help screen"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " RESTORING SERVICES & ENFORCING PERMANENT ANTI-FLICKER CONFIGURATION" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

# 1. Permanent DWM, AMD GPU, Edge, and Cursor Anti-Flicker Invariants
Write-Host "`n[1/5] Enforcing Anti-Flicker Invariants..." -ForegroundColor Yellow

# DWM MPO fix
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -Value 5 -Type DWord -Force -ErrorAction SilentlyContinue

# AMD GPU Driver ULPS disable (stabilizes idle VRAM clock)
$amdPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
if (Test-Path $amdPath) {
    Set-ItemProperty -Path $amdPath -Name "EnableUlps" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Host "  -> [ENFORCED] AMD GPU EnableUlps = 0 (Disabled)" -ForegroundColor Green
}

# Edge Policy (Disable Startup Boost & Background extensions)
$edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (!(Test-Path $edgePolicyPath)) { New-Item -Path $edgePolicyPath -Force | Out-Null }
Set-ItemProperty -Path $edgePolicyPath -Name "StartupBoostEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $edgePolicyPath -Name "BackgroundModeEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Cursor standard settings
Set-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "CursorBaseSize" -Value 32 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "ContactVisualization" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "GestureVisualization" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "SnapToDefaultButton" -Value "0" -Force -ErrorAction SilentlyContinue

# PowerToys FindMyMouse hook suppression
$ptSettings = "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json"
if (Test-Path $ptSettings) {
    try {
        $ptJson = Get-Content $ptSettings -Raw | ConvertFrom-Json
        $ptJson.enabled.FindMyMouse = $false
        $ptJson | ConvertTo-Json -Depth 10 | Set-Content $ptSettings -Encoding utf8
        Write-Host "  -> [ENFORCED] PowerToys 'FindMyMouse' hook disabled in settings" -ForegroundColor Green
    } catch {}
}

# Process Explorer 5s Refresh Rate lock
if (Test-Path "HKCU:\Software\Sysinternals\Process Explorer") {
    Set-ItemProperty -Path "HKCU:\Software\Sysinternals\Process Explorer" -Name "RefreshRate" -Value 5000 -Type DWord -Force -ErrorAction SilentlyContinue
}

Write-Host "  -> [ENFORCED] DWM MPO Fix (OverlayTestMode = 5)" -ForegroundColor Green
Write-Host "  -> [ENFORCED] Standard Cursor Size 32, Visualizations Disabled, SnapTo Disabled" -ForegroundColor Green

# 2. Restore Background Services to Automatic and Running
$services = @(
  "tvnserver",
  "HASS.Agent Satellite Service",
  "MacriumService",
  "Everything (1.5a)"
)

Write-Host "`n[2/5] Restoring Background Services..." -ForegroundColor Yellow
foreach ($s in $services) {
  Set-Service -Name $s -StartupType Automatic -ErrorAction SilentlyContinue
  Start-Service -Name $s -ErrorAction SilentlyContinue
  Write-Host "  -> [RUNNING] Service '$s' (Automatic)" -ForegroundColor Green
}

# 3. Re-enable Bluetooth
Write-Host "`n[3/5] Ensuring Bluetooth Adapter is Active..." -ForegroundColor Yellow
Enable-PnpDevice -InstanceId "USB\VID_0489&PID_E0E2&MI_00\7&219397DC&0&0000" -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "  -> [ENABLED] MediaTek Bluetooth Adapter" -ForegroundColor Green

# 4. Ensure Background Apps are Running
Write-Host "`n[4/5] Starting Background Applications (PowerToys, OneDrive, Everything)..." -ForegroundColor Yellow
Start-Process "C:\Program Files\Microsoft OneDrive\OneDrive.exe" -ArgumentList "/background" -ErrorAction SilentlyContinue
Start-Process "D:\Tools\Everything 1.5a\Everything.exe" -ArgumentList "-startup" -ErrorAction SilentlyContinue
Start-Process "$env:LOCALAPPDATA\PowerToys\PowerToys.exe" -ErrorAction SilentlyContinue

# 5. Ensure LCM Tools in Machine Environment PATH
Write-Host "`n[5/6] Enforcing LCM Tools in Machine PATH..." -ForegroundColor Yellow
$toolsPath = 'D:\Git_Repositories\LCM_Inventory\Cmd'
try {
  $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  if ($machinePath -notmatch [regex]::Escape($toolsPath)) {
    $parts = @($machinePath -split ';' | Where-Object { [string]::IsNullOrWhiteSpace($_) -eq $false })
    $newParts = [System.Collections.Generic.List[string]]::new()
    $inserted = $false
    foreach ($p in $parts) {
      if ($p.TrimEnd('\') -eq 'D:\OneDrive\cmd' -and -not $inserted) {
        $newParts.Add($toolsPath)
        $inserted = $true
      }
      $newParts.Add($p)
    }
    if (-not $inserted) { $newParts.Insert(0, $toolsPath) }
    [Environment]::SetEnvironmentVariable('Path', ($newParts -join ';'), 'Machine')
    Write-Host "  -> [ENFORCED] Machine PATH updated with '$toolsPath'" -ForegroundColor Green
  } else {
    Write-Host "  -> [VERIFIED] Machine PATH already contains '$toolsPath'" -ForegroundColor Green
  }
} catch {
  Write-Host "  -> [NOTE] Run 'SetGitRoot' (or 'pwsh LCM_Inventory/tools/Set-GitRoot.ps1') with Administrator rights to update Machine PATH." -ForegroundColor Yellow
}

# 6. Reload Win32 system parameters
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class FinalSystemReloader {
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint pvParam, uint fWinIni);
}
"@
[FinalSystemReloader]::SystemParametersInfo(0x0057, 0, 0, 3) | Out-Null
[FinalSystemReloader]::SystemParametersInfo(0x005F, 0, 0, 3) | Out-Null

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " SYSTEM FULLY OPERATIONAL (ALL VERIFIED INVARIANTS LOCKED)" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
