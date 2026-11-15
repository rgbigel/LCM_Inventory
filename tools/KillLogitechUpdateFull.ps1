# Module: KillLogitechUpdateFull.ps1
# Purpose: Disable Logitech auto-update and remove HID overlay components
# Path: D:\OneDrive\cmd\KillLogitechUpdateFull.ps1
# Authors: Rolf + Copilot + Antigravity
# Version: 2.6.2
# Date: 2026-08-23
# Changelog:
#   - Added DLL removal
#   - Added HID filter removal
#   - Added Options+ update trigger suppression
#   - Added Logi Options+ 2.6.x services, processes, directories, Run keys, and Flow suppression
#   - Added granular path reporting for missing items and specific exception diagnostics for permission/authority errors

# Helper function to set registry DWORD with full diagnostic reporting
function Set-RegDwordSafe {
    param (
        [string]$Path,
        [string]$Name,
        [int]$Value
    )
    try {
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        Write-Host "[SET] $Path\$Name = $Value" -ForegroundColor Green
    } catch {
        Write-Warning "[ERROR] Cannot set '$Name' in '$Path': $($_.Exception.Message)"
    }
}

# Stop and disable Logitech Windows Services
$services = @(
    "OptionsPlusUpdaterService",
    "LogiOptionsPlusService",
    "LGHUBUpdaterService",
    "logi_lamparray_service"
)

foreach ($s in $services) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($null -ne $svc) {
        try {
            Stop-Service -Name $s -Force -ErrorAction Stop
            Set-Service -Name $s -StartupType Disabled -ErrorAction Stop
            Write-Host "[DISABLED] Service '$s'" -ForegroundColor Green
        } catch {
            Write-Warning "[ERROR] Service '$s': $($_.Exception.Message)"
        }
    } else {
        Write-Host "[NOT FOUND] Service '$s' (skipped)" -ForegroundColor DarkGray
    }
}

# Kill running Logitech processes
$procs = @(
    "LogiOverlay",
    "LogiOptionsPlus",
    "LogiOptionsPlusAgent",
    "LogiOptionsPlusService",
    "LGHUBUpdaterService",
    "LogiLDA",
    "logioptionsplus_agent",
    "logioptionsplus_appbroker",
    "logioptionsplus_updater",
    "logioptionsplus",
    "logi_download_assistant",
    "logi_crashpad_handler",
    "PlugInInstallerUtility",
    "PlugInInstallerUtility2"
)

foreach ($p in $procs) {
    $running = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($null -ne $running) {
        try {
            $running | Stop-Process -Force -ErrorAction Stop
            Write-Host "[TERMINATED] Process '$p'" -ForegroundColor Green
        } catch {
            Write-Warning "[ERROR] Process '$p': $($_.Exception.Message)"
        }
    } else {
        Write-Host "[NOT RUNNING] Process '$p' (skipped)" -ForegroundColor DarkGray
    }
}

# Remove HID overlay driver (Caps-Lock corruption source) & Windows Update Co-Installer DLLs
$hidPaths = @(
    "C:\Windows\System32\drivers\LogiHidFilter.sys",
    "C:\Windows\System32\LogiOverlay.dll",
    "C:\Windows\System32\LogiLDA.DLL",
    "C:\Windows\SysWOW64\LogiLDA.DLL",
    "C:\Program Files\Logitech\LogiOverlay\LogiOverlay.dll",
    "C:\Program Files\Logitech\LogiOverlay\LogiHidFilter.sys"
)

foreach ($f in $hidPaths) {
    if (Test-Path -LiteralPath $f) {
        try {
            Remove-Item -LiteralPath $f -Force -ErrorAction Stop
            Write-Host "[REMOVED] File: $f" -ForegroundColor Green
        } catch {
            Write-Warning "[ERROR] File '$f': $($_.Exception.Message)"
        }
    } else {
        Write-Host "[NOT FOUND] File '$f' (skipped)" -ForegroundColor DarkGray
    }
}

# Remove Logitech auto-update DLLs & Modern Installation / Flow directories
$updateDlls = @(
    "C:\Program Files\Logitech\LogiOptionsPlus\Updater.dll",
    "C:\Program Files\Logitech\LogiOptionsPlus\UpdateService.dll",
    "C:\Program Files\Logitech\LogiOptionsPlus\LogiLDA.dll",
    "C:\Program Files\LogiOptionsPlus",
    "C:\Program Files\LogiDownloadAssistant",
    "C:\Program Files\Logi",
    "C:\ProgramData\LogiOptionsPlus",
    "C:\ProgramData\Logi",
    "C:\ProgramData\Logishrd",
    "$env:LOCALAPPDATA\LogiOptionsPlus\flow"
)

