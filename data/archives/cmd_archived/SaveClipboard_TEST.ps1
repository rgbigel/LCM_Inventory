# File: HeaderImage.png
# Version: 1.5.0 (with debug switch -d)

param(
    [Parameter(Position = 0)]
    [string]$FolderPath = "",

    [Parameter(Position = 1)]
    [string]$FilePath = "",

    [switch]$d
)

# ---------------------------
# DEBUG MODE
# ---------------------------
if ($d) {
    Write-Host "=== DEBUG MODE ACTIVE ==="
    Write-Host "FolderPath = '$FolderPath'"
    Write-Host "FilePath   = '$FilePath'"
    Write-Host "Raw args   = $($args -join ', ')"
}

# ---------------------------
# Load required assemblies
# ---------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework

function Show-ErrorPopup($msg) {
    [System.Windows.MessageBox]::Show($msg, "SaveClipboard.ps1", "OK", "Error") | Out-Null
}

# ---------------------------
# Clipboard detection
# ---------------------------
$HasImage = [System.Windows.Forms.Clipboard]::ContainsImage()
$ImageObj = $HasImage ? [System.Windows.Forms.Clipboard]::GetImage() : $null

if ($d) {
    Write-Host "HasImage = $HasImage"
}

# ---------------------------
# Comment delimiters for header parsing
# ---------------------------
$CommentDelimiters = @{
    "ps1"       = @("#")
    "py"        = @("#")
    "c"         = @("//")
    "cs"        = @("//")
    "cpp"       = @("//")
    "js"        = @("//")
    "ts"        = @("//")
    "ini"       = @(";")
    "cfg"       = @(";")
    "reg"       = @(";", "#")
    "ahk"       = @(";")
    "json"      = @()
    "apk"       = @()
    "arguments" = @()
    "abc"       = @()
}

