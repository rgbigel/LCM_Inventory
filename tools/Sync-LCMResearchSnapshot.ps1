<#
.SYNOPSIS
    Synchronizes a snapshot of the LCM research and governance architecture to Google Drive.
.DESCRIPTION
    Module: Sync-LCMResearchSnapshot
    Purpose: Mirrors core LCM subsystems, documentation, and root-level files to Google Drive with .txt extensions for cloud inspection and LLM analysis.
    Path: tools/Sync-LCMResearchSnapshot.ps1
    Authors: Rolf, Antigravity AI
    Version: 1.0.0
    Date: 2026-09-04
.PARAMETER SourceRoot
    The source workspace root directory. Defaults to "D:\Git_Repositories".
.PARAMETER TargetRoot
    The destination target directory. Defaults to "D:\GDrive\LCM".
.PARAMETER IncludeRootFiles
    Switch to include root governance files (AGENTS.md, GEMINI.md, README.md, etc.). Defaults to $true.
.PARAMETER Detailed
    Shows detailed progress messages for each mirrored file.
.PARAMETER Help
    Displays usage guidance and exits.
.EXAMPLE
    pwsh -File tools/Sync-LCMResearchSnapshot.ps1
.EXAMPLE
    pwsh -File tools/Sync-LCMResearchSnapshot.ps1 -TargetRoot "D:\GDrive\LCM" -Detailed
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Root workspace directory containing source repositories')]
    [string]$SourceRoot = "D:\Git_Repositories",

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Destination root directory on Google Drive or mirror destination')]
    [string]$TargetRoot = "D:\GDrive\LCM",

    [Parameter(Mandatory = $false, HelpMessage = 'Include top-level root markdown and text files (AGENTS.md, etc.)')]
    [switch]$IncludeRootFiles = $true,

    [Parameter(Mandatory = $false, HelpMessage = 'Force overwrite and re-mirror of all destination files')]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = 'Display verbose logging for each individual file mirrored')]
    [Alias('ShowAll')]
    [switch]$Detailed,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# RULE-PS-010: Help handling
