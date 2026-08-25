# =================================================================================================
#  Module:      ProfileRecoveryToolkit-Repair.ps1
#  Path:        .\Maintenance
#  Author:      Rolf Bercht
#  Version:     1.0.0
#  Changelog:
#      1.000  --------  Initial repair module for profile, AppX, WebViewHost and WebView2
# =================================================================================================

<#
.SYNOPSIS
    Repair module for profile-related AppX, WebViewHost and WebView2 issues.

.DESCRIPTION
    This script requires Administrator rights.
    It performs controlled repair actions based on known failure patterns after System Restore.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info { Write-Host "[INFO ] $args" -ForegroundColor Cyan }
function Write-OK   { Write-Host "[ OK  ] $args"   -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN ] $args"  -ForegroundColor Yellow }
function Write-Err  { Write-Host "[FAIL ] $args"  -ForegroundColor Red }

# -------------------------------------------------------------------------------------------------
# Admin check
# -------------------------------------------------------------------------------------------------

Write-Info "Checking for Administrator rights..."

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err "This repair module must be run as Administrator."
    exit 1
}

Write-OK "Administrator rights confirmed."

# -------------------------------------------------------------------------------------------------
# Section 1: Remove stale WebView2 GUIDs
# -------------------------------------------------------------------------------------------------

Write-Info "Checking for stale WebView2 runtime GUIDs..."

$WebView2GUID = "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"

$RegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\" + $WebView2GUID,
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\" + $WebView2GUID,
    "HKCU:\Software\Microsoft\EdgeUpdate\Clients\" + $WebView2GUID
)

$found = @()

foreach ($p in $RegPaths) {
    if (Test-Path $p) {
        Write-Warn ("Found stale WebView2 GUID at " + $p)
        $found += $p
    }
}

if ($found.Count -eq 0) {
    Write-OK "No stale WebView2 GUIDs found."
}
else {
    Write-Info "Removing stale WebView2 GUIDs..."

    foreach ($p in $found) {
        try {
            Remove-Item -Path $p -Recurse -Force
            Write-OK ("Removed GUID at " + $p)
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Err ("Failed to remove GUID at " + $p + " - " + $errMsg)
        }
    }

    Write-Warn "WebView2 runtime should be reinstalled after this repair."
}

# -------------------------------------------------------------------------------------------------
# Section 2: Re-register WebViewHost AppX package
# -------------------------------------------------------------------------------------------------

Write-Info "Re-registering WebViewHost AppX package..."

try {
    $pkg = Get-AppxPackage "Microsoft.Win32WebViewHost" -ErrorAction SilentlyContinue

    if (-not $pkg) {
        Write-Warn "WebViewHost package not found. Attempting system-level registration..."

        $systemPath = "C:\Windows\SystemApps\Microsoft.Win32WebViewHost_cw5n1h2txyewy\AppXManifest.xml"

        if (Test-Path $systemPath) {
            try {
                Add-AppxPackage -DisableDevelopmentMode -Register $systemPath
                Write-OK "System-level WebViewHost registration completed."
            }
            catch {
                $errMsg = $_.Exception.Message
                Write-Err ("Failed to register WebViewHost - " + $errMsg)
            }
        }
        else {
            Write-Err "System WebViewHost manifest not found. System may be damaged."
        }
    }
    else {
        $manifest = Join-Path $pkg.InstallLocation "AppXManifest.xml"

        if (Test-Path $manifest) {
            try {
                Add-AppxPackage -DisableDevelopmentMode -Register $manifest
                Write-OK "User-level WebViewHost registration completed."
            }
            catch {
                $errMsg = $_.Exception.Message
                Write-Err ("Failed to register WebViewHost - " + $errMsg)
            }
        }
        else {
            Write-Err "WebViewHost manifest missing in package directory."
        }
    }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Err ("Error while processing WebViewHost registration - " + $errMsg)
}

# -------------------------------------------------------------------------------------------------
# Section 3: Repair profile ACLs for WebViewHost folder
# -------------------------------------------------------------------------------------------------

Write-Info "Repairing ACLs for WebViewHost folder..."

$PkgName = "Microsoft.Win32WebViewHost_cw5n1h2txyewy"
$PkgPath = Join-Path $env:LOCALAPPDATA "Packages\" + $PkgName

if (Test-Path $PkgPath) {
    try {
        $acl = Get-Acl $PkgPath
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "ALL APPLICATION PACKAGES",
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )

        $acl.SetAccessRule($rule)
        Set-Acl -Path $PkgPath -AclObject $acl

        Write-OK "ACLs repaired."
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-Err ("Failed to repair ACLs - " + $errMsg)
    }
}
else {
    Write-Warn "WebViewHost folder does not exist. It will be created automatically after next WebViewHost launch."
}

# -------------------------------------------------------------------------------------------------
# Section 4: Optional SFC and DISM
# -------------------------------------------------------------------------------------------------

Write-Info "Running SFC and DISM is recommended if profile or AppX issues persist."

Write-Info "To run them manually:"
Write-Info "  sfc /scannow"
Write-Info "  DISM /Online /Cleanup-Image /RestoreHealth"

Write-OK "Repair module completed."
