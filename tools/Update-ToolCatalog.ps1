<#
.SYNOPSIS
  Scans and synchronizes all LCM Workspace & Subsystem tools into canonical catalog artifacts.
.DESCRIPTION
  Module: Update-ToolCatalog
  Purpose: Scans and synchronizes all LCM Workspace & Subsystem tools into a canonical JSON catalog
           (LCM_Inventory/config/tool_catalog.json), documentation index (LCM_Inventory/docs/README.md), and standardizes
           clean short-name command trampolines in LCM_Inventory/Cmd/ adhering to the 4-category taxonomy
           (Setters, Showers, Getters, Action Runners).
           Extracts AST dependencies, enforces ShortName uniqueness, and cleans legacy long .cmd files.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: D:\Git_Repositories\LCM_Inventory\tools\Update-ToolCatalog.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.1
  Date: 2026-10-21
.PARAMETER Silent
  Suppresses non-error terminal output (useful in automated pipelines).
.PARAMETER ShowAll
  Displays granular scan discovery logs for every inspected directory.
.PARAMETER LogFile
  Custom log file destination. Defaults to D:\Git_Repositories\LCM_Inventory\data\logs\lcm\Update-ToolCatalog-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Update-ToolCatalog.ps1 -h
.EXAMPLE
  pwsh tools/Update-ToolCatalog.ps1
.EXAMPLE
  pwsh tools/Update-ToolCatalog.ps1 -ShowAll
#>

[CmdletBinding()]
param(
  [switch]$Silent,
  [switch]$ShowAll,
  [string]$LogFile = "",
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.1"
$scriptName = "Update-ToolCatalog"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " TOOL CATALOG & SHORT-NAME SYNCHRONIZATION ENGINE (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Scans and synchronizes all LCM Workspace & Subsystem tools into"
  Write-Host "  LCM_Inventory/config/tool_catalog.json, LCM_Inventory/docs/README.md, and standardizes short-name"
  Write-Host "  command trampolines in LCM_Inventory/Cmd/ with AST dependency tracking."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Update-ToolCatalog.ps1 [-Silent] [-ShowAll] [-LogFile <path>] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Silent        : Suppresses interactive console status outputs."
  Write-Host "  -ShowAll       : Exposes verbose scan logs for each file and link target."
  Write-Host "  -LogFile <str> : Custom log file destination."
  Write-Host "  -h, -Help, -?  : Displays this comprehensive parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Update-ToolCatalog.ps1"
  Write-Host "  pwsh tools/Update-ToolCatalog.ps1 -ShowAll"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Initialize Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
$inventoryRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $inventoryRoot 'tools'
$cmdDir = Join-Path $inventoryRoot 'Cmd'
$logDir = Join-Path $inventoryRoot 'data\logs\lcm'
$configDir = Join-Path $inventoryRoot 'config'
$docsDir = Join-Path $inventoryRoot 'docs'

if (-not (Test-Path -Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path -Path $cmdDir)) { New-Item -Path $cmdDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path -Path $configDir)) { New-Item -Path $configDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path -Path $docsDir)) { New-Item -Path $docsDir -ItemType Directory -Force | Out-Null }

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $LogFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"
}
$script:ActiveLogFile = $LogFile
$script:ShowDetails = $ShowAll
$script:RepoElevationCache = @{}

function Write-ToolLog {
  param(
    [AllowEmptyString()]
    [string]$Message = "",
    [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "ACTION", "SUMMARY")]
    [string]$Level = "INFO",
    [switch]$ConsoleOnly,
    [switch]$LogOnly
  )

  $timeHeader = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  $formattedLog = "[$timeHeader] [$Level] $Message"

  if (-not $ConsoleOnly -and -not [string]::IsNullOrWhiteSpace($script:ActiveLogFile)) {
    try {
      $formattedLog | Out-File -FilePath $script:ActiveLogFile -Append -Encoding UTF8
    } catch {}
  }

  if (-not $LogOnly -and -not $Silent) {
    switch ($Level) {
      "WARN"    { Write-Warning $Message }
      "ERROR"   { Write-Error $Message }
      "DEBUG"   { if ($script:ShowDetails) { Write-Host "  [DEBUG] $Message" -ForegroundColor DarkGray } }
      "ACTION"  { Write-Host "  -> $Message" -ForegroundColor Green }
      "SUMMARY" { Write-Host $Message -ForegroundColor Cyan }
      default   { Write-Host $Message }
    }
  }
}

Write-ToolLog -Message "==========================================================================" -Level INFO
Write-ToolLog -Message " TOOL CATALOG SYNCHRONIZATION ENGINE (v$($scriptVersion))" -Level INFO
Write-ToolLog -Message " Workspace Root: $workspaceRoot" -Level INFO
Write-ToolLog -Message " Command Hub   : $cmdDir" -Level INFO
Write-ToolLog -Message " Audit Log     : $LogFile" -Level INFO
Write-ToolLog -Message "==========================================================================" -Level INFO

$catalogJsonPath = Join-Path $configDir 'tool_catalog.json'
$readmePath = Join-Path $docsDir 'README.md'

