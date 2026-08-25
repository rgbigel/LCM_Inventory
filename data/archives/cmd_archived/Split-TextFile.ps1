# File: Split-TextFile.ps1
# Version: 1.0.0
# Author: Rolf
# Created: 2026-05-04
# Updated: 2026-05-04
# Description:
#   Splits a text file into numbered parts without breaking lines.
#   Each part is limited by a maximum character count.
# Notes:
#   - Splits only at line endings.
#   - Creates a "Parts" subfolder next to the input file.
#   - Performs strict error checking for read/write operations.
# Changelog:
#   1.0.0 - Initial version.

param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [int]$MaxChars = 6000
)

# --- Validate input file ---
if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Error ("Input file does not exist: " + $InputFile)
    exit 1
}

try {
    $lines = Get-Content -LiteralPath $InputFile -ErrorAction Stop
}
catch {
    $msg = "Failed to read input file: {0}" -f $_.Exception.Message
    Write-Error $msg
    exit 1
}

# --- Prepare output folder ---
$outDir = Join-Path (Split-Path -Parent $InputFile) 'Parts'

try {
    New-Item -ItemType Directory -Path $outDir -Force -ErrorAction Stop | Out-Null
}
catch {
    $msg = "Failed to create output directory: {0}" -f $_.Exception.Message
    Write-Error $msg
    exit 1
}

# --- Split logic (line-safe) ---
$buf = ''
$idx = 1

foreach ($line in $lines) {
    $add = $line + "`r`n"

    if (($buf.Length + $add.Length) -gt $MaxChars) {
        $name = '{0:D3}.txt' -f $idx
        $path = Join-Path $outDir $name

        try {
            Set-Content -LiteralPath $path -Value $buf -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            $msg = "Failed to write part {0}: {1}" -f $idx, $_.Exception.Message
            Write-Error $msg
            exit 1
        }

        $idx++
        $buf = ''
    }

    $buf += $add
}

# --- Write final part ---
if ($buf.Length -gt 0) {
    $name = '{0:D3}.txt' -f $idx
    $path = Join-Path $outDir $name

    try {
        Set-Content -LiteralPath $path -Value $buf -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        $msg = "Failed to write final part: {0}" -f $_.Exception.Message
        Write-Error $msg
        exit 1
    }
}

Write-Output ("Split completed. Parts in: " + $outDir)
