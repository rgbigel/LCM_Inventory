# =================================================================================================
#  Module:      OCRBatch.ps1
#  Path:        D:\Onedrive\cmd
#  Author:      Rolf Bercht
#  Version:     1.0.0
#  Changelog:
#      1.000  --------  Initial version with dynamic filtering and OCR batch processing
# =================================================================================================

param(
    # Root directory to scan for PDF files.
    # Defaults to the current working directory.
    [string]$Source = (Get-Location).Path,

    # Letter ranges to exclude (case-insensitive).
    # Example: "A-A","P-Z" excludes A and P–Z → allows B–O.
    [string[]]$ExclusionRanges = @("A-A","P-Z"),

    # Optional target directory. If empty, "<Source>_OCR" is used.
    [string]$Target = ""
)

# If no target specified, create "<Source>_OCR"
if ($Target -eq "") {
    $Target = "${Source}_OCR"
}

# Prepare log files
$LogOK  = Join-Path $Target "ocr_success.log"
$LogErr = Join-Path $Target "ocr_errors.log"

# Ensure target root exists
New-Item -ItemType Directory -Force -Path $Target | Out-Null


# --- BUILD EXCLUSION REGEX FROM RANGES ---
$ExclusionRegexParts = $ExclusionRanges | ForEach-Object {
    $parts = $_.Split("-")
    "[" + $parts[0] + "-" + $parts[1] + "]"
}

$ExclusionRegex = "^(" + ($ExclusionRegexParts -join "|") + ")"


# --- FILTER FUNCTION ---
function FolderAllowed($path, $sourceRoot, $excludeRegex) {

    $rel = $path.Substring($sourceRoot.Length).TrimStart("\")
    if ($rel -eq "") { return $true }

    $first = $rel.Split("\")[0]

    if ($first -match $excludeRegex) {
        return $false
    }

    return $true
}


# --- PROCESSING LOOP ---
Get-ChildItem $Source -Recurse -Filter *.pdf | ForEach-Object {

    if (-not (FolderAllowed $_.FullName $Source $ExclusionRegex)) {
        return
    }

    $RelativePath = $_.FullName.Substring($Source.Length).TrimStart("\")
    $OutputPath   = Join-Path $Target $RelativePath
    $OutputDir    = Split-Path $OutputPath

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

    try {
        ocrmypdf --skip-text --jobs 8 --optimize 3 `
            $_.FullName $OutputPath -q

        Add-Content $LogOK "+ OK  $($_.FullName)  -->  $OutputPath"
    }
    catch {
        Add-Content $LogErr "- ERR $($_.FullName)  -->  $OutputPath  |  $($_.Exception.Message)"
    }
}