# ------------------------------------------------------------------------------
# 2. Authoritative Metadata Dictionary with Role, Audience, and Short-Names
# ------------------------------------------------------------------------------
$metadataOverrides = @{
  "LCM_Tools\tools\Sync-LCMResearchSnapshot.ps1" = @{
    ShortName   = "SyncLCMResearchSnapshot"
    Group       = "LCM_Tools"
    Domain      = "LCM_Tools"
    Audience    = "Developer"
    Role        = "Utility"
    NoExit      = $false
    Category    = "Research Snapshot"
    Description = "Mirrors selected LCM workspace research and governance files to a configured snapshot destination."
  }
  # System Invariants & Hardware Stability
  "Kill-LogitechUpdate.ps1" = @{
    ShortName   = "KillLogitech"
    Audience    = "User"
    Role        = "Invariants"
    Category    = "Hardware Stability"
    Description = "Enforces 54/54 Logitech updater suppressions across tasks, registry run keys, and services."
  }
  "Set-MouseFlickerInvariants.ps1" = @{
    ShortName   = "SetMouseFlicker"
    Audience    = "User"
    Role        = "Invariants"
    Category    = "Hardware Stability"
    Description = "Enforces AMD Radeon RX 580 ULPS disabled, DWM MPO OverlayTestMode=5, and PowerToys hook locks."
  }
  "Restore-SystemSettings.ps1" = @{
    ShortName   = "RestoreSystemSettings"
    Audience    = "User"
    Role        = "Invariants"
    Category    = "System Invariants"
    Description = "Authoritative LCM system restore tool restoring background services while enforcing anti-flicker invariants."
  }
  # Workspace Supervision Engine
  "Show-SupervisionHub.ps1" = @{
    ShortName   = "ShowSupervisionHub"
    Audience    = "User"
    Role        = "Visualization"
    Category    = "Supervision & Health"
    Description = "Renders and launches the interactive Workspace Supervision Hub dashboard on your desktop."
    Example     = 'pwsh -File "LCM_Supervision\tools\Show-SupervisionHub.ps1"'
  }
  "Manage-SupervisionTask.ps1" = @{
    ShortName   = "ManageSupervisionTask"
    Audience    = "User"
    Role        = "Management"
    Category    = "Supervision & Health"
    Description = "CM Task Controller to Start, Stop, Pause, Resume, Add, Delete, and Run supervision tasks."
    Example     = 'pwsh -File "LCM_Supervision\tools\Manage-SupervisionTask.ps1" -Action Get'
  }
  "Invoke-SupervisionRunner.ps1" = @{
    ShortName   = "InvokeSupervisionRunner"
    Audience    = "Developer"
    Role        = "Management"
    Category    = "Supervision & Health"
    Description = "Unified task dispatcher executing supervision cycles and logging observation telemetry."
    Example     = 'pwsh -File "LCM_Supervision\tools\Invoke-SupervisionRunner.ps1" -All'
  }
  # System Customizations (@00- to @21-)
  "@00-RegKeyDefaultTypeSet.cmd" = @{
    ShortName   = "RegKeyDefaultTypeSet"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "Registry Tweaks"
    Description = "Configures default registry key types, associations, and type safety flags."
    Example     = 'pwsh -File "SystemConfiguration\Source\@00-RegKeyDefaultTypeSet.cmd"'
  }
  "@00-Set_System_Font_Verdana-MedionPC.reg" = @{
    ShortName   = "SetSystemFontVerdanaMedion"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    Category    = "System Fonts"
    Description = "Sets system UI font to Verdana (Medion PC hardware profile)."
    Example     = 'reg import "SystemConfiguration\Source\@00-Set_System_Font_Verdana-MedionPC.reg"'
  }
  "@00-Set_System_Font_Verdana.reg" = @{
    ShortName   = "SetSystemFontVerdana"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    Category    = "System Fonts"
    Description = "Sets system UI font to Verdana across all Windows desktop interface elements."
    Example     = 'reg import "SystemConfiguration\Source\@00-Set_System_Font_Verdana.reg"'
  }
  "@00-Skip_TPM_Check_on_Dynamic_Update.cmd" = @{
    ShortName   = "SkipTpmCheckDynamicUpdate"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "System Setup"
    Description = "Applies bypass registry keys for TPM and CPU compatibility checks during dynamic updates."
    Example     = 'pwsh -File "SystemConfiguration\Source\@00-Skip_TPM_Check_on_Dynamic_Update.cmd"'
  }
  "@01-Use_GPEDIT.msc_to_disable_Encryption.txt" = @{
    ShortName   = "DisableEncryptionGuide"
    Audience    = "User"
    Role        = "Customization"
    Category    = "System Security"
    Description = "Reference guide and instructions for disabling BitLocker and drive encryption via Group Policy."
    Example     = 'notepad "SystemConfiguration\Source\@01-Use_GPEDIT.msc_to_disable_Encryption.txt"'
  }
  "@02-Set_the_date_and_time_format_(ADM_systemwide).ps1" = @{
    ShortName   = "SetDateTimeFormatAdm"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "Regional Settings"
    Description = "Configures ISO-standard date/time format (yyyy-MM-dd HH:mm:ss) system-wide across all user profiles."
    Example     = 'pwsh -File "SystemConfiguration\Source\@02-Set_the_date_and_time_format_(ADM_systemwide).ps1"'
  }
  "@03-Set_the_date_and_time_format_(HKCU_and_Current).reg" = @{
    ShortName   = "SetDateTimeFormatHkcu"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $false
    Category    = "Regional Settings"
    Description = "Applies ISO date/time format registry overrides for current user (HKCU)."
    Example     = 'reg import "SystemConfiguration\Source\@03-Set_the_date_and_time_format_(HKCU_and_Current).reg"'
  }
  "@04-Remove_Removable_Drive_Icon.reg" = @{
    ShortName   = "RemoveRemovableDriveIcon"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    Category    = "Explorer Tweaks"
    Description = "Removes redundant removable drive duplicate icons from Explorer navigation tree."
    Example     = 'reg import "SystemConfiguration\Source\@04-Remove_Removable_Drive_Icon.reg"'
  }
  "@05-Kill_Explorer_showing_friendly_names.reg" = @{
    ShortName   = "KillExplorerFriendlyNames"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    Category    = "Explorer Tweaks"
    Description = "Disables friendly dates and abstracted filenames in Windows Explorer for raw canonical names."
    Example     = 'reg import "SystemConfiguration\Source\@05-Kill_Explorer_showing_friendly_names.reg"'
  }
  "@06-Configure_Easy_Context_Menu.lnk" = @{
    ShortName   = "ConfigureEasyContextMenu"
    Audience    = "User"
    Role        = "Customization"
    Category    = "Context Menus"
    Description = "Shortcut launcher for Easy Context Menu configuration utility."
    Example     = 'start "SystemConfiguration\Source\@06-Configure_Easy_Context_Menu.lnk"'
  }
  "@07-Autorun_Entry_for_RenderLockScreen.cmd" = @{
    ShortName   = "AutorunRenderLockScreen"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "Desktop Personalization"
    Description = "Configures autorun startup registry entry for lock screen rendering runner."
    Example     = 'pwsh -File "SystemConfiguration\Source\@07-Autorun_Entry_for_RenderLockScreen.cmd"'
  }
  "@08-WinSetView.lnk" = @{
    ShortName   = "WinSetView"
    Audience    = "User"
    Role        = "Customization"
    Category    = "Explorer Tweaks"
    Description = "Shortcut launcher for WinSetView folder view preferences customizer."
    Example     = 'start "SystemConfiguration\Source\@08-WinSetView.lnk"'
  }
  "@09-Use_Stylefolder_for_Folder_Comments.txt" = @{
    ShortName   = "StylefolderCommentsGuide"
    Audience    = "User"
    Role        = "Customization"
    Category    = "Explorer Tweaks"
    Description = "Instruction guide for configuring desktop.ini folder comments via Stylefolder."
    Example     = 'notepad "SystemConfiguration\Source\@09-Use_Stylefolder_for_Folder_Comments.txt"'
  }
  "@10-More_Options_OFF.reg" = @{
    ShortName   = "MoreOptionsOff"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    Category    = "Context Menus"
    Description = "Disables Windows 11 'Show more options' collapsed context menu to restore classic full menu."
    Example     = 'reg import "SystemConfiguration\Source\@10-More_Options_OFF.reg"'
  }
  "@11-FileMenuTools.lnk" = @{
    ShortName   = "FileMenuTools"
    Audience    = "User"
    Role        = "Customization"
    Category    = "Context Menus"
    Description = "Shortcut launcher for FileMenuTools context menu extension."
    Example     = 'start "SystemConfiguration\Source\@11-FileMenuTools.lnk"'
  }
  "@12-Winaero_Tweaker.lnk" = @{
    ShortName   = "WinaeroTweaker"
    Audience    = "User"
    Role        = "Customization"
    Category    = "System Personalization"
    Description = "Shortcut launcher for Winaero Tweaker Windows customization suite."
    Example     = 'start "SystemConfiguration\Source\@12-Winaero_Tweaker.lnk"'
  }
  "@13-PowerToys.lnk" = @{
    ShortName   = "PowerToys"
    Audience    = "User"
    Role        = "Customization"
    Category    = "System Personalization"
    Description = "Shortcut launcher for Microsoft PowerToys suite."
    Example     = 'start "SystemConfiguration\Source\@13-PowerToys.lnk"'
  }
  "@14-SecureDesktopOff.ps1" = @{
    ShortName   = "SecureDesktopOff"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "Security Tweaks"
    Description = "Disables UAC secure desktop dimming switch (PromptOnSecureDesktop=0) for automation workflows."
    Example     = 'pwsh -File "SystemConfiguration\Source\@14-SecureDesktopOff.ps1"'
  }
  "@15-PS7AppKiller.ps1" = @{
    ShortName   = "PS7AppKiller"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "Process Management"
    Description = "Terminates lingering or frozen background PowerShell 7 host processes."
    Example     = 'pwsh -File "SystemConfiguration\Source\@15-PS7AppKiller.ps1"'
  }
  "@16-GoAdm_changer.ps1" = @{
    ShortName   = "GoAdmChanger"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "Administrative Privileges"
    Description = "Configures and switches GoAdm administrative privilege profiles."
    Example     = 'pwsh -File "SystemConfiguration\Source\@16-GoAdm_changer.ps1"'
  }
  "@17-FiraFonts.ps1" = @{
    ShortName   = "FiraFonts"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "System Fonts"
    Description = "Installs and registers Fira Code and Fira Sans fonts system-wide in Windows Font Table."
    Example     = 'pwsh -File "SystemConfiguration\Source\@17-FiraFonts.ps1"'
  }
  "@18-ShellNewPS1.ps1" = @{
    ShortName   = "ShellNewPS1"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "Explorer Tweaks"
    Description = "Registers PowerShell (.ps1) script creation entry in Windows Explorer 'New' context menu."
    Example     = 'pwsh -File "SystemConfiguration\Source\@18-ShellNewPS1.ps1"'
  }
  "@19-DefineSecureD.ps1" = @{
    ShortName   = "DefineSecureD"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "Volume Security"
    Description = "Sets secure NTFS ACLs, volume labels, and junction permissions on D: drive."
    Example     = 'pwsh -File "SystemConfiguration\Source\@19-DefineSecureD.ps1"'
  }
  "@20-KillLogitechUpdateFull.ps1" = @{
    ShortName   = "KillLogitechUpdateFull"
    Audience    = "User"
    Role        = "Invariants"
    Admin       = $true
    NoExit      = $true
    Category    = "Hardware Stability"
    Description = "Enforces 54/54 Logitech updater suppressions across scheduled tasks, registry run keys, and services."
    Example     = 'pwsh -File "SystemConfiguration\Source\@20-KillLogitechUpdateFull.ps1"'
  }
  "@21-FixMouseFlickerInvariants.ps1" = @{
    ShortName   = "FixMouseFlickerInvariants"
    Audience    = "User"
    Role        = "Invariants"
    Admin       = $true
    NoExit      = $true
    Category    = "Hardware Stability"
    Description = "Enforces AMD Radeon RX 580 ULPS disabled, DWM MPO OverlayTestMode=5, and PowerToys hook locks."
    Example     = 'pwsh -File "SystemConfiguration\Source\@21-FixMouseFlickerInvariants.ps1"'
  }
  "`$21-DesktopSubFoldersLauncher.cmd" = @{
    ShortName   = "DesktopSubFoldersLauncher"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "Desktop Personalization"
    Description = "Launches master customization applicator with optional trace, pause, and hidden parameters."
    Example     = 'DesktopSubFoldersLauncher'
  }

  # System Customizations & AI Memory
  "Apply-AllCustomizations.ps1" = @{
    ShortName   = "ApplyAllCustomizations"
    Aliases     = @("ApplyCustomizations", "ApplyCustomization", "ApplyAllCustomization")
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "System Customization"
    Description = "Executes all @00- to @21- system customization scripts in numerical order."
    Example     = 'ApplyCustomizations'
  }
  "Set-SecureDVolume.ps1" = @{
    ShortName   = "SetSecureD"
    Audience    = "User"
    Role        = "Customization"
    Category    = "Volume Security"
    Description = "Configures and locks secure volume attributes and junctions for D: drive."
    Example     = 'SetSecureD'
  }
  "Initialize-SharedAiMemory.ps1" = @{
    ShortName   = "InitializeAiMemory"
    Audience    = "User"
    Role        = "Customization"
    Category    = "AI Memory Management"
    Description = "Migrates, safeguards, and verifies %USERPROFILE%\.gemini with persistent Drive A:\.gemini and GitHub baseline."
    Example     = 'InitializeAiMemory'
  }
  "ToggleSecure.ps1" = @{
    ShortName   = "ToggleSecure"
    Audience    = "User"
    Role        = "Customization"
    Admin       = $true
    NoExit      = $true
    Category    = "Registry Tweaks"
    Description = "Toggles or sets Windows EnableSecureUIPaths (HKLM Policies\System) with live confirmation."
    Example     = 'ToggleSecure'
  }
  "Show-LastLog.ps1" = @{
    ShortName   = "ShowLastLog"
    Audience    = "User"
    Role        = "Diagnostics"
    NoExit      = $true
    Category    = "Log Diagnostics"
    Description = "Displays the most recently updated audit log in the workspace with live tail and level filtering."
    Example     = 'ShowLastLog'
  }
  "Show-ToolsExplorer.ps1" = @{
    ShortName   = "ToolsExplorer"
    Aliases     = @("ToolExplorer")
    Audience    = "User"
    Role        = "GUI"
    NoExit      = $false
    Category    = "Tool Discovery"
    Description = "Opens the modern interactive LCM Tool Explorer dashboard in the browser or terminal."
    Example     = 'ToolsExplorer'
  }
  "Show-ToolIndex.ps1" = @{
    ShortName   = "ShowToolIndex"
    Audience    = "Developer"
    Role        = "GUI"
    NoExit      = $false
    Category    = "Tool Discovery"
    Description = "Underlying generation engine for the interactive LCM Tool Explorer HTML application."
    Example     = 'ShowToolIndex'
  }
  "Show-Actions.ps1" = @{
    ShortName   = "ShowActions"
    Audience    = "User"
    Role        = "Telemetry"
    NoExit      = $false
    Category    = "Audit Logs"
    Description = "Fast lightweight terminal reader displaying recent operational actions and tool execution step summaries."
    Example     = 'ShowActions'
  }
  "Show-CmdFolderAnalysis.ps1" = @{
    ShortName   = "ShowCmdAnalysis"
    Audience    = "User"
    Role        = "GUI"
    NoExit      = $false
    Category    = "Tool Analysis"
    Description = "Interactive HTML viewer analyzing all legacy batch scripts and modern PowerShell tool equivalents."
  }
  "Invoke-MacriumBcrReview.ps1" = @{
    ShortName   = "BCR"
    Aliases     = @("MacriumBcrReview")
    Audience    = "User"
    Role        = "ReviewGate"
    NoExit      = $false
    Category    = "Proposal Review"
    Description = "Opens the exact CRP/BUG Macrium BCR review using the writable baseline and the _LCM Beyond Compare profile."
    Example     = 'BCR -CRP CRP-284 -RepositoryName LCM_Inventory'
  }
  "Invoke-AsusDebloater.ps1" = @{
    ShortName   = "AsusDebloater"
    Audience    = "User"
    Role        = "Repair"
    Category    = "Hardware Stability"
    Description = "Suppresses unnecessary ASUS background services and scheduled updater tasks."
    Example     = 'pwsh -File "SystemConfiguration\Source\Invoke-AsusDebloater.ps1"'
  }
  "Show-HaInventory.ps1" = @{
    ShortName   = "ShowHaInventory"
    Audience    = "User"
    Role        = "GUI"
    NoExit      = $false
    Category    = "Subsystem GUI"
    Description = "Generates and launches the authoritative Home Assistant HaSSD06 Subsystem Viewer dashboard."
  }
  "ShowHaInventory.ps1" = @{
    ShortName   = "ShowHaInventory"
    Audience    = "User"
    Role        = "GUI"
    NoExit      = $false
    Category    = "Subsystem GUI"
    Description = "Alias for Show-HaInventory.ps1. Generates and opens browser dashboard (SHOW_HA_INVENTORY.html)."
  }
  "Invoke-HaUpdateGate.ps1" = @{
    ShortName   = "HaUpdateGate"
    Audience    = "User"
    Role        = "QualityGate"
    Category    = "Subsystem Update Gate"
    Description = "5-stage update runner (RULE-SUB-006): changelog review, CRP extraction, backup & execution."
    Example     = 'pwsh -File "HaSSD06_Inventory\tools\Invoke-HaUpdateGate.ps1"'
  }
  "Update-HaInventory.ps1" = @{
    ShortName   = "UpdateHaInventory"
    Audience    = "User"
    Role        = "Telemetry"
    Category    = "Subsystem Telemetry"
    Description = "Pulls live WebSocket registry & REST data to reconcile all entities, devices, & integrations."
    Example     = 'pwsh -File "HaSSD06_Inventory\tools\Update-HaInventory.ps1"'
  }
  "Show-HaAuthDialog.ps1" = @{
    ShortName   = "ShowHaAuthDialog"
    Audience    = "User"
    Role        = "Auth"
    Category    = "JIT Authentication"
    Description = "WPF desktop dialog for secure ephemeral credentials with password reveal (RULE-SUB-003)."
    Example     = 'pwsh -File "HaSSD06\tools\subsystem\Show-HaAuthDialog.ps1"'
  }
  "Test-LCM_Readiness.ps1" = @{
    ShortName   = "TestLCM_Readiness"
    Aliases     = @("TestWorkspaceReadiness")
    Audience    = "User"
    Role        = "QualityGate"
    Category    = "Quality Gate"
    Description = "Executes the 5-stage automated LCM readiness quality gate across all repositories."
    Example     = 'pwsh -File "LCM_Inventory\tools\Test-LCM_Readiness.ps1"'
  }
  "Get-ChkdskBootLog.ps1" = @{
    ShortName   = "GetChkdskBootLog"
    Audience    = "User"
    Role        = "Diagnostics"
    Category    = "Disk Diagnostics"
    Description = "Extracts and parses the most recent CHKDSK boot log from the Windows Event Log."
    Example     = 'pwsh -File "SystemConfiguration\Source\Get-ChkdskBootLog.ps1"'
  }
  "Get-SystemPortInventory.ps1" = @{
    ShortName   = "GetSystemPortInventory"
    Audience    = "User"
    Role        = "Diagnostics"
    Category    = "Network Diagnostics"
    Description = "Scans and audits all active local listening TCP/UDP ports and verifies port 9876 availability."
  }
  "Search-Everything.ps1" = @{
    ShortName   = "SearchEverything"
    Audience    = "User"
    Role        = "Utility"
    Category    = "File Search"
    Description = "CLI search interface utilizing Voidtools Everything command line utility (es.exe)."
  }
  "LcmDesktopDaemon.ps1" = @{
    ShortName   = "LcmDaemon"
    Audience    = "Developer"
    Role        = "Elevation"
    Category    = "Desktop Bridge"
    Description = "Lightweight high-performance HTTP/REST bridge daemon running in Session 1 for cross-session GUI dispatch."
  }
  "Register-LcmDesktopDaemon.ps1" = @{
    ShortName   = "RegisterDaemon"
    Audience    = "Developer"
    Role        = "Elevation"
    Category    = "Desktop Bridge"
    Description = "Registers the persistent LCM Desktop REST Bridge Daemon in Task Scheduler with automatic startup."
  }
  "Show-LcmDaemon.ps1" = @{
    ShortName   = "ShowDaemon"
    Audience    = "User"
    Role        = "Diagnostics"
    Category    = "Desktop Bridge"
    Description = "Displays live telemetry, runtime status, and log tailing for the LCM Desktop REST Bridge Daemon."
  }
  "Create-LcmTool.ps1" = @{
    ShortName   = "CreateTool"
    Audience    = "Developer"
    Role        = "Utility"
    Category    = "Tool Scaffolding"
    Description = "Scaffolds new LCM PowerShell tools, derives short names, and generates trampolines in LCM_Inventory/Cmd/."
  }
  "Show-LcmControl.ps1" = @{
    ShortName   = "ShowCM"
    Aliases     = @()
    Audience    = "User"
    Role        = "GUI"
    NoExit      = $false
    Group       = "LCM"
    Domain      = "LCM"
    Category    = "Configuration Management"
    Description = "Unified LCM Control Hub dashboard and proposal lifecycle manager."
    Example     = 'ShowCM'
  }
  "Show-SuperController.ps1" = @{
    ShortName   = "SuperController"
    Aliases     = @()
    Audience    = "User"
    Role        = "GUI"
    NoExit      = $false
    Group       = "LCM"
    Domain      = "LCM"
    Category    = "Navigation"
    Description = "Workspace AI Super-Controller unified navigation dispatcher for ToolsExplorer and ShowCM."
    Example     = 'SuperController'
  }
}