# ---------------------------
# Utility functions
# ---------------------------
function Ensure-Directory($path, [bool]$UsePopup, [switch]$d) {
    if ($d) { Write-Host "Ensure-Directory: '$path'" }

    if (-not $path) {
        if ($UsePopup) { Show-ErrorPopup "Target directory is empty." }
        else { Write-Host "Error: Target directory is empty." }
        exit 1
    }

    if (-not (Test-Path $path -PathType Container)) {
        try {
            if ($d) { Write-Host "Creating directory: $path" }
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
        catch {
            if ($UsePopup) { Show-ErrorPopup "Cannot create target directory:`n$path" }
            else { Write-Host "Error: Cannot create target directory: $path" }
            exit 1
        }
    }
}

function Sanitize-Filename($name, [switch]$d) {
    if ($d) { Write-Host "Sanitize-Filename (in): '$name'" }
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($char in $invalid) { $name = $name.Replace($char, "_") }
    if ($d) { Write-Host "Sanitize-Filename (out): '$name'" }
    return $name
}

function Get-NonCollidingName($directory, $filename, [switch]$d) {
    if ($d) { Write-Host "Get-NonCollidingName: dir='$directory', file='$filename'" }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($filename)
    $ext  = [System.IO.Path]::GetExtension($filename)
    $full = Join-Path $directory $filename

    if ($base -ne "SaveClipboard" -or -not (Test-Path $full)) {
        if ($d) { Write-Host "Using non-colliding name: $full" }
        return $full
    }

    $i = 0
    while ($true) {
        $candidate = Join-Path $directory ("{0}_{1:000}{2}" -f $base, $i, $ext)
        if (-not (Test-Path $candidate)) {
            if ($d) { Write-Host "Collision resolved: $candidate" }
            return $candidate
        }
        $i++
    }
}

function Get-ExtensionName($name) {
    $ext = [System.IO.Path]::GetExtension($name)
    return $ext ? $ext.TrimStart(".").ToLower() : ""
}

function Get-HeaderFilename([string]$ScriptPath, [string]$TargetExt, [switch]$d) {
    if ($d) { Write-Host "Get-HeaderFilename: ScriptPath='$ScriptPath', TargetExt='$TargetExt'" }

    $header = Get-Content -Path $ScriptPath -TotalCount 40
    $delims = $CommentDelimiters.ContainsKey($TargetExt) ? $CommentDelimiters[$TargetExt] : @("#",";","//","--")

    foreach ($line in $header) {
        $clean = $line.Trim()

        if ($clean -match '^-{3,}$') { continue }
        if ($clean -match '^#{3,}$') { continue }

        foreach ($dlim in $delims) {
            if (-not $dlim) { continue }
            $esc = [Regex]::Escape($dlim)

            if ($clean -match "^{0}\s*File:\s*(.+)$" -f $esc) {
                if ($d) { Write-Host "Header filename (File:): '$($Matches[1].Trim())'" }
                return $Matches[1].Trim()
            }

            if ($clean -match "^{0}\s*([A-Za-z0-9 _\-\.\(\)]+)$" -f $esc) {
                if ($d) { Write-Host "Header filename (bare after delim): '$($Matches[1].Trim())'" }
                return $Matches[1].Trim()
            }
        }

        if ($clean -match '^([A-Za-z0-9 _\-\.\(\)]+)$') {
            if ($d) { Write-Host "Header filename (bare): '$($Matches[1].Trim())'" }
            return $Matches[1].Trim()
        }
    }

    if ($d) { Write-Host "No header filename found." }
    return $null
}

# ---------------------------
# Normalize parameters
# ---------------------------
$FolderPath = $FolderPath.Trim()
$FilePath   = $FilePath.Trim()

if ($d) {
    Write-Host "FolderPath (trimmed): '$FolderPath'"
    Write-Host "FilePath   (trimmed): '$FilePath'"
}

$HasFolder = $FolderPath -ne ""
$HasFile   = $FilePath   -ne ""

if (-not $HasFolder -and -not $HasFile) {
    Write-Host "Error: Both parameters empty."
    exit 1
}

# ---------------------------
# Clipboard text
# ---------------------------
$clipText = Get-Clipboard -Raw

if ($d) {
    $preview = if ($clipText.Length -gt 40) { $clipText.Substring(0,40) + "..." } else { $clipText }
    Write-Host "Clipboard text preview: '$preview'"
}

# ---------------------------
# Determine target directory + initial filename
# ---------------------------
$TargetDirectory = $HasFile ? (Split-Path $FilePath -Parent) : $FolderPath
$InitialFilename = $HasFile ? [System.IO.Path]::GetFileName($FilePath) : $null

if ($d) {
    Write-Host "TargetDirectory = '$TargetDirectory'"
    Write-Host "InitialFilename = '$InitialFilename'"
}

Ensure-Directory -path $TargetDirectory -UsePopup:$true -d:$d

# ---------------------------
# Filename from clipboard
# ---------------------------
$clipboardName = $null
if ($clipText -and $clipText -match '^[A-Za-z0-9 _\-\.\(\)]+$') {
    $clipboardName = $clipText.Trim()
    if ($d) { Write-Host "Clipboard-derived filename: '$clipboardName'" }
}

# ---------------------------
# Determine extension for header parsing
# ---------------------------
$targetExt = ""
if ($clipboardName) {
    $targetExt = Get-ExtensionName $clipboardName
} elseif ($InitialFilename) {
    $targetExt = Get-ExtensionName $InitialFilename
}

if ($d) { Write-Host "Target extension for header parsing: '$targetExt'" }

# ---------------------------
# Header filename
# ---------------------------
$headerName = Get-HeaderFilename -ScriptPath $PSCommandPath -TargetExt $targetExt -d:$d

# ---------------------------
# Filename resolution
# ---------------------------
$filename = $clipboardName
if (-not $filename -and $InitialFilename) { $filename = $InitialFilename }
if (-not $filename -and $headerName)     { $filename = $headerName }
if (-not $filename)                      { $filename = "ClipboardOutput.txt" }

$filename = Sanitize-Filename -name $filename -d:$d

if ($d) { Write-Host "Filename after resolution: '$filename'" }

# ---------------------------
# IMAGE MODE
# ---------------------------
if ($HasImage) {
    if ($d) { Write-Host "Mode: IMAGE" }

    $ext = [System.IO.Path]::GetExtension($filename)
    if (-not $ext) {
        $filename += ".png"
        if ($d) { Write-Host "Defaulting image extension to .png" }
    }
    elseif ($ext.ToLower() -eq ".jpeg") {
        $filename = [System.IO.Path]::ChangeExtension($filename, ".jpg")
        if ($d) { Write-Host "Normalized .jpeg to .jpg" }
    }

    if ($filename.ToLower().EndsWith(".ps1") -and -not $clipboardName) {
        $filename = [System.IO.Path]::ChangeExtension($filename, ".png")
        if ($d) { Write-Host "Avoiding accidental .ps1 for image" }
    }

    $full = Get-NonCollidingName -directory $TargetDirectory -filename $filename -d:$d

    if ($d) { Write-Host "Final image path: '$full'" }

    try {
        if ($full.ToLower().EndsWith(".jpg")) {
            $ImageObj.Save($full, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        } else {
            $ImageObj.Save($full, [System.Drawing.Imaging.ImageFormat]::Png)
        }
    }
    catch {
        Show-ErrorPopup "Error writing image:`n$full"
        if ($d) { Write-Host "Exception: $($_.Exception.Message)" }
        exit 1
    }

    if ($d) { Write-Host "=== END (IMAGE) ===" }
    exit 0
}

# ---------------------------
# TEXT MODE
# ---------------------------
if ($d) { Write-Host "Mode: TEXT" }

if ($filename -notmatch '\.[A-Za-z0-9]+$') {
    if ($filename -notmatch '^\.[A-Za-z0-9]+$') {
        $filename += ".txt"
        if ($d) { Write-Host "Defaulting text extension to .txt" }
    }
}

if ($filename.ToLower().EndsWith(".ps1") -and -not $clipboardName) {
    $filename = [System.IO.Path]::ChangeExtension($filename, ".txt")
    if ($d) { Write-Host "Avoiding accidental .ps1 for text" }
}

$full = Get-NonCollidingName -directory $TargetDirectory -filename $filename -d:$d

if ($d) { Write-Host "Final text path: '$full'" }

try {
    Set-Content -Path $full -Value $clipText -Encoding UTF8
}
catch {
    Show-ErrorPopup "Error writing file:`n$full"
    if ($d) { Write-Host "Exception: $($_.Exception.Message)" }
    exit 1
}

if ($d) { Write-Host "=== END (TEXT) ===" }
