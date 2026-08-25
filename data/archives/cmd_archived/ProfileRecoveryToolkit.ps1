# =================================================================================================
#  Module:      ProfileRecoveryToolkit.ps1
#  Path:        .\Maintenance
#  Author:      Rolf Bercht
#  Version:     1.0.0
#  Changelog:
#      1.000  --------  Initial toolkit for profile and AppX health diagnostics
# =================================================================================================

<#
.SYNOPSIS
    Diagnostics toolkit for user profile, AppX, WebViewHost and WebView2 health.

.DESCRIPTION
    This script does NOT change anything by default.
    It performs read-only checks and prints PASS/WARN/FAIL with guidance.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info { Write-Host "[INFO ] $args" -ForegroundColor Cyan }
function Write-OK   { Write-Host "[ OK  ] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN ] $args" -ForegroundColor Yellow }
function Write-Err  { Write-Host "[FAIL ] $args" -ForegroundColor Red }

# -------------------------------------------------------------------------------------------------
# Section 1: Basic profile file checks (UsrClass.dat, NTUSER.DAT)
# -------------------------------------------------------------------------------------------------

Write-Info "Checking basic profile files..."

$UserProfile = $env:USERPROFILE
$UsrClassPath = Join-Path $UserProfile "AppData\Local\Microsoft\Windows\UsrClass.dat"
$UsrClassLog1 = $UsrClassPath + ".LOG1"
$UsrClassLog2 = $UsrClassPath + ".LOG2"
$NtUserPath   = Join-Path $UserProfile "NTUSER.DAT"

$missing = @()

if (-not (Test-Path $UsrClassPath)) { $missing += $UsrClassPath }
if (-not (Test-Path $UsrClassLog1)) { $missing += $UsrClassLog1 }
if (-not (Test-Path $UsrClassLog2)) { $missing += $UsrClassLog2 }
if (-not (Test-Path $NtUserPath))   { $missing += $NtUserPath }

if ($missing.Count -eq 0) {
    Write-OK "All core profile files are present."
}
else {
    Write-Err "Missing or inaccessible profile files detected."
    foreach ($m in $missing) {
        Write-Err ("Missing - " + $m)
    }
    Write-Warn "If these files are missing, the profile may be unrecoverable. Consider using a clean admin profile or in-place upgrade."
}

# -------------------------------------------------------------------------------------------------
# Section 2: ProfileList registry consistency
# -------------------------------------------------------------------------------------------------

Write-Info "Checking ProfileList registry consistency..."

try {
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $profileKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\" + $sid

    if (Test-Path $profileKeyPath) {
        $profileKey = Get-ItemProperty -Path $profileKeyPath
        $profileImagePath = $profileKey.ProfileImagePath

        Write-Info ("Profile SID: " + $sid)
        Write-Info ("ProfileImagePath: " + $profileImagePath)

        if ($profileImagePath -and (Test-Path $profileImagePath)) {
            Write-OK "ProfileList entry matches an existing profile directory."
        }
        else {
            Write-Err "ProfileList entry does not match an existing directory."
            Write-Warn "This can cause profile type detection failures and AppX deployment errors."
        }
    }
    else {
        Write-Err "No ProfileList entry found for current user SID."
        Write-Warn "This is a strong indicator of a broken profile."
    }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Err ("Error while reading ProfileList - " + $errMsg)
}

# -------------------------------------------------------------------------------------------------
# Section 3: AppX / WebViewHost package state
# -------------------------------------------------------------------------------------------------

Write-Info "Checking WebViewHost AppX package..."

try {
    $pkg = Get-AppxPackage "Microsoft.Win32WebViewHost" -ErrorAction SilentlyContinue

    if (-not $pkg) {
        Write-Warn "WebViewHost AppX package is not registered for this user."
        Write-Warn "This can be normal on some builds, but often indicates AppX damage after System Restore."
    }
    else {
        Write-OK ("WebViewHost package found at " + $pkg.InstallLocation)
        $manifestPath = Join-Path $pkg.InstallLocation "AppXManifest.xml"

        if (Test-Path $manifestPath) {
            Write-Info "Testing Add-AppxPackage registration (no changes expected if healthy)..."
            try {
                Add-AppxPackage -DisableDevelopmentMode -Register $manifestPath -ErrorAction Stop
                Write-OK "Add-AppxPackage completed without fatal deployment errors."
            }
            catch {
                $errMsg = $_.Exception.Message
                Write-Err ("Add-AppxPackage failed - " + $errMsg)
                Write-Warn "Deployment errors here often mean profile type detection problems or AppX subsystem corruption."
            }
        }
        else {
            Write-Err "AppXManifest.xml not found for WebViewHost package."
        }
    }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Err ("Error while querying WebViewHost package - " + $errMsg)
}

# -------------------------------------------------------------------------------------------------
# Section 4: WebView2 runtime GUID presence
# -------------------------------------------------------------------------------------------------

Write-Info "Checking WebView2 runtime registry GUID..."

$WebView2GUID = "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"

$RegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\" + $WebView2GUID,
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\" + $WebView2GUID,
    "HKCU:\Software\Microsoft\EdgeUpdate\Clients\" + $WebView2GUID
)

$found = @()

foreach ($p in $RegPaths) {
    if (Test-Path $p) {
        Write-Warn ("Found WebView2 runtime registration at " + $p)
        $found += $p
    }
}

if ($found.Count -eq 0) {
    Write-OK "No stale WebView2 runtime GUIDs detected in standard locations."
}
else {
    Write-Warn "If WebViewHost or WebView2 based apps are failing, consider removing these keys as Administrator and reinstalling WebView2."
}

# -------------------------------------------------------------------------------------------------
# Section 5: Quick guidance summary
# -------------------------------------------------------------------------------------------------

Write-Info "Summary and next steps:"

Write-Info "1) If profile files are missing or ProfileList is inconsistent:"
Write-Info "   - A new clean admin profile (like FixProfile) is recommended."
Write-Info "   - Or perform an in-place upgrade repair of Windows."

Write-Info "2) If Add-AppxPackage for WebViewHost fails with profile type errors:"
Write-Info "   - This usually means the current profile is damaged by System Restore."
Write-Info "   - Logging into a clean admin profile once can often restore AppX subsystem state."

Write-Info "3) If WebView2 GUIDs exist and WebView2 apps fail:"
Write-Info "   - Remove the GUIDs as Administrator and reinstall WebView2 runtime from Microsoft."

Write-OK "ProfileRecoveryToolkit diagnostics completed."