# ------------------------------------------------------------------------------
# 2. Authoritative Tool Catalog Baseline (LCM_Inventory/config/tool_catalog.json)
# ------------------------------------------------------------------------------
$authoritativeCatalog = @{}
if (Test-Path -LiteralPath $catalogJsonPath) {
  try {
    $existingCatalogList = Get-Content -LiteralPath $catalogJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($entry in $existingCatalogList) {
      if (-not [string]::IsNullOrWhiteSpace($entry.Name)) {
        $authoritativeCatalog[$entry.Name] = $entry
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($entry.Name)
        if (-not $authoritativeCatalog.ContainsKey($stem)) {
          $authoritativeCatalog[$stem] = $entry
        }
      }
    }
    Write-ToolLog -Message "Loaded authoritative catalog baseline ($($existingCatalogList.Count) tools) from $catalogJsonPath" -Level INFO
  } catch {
    Write-ToolLog -Message "Warning: Failed to parse authoritative catalog from $catalogJsonPath : $_" -Level WARN
  }
}

# Merge persistent runtime overrides from LCM_Inventory\config\tool_catalog_overrides.json
$overridesFile = Join-Path $configDir 'tool_catalog_overrides.json'
if (Test-Path -LiteralPath $overridesFile) {
  try {
    $dynOverrides = Get-Content -LiteralPath $overridesFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in $dynOverrides.PSObject.Properties) {
      $tName = $prop.Name
      $tVal = $prop.Value
      if (-not $metadataOverrides.ContainsKey($tName)) {
        $metadataOverrides[$tName] = @{}
      }
      foreach ($p in $tVal.PSObject.Properties) {
        $metadataOverrides[$tName][$p.Name] = $p.Value
      }
    }
    Write-ToolLog -Message "Loaded dynamic runtime overrides from $overridesFile" -Level DEBUG
  } catch {}
}

