# =================================================================================================
#  Module:      WebViewHostFix.ps1
#  Path:        .\Maintenance
#  Author:      Rolf Bercht
#  Version:     1.3.0
#  Changelog:
#      1.000  --------  Initial module creation for WebViewHost restart-loop repair
#      1.100  --------  Strict-Mode cleanup, removed $_ from all strings
#      1.200  --------  Parser-safe strings, no variable before colon
#      1.300  --------  Added deterministic wait-loop for folder creation
# =================================================================================================

<#
.SYNOPSIS
    Repariert WebViewHost.exe Restart-Loops nach System Restore.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info { Write-Host "[INFO ] $args" -ForegroundColor Cyan }
function Write-OK   { Write-Host "[ OK  ] $args"   -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN ] $args"  -ForegroundColor Yellow }
function Write-Err  { Write-Host "[FAIL ] $args"  -ForegroundColor Red }

$PkgName   = "Microsoft.Win32WebViewHost_cw5n1h2txyewy"
$PkgPath   = Join-Path $env:LOCALAPPDATA "Packages\$PkgName"
$PkgBackup = "$PkgPath.BAK_$(Get-Date -Format yyyyMMdd_HHmmss)"

Write-Info "Pruefe AppData-Ordner..."

if (Test-Path $PkgPath) {
    Write-Info "Sichere defekten Ordner:"
    Write-Info "  $PkgBackup"

    try {
        Rename-Item -Path $PkgPath -NewName $PkgBackup
        Write-OK "Ordner gesichert."
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-Err ("Fehler beim Sichern des Ordners - " + $errMsg)
    }
}
else {
    Write-Warn "Ordner existiert nicht, vermutlich bereits geloescht."
}

Write-Info "Registriere WebViewHost-AppX neu..."

try {
    $pkg = Get-AppxPackage "Microsoft.Win32WebViewHost"

    if (-not $pkg) {
        Write-Err "AppX-Paket nicht gefunden. System beschaedigt."
    }
    else {
        Add-AppxPackage -DisableDevelopmentMode -Register "$($pkg.InstallLocation)\AppXManifest.xml"
        Write-OK "AppX erfolgreich registriert."
    }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Err ("Fehler bei Add-AppxPackage - " + $errMsg)
}

# -------------------------------------------------------------------------------------------------
# WAIT LOOP: Warten, bis Windows den Ordner neu erzeugt
# -------------------------------------------------------------------------------------------------

Write-Info "Warte auf Neuerstellung des WebViewHost-Ordners..."

$MaxWaitSeconds = 20
$Waited = 0

while (-not (Test-Path $PkgPath) -and $Waited -lt $MaxWaitSeconds) {
    Start-Sleep -Seconds 1
    $Waited = $Waited + 1
}

if (-not (Test-Path $PkgPath)) {
    Write-Warn "Ordner wurde nicht automatisch erzeugt. ACLs werden uebersprungen."
}
else {
    Write-OK ("Ordner gefunden nach " + $Waited + " Sekunden.")
    Write-Info "Setze Berechtigungen fuer ALL APPLICATION PACKAGES..."

    try {
        $acl  = Get-Acl $PkgPath
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "ALL APPLICATION PACKAGES",
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )

        $acl.SetAccessRule($rule)
        Set-Acl -Path $PkgPath -AclObject $acl

        Write-OK "Berechtigungen gesetzt."
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-Err ("Fehler beim Setzen der ACL - " + $errMsg)
    }
}

# -------------------------------------------------------------------------------------------------
# WebView2 GUID Check
# -------------------------------------------------------------------------------------------------

$WebView2GUID = "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"

$RegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$WebView2GUID",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$WebView2GUID",
    "HKCU:\Software\Microsoft\EdgeUpdate\Clients\$WebView2GUID"
)

Write-Info "Pruefe WebView2 Runtime-Registrierung..."

$found = @()

foreach ($p in $RegPaths) {
    if (Test-Path $p) {
        Write-Warn ("Gefunden - " + $p)
        $found += $p
    }
}

if ($found.Count -eq 0) {
    Write-OK "Keine defekten WebView2-GUIDs gefunden."
}
else {
    Write-Warn "Defekte WebView2-Eintraege erkannt."
    $choice = Read-Host "Soll ich diese GUIDs loeschen? (j/n)"

    if ($choice -eq "j") {
        foreach ($p in $found) {
            try {
                Remove-Item -Path $p -Recurse -Force
                Write-OK ("Geloescht - " + $p)
            }
            catch {
                $errMsg = $_.Exception.Message
                Write-Err ("Fehler beim Loeschen von " + $p + " - " + $errMsg)
            }
        }
    }
    else {
        Write-Warn "GUIDs wurden NICHT geloescht."
    }
}

Write-OK "Fertig. Starte Windows neu, wenn WebViewHost weiterhin crasht."