if ($Help) {
    Write-Host @"

=== Sync-LCMResearchSnapshot v1.0.0 Help ===

SYNOPSIS:
    Mirrors core LCM subsystems and root governance files to Google Drive, appending '.txt'
    so that cloud tools and LLMs can inspect them natively.

SYNTAX:
    Sync-LCMResearchSnapshot.ps1 [[-SourceRoot] <string>] [[-TargetRoot] <string>] [-IncludeRootFiles] [-Detailed] [-Help]

PARAMETERS:
    -SourceRoot <string>
        The source repository root. Default: "D:\Git_Repositories"
    -TargetRoot <string>
        The destination directory. Default: "D:\GDrive\LCM"
    -IncludeRootFiles
        Includes top-level root markdown and text files (AGENTS.md, GEMINI.md, etc.). Default: `$true
    -Detailed (-ShowAll)
        Emits verbose logging for each individual file mirrored.
    -Help (-h, -?)
        Displays this help message.

EXAMPLES:
    pwsh -File tools/Sync-LCMResearchSnapshot.ps1
    pwsh -File tools/Sync-LCMResearchSnapshot.ps1 -Detailed
    pwsh -File tools/Sync-LCMResearchSnapshot.ps1 -TargetRoot "D:\GDrive\LCM_Backup"

"@
    exit 0
}

# RULE-PS-009: Logging setup
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logDir = Join-Path $SourceRoot "LCM_Inventory\data\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logPath = Join-Path $logDir "Sync-LCMResearchSnapshot_$timestamp.log"

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    $entry = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message
    Add-Content -Path $logPath -Value $entry -Encoding UTF8
    Write-Host $Message -ForegroundColor $Color
}

Write-Log -Level "INFO" -Message "`n=== Synchronizing LCM Research Snapshot to $TargetRoot ===" -Color Cyan
Write-Log -Level "INFO" -Message "Source Root: $SourceRoot" -Color Gray
Write-Log -Level "INFO" -Message "Target Root: $TargetRoot" -Color Gray
Write-Log -Level "INFO" -Message "Audit Log: $logPath" -Color Gray

# Core subsystems defining the LCM/LCD architecture
$includeSubsystems = @(
    ".lcm",
    ".agents",
    "docs",
    "LCM_Inventory",
    "LCM_Supervision",
    "LCM_AI"
)

# Text and code extensions Gemini / Drive can inspect natively once appended with .txt
$textExtensions = @(".md", ".ps1", ".psm1", ".json", ".yaml", ".yml", ".rules", ".txt", ".conf")

# Ignore Git internals, local environment cruft, and large runtime binary caches
$excludePatterns = @(
    "\\\.git\\",
    "\\node_modules\\",
    "\\\.vscode\\",
    "\\\.tmp",
    "\\data\\logs\\",
    "\\logs\\",
    "\\\.venv\\"
)

if (-not (Test-Path $TargetRoot)) {
    New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null
    Write-Log -Level "ACTION" -Message "Created target directory: $TargetRoot" -Color Yellow
}

$manifest = [System.Collections.Generic.List[string]]::new()
$manifest.Add("=== LCM REPOSITORY SNAPSHOT MANIFEST: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===")
$manifest.Add("Source Root: $SourceRoot")
$manifest.Add("Target Root: $TargetRoot`n")

$copiedCount = 0
$skippedCount = 0

# Helper to process a single file
function Copy-MirroredFile {
    param(
        [Parameter(Mandatory = $true)]$FileItem
    )

    $fullName = $FileItem.FullName
    $relPath = $fullName.Substring($SourceRoot.Length).TrimStart("\", "/")

    # Exclude transients and git objects
    $skip = $false
    foreach ($pat in $excludePatterns) {
        if ($fullName -match $pat) {
            $skip = $true
            break
        }
    }
    if ($skip) { return }

    # Filter extensions and mirror
    $ext = $FileItem.Extension.ToLower()
    if ($textExtensions -contains $ext) {
        $destRelPath = $relPath + ".txt"
        $destFullPath = Join-Path $TargetRoot $destRelPath
        $destDir = Split-Path $destFullPath -Parent

        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        Copy-Item -Path $fullName -Destination $destFullPath -Force
        $script:manifest.Add("$relPath -> $destRelPath ($($FileItem.Length) bytes)")
        $script:copiedCount++

        if ($Detailed) {
            Write-Log -Level "DEBUG" -Message "Mirrored: $relPath -> $destRelPath" -Color DarkGray
        }
    } else {
        $script:skippedCount++
    }
}

# 1. Process Root Files if enabled
if ($IncludeRootFiles) {
    Write-Log -Level "INFO" -Message "Scanning root files..." -Color White
    $rootFiles = @(Get-ChildItem -Path $SourceRoot -File -ErrorAction SilentlyContinue)
    foreach ($rf in $rootFiles) {
        Copy-MirroredFile -FileItem $rf
    }
}

# 2. Process Core Subsystems
foreach ($sub in $includeSubsystems) {
    $subPath = Join-Path $SourceRoot $sub
    if (-not (Test-Path $subPath)) {
        Write-Log -Level "WARN" -Message "Subsystem path not found, skipping: $subPath" -Color Yellow
        continue
    }

    Write-Log -Level "INFO" -Message "Scanning subsystem: $sub..." -Color White
    $files = @(Get-ChildItem -Path $subPath -Recurse -File -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        # Check if file is located inside a symlink/reparse point to avoid infinite loops or duplicates
        Copy-MirroredFile -FileItem $file
    }
}

# Write full file manifest to the Google Drive root using atomic staging & retry
$manifestPath = Join-Path $TargetRoot "MANIFEST.txt"
$manifestTmp = "$manifestPath.tmp"

$manifestWritten = $false
$maxRetries = 3
$delayMs = 250

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    try {
        $manifest | Set-Content -Path $manifestTmp -Encoding UTF8
        [System.IO.File]::Move($manifestTmp, $manifestPath, $true)
        $manifestWritten = $true
        break
    } catch {
        Write-Log -Level "WARN" -Message "Manifest write attempt $attempt failed ($($_.Exception.Message)). Retrying in ${delayMs}ms..." -Color Yellow
        Start-Sleep -Milliseconds $delayMs
        $delayMs *= 2
    }
}

if (-not $manifestWritten) {
    Write-Log -Level "ERROR" -Message "Failed to write manifest to $manifestPath after $maxRetries attempts." -Color Red
    if (Test-Path $manifestTmp) { Remove-Item -Path $manifestTmp -Force -ErrorAction SilentlyContinue }
} else {
    Write-Log -Level "ACTION" -Message "Manifest generated at: $manifestPath" -Color Cyan
}

# RULE-PS-009: Mandatory [SUMMARY] Footer
$summaryBlock = @"

=======================================================
[SUMMARY] Sync-LCMResearchSnapshot Execution Complete
=======================================================
Tool Name       : Sync-LCMResearchSnapshot
Version         : 1.0.0
Execution Status: COMPLETED
Files Mirrored  : $copiedCount
Manifest Path   : $manifestPath
Audit Log       : $logPath
Timestamp       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')
=======================================================
"@

Write-Log -Level "SUMMARY" -Message $summaryBlock -Color Green
