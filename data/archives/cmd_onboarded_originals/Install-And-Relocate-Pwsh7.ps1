# ------------------------------------------------------------
# Install-And-Relocate-Pwsh7.ps1 (korrigiert)
# Installiert PowerShell 7 MSI, verschiebt es nach D:\Tools,
# setzt Junction in Program Files und prüft PATH + Version.
# ------------------------------------------------------------

$msiUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.6.1-win-x64.msi"
$msiFile = "$env:TEMP\pwsh7.msi"

$targetDir = "D:\Tools\PowerShell7"
$junctionDir = "C:\Program Files\PowerShell\7"

Write-Host "=== PowerShell 7 Automations-Setup ==="

# 1) Prüfen, ob MSI-Version bereits installiert oder verschoben ist
if (Test-Path $junctionDir -or Test-Path $targetDir) {
    Write-Host "PowerShell 7 scheint bereits installiert oder verschoben zu sein."
} else {
    Write-Host "Lade PowerShell 7 MSI herunter..."
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiFile

    Write-Host "Installiere PowerShell 7 MSI..."
    Start-Process msiexec.exe -ArgumentList "/i `"$msiFile`" /quiet /norestart" -Wait
}

# 2) Standardpfad prüfen
$defaultInstall = "C:\Program Files\PowerShell\7"

if (-not (Test-Path $defaultInstall)) {
    Write-Host "Standardpfad nicht gefunden, prüfe alternative Version..."
    if (-not (Test-Path $targetDir)) {
        Write-Host "Fehler: MSI-Installation scheint fehlgeschlagen zu sein."
        exit 1
    }
}

# 3) Verschieben nach D:\Tools
if (-not (Test-Path $targetDir)) {
    Write-Host "Verschiebe PowerShell 7 nach $targetDir ..."
    Move-Item $defaultInstall $targetDir
}

# 4) Junction neu erstellen
if (Test-Path $junctionDir) {
    Write-Host "Lösche alte Junction..."
    Remove-Item $junctionDir -Force
}

Write-Host "Erstelle Junction..."
cmd /c mklink /J "$junctionDir" "$targetDir" | Out-Null

# 5) PATH prüfen
$pwshPath = $junctionDir
$envPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($envPath -notlike "*$pwshPath*") {
    Write-Host "Füge PowerShell 7 zum PATH hinzu..."
    $newPath = $envPath + ";" + $pwshPath
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
}

# 6) Versionstest
Write-Host "Starte pwsh Versionstest..."
$version = & "$pwshPath\pwsh.exe" -NoLogo -Command '$PSVersionTable.PSVersion.ToString()'
Write-Host "PowerShell 7 Version: $version"

Write-Host "=== Fertig! ==="
