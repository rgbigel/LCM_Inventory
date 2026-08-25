[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('v')]
    [string]$VolumeList,

    [Alias('n')]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$MaxItems = 0,

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
        [string[]]$ForwardArgs
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
    Write-Host '[X] ACL-Check requires elevation. Re-launching as Administrator in PowerShell 7...'
    $forwardArgs = @('-v', $VolumeList)
    if ($MaxItems -gt 0) {
        $forwardArgs += @('-n', $MaxItems)
    }
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
# ACL-Check 2.2 – Kompakte Ausgabe + CSV
# ============================================

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputDirectory = 'C:\Temp\ACL-Fixes'
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path -Path $outputDirectory -ChildPath "ACL_Check_$timestamp.log"
$CsvFile = Join-Path -Path $outputDirectory -ChildPath "ACL_Check_$timestamp.csv"

$script:TotalChecked = 0
$script:TotalErrors = 0
$script:TotalVerifyFailures = 0
$script:TotalReadProbeFailures = 0
$script:CurrentChecked = 0
$script:CurrentErrors = 0
$script:CurrentVerifyFailures = 0
$script:CurrentReadProbeFailures = 0
$script:StopRequested = $false

# HashSet für Problemordner
$ProblemFolders = New-Object System.Collections.Generic.HashSet[string]

function Log-ProblemFolder {
    param([string]$Path)

    # Korrigiert: Split-Path nur mit -Path
    $folder = Split-Path -Path $Path -Parent

    if (-not $ProblemFolders.Contains($folder)) {
        $ProblemFolders.Add($folder) | Out-Null
        Add-Content -LiteralPath $LogFile -Value $folder
        Write-Host $folder
    }
}

function Write-AclDiagnostic {
    param(
        [string]$Path,
        [string]$Reason,
        [string]$ExceptionMessage
    )

    Add-Content -LiteralPath $LogFile -Value '--- ACL DIAGNOSTIC ---'
    Add-Content -LiteralPath $LogFile -Value ("Path: {0}" -f $Path)
    Add-Content -LiteralPath $LogFile -Value ("Reason: {0}" -f $Reason)

    if (-not [string]::IsNullOrWhiteSpace($ExceptionMessage)) {
        Add-Content -LiteralPath $LogFile -Value ("Exception: {0}" -f $ExceptionMessage)
    }

    $aclOutput = icacls $Path 2>&1 | Out-String
    Add-Content -LiteralPath $LogFile -Value 'icacls output:'
    Add-Content -LiteralPath $LogFile -Value $aclOutput.TrimEnd()
    Add-Content -LiteralPath $LogFile -Value '----------------------'
}

function Test-FileReadable {
    param([string]$Path)

    $stream = $null
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $buffer = New-Object byte[] 1024
        $null = $stream.Read($buffer, 0, $buffer.Length)
        return $null
    }
    catch {
        return $_.Exception.Message
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}

function Test-PathAccess {
    param([System.IO.FileSystemInfo]$Item)

    $Path = $Item.FullName

    $script:TotalChecked++
    $script:CurrentChecked++

    # 1) ACL-Integrität prüfen
    icacls $Path /verify 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $script:TotalErrors++
        $script:TotalVerifyFailures++
        $script:CurrentErrors++
        $script:CurrentVerifyFailures++
        Log-ProblemFolder -Path $Path
        Write-AclDiagnostic -Path $Path -Reason 'ACL verify failed' -ExceptionMessage $null
        return
    }

    # 2) Real read test for files (open and read up to 1 KB)
    if (-not $Item.PSIsContainer) {
        $readFailure = Test-FileReadable -Path $Path
        if ($null -ne $readFailure) {
            $script:TotalErrors++
            $script:TotalReadProbeFailures++
            $script:CurrentErrors++
            $script:CurrentReadProbeFailures++
            Log-ProblemFolder -Path $Path
            Write-AclDiagnostic -Path $Path -Reason 'File open/read failed (1 KB probe)' -ExceptionMessage $readFailure
            return
        }
    }
}

