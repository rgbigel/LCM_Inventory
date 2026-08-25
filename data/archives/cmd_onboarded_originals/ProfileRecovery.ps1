# =================================================================================================
#  Module:      ProfileRecovery.ps1
#  Path:        .\Maintenance
#  Author:      Rolf Bercht
#  Version:     1.0.0
#  Changelog:
#      1.000  --------  Unified launcher for diagnostics and repair
# =================================================================================================

<#
.SYNOPSIS
    Unified launcher for profile diagnostics and repair.

.DESCRIPTION
    Runs diagnostics first, evaluates results, and optionally runs the repair module.
    This script does not modify the system unless you confirm repair actions.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info { Write-Host "[INFO ] $args" -ForegroundColor Cyan }
function Write-OK   { Write-Host "[ OK  ] $args"   -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN ] $args"  -ForegroundColor Yellow }
function Write-Err  { Write-Host "[FAIL ] $args"  -ForegroundColor Red }

# -------------------------------------------------------------------------------------------------
# Paths
# -------------------------------------------------------------------------------------------------

$ToolkitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DiagPath    = Join-Path $ToolkitRoot "ProfileRecoveryToolkit.ps1"
$RepairPath  = Join-Path $ToolkitRoot "ProfileRecoveryToolkit-Repair.ps1"
$LogDir      = Join-Path $ToolkitRoot "Logs"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile   = Join-Path $LogDir ("ProfileRecovery_" + $Timestamp + ".log")

# -------------------------------------------------------------------------------------------------
# Logging helper
# -------------------------------------------------------------------------------------------------

function Log {
    param([string]$Text)
    Add-Content -Path $LogFile -Value $Text
}

Write-Info "Profile Recovery Launcher started."
Log "Launcher started at $Timestamp"

# -------------------------------------------------------------------------------------------------
# Check for required modules
# -------------------------------------------------------------------------------------------------

if (-not (Test-Path $DiagPath)) {
    Write-Err "Diagnostics module not found: $DiagPath"
    exit 1
}

if (-not (Test-Path $RepairPath)) {
    Write-Err "Repair module not found: $RepairPath"
    exit 1
}

# -------------------------------------------------------------------------------------------------
# Run diagnostics
# -------------------------------------------------------------------------------------------------

Write-Info "Running diagnostics..."
Log "Running diagnostics..."

try {
    $DiagOutput = & $DiagPath 2>&1
    $DiagOutput | Tee-Object -FilePath $LogFile
}
catch {
    $errMsg = $_.Exception.Message
    Write-Err ("Diagnostics failed - " + $errMsg)
    Log "Diagnostics failed: $errMsg"
    exit 1
}

Write-OK "Diagnostics completed."

# -------------------------------------------------------------------------------------------------
# Evaluate diagnostic results
# -------------------------------------------------------------------------------------------------

$NeedsRepair = $false
$NeedsFixProfile = $false

foreach ($line in $DiagOutput) {

    if ($line -match "

\[FAIL \]

") {
        $NeedsRepair = $true
    }

    if ($line -match "Missing or inaccessible profile files") {
        $NeedsFixProfile = $true
    }

    if ($line -match "ProfileList entry does not match") {
        $NeedsFixProfile = $true
    }

    if ($line -match "profile may be unrecoverable") {
        $NeedsFixProfile = $true
    }

    if ($line -match "profile type detection failures") {
        $NeedsFixProfile = $true
    }
}

# -------------------------------------------------------------------------------------------------
# Decision logic
# -------------------------------------------------------------------------------------------------

if ($NeedsFixProfile) {
    Write-Warn "Diagnostics indicate profile corruption."
    Write-Warn "You must log into your clean FixProfile account once before repairs can succeed."
    Write-Warn "After logging into FixProfile, return here and run ProfileRecovery.ps1 again."
    Log "Profile corruption detected. FixProfile required."
    exit 0
}

if (-not $NeedsRepair) {
    Write-OK "No repair actions required. System appears healthy."
    Log "No repair actions required."
    exit 0
}

Write-Warn "Diagnostics indicate that repair actions are recommended."
Log "Repair recommended."

# -------------------------------------------------------------------------------------------------
# Ask user for confirmation
# -------------------------------------------------------------------------------------------------

$choice = Read-Host "Run repair module now? (y/n)"

if ($choice -ne "y") {
    Write-Warn "Repair cancelled by user."
    Log "Repair cancelled."
    exit 0
}

# -------------------------------------------------------------------------------------------------
# Run repair module
# -------------------------------------------------------------------------------------------------

Write-Info "Running repair module..."
Log "Running repair module..."

try {
    $RepairOutput = & $RepairPath 2>&1
    $RepairOutput | Tee-Object -FilePath $LogFile
}
catch {
    $errMsg = $_.Exception.Message
    Write-Err ("Repair failed - " + $errMsg)
    Log "Repair failed: $errMsg"
    exit 1
}

Write-OK "Repair completed."
Log "Repair completed."

Write-Info "A reboot is recommended if repairs were applied."
Log "Launcher finished."
