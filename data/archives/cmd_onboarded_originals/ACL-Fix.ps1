[CmdletBinding()]
param(
    [Alias('t')]
    [switch]$TraceMode
)

Set-StrictMode -Version Latest

function Test-IsElevated {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Restart-ScriptElevated {
    param(
        [string[]]$ForwardArgs = @()
    )

    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
    if (-not $pwsh) {
        throw 'PowerShell 7 (pwsh) was not found. Install PowerShell 7 to run this script elevated.'
    }

    $argumentList = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $PSCommandPath
    ) + $ForwardArgs

    Start-Process -FilePath $pwsh -Verb RunAs -ArgumentList $argumentList | Out-Null
}

if (-not (Test-IsElevated)) {
    Write-Host '[X] ACL-Fix requires elevation. Re-launching as Administrator in PowerShell 7...'
    $forwardArgs = @()
    if ($TraceMode) {
        $forwardArgs += '-t'
    }
    Restart-ScriptElevated -ForwardArgs $forwardArgs
    exit 0
}

function Write-TraceMessage {
    param([string]$Message)

    if ($TraceMode) {
        Write-Host ('[TRACE] {0}' -f $Message)
    }
}

# ============================================
# ACL-Fix 1.1 – Automatische CSV-Erkennung
# ============================================

$OutputPath = 'C:\Temp\ACL-Fixes'

if (-not (Test-Path -LiteralPath $OutputPath -PathType Container)) {
    Write-Host ("Output path not found: {0}. Abbruch." -f $OutputPath)
    exit 1
}
Write-TraceMessage -Message ('Using output path: {0}' -f $OutputPath)

# Neueste CSV nur aus dem festen Output-Ordner suchen
$csv = Get-ChildItem -LiteralPath $OutputPath -Filter 'ACL_Check_*.csv' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $csv) {
    Write-Host ("Keine ACL_Check_*.csv in {0} gefunden. Abbruch." -f $OutputPath)
    exit 1
}
Write-TraceMessage -Message ('Selected CSV: {0}' -f $csv.FullName)

$CsvFile = $csv.FullName
$LogFile = Join-Path -Path $OutputPath -ChildPath ("ACL_Fix_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

# Geschützte Windows-Bereiche, die NICHT repariert werden dürfen
$Protected = @(
    "C:\Windows",
    "C:\Program Files",
    "C:\Program Files (x86)",
    "C:\ProgramData",
    "C:\Users\Default",
    "C:\Users\All Users",
    "C:\Recovery",
    "C:\$Recycle.Bin",
    "C:\System Volume Information"
)

function Write-Log {
    param([string]$Message)
    Add-Content -LiteralPath $LogFile -Value $Message
    Write-Host $Message
}

function Is-ProtectedPath {
    param([string]$Path)

    foreach ($p in $Protected) {
        if ($Path.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Fix-Acl {
    param([string]$Folder)

    if (-not (Test-Path -LiteralPath $Folder)) {
        Write-Log ("SKIP (not found): {0}" -f $Folder)
        return
    }

    if (Is-ProtectedPath -Path $Folder) {
        Write-Log ("SKIP (protected): {0}" -f $Folder)
        return
    }

    Write-Log ("FIXING: {0}" -f $Folder)

    # Owner übernehmen
    takeown /f "$Folder" /r /d y 2>$null | Out-Null

    # Vollzugriff für aktuellen Benutzer
    icacls "$Folder" /grant:r $env:USERNAME`:F /t 2>$null | Out-Null

    # SYSTEM + Administrators wiederherstellen
    icacls "$Folder" /grant:r SYSTEM`:F /t 2>$null | Out-Null
    icacls "$Folder" /grant:r Administrators`:F /t 2>$null | Out-Null

    # Vererbung aktivieren
    icacls "$Folder" /inheritance:e 2>$null | Out-Null

    Write-Log ("DONE: {0}" -f $Folder)
}

# Start
Write-Host "ACL-Fix gestartet."
Write-Host ("CSV: {0}" -f $CsvFile)
Write-Host ("Logfile: {0}" -f $LogFile)

$folders = Get-Content -LiteralPath $CsvFile

foreach ($folder in $folders) {
    Fix-Acl -Folder $folder
}

Write-Host "=============================="
Write-Host "ACL-Fix abgeschlossen."
Write-Host ("Logfile: {0}" -f $LogFile)
Write-Host "=============================="
