# File: ToolPathReplacer.ps1
# Version: 2.0.0
# Author: Rolf
# Created: 2026-06-05
# Updated: 2026-06-05
#
# Description:
#   Replaces a program folder (e.g. C:\Program Files\PowerShell\7) with a junction
#   pointing to D:\Tools\<BaseName>. BaseName is derived from the parent folder
#   (e.g. PowerShell, Git, SomeApp). Handles naming, copying, verification,
#   deletion, junction creation, and logging. Also writes a junction info file
#   under D:\Tools\Alias\Junctions for later multi-boot / system management.
#
# Notes:
#   Requires elevation. Non-destructive: existing -Old folders are preserved.
#
# Changelog:
#   2.0.0 - Logging moved to D:\Tools\Alias\Logs, junction info added under Alias\Junctions
#   1.2.0 - Robust naming logic based on parent folder
#   1.1.0 - Added logging
#   1.0.0 - Initial release


param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath
)

# Normalize input
$SourcePath = $SourcePath.TrimEnd('\')

# Alias root
$AliasRoot     = 'D:\Tools\Alias'
$LogRoot       = Join-Path $AliasRoot 'Logs'
$JunctionRoot  = Join-Path $AliasRoot 'Junctions'

# Ensure base dirs
foreach ($dir in @($AliasRoot, $LogRoot, $JunctionRoot)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# Log file
$LogFile = Join-Path $LogRoot ('ToolPathReplacer_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')

function Log {
    param([string]$Text)
    $timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $line = "$timestamp  $Text"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function LogSuccess {
    param([string]$Text)
    $timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $line = "$timestamp  SUCCESS: $Text"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line -ForegroundColor Green
}

function LogError {
    param([string]$Text)
    $timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $line = "$timestamp  ERROR: $Text"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line -ForegroundColor Red
}


Log "=== ToolPathReplacer started ==="
Log "SourcePath = $SourcePath"

if (-not (Test-Path $SourcePath)) {
    LogError "Source path does not exist: $SourcePath"
    exit 1
}

# Extract names
$Leaf       = Split-Path $SourcePath -Leaf
$Parent     = Split-Path $SourcePath -Parent
$ParentName = Split-Path $Parent -Leaf

Log "Leaf       = $Leaf"
Log "Parent     = $Parent"
Log "ParentName = $ParentName"

# Naming: always base on ParentName, with numeric suffix if needed
$TargetRoot = 'D:\Tools'
$BaseName   = $ParentName

# Try BaseName
$Candidate = Join-Path $TargetRoot $BaseName

if (-not (Test-Path $Candidate)) {
    $TargetPath = $Candidate
}
else {
    # Add numeric suffix
    $i = 1
    while ($true) {
        $Try = Join-Path $TargetRoot ("${BaseName}_$i")
        if (-not (Test-Path $Try)) {
            $TargetPath = $Try
            break
        }
        $i++
    }
}

$OldPath = "${TargetPath}-Old"

Log "TargetRoot = $TargetRoot"
Log "TargetPath = $TargetPath"
Log "OldPath    = $OldPath"

# Ensure D:\Tools exists
if (-not (Test-Path $TargetRoot)) {
    try {
        New-Item -Path $TargetRoot -ItemType Directory -Force | Out-Null
        LogSuccess "Created directory: $TargetRoot"
    }
    catch {
        $msg = $_.Exception.Message
        LogError "Cannot create $TargetRoot -> $msg"
        exit 1
    }
}
else {
    Log "Target root exists: $TargetRoot"
}

# Rename existing target if needed
if (Test-Path $TargetPath) {
    if (Test-Path $OldPath) {
        Log "OldPath already exists. Skipping rename."
    }
    else {
        try {
            Rename-Item -Path $TargetPath -NewName ((Split-Path $TargetPath -Leaf) + '-Old') -Force
            LogSuccess "Renamed existing target to: $OldPath"
        }
        catch {
            $msg = $_.Exception.Message
            LogError "Failed to rename $TargetPath -> $OldPath -> $msg"
            exit 1
        }
    }
}
else {
    Log "No existing target folder found."
}

# Copy
try {
    Copy-Item -Path $SourcePath -Destination $TargetPath -Recurse -Force
    LogSuccess "Copied to: $TargetPath"
}
catch {
    $msg = $_.Exception.Message
    LogError "Copy failed -> $msg"
    exit 1
}

# Verify
if (-not (Test-Path $TargetPath)) {
    LogError "Copy verification failed. Target missing."
    exit 1
}
else {
    LogSuccess "Copy verification OK."
}

# Delete original
try {
    Remove-Item -Path $SourcePath -Recurse -Force
    LogSuccess "Deleted original: $SourcePath"
}
catch {
    $msg = $_.Exception.Message
    LogError "Failed to delete original -> $msg"
    exit 1
}

# Junction
try {
    New-Item -Path $SourcePath -ItemType Junction -Value $TargetPath | Out-Null
    LogSuccess "Created junction: $SourcePath -> $TargetPath"
}
catch {
    $msg = $_.Exception.Message
    LogError "Failed to create junction -> $msg"
    exit 1
}

# Junction info file
$JunctionName = (Split-Path $TargetPath -Leaf)
$JunctionInfo = Join-Path $JunctionRoot ($JunctionName + '.txt')

$info = @()
$info += "Source : $SourcePath"
$info += "Target : $TargetPath"
$info += "Leaf   : $Leaf"
$info += "Parent : $Parent"
$info += "Name   : $JunctionName"
$info += "Created: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

try {
    Set-Content -Path $JunctionInfo -Value $info
    LogSuccess "Wrote junction info: $JunctionInfo"
}
catch {
    $msg = $_.Exception.Message
    LogError "Failed to write junction info -> $msg"
}

Log "=== ToolPathReplacer completed successfully ==="
Log "Log file saved to: $LogFile"
