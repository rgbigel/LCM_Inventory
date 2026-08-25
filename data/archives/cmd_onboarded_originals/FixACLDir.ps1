param(
    [Parameter(Position = 0)]
    [Alias('Fix_Root')]
    [string]$Path = 'D:\',
    [Alias('ForceDelete')]
    [switch]$f,
    [Alias('Trace')]
    [switch]$t
)

<#
===============================================================
Module:      FixACLDir.ps1
Purpose:     Apply Secure ACLs using inheritance (Authenticated Users only).
             Optional: -f deletes all content inside the REAL Recycle Bin.
Path:        D:\OneDrive\cmd\FixACLDir.ps1
Authors:     Rolf + Copilot
Version:     3.1.1
Changelog:
    3.1.1    Added AppX package guard under WindowsApps so leaf Store packages
             are not ACL-rewritten while still allowing operation on D:\.
    3.1.0    Elevates before target access checks so inaccessible paths can be
             repaired instead of failing early while non-elevated. Renamed the
             internal target variable to Fix_Root. Delete failures are reported.
    3.0.0    Converted from the FixACLDir.cmd cmd+pwsh hybrid to a single,
             clean pwsh script with trace logging, robust icacls exit-code
             checks, pwsh self-elevation, drive-root-safe icacls paths, and
             REAL Recycle Bin-only force deletion.
===============================================================
#>

$ErrorActionPreference = 'Stop'

function Write-TraceLine {
    param([string]$Message)
    if ($t) { Write-Host "TRACE: $Message" }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Icacls {
    param(
        [string]$TargetPath,
        [string[]]$Arguments
    )

    $safePath = $TargetPath
    if ($safePath.EndsWith('\', [StringComparison]::Ordinal)) { $safePath = "$safePath." }

    & icacls.exe $safePath @Arguments | ForEach-Object { Write-Host $_ }
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "icacls failed with exit code $exitCode for $TargetPath."
    }
}

try {
    $RawTarget = $Path
    if ([string]::IsNullOrWhiteSpace($RawTarget)) { $RawTarget = 'D:\' }

    if ($RawTarget -notmatch '^[A-Za-z]:\\') {
        $RawTarget = Join-Path (Get-Location) $RawTarget
    }

    $Fix_Root = [IO.Path]::GetFullPath($RawTarget)
    if ($Fix_Root.Length -eq 2 -and $Fix_Root[1] -eq ':') { $Fix_Root = "$Fix_Root\" }

    $DriveRoot = [IO.Path]::GetPathRoot($Fix_Root)

    if ($Fix_Root -like '*$Recycle.bin*') {
        $Fix_Root = Join-Path $DriveRoot '$Recycle.bin'
    }

    Write-TraceLine "Target path after normalization: $Fix_Root"

    if (-not (Test-IsAdministrator)) {
        Write-Host "You are NOT Authorized. Are you ABSOLUTELY Certain?"
        $confirm = Read-Host "Enter Y or YES to continue"
        if ($confirm -notin @('Y', 'YES')) {
            throw "Confirmation failed."
        }

        Write-TraceLine "Relaunching elevated via pwsh for $Fix_Root"
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Path', "`"$Fix_Root`"")
        if ($f) { $arguments += '-f' }
        if ($t) { $arguments += '-t' }

        try {
            $process = Start-Process -FilePath 'pwsh' -ArgumentList $arguments -Verb RunAs -Wait -PassThru -ErrorAction Stop
            if ($null -ne $process.ExitCode) { exit $process.ExitCode }
            exit 0
        }
        catch {
            throw "Elevation failed or was cancelled. $($_.Exception.Message)"
        }
    }

    if (-not (Test-Path -LiteralPath $Fix_Root)) {
        throw "Target path does not exist: $Fix_Root"
    }

    if (Test-Path -LiteralPath (Join-Path $Fix_Root 'Windows')) {
        throw "Windows folder detected at $(Join-Path $Fix_Root 'Windows')"
    }

    # AppX package guard under WindowsApps: block only leaf Store packages
    $windowsAppsRoot = Join-Path $DriveRoot 'WindowsApps'
    if ($Fix_Root.StartsWith($windowsAppsRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $relativeWa = $Fix_Root.Substring($windowsAppsRoot.Length).Trim('\')
        if ($relativeWa -match '^[^\\]+_[^\\]+_~_[^\\]+$') {
            throw "AppX package detected at $Fix_Root"
        }
    }

    $relative = $Fix_Root.Substring($DriveRoot.Length).Trim('\')
    $segments = @()
    if ($relative) { $segments = $relative -split '\\' }

    $current = $DriveRoot
    $ancestorList = @($current)
    foreach ($segment in $segments) {
        $current = Join-Path $current $segment
        $ancestorList += $current
    }

    foreach ($ancestorPath in $ancestorList) {
        $accessible = $true
        try {
            Get-ChildItem -LiteralPath $ancestorPath -Force -ErrorAction Stop | Out-Null
        }
        catch {
            $accessible = $false
        }

        if (-not $accessible) {
            Write-Host "Unlocking ACL for $ancestorPath"
            Invoke-Icacls -TargetPath $ancestorPath -Arguments @('/inheritance:e')
            Invoke-Icacls -TargetPath $ancestorPath -Arguments @('/grant:r', 'Authenticated Users:(RX)')
        }
    }

    if ($f) {
        $recycleBinPath = Join-Path $DriveRoot '$Recycle.bin'
        if ($Fix_Root -ieq $recycleBinPath) {
            Write-Host "FORCE DELETE MODE: Removing all content inside REAL Recycle Bin $Fix_Root"
            Get-ChildItem -LiteralPath $Fix_Root -Force -ErrorAction Stop | ForEach-Object {
                Write-Host "Deleting: $($_.FullName)"
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
            }
            Write-Host "All content inside $Fix_Root has been deleted."
        }
        else {
            Write-Host "-f ignored: $Fix_Root is NOT a REAL Recycle Bin."
        }
    }

    Write-Host "ACLs applied to $Fix_Root (inheritance enabled, will take long)"
    Invoke-Icacls -TargetPath $Fix_Root -Arguments @('/inheritance:e')

    Write-Host "$Fix_Root (Setting User Rights for Authenticated users)"
    Invoke-Icacls -TargetPath $Fix_Root -Arguments @('/grant:r', 'Authenticated Users:(OI)(CI)(F)')

    Write-Host "$Fix_Root (Removing Rights for plain Users and Everyone)"
    try { Invoke-Icacls -TargetPath $Fix_Root -Arguments @('/remove:g', 'Users') }
    catch { Write-Host "NOTE: Users group was not present or could not be removed on $Fix_Root." }
    try { Invoke-Icacls -TargetPath $Fix_Root -Arguments @('/remove:g', 'Everyone') }
    catch { Write-Host "NOTE: Everyone group was not present or could not be removed on $Fix_Root." }

    Write-Host "DONE: ACLs applied to $Fix_Root (inheritance enabled)."
    exit 0
}
catch {
    Write-Host "ABORT: $($_.Exception.Message)"
    exit 1
}
