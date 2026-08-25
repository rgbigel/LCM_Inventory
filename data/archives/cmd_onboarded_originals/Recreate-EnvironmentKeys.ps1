# File: Recreate-EnvironmentKeys.ps1
# Version: 1.1.0
# Author: Rolf
# Created: 2026-06-05
# Updated: 2026-06-05
#
# Description:
#   Safely recreates missing HKLM and HKCU Environment registry keys.
#   Non-destructive. Creates keys only if missing. Does not modify existing values.
#
# Notes:
#   Includes error handling and success verification for each operation.
#
# Changelog:
#   1.1.0 - Added error catching and success checks
#   1.0.0 - Initial release


# --- Begin Script ---

# Prepare error variable (InvariantRules: never use $_ inside strings)
$errMsg = $null

# HKLM Environment Key
$hklmEnv = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
try {
    if (-not (Test-Path $hklmEnv)) {
        New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'Environment' -Force | Out-Null
    }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Host "ERROR: Failed to create HKLM Environment key: $errMsg"
}

# Verify HKLM success
if (Test-Path $hklmEnv) {
    Write-Host "SUCCESS: HKLM Environment key exists."
} else {
    Write-Host "FAIL: HKLM Environment key is still missing."
}

# HKCU Environment Key
$hkcuEnv = 'HKCU:\Environment'
try {
    if (-not (Test-Path $hkcuEnv)) {
        New-Item -Path 'HKCU:' -Name 'Environment' -Force | Out-Null
    }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Host "ERROR: Failed to create HKCU Environment key: $errMsg"
}

# Verify HKCU success
if (Test-Path $hkcuEnv) {
    Write-Host "SUCCESS: HKCU Environment key exists."
} else {
    Write-Host "FAIL: HKCU Environment key is still missing."
}

# --- End Script ---