# ------------------------------------------------------------------------------
# 3. Helper Functions: Taxonomy Short-Name Derivation & AST Dependency Parsing
# ------------------------------------------------------------------------------
function Get-LcmToolShortName {
  param(
    [string]$FileName,
    [string]$BaseStem,
    [string]$Domain,
    [hashtable]$Meta
  )

  if ($Meta -and $Meta.ContainsKey('ShortName') -and -not [string]::IsNullOrWhiteSpace($Meta.ShortName)) {
    return $Meta.ShortName
  }

  $clean = $BaseStem
  # Strip legacy numbering e.g. @20-, @00-, 00-, $21-, --_$21-
  $clean = $clean -replace '^(--_)?(@|\$)?\d+[-_]?', ''
  $clean = $clean -replace '^\$\d+[-_]?', ''
  $clean = $clean -replace '^@\d+[-_]?', ''
  $clean = $clean -replace '^\d+[-_]?', ''
  $clean = $clean -replace '^\$', ''

  # Creators: Create<Noun>
  if ($clean -match '^(Create)[-_]?(.*)$') {
    $noun = ($Matches[2] -replace '[-_]', '')
    return "Create$noun"
  }
  # Setters: Set<Noun>
  if ($clean -match '^(Set)[-_]?(.*)$') {
    $noun = ($Matches[2] -replace '[-_]', '')
    return "Set$noun"
  }
  # Showers: Show<Noun>
  if ($clean -match '^(Show)[-_]?(.*)$') {
    $noun = ($Matches[2] -replace '[-_]', '')
    return "Show$noun"
  }
  # Getters: Get<Noun>
  if ($clean -match '^(Get)[-_]?(.*)$') {
    $noun = ($Matches[2] -replace '[-_]', '')
    return "Get$noun"
  }
  # Action Runners (Invoke- -> stripped, Test/Repair/Restore/Kill/Convert/Build/etc. -> ActionNoun)
  if ($clean -match '^(Invoke)[-_]?(.*)$') {
    $noun = ($Matches[2] -replace '[-_]', '')
    return $noun
  }
  if ($clean -match '^(Test|Diagnose|Repair|Restore|Kill|Convert|Build|Find|Fix|Initialize|Install|Register|Search|Stop|Submit|Toggle|Unlock|Enter|Save|Start|Sync|Update|Export)[-_]?(.*)$') {
    $prefix = $Matches[1]
    $noun = ($Matches[2] -replace '[-_]', '')
    return "$prefix$noun"
  }

  # Python tool special names
  if ($FileName.EndsWith('.py', [System.StringComparison]::OrdinalIgnoreCase)) {
    if ($clean -eq 'run_audit') { return 'HaAudit' }
    if ($clean -eq 'inspect_ha_logs') { return 'HaLogs' }
    if ($clean -eq 'invoke_ha_backup') { return 'HaBackup' }
    if ($clean -eq 'invoke_ha_core_update') { return 'HaCoreUpdate' }
    if ($clean -eq 'list_all_updates') { return 'HaListUpdates' }
    if ($clean -eq 'update_ha_inventory') { return 'HaUpdateInventory' }
  }

  return ($clean -replace '[-_]', '')
}

