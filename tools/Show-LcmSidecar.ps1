<#
.SYNOPSIS
  Renders and launches the interactive LCM Sidecar & Command Selector webview.

.DESCRIPTION
  Builds the single-page LCM Sidecar companion dashboard (Option B: Right-half / standalone app window)
  with live Command Selector, Proposal Actions ribbon, BroadcastChannel sync,
  and REST daemon execution.

.PARAMETER Window
  Launches the Sidecar as a dedicated, standalone application window via Edge App mode (default).

.PARAMETER Tab
  Opens the Sidecar as a regular browser tab in the default browser.

.PARAMETER InEditor
  Opens the rendered Sidecar inside an Antigravity IDE editor tab.

.PARAMETER NoLaunch
  Compiles the HTML dashboard without launching it on the desktop.

.PARAMETER Help
  Displays cmdlet usage help per RULE-PS-010.

.EXAMPLE
  pwsh tools/Show-LcmSidecar.ps1
  pwsh tools/Show-LcmSidecar.ps1 -Tab
  pwsh tools/Show-LcmSidecar.ps1 -NoLaunch
#>
[CmdletBinding()]
param(
    [switch]$Window,
    [switch]$Tab,
    [switch]$InEditor,
    [switch]$NoLaunch,
    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "7.2.0"
$scriptName = "Show-LcmSidecar"

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM SIDECAR & COMMAND SELECTOR LAUNCHER (v$scriptVersion)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Renders and opens the LCM Sidecar & Command Selector companion dashboard."
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Show-LcmSidecar.ps1 [-Window] [-Tab] [-InEditor] [-NoLaunch] [-h]"
    Write-Host "MODES:" -ForegroundColor Yellow
    Write-Host "  (default) / -Window : Opens as a standalone app window (chromeless Edge App mode)."
    Write-Host "  -Tab                : Opens as a normal tab in your default browser."
    Write-Host "  -InEditor           : Opens inside Antigravity IDE editor."
    return
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
    $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$proposalsFile = Join-Path $workspaceRoot "LCM_Inventory\data\proposals\proposals.json"
$htmlTemplateFile = Join-Path $workspaceRoot "LCM_Inventory\assets\LCM_SIDECAR.html"

if (-not (Test-Path -LiteralPath $proposalsFile)) {
    throw "Proposals ledger not found at: $proposalsFile"
}
if (-not (Test-Path -LiteralPath $htmlTemplateFile)) {
    throw "LCM Sidecar HTML template not found at: $htmlTemplateFile"
}

$proposalsRaw = Get-Content -LiteralPath $proposalsFile -Raw -Encoding UTF8
$htmlContent = Get-Content -LiteralPath $htmlTemplateFile -Raw -Encoding UTF8

$injectedBlock = "const RAW_PROPOSALS = $proposalsRaw;"
$htmlContent = $htmlContent.Replace('/*__INJECTED_DATA_PLACEHOLDER__*/', $injectedBlock)

$artifactsDir = Join-Path $workspaceRoot "LCM_Inventory\data\artifacts"
if (-not (Test-Path -LiteralPath $artifactsDir)) {
    New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
}

$renderedPath = Join-Path $artifactsDir "LCM_SIDECAR.html"
Set-Content -LiteralPath $renderedPath -Value $htmlContent -Encoding UTF8

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM SIDECAR & COMMAND SELECTOR COMPILED" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Dashboard : $renderedPath"
Write-Host " Ledger    : $proposalsFile"

if (-not $NoLaunch) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    $fileUri = [System.Uri]::new($renderedPath).AbsoluteUri

    if ($InEditor) {
        $ideCmd = "D:\Tools\Antigravity IDE\bin\antigravity-ide.cmd"
        if (Test-Path -LiteralPath $ideCmd) {
            Write-Host "  -> Opening Sidecar in Antigravity IDE editor tab..." -ForegroundColor Cyan
            & $ideCmd -r "$renderedPath"
            return
        }
    }

    if ($Tab) {
        Write-Host "  -> Opening Sidecar as a browser tab..." -ForegroundColor Cyan
        $dispatcher = Join-Path $workspaceRoot ".lcm\tools\internal\Invoke-InteractiveDesktop.ps1"
        if (Test-Path -LiteralPath $dispatcher) {
            & $dispatcher -FilePath $fileUri
        } else {
            Start-Process -FilePath $fileUri
        }
        return
    }

    # --------------------------------------------------------------------------
    # Dynamic User Default Browser Discovery (Windows Registry UserChoice)
    # --------------------------------------------------------------------------
    $browserPath = $null
    $browserName = "unknown"
    try {
        $progId = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" -ErrorAction Stop).ProgId
        $cmd = (Get-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\$progId\shell\open\command" -ErrorAction Stop).'(Default)'
        if ($cmd -match '"([^"]+\.exe)"') { $browserPath = $Matches[1] }
        elseif ($cmd -match '^\s*([^\s]+\.exe)') { $browserPath = $Matches[1] }
        if ($browserPath) {
            $browserName = [System.IO.Path]::GetFileNameWithoutExtension($browserPath).ToLowerInvariant()
        }
    } catch {}

    # Secondary fallback to known paths
    if (-not $browserPath -or -not (Test-Path -LiteralPath $browserPath)) {
        $zenPath = "D:\Tools\Zen Browser\zen.exe"
        if (Test-Path -LiteralPath $zenPath) {
            $browserPath = $zenPath
            $browserName = "zen"
        } else {
            $firefoxCandidates = @(
                "C:\Program Files\Mozilla Firefox\firefox.exe",
                "C:\Program Files (x86)\Mozilla Firefox\firefox.exe"
            )
            foreach ($cand in $firefoxCandidates) {
                if (Test-Path -LiteralPath $cand) { $browserPath = $cand; $browserName = "firefox"; break }
            }
        }
    }

    $dispatcher = Join-Path $workspaceRoot ".lcm\tools\internal\Invoke-InteractiveDesktop.ps1"

    if ($browserPath -and (Test-Path -LiteralPath $browserPath)) {
        Write-Host "  -> Opening Sidecar in $browserName tab..." -ForegroundColor Green
        $tabArg = if ($browserName -in @('zen', 'firefox')) { "--new-tab `"$fileUri`"" } else { "`"$fileUri`"" }
        if (Test-Path -LiteralPath $dispatcher) {
            & $dispatcher -FilePath $browserPath -ArgumentList $tabArg
        } else {
            Start-Process -FilePath $browserPath -ArgumentList $tabArg
        }
    } else {
        Write-Host "  -> Dispatching Sidecar via default browser..." -ForegroundColor Cyan
        if (Test-Path -LiteralPath $dispatcher) {
            & $dispatcher -FilePath $fileUri
        } else {
            Start-Process -FilePath $fileUri
        }
    }
} else {
    Write-Host " Dashboard rendered cleanly (launch suppressed via -NoLaunch)." -ForegroundColor DarkGray
    Write-Host "==========================================================================" -ForegroundColor Cyan
}