foreach ($f in $updateDlls) {
    if (Test-Path -LiteralPath $f) {
        try {
            Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction Stop
            Write-Host "[REMOVED] Directory/File: $f" -ForegroundColor Green
        } catch {
            Write-Warning "[ERROR] Path '$f': $($_.Exception.Message)"
        }
    } else {
        Write-Host "[NOT FOUND] Path '$f' (skipped)" -ForegroundColor DarkGray
    }
}

# Disable Logitech scheduled tasks
$logiTasks = @(
    "\Logitech\LogiLDA",
    "\Logitech\LogiOptionsPlusUpdate",
    "\Logitech\LogiOptionsPlusMaintenance"
)

foreach ($t in $logiTasks) {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($null -ne $task) {
        try {
            Disable-ScheduledTask -TaskName $t -ErrorAction Stop | Out-Null
            Write-Host "[DISABLED] Scheduled Task '$t'" -ForegroundColor Green
        } catch {
            Write-Warning "[ERROR] Scheduled Task '$t': $($_.Exception.Message)"
        }
    } else {
        Write-Host "[NOT FOUND] Scheduled Task '$t' (skipped)" -ForegroundColor DarkGray
    }
}

# Remove Logitech Run entries with explicit path and value validation
$runEntries = @(
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Name = "Logitech Download Assistant" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Name = "Logitech Download Assistant" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Name = "Logi Download Assistant" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Name = "Logi Download Assistant" },
    @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; Name = "Logi Download Assistant" },
    @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; Name = "Logitech Download Assistant" }
)

foreach ($entry in $runEntries) {
    if (!(Test-Path $entry.Path)) {
        Write-Host "[NOT FOUND] Registry Key '$($entry.Path)' (skipped)" -ForegroundColor DarkGray
        continue
    }
    try {
        $item = Get-ItemProperty -Path $entry.Path -ErrorAction Stop
        if ($null -ne $item.PSObject.Properties[$entry.Name]) {
            Remove-ItemProperty -Path $entry.Path -Name $entry.Name -Force -ErrorAction Stop
            Write-Host "[REMOVED] Value '$($entry.Name)' from $($entry.Path)" -ForegroundColor Green
        } else {
            Write-Host "[NOT FOUND] Value '$($entry.Name)' in $($entry.Path) (skipped)" -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning "[ERROR] Value '$($entry.Name)' in $($entry.Path): $($_.Exception.Message)"
    }
}

# Disable Options+ internal update flags
Set-RegDwordSafe -Path "HKCU:\Software\Logitech\LogiOptionsPlus" -Name "DisableAutoUpdate" -Value 1
Set-RegDwordSafe -Path "HKCU:\Software\Logitech\LogiOptionsPlus" -Name "DisableUpdateCheck" -Value 1

# Disable Flow (Mouse Edge Jumping) & Telemetry
Set-RegDwordSafe -Path "HKLM:\SOFTWARE\Logitech\LogiOptionsPlus" -Name "DisableFlow" -Value 1
Set-RegDwordSafe -Path "HKCU:\Software\Logitech\LogiOptionsPlus" -Name "DisableFlow" -Value 1
Set-RegDwordSafe -Path "HKCU:\Software\Logitech\LogiOptionsPlus" -Name "DisableAnalytics" -Value 1
Set-RegDwordSafe -Path "HKCU:\Software\Logitech\LogiOptionsPlus" -Name "AnalyticsEnabled" -Value 0
Set-RegDwordSafe -Path "HKCU:\Software\Logi\DownloadAssistant" -Name "Disabled" -Value 1
Set-RegDwordSafe -Path "HKCU:\Software\LogiShrd\DownloadAssistant" -Name "Disabled" -Value 1
Set-RegDwordSafe -Path "HKLM:\SOFTWARE\Logishrd\DownloadAssistant" -Name "Protocol" -Value 0

# Remove Options+ update triggers
$updateKeys = @(
    "HKCU:\Software\Logitech\LogiOptionsPlus\Update",
    "HKLM:\SOFTWARE\Logitech\LogiOptionsPlus\Update"
)

foreach ($k in $updateKeys) {
    if (Test-Path $k) {
        try {
            Remove-Item -Path $k -Recurse -Force -ErrorAction Stop
            Write-Host "[REMOVED] Registry Key: $k" -ForegroundColor Green
        } catch {
            Write-Warning "[ERROR] Registry Key '$k': $($_.Exception.Message)"
        }
    } else {
        Write-Host "[NOT FOUND] Registry Key '$k' (skipped)" -ForegroundColor DarkGray
    }
}

Write-Host "`nLogitech auto-update and HID overlay components have been fully processed." -ForegroundColor Cyan