function Scan-Volume {
    param([string]$Root)

    Write-Host ("Scanning {0} ..." -f $Root)

    $index = 0
    $hadItems = $false

    foreach ($item in (Get-ChildItem -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue)) {
        if ($MaxItems -gt 0 -and $script:TotalChecked -ge $MaxItems) {
            $script:StopRequested = $true
            break
        }

        $hadItems = $true
        $index++

        Write-Progress -Activity ("Scanning {0}" -f $Root) `
                       -Status ("Checked in root: {0}" -f $index)

        Test-PathAccess -Item $item
    }

    if (-not $hadItems) {
        Write-Host ("No items found under {0}" -f $Root)
    }

    Write-Progress -Activity ("Scanning {0}" -f $Root) -Completed
}

function Write-FinalSummary {
    Write-Host "=============================="
    if ($MaxItems -gt 0) {
        Write-Host "partial Summary"
    }
    else {
        Write-Host "over-all Summary"
    }
    Write-Host ("Total Checked: {0}" -f $script:TotalChecked)
    Write-Host ("Total Errors:  {0}" -f $script:TotalErrors)
    Write-Host ("Verify Failures: {0}" -f $script:TotalVerifyFailures)
    Write-Host ("Read Probe Failures: {0}" -f $script:TotalReadProbeFailures)
    Write-Host ("Problem Folders: {0}" -f $ProblemFolders.Count)
    if ($MaxItems -gt 0) {
        Write-Host ("Limiter:       {0}" -f $MaxItems)
    }
    Write-Host ("Logfile:       {0}" -f $LogFile)
    Write-Host ("CSV:           {0}" -f $CsvFile)
    Write-Host "=============================="
}

# Parse and validate comma-separated paths from -v / -VolumeList
$scanRoots = $VolumeList -split ',' |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

if (@($scanRoots).Count -eq 0) {
    if ($MaxItems -gt 0) {
        Write-Warning 'No valid paths were provided via -v. A partial summary will still be produced.'
    }
    else {
        throw 'No valid paths were provided via -v. Example: -v "D:\OneDrive,A:"'
    }
}

try {
    # Start
    Write-Host "ACL-Check gestartet."
    Write-Host ("Logfile: {0}" -f $LogFile)
    Write-TraceMessage -Message ('Trace mode enabled. VolumeList={0}' -f $VolumeList)
    if ($MaxItems -gt 0) {
        Write-Host ("Limiter active: stopping after {0} checked items." -f $MaxItems)
    }

    foreach ($root in $scanRoots) {
        if ($script:StopRequested) {
            break
        }

        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            Write-Warning ("Skipping invalid or inaccessible path: {0}" -f $root)
            continue
        }

        $script:CurrentChecked = 0
        $script:CurrentErrors = 0
        $script:CurrentVerifyFailures = 0
        $script:CurrentReadProbeFailures = 0
        $rootProblemBefore = $ProblemFolders.Count

        Scan-Volume -Root $root
        Write-TraceMessage -Message ('Completed root scan: {0}' -f $root)

        $rootProblemCount = $ProblemFolders.Count - $rootProblemBefore
        Write-Host "------------------------------"
        Write-Host ("Root Summary: {0}" -f $root)
        Write-Host ("Checked: {0}" -f $script:CurrentChecked)
        Write-Host ("Errors:  {0}" -f $script:CurrentErrors)
        Write-Host ("Verify Failures: {0}" -f $script:CurrentVerifyFailures)
        Write-Host ("Read Probe Failures: {0}" -f $script:CurrentReadProbeFailures)
        Write-Host ("Problem Folders: {0}" -f $rootProblemCount)
        Write-Host "------------------------------"

        if ($script:StopRequested) {
            Write-Host ("Limiter reached after {0} checked items. Stopping remaining roots." -f $script:TotalChecked)
        }
    }

    # CSV schreiben
    $ProblemFolders | Sort-Object | ForEach-Object {
        Add-Content -LiteralPath $CsvFile -Value $_
    }
}
catch {
    Write-Warning ("ACL-Check encountered an error: {0}" -f $_.Exception.Message)
}
finally {
    Write-FinalSummary
}