function Get-LcmToolDependencies {
  param(
    [string]$FilePath
  )
  $deps = [System.Collections.Generic.HashSet[string]]::new()
  if (-not (Test-Path -LiteralPath $FilePath)) { return @() }
  $ownName = [System.IO.Path]::GetFileName($FilePath)

  # 1. Parse header for .DEPENDENCIES
  try {
    $content = Get-Content -LiteralPath $FilePath -Raw -ErrorAction SilentlyContinue
    if ($content -match '(?ms)\.DEPENDENCIES\s*\r?\n(.*?)(?=\r?\n\s*\.[A-Z]+|\r?\n\s*#>)') {
      $depBlock = $Matches[1]
      foreach ($line in ($depBlock -split "\r?\n")) {
        $trimmed = $line.Trim().TrimStart('-', '*', ' ')
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
          $deps.Add($trimmed) | Out-Null
        }
      }
    }
    # Parse #Requires statements
    if ($content -match '(?m)^\s*#Requires\s+-Modules?\s+([^\r\n]+)') {
      $modList = $Matches[1].Trim()
      foreach ($m in ($modList -split '[\s,]+')) {
        $mClean = $m.Trim('"', "'")
        if (-not [string]::IsNullOrWhiteSpace($mClean)) { $deps.Add("Module: $mClean") | Out-Null }
      }
    }
  } catch {}

  # 2. Extract referenced script files (*.ps1, *.psm1, *.py, *.cmd, *.bat) from strings
  try {
    if ($content) {
      $scriptMatches = [regex]::Matches($content, '[\''\""]([a-zA-Z0-9_\-\@\\\/]+\.(?:ps1|psm1|py|cmd|bat))[\''\""]')
      foreach ($sm in $scriptMatches) {
        $foundFn = [System.IO.Path]::GetFileName($sm.Groups[1].Value)
        if ($foundFn -and $foundFn -ne $ownName) {
          $deps.Add($foundFn) | Out-Null
        }
      }
      # Extract notable system/utility executables (e.g. PsExec.exe, BCompare.exe, Everything.exe)
      $exeMatches = [regex]::Matches($content, '(?i)(PsExec(?:\.exe)?|BCompare(?:\.exe)?|Everything(?:\.exe)?|es\.exe|git\.exe)')
      foreach ($em in $exeMatches) {
        $deps.Add($em.Groups[1].Value) | Out-Null
      }
    }
  } catch {}

  # 3. AST parsing for PowerShell scripts
  if ($FilePath.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase) -or $FilePath.EndsWith('.psm1', [System.StringComparison]::OrdinalIgnoreCase)) {
    try {
      $tokens = $null
      $errors = $null
      $ast = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$errors)
      $cmdAsts = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
      $commonSwitches = @('SilentlyContinue', 'Stop', 'Continue', 'Inquire', 'Ignore', 'Suspend', 'Force', 'Verbose', 'Debug')
      foreach ($cmd in $cmdAsts) {
        $cmdName = $cmd.GetCommandName()
        if ($cmdName -eq 'Import-Module') {
          $elements = $cmd.CommandElements
          for ($i = 1; $i -lt $elements.Count; $i++) {
            $elText = $elements[$i].Extent.Text.Trim('"', "'")
            if ($elText -notlike '-*' -and $elText -notlike '$*' -and $commonSwitches -notcontains $elText) {
              $deps.Add("Module: $elText") | Out-Null
              break
            }
          }
        }
      }
    } catch {}
  }
  return @($deps)
}

# ------------------------------------------------------------------------------
# 4. Scan Locations
# ------------------------------------------------------------------------------
Import-Module -Name (Join-Path $inventoryRoot 'modules\LcmToolScanLocations.psm1')
$scanDefinitions = @(Get-LcmToolScanLocations)

$toolsList = [System.Collections.Generic.List[PSCustomObject]]::new()
$processedPaths = [System.Collections.Generic.HashSet[string]]::new()
$usedShortNames = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$execStatus = "COMPLETED"
$createdCmdCount = 0
$purgedCount = 0

try {
  foreach ($sd in $scanDefinitions) {
    $targetDir = Join-Path $workspaceRoot $sd.Path
    if (-not (Test-Path $targetDir)) { continue }

    $files = @(Get-ChildItem -Path $targetDir -Filter $sd.Filter -File -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
      if ($f.FullName.Contains("\scratch\") -or $f.FullName.Contains("\.venv\") -or $f.FullName.Contains("\__pycache__\") -or $f.FullName.Contains("\LCM_Inventory\Cmd\")) {
        continue
      }

      # Canonical target resolution for deduplication
      $targetCanonical = $f.FullName
      if ($f.LinkType -eq 'SymbolicLink' -or $f.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
        try {
          $resolved = [System.IO.File]::ResolveLinkTarget($f.FullName, $true)
          if ($resolved) {
            $targetCanonical = $resolved.FullName
          }
        } catch {}
      }

      $nameAndTargetKey = ($f.Name + "::" + $targetCanonical).ToLowerInvariant()
      if ($processedPaths.Contains($nameAndTargetKey)) {
        continue
      }
      $processedPaths.Add($nameAndTargetKey) | Out-Null

      $fileName = $f.Name
      $ext = $f.Extension.ToLowerInvariant()
      $lang = if ($ext -eq '.ps1') { 'PowerShell' } elseif ($ext -eq '.py') { 'Python' } elseif ($ext -in @('.cmd', '.bat')) { 'Batch' } elseif ($ext -eq '.exe') { 'Executable' } elseif ($ext -eq '.reg') { 'Registry' } elseif ($ext -eq '.lnk') { 'Shortcut' } elseif ($ext -eq '.txt') { 'Instruction' } else { 'Script' }

      $relPath = $f.FullName.Substring($workspaceRoot.Length).TrimStart('\', '/')
      $baseStem = [System.IO.Path]::GetFileNameWithoutExtension($fileName)

      # Resolve metadata from authoritative catalog or derive defaults
      $existing = $null
      if ($authoritativeCatalog.ContainsKey($fileName)) {
        $existing = $authoritativeCatalog[$fileName]
      } elseif ($authoritativeCatalog.ContainsKey("$baseStem.ps1")) {
        $existing = $authoritativeCatalog["$baseStem.ps1"]
      } elseif ($authoritativeCatalog.ContainsKey("$baseStem.cmd")) {
        $existing = $authoritativeCatalog["$baseStem.cmd"]
      } elseif ($authoritativeCatalog.ContainsKey("$baseStem.py")) {
        $existing = $authoritativeCatalog["$baseStem.py"]
      } elseif ($authoritativeCatalog.ContainsKey($baseStem)) {
        $existing = $authoritativeCatalog[$baseStem]
      }

      $meta = @{}
      if ($existing) {
        if ($existing.PSObject.Properties['ShortName'] -and -not [string]::IsNullOrWhiteSpace($existing.ShortName)) { $meta['ShortName'] = $existing.ShortName }
        if ($existing.PSObject.Properties['Aliases'] -and $null -ne $existing.Aliases) { $meta['Aliases'] = @($existing.Aliases) }
        if ($existing.PSObject.Properties['Audience'] -and -not [string]::IsNullOrWhiteSpace($existing.Audience)) { $meta['Audience'] = $existing.Audience }
        if ($existing.PSObject.Properties['Role'] -and -not [string]::IsNullOrWhiteSpace($existing.Role)) { $meta['Role'] = $existing.Role }
        if ($existing.PSObject.Properties['Category'] -and -not [string]::IsNullOrWhiteSpace($existing.Category)) { $meta['Category'] = $existing.Category }
        if ($existing.PSObject.Properties['Description'] -and -not [string]::IsNullOrWhiteSpace($existing.Description)) { $meta['Description'] = $existing.Description }
        if ($existing.PSObject.Properties['Example'] -and -not [string]::IsNullOrWhiteSpace($existing.Example)) { $meta['Example'] = $existing.Example }
        if ($existing.PSObject.Properties['Group'] -and -not [string]::IsNullOrWhiteSpace($existing.Group)) { $meta['Group'] = $existing.Group }
        if ($existing.PSObject.Properties['Domain'] -and -not [string]::IsNullOrWhiteSpace($existing.Domain)) { $meta['Domain'] = $existing.Domain }
        if ($null -ne $existing.PSObject.Properties['Admin']) { $meta['Admin'] = [bool]$existing.Admin }
        if ($null -ne $existing.PSObject.Properties['NoExit']) { $meta['NoExit'] = [bool]$existing.NoExit }
      } else {
        $meta['Audience'] = "Developer"
        $meta['Role'] = "Utility"
        $meta['Category'] = "Utility"
        $meta['Description'] = "$baseStem execution tool."
      }

      # Apply metadata overrides if defined for this file, relative path, or base stem
      $overrideKey = $null
      $normRel = if ($relPath) { $relPath.Replace('/', '\') } else { '' }
      $normRelFwd = if ($relPath) { $relPath.Replace('\', '/') } else { '' }

      if ($normRel -and $metadataOverrides.ContainsKey($normRel)) {
        $overrideKey = $normRel
      } elseif ($normRelFwd -and $metadataOverrides.ContainsKey($normRelFwd)) {
        $overrideKey = $normRelFwd
      } elseif ($metadataOverrides.ContainsKey($fileName)) {
        $overrideKey = $fileName
      } elseif ($metadataOverrides.ContainsKey("$baseStem.ps1")) {
        $overrideKey = "$baseStem.ps1"
      } elseif ($metadataOverrides.ContainsKey($baseStem)) {
        $overrideKey = $baseStem
      }
      if ($overrideKey) {
        foreach ($k in $metadataOverrides[$overrideKey].Keys) {
          $meta[$k] = $metadataOverrides[$overrideKey][$k]
        }
      }

      # Determine Short-Name per taxonomy & enforce uniqueness
      $rawShortName = Get-LcmToolShortName -FileName $fileName -BaseStem $baseStem -Domain $sd.Domain -Meta $meta
      $finalShortName = $rawShortName
      if ($usedShortNames.ContainsKey($finalShortName)) {
        # Check if identical target
        $existingPath = $usedShortNames[$finalShortName]
        if ($existingPath.ToLowerInvariant() -ne $targetCanonical.ToLowerInvariant()) {
          if ($sd.Domain -like '*HaSSD06*' -and $fileName -eq 'Test-RepoReadiness.ps1') {
            $finalShortName = "TestHaRepoReady"
          } else {
            $prefix = ($sd.Domain -replace '[^a-zA-Z0-9]', '')
            $cleanBase = $rawShortName -replace "^($prefix)+", ""
            $finalShortName = "$prefix$cleanBase"
          }
          Write-ToolLog -Message "Disambiguated ShortName collision for $fileName -> $finalShortName" -Level WARN
        }
      }
      if (-not $usedShortNames.ContainsKey($finalShortName)) {
        $usedShortNames.Add($finalShortName, $targetCanonical)
      }

      $rawRoleVal = if ($meta.ContainsKey('Role')) { $meta.Role } else { 'Utility' }
      $roleVal = switch ($rawRoleVal) {
        'SystemInvariants'     { 'Invariants' }
        'SystemCustomization'  { 'Customization' }
        'SystemRepair'         { 'Repair' }
        'SystemDiagnostics'    { 'Diagnostics' }
        'SubsystemDiagnostics' { 'Diagnostics' }
        'SystemSecurity'       { 'Security' }
        'InventoryTelemetry'   { 'Telemetry' }
        'SubsystemTelemetry'   { 'Telemetry' }
        'InventoryAudit'       { 'Audit' }
        'SubsystemAudit'       { 'Audit' }
        'InventoryQuery'       { 'Query' }
        'SubsystemRecovery'    { 'Recovery' }
        'SubsystemAuth'        { 'Auth' }
        'SubsystemUpdate'      { 'Update' }
        'SubsystemUpdateGate'  { 'QualityGate' }
        'DesktopGUI'           { 'GUI' }
        'SubsystemGUI'         { 'GUI' }
        'ToolDiscovery'        { 'ToolManagement' }
        default                { $rawRoleVal }
      }
      $audVal  = if ($meta.ContainsKey('Audience')) { $meta.Audience } else { 'Developer' }
      $catVal  = if ($meta.ContainsKey('Category')) { $meta.Category } else { 'Utility' }
      $descVal = if ($meta.ContainsKey('Description')) { $meta.Description } else { "$baseStem execution tool." }

      # Admin requirement heuristic
      $adminRequired = $false
      if ($meta.ContainsKey('Admin')) {
        $adminRequired = [bool]$meta.Admin
      } else {
        $contentPreview = ""
        try { $contentPreview = (Get-Content -LiteralPath $f.FullName -TotalCount 250 -ErrorAction SilentlyContinue) -join "`n" } catch {}
        if ($contentPreview -match 'Requires -RunAsAdministrator|Administrator|IsInRole|Verb RunAs|HKLM:|powercfg|icacls|takeown|fltmc|sc\.exe|Set-Service|Stop-Service|SystemPrivilege|PsExec|\[EnvironmentVariableTarget\]::Machine|''Machine''' -or
            $roleVal -in @('Invariants', 'Repair', 'SystemInvariants', 'SystemRepair') -or
            $baseStem -in @('GoAdm', 'Set-MachineWideExecutionPolicy', 'Set-SecureDVolume', 'Kill-LogitechUpdate', 'Set-MouseFlickerInvariants', 'Invoke-AsusDebloater', 'Set-BluetoothAlwaysOn', 'Enter-PSSystemPrivilege', 'Enter-XYSystemPrivilege', 'PS_SystemPrivilege', 'SystemPrivilege_XY', 'Unlock-ForcedUSO', 'Invoke-AcronisMiniFilterCleanup', '@14-SecureDesktopOff', '@15-PS7AppKiller', '@16-GoAdm_changer', '@17-FiraFonts', '@18-ShellNewPS1', '@19-DefineSecureD', '@20-KillLogitechUpdateFull', '@21-FixMouseFlickerInvariants', '@00-RegKeyDefaultTypeSet', '@00-Skip_TPM_Check_on_Dynamic_Update', '@02-Set_the_date_and_time_format_(ADM_systemwide)', 'Apply-AllCustomizations', 'Set-GitRoot', 'Repair-VolumeAcl', 'Repair-SystemAcl', 'Get-SystemAclAudit', 'Forced USO Unlock', 'AcronisMiniFilterCleanup') -or
            $baseStem -match 'SystemPrivilege|SystemPriviledge|PsExec') {
          $adminRequired = $true
        }
      }

      # Repository-level declaration (AGENTS.md 'Elevation: Administrator') always applies
      $repoRelParts = @($f.FullName.Substring($workspaceRoot.Length).TrimStart('\') -split '\\')
      $repoCandidates = @($baseStem)
      if ($repoRelParts.Count -gt 1) { $repoCandidates += $repoRelParts[0] }
      foreach ($repoName in $repoCandidates) {
        if (-not $script:RepoElevationCache.ContainsKey($repoName)) {
          $agentsFile = Join-Path (Join-Path $workspaceRoot $repoName) 'AGENTS.md'
          $script:RepoElevationCache[$repoName] = (Test-Path -LiteralPath $agentsFile) -and
            [bool](Select-String -LiteralPath $agentsFile -Pattern '^\s*Elevation:\s*Administrator\s*$' -Quiet)
        }
        if ($script:RepoElevationCache[$repoName]) { $adminRequired = $true }
      }

      # Compute accurate environment-specific Example command (preferring ShortName)
      $exampleCmd = if ($meta.ContainsKey('Example') -and -not [string]::IsNullOrWhiteSpace($meta.Example) -and $meta.Example -notlike '*tools\*') {
        $meta.Example
      } elseif (-not [string]::IsNullOrWhiteSpace($finalShortName)) {
        $finalShortName
      } elseif ($lang -eq 'Python') {
        "python `"$relPath`""
      } elseif ($lang -eq 'Batch') {
        "cmd /c `"$relPath`""
      } elseif ($lang -eq 'Executable') {
        "`"$relPath`""
      } else {
        "pwsh -File `"$relPath`""
      }

      # Extract Explicit Parameters
      $paramsList = @()
      $ignoredParams = @('Help', 'h', '?', 'LogFile', 'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'WhatIf', 'Confirm', 'NoLaunch')
      if ($ext -in @('.ps1', '.psm1')) {
        try {
          $tokens = $null
          $errors = $null
          $fileContent = Get-Content -LiteralPath $targetCanonical -Raw -ErrorAction SilentlyContinue
          $ast = [System.Management.Automation.Language.Parser]::ParseFile($targetCanonical, [ref]$tokens, [ref]$errors)
          if ($ast.ParamBlock -and $ast.ParamBlock.Parameters) {
            foreach ($p in $ast.ParamBlock.Parameters) {
              $pName = $p.Name.VariablePath.UserPath
              if ($ignoredParams -contains $pName) { continue }
              $pType = if ($p.StaticType) { $p.StaticType.Name } else { "String" }
              $isMandatory = $false
              foreach ($attr in $p.Attributes) {
                if ($attr.TypeName.Name -eq 'Parameter') {
                  if ($attr.Extent.Text -match 'Mandatory\s*=\s*\$true' -or $attr.Extent.Text -match 'Mandatory\b(?!\s*=\s*\$false)') {
                    $isMandatory = $true
                  }
                }
              }
              $pDefault = if ($p.DefaultValue) { $p.DefaultValue.Extent.Text.Trim('"', "'") } else { "" }
              
              # Extract parameter description: prefer HelpMessage attribute, fallback to .PARAMETER docblock
              $pDesc = ""
              foreach ($attr in $p.Attributes) {
                if ($attr.TypeName.Name -eq 'Parameter') {
                  if ($attr.NamedArguments) {
                    foreach ($arg in $attr.NamedArguments) {
                      if ($arg.ArgumentName -eq 'HelpMessage' -and $arg.Argument) {
                        $pDesc = $arg.Argument.Extent.Text.Trim('"', "'")
                      }
                    }
                  }
                }
              }
              if ([string]::IsNullOrWhiteSpace($pDesc) -and $fileContent -match "(?ms)\.PARAMETER\s+$pName\s*\r?\n\s*(.*?)(?=\r?\n\s*\.[A-Z]+|\r?\n\s*#>)") {
                $pDesc = ($Matches[1].Trim() -replace '\s+', ' ')
              }

              $paramsList += [PSCustomObject]@{
                Name        = $pName
                Type        = $pType
                Mandatory   = $isMandatory
                Default     = $pDefault
                Description = $pDesc
              }
            }
          }
        } catch {}
      }

      # Extract Dependencies
      $depsList = Get-LcmToolDependencies -FilePath $targetCanonical

      # NoExit heuristic
      $noExitRequired = $true
      if ($meta.ContainsKey('NoExit')) {
        $noExitRequired = [bool]$meta.NoExit
      } else {
        if ($baseStem -in @('Show-ToolsExplorer', 'ToolsExplorer', 'Show-Tools', 'ShowTools', 'Show-ToolIndex', 'Show-HaInventory', 'ShowHaInventory', 'Show-HaInventoryApp', 'Build-HaInventoryViewer', 'Update-ToolCatalog', 'Sync-ToolSymlinks', 'Show-WorkspaceInventoryApp', 'Show-LCM_InventoryApp', 'Update-HaInventory') -or
            $roleVal -in @('DesktopGUI', 'SubsystemGUI', 'GUI') -or
            ($roleVal -in @('QualityGate', 'InventoryTelemetry', 'SubsystemTelemetry', 'ReviewCommit') -and -not $adminRequired -and $audVal -eq 'Developer')) {
          $noExitRequired = $false
        }
      }

      $toolEntry = [PSCustomObject]@{
        Name        = $fileName
        ShortName   = $finalShortName
        Aliases     = if ($meta.ContainsKey('Aliases')) { @($meta.Aliases) } else { @() }
        Role        = $roleVal
        Audience    = $audVal
        Admin       = $adminRequired
        NoExit      = $noExitRequired
        Group       = if ($meta.ContainsKey('Group')) { $meta.Group } elseif ($meta.ContainsKey('Subsystem')) { $meta.Subsystem } elseif ($meta.ContainsKey('Domain')) { $meta.Domain } else { $sd.Group }
        Domain      = if ($meta.ContainsKey('Domain')) { $meta.Domain } elseif ($meta.ContainsKey('Subsystem')) { $meta.Subsystem } elseif ($meta.ContainsKey('Group')) { $meta.Group } else { $sd.Domain }
        Type        = $lang
        Category    = $catVal
        Description = $descVal
        Example     = $exampleCmd
        RelativePath= $relPath
        Parameters  = $paramsList
        Dependencies= $depsList
      }

      $toolsList.Add($toolEntry)
      Write-ToolLog -Message "Scanned: $fileName [ShortName: $finalShortName] ($roleVal - $($audVal) - Admin: $adminRequired - NoExit: $noExitRequired)" -Level DEBUG
    }
  }

  # Sort tools: Group, Audience (User first), Role, ShortName ascending
  $sortedTools = @($toolsList | Sort-Object Group, @{Expression={if ($_.Audience -eq 'User') { 0 } else { 1 }}}, Role, ShortName)

  # Write JSON Catalog (UTF-8 without BOM)
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  $jsonContent = $sortedTools | ConvertTo-Json -Depth 5
  [System.IO.File]::WriteAllText($catalogJsonPath, $jsonContent, $utf8NoBom)
  Write-ToolLog -Message "Persisted canonical catalog: $catalogJsonPath" -Level ACTION

  # ----------------------------------------------------------------------------
  # 5. Generate Short-Name Command Trampolines in LCM_Inventory/Cmd/
  # ----------------------------------------------------------------------------
  $createdCmdCount = 0
  $preservedCmdCount = 0
  $generatedLauncherMarker = ':: Generated by Update-ToolCatalog'
  $distinctShortNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  foreach ($t in $sortedTools) {
    $namesToGenerate = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($t.ShortName)) {
      $namesToGenerate.Add($t.ShortName.Trim())
    }
    if ($null -ne $t.Aliases) {
      foreach ($a in @($t.Aliases)) {
        if (-not [string]::IsNullOrWhiteSpace($a)) {
          foreach ($subA in ($a -split '[,;]')) {
            $trimmed = $subA.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
              $namesToGenerate.Add($trimmed)
            }
          }
        }
      }
    }

    foreach ($sn in $namesToGenerate) {
      if ([string]::IsNullOrWhiteSpace($sn)) { continue }
      if ($distinctShortNames.Contains($sn)) { continue }
      $distinctShortNames.Add($sn) | Out-Null

      $targetCmdPath = Join-Path $cmdDir "$sn.cmd"
      if (Test-Path -LiteralPath $targetCmdPath) {
        $existingContent = [System.IO.File]::ReadAllText($targetCmdPath)
        if (-not $existingContent.Contains($generatedLauncherMarker)) {
          $preservedCmdCount++
          Write-ToolLog -Message "Preserved unmanaged launcher: $($targetCmdPath)" -Level INFO
          continue
        }
      }
      
      # Format target relative path with forward slashes anchored to %Git_Root%
      $relPathForward = $t.RelativePath.Replace('\', '/')
      $targetRef = "%Git_Root%/$relPathForward"
      $noExitFlag = if ($t.NoExit) { "-NoExit " } else { "" }

      $gitRootPreamble = "if not defined Git_Root set `"Git_Root=%~dp0..\..`"`r`nif not exist `"%Git_Root%\LCM_Inventory`" set `"Git_Root=D:\Git_Repositories`"`r`n"

      $elevationCheck = if ($t.Admin) {
        "net session >nul 2>&1`r`nif %errorlevel% neq 0 (`r`n  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File `"%Git_Root%/LCM_Inventory/tools/Invoke-PrivilegedTool.ps1`" -Tool `"$sn`" -Arguments `"%*`"`r`n  exit /b`r`n)`r`n"
      } else { "" }

      $cmdBody = if ($t.Type -eq 'Python') {
        "@echo off`r`n$generatedLauncherMarker`r`n${gitRootPreamble}${elevationCheck}setlocal`r`npython `"$targetRef`" %*`r`nendlocal`r`n"
      } elseif ($t.Type -eq 'Batch') {
        "@echo off`r`n$generatedLauncherMarker`r`n${gitRootPreamble}${elevationCheck}call `"$targetRef`" %*`r`n"
      } elseif ($t.Type -eq 'Executable') {
        "@echo off`r`n$generatedLauncherMarker`r`n${gitRootPreamble}${elevationCheck}`"$targetRef`" %*`r`n"
      } else {
        "@echo off`r`n$generatedLauncherMarker`r`n${gitRootPreamble}${elevationCheck}pwsh.exe $noExitFlag-NoProfile -ExecutionPolicy Bypass -File `"$targetRef`" %*`r`n"
      }

      [System.IO.File]::WriteAllText($targetCmdPath, $cmdBody, [System.Text.Encoding]::ASCII)
      $createdCmdCount++
    }
  }
  Write-ToolLog -Message "Generated $createdCmdCount short-name .cmd launchers in $cmdDir" -Level ACTION
  if ($preservedCmdCount -gt 0) {
    Write-ToolLog -Message "Preserved $preservedCmdCount unmanaged .cmd launchers in $cmdDir" -Level INFO
  }

  # Purge only generator-owned orphaned .cmd files in LCM_Inventory/Cmd/
  $purgedCmdCount = 0
  $existingCmds = @(Get-ChildItem -Path $cmdDir -Filter "*.cmd" -File | Where-Object {
      [System.IO.File]::ReadAllText($_.FullName).Contains($generatedLauncherMarker)
    })
  foreach ($cf in $existingCmds) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($cf.Name)
    if (-not $distinctShortNames.Contains($baseName)) {
      try {
        Remove-Item -LiteralPath $cf.FullName -Force
        $purgedCmdCount++
        Write-ToolLog -Message "Purged orphaned launcher: $($cf.Name)" -Level DEBUG
      } catch {}
    }
  }
  if ($purgedCmdCount -gt 0) {
    Write-ToolLog -Message "Purged $purgedCmdCount orphaned .cmd launchers from $cmdDir" -Level ACTION
  }

  # ----------------------------------------------------------------------------
  # 6. Purge Legacy Long .cmd Companion Files from tools/ Root
  # ----------------------------------------------------------------------------
  $purgedCount = 0
  $existingRootCmds = if (Test-Path -LiteralPath $toolsDir -PathType Container) {
    @(Get-ChildItem -LiteralPath $toolsDir -Filter "*.cmd" -File)
  } else {
    @()
    Write-ToolLog -Message "Legacy internal-tools directory is absent; no companion launchers require cleanup." -Level INFO
  }
  foreach ($rc in $existingRootCmds) {
    try {
      Remove-Item -LiteralPath $rc.FullName -Force
      $purgedCount++
      Write-ToolLog -Message "Cleaned redundant root trampoline: $($rc.Name)" -Level DEBUG
    } catch {}
  }
  if ($purgedCount -gt 0) {
    Write-ToolLog -Message "Cleaned $purgedCount legacy companion .cmd files from tools/ root." -Level ACTION
  }

  # ----------------------------------------------------------------------------
  # 7. Generate README.md Reference
  # ----------------------------------------------------------------------------
  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.AppendLine("# Workspace & Subsystem Tooling Index")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("Module: LCM_Inventory/docs/README.md  ")
  [void]$sb.AppendLine("Purpose: Authoritative index of all Lifecycle Model (LCM) and Subsystem tools with Role, ShortName, and User vs Developer classification.  ")
  [void]$sb.AppendLine("Path: LCM_Inventory/docs/README.md  ")
  [void]$sb.AppendLine("Authors: Rolf, LCM_AI Engine  ")
  [void]$sb.AppendLine("Version: $scriptVersion  ")
  [void]$sb.AppendLine("Status: Authoritative Reference  ")
  $now = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  [void]$sb.AppendLine("Updated: $now  ")
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('---')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('## Workspace Readiness')
  [void]$sb.AppendLine('`TestWorkspaceReadiness` is the required workspace quality gate, not an example')
  [void]$sb.AppendLine('command. Run it from any terminal before a governed handoff:')
  [void]$sb.AppendLine('```cmd')
  [void]$sb.AppendLine('TestWorkspaceReadiness')
  [void]$sb.AppendLine('```')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('---')
  [void]$sb.AppendLine('')

  # Section 1: User-Exposed Tools
  [void]$sb.AppendLine('## 1. User & Operator Exposed Commands (Daily Operations)')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('| Short Name | Source Tool | Role | Group | Type | Category | Description | Command |')
  [void]$sb.AppendLine('| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |')
  $userTools = @($sortedTools | Where-Object { $_.Audience -eq 'User' } | Sort-Object Role, ShortName)
  foreach ($t in $userTools) {
    $linkPath = $t.RelativePath.Replace('\', '/')
    [void]$sb.AppendLine("| **$($t.ShortName)** | [$($t.Name)](file:///$linkPath) | $($t.Role) | $($t.Group) | $($t.Type) | $($t.Category) | $($t.Description) | $($t.ShortName) |")
  }
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('---')
  [void]$sb.AppendLine('')

  # Section 2: Developer & Diagnostic Plumbing Tools
  [void]$sb.AppendLine('## 2. Developer & Diagnostic Plumbing Tools')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('| Short Name | Source Tool | Role | Group | Type | Category | Description | Command |')
  [void]$sb.AppendLine('| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |')
  $devTools = @($sortedTools | Where-Object { $_.Audience -eq 'Developer' } | Sort-Object Role, ShortName)
  foreach ($t in $devTools) {
    $linkPath = $t.RelativePath.Replace('\', '/')
    [void]$sb.AppendLine("| **$($t.ShortName)** | [$($t.Name)](file:///$linkPath) | $($t.Role) | $($t.Group) | $($t.Type) | $($t.Category) | $($t.Description) | $($t.ShortName) |")
  }
  [void]$sb.AppendLine('')

  [System.IO.File]::WriteAllText($readmePath, $sb.ToString(), $utf8NoBom)

  Write-ToolLog -Message "Tool catalog synchronized successfully: $($sortedTools.Count) tools ($($userTools.Count) User, $($devTools.Count) Developer)." -Level ACTION
  Write-ToolLog -Message "  Manifest : $catalogJsonPath" -Level INFO
  Write-ToolLog -Message "  Reference: $readmePath" -Level INFO

} catch {
  $execStatus = "FAILED"
  Write-ToolLog -Message "Catalog generation error: $_" -Level ERROR
  throw
} finally {
  $now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  Write-ToolLog -Message "" -Level INFO
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
  Write-ToolLog -Message " [SUMMARY] $scriptName (v$($scriptVersion))" -Level SUMMARY
  Write-ToolLog -Message " Status    : $execStatus" -Level SUMMARY
  Write-ToolLog -Message " Tools     : $($toolsList.Count)" -Level SUMMARY
  Write-ToolLog -Message " Launchers : $createdCmdCount" -Level SUMMARY
  Write-ToolLog -Message " Purged    : $purgedCount" -Level SUMMARY
  Write-ToolLog -Message " Timestamp : $now" -Level SUMMARY
  Write-ToolLog -Message " Log File  : $LogFile" -Level SUMMARY
  Write-ToolLog -Message "==========================================================================" -Level SUMMARY
}
