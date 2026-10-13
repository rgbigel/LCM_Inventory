<#
.SYNOPSIS
  Generates and launches the authoritative LCM Tool Explorer interactive HTML application.
.DESCRIPTION
  Module: Show-ToolsExplorer
  Purpose: Generates and opens the modern, interactive HTML Tool Explorer dashboard
           conforming to the INVENTORY_VIEWER design standard.
           Features:
           1. Top-line left-adjusted global search filter with !term negation engine.
           2. Table-aligned column filter selectors matching each respective column (Tool Name, Env., Group, Role, Audience, Admin, Category).
           3. Dedicated 'Env.' (Environment: PS1, CMD, PY) column and filter dropdown.
           4. Dedicated 'Admin (Required)' column with auto-detected elevation badges.
           5. Click-to-run on tool names dispatching real visible console processes to Session 1 via lcm:// protocol & Invoke-InteractiveDesktop (elevated based on Admin column).
           6. In-place editable cells for Role, Audience, Category, and Admin with persistence.
           7. Dedicated narrow 'NoExit' column with interactive clickable toggle (🔴 NoExit / 🟢 May Exit) persisting to catalog inventory.
           8. Creation timestamp and [🔄 Refresh Data & View] button in top bar.
           9. Modular architecture built on tools/modules/LcmToolCatalog.psm1 and tools/assets/*.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: LCM_Inventory/tools/Show-ToolsExplorer.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
.PARAMETER Audience
  Pre-filter by audience category: 'User' (daily operations), 'Dev' (internal plumbing), or 'All'. Defaults to 'User'.
.PARAMETER Group
  Pre-filter by group or subsystem name (e.g. 'HaSSD06', 'SystemConfiguration', 'LCM_Inventory', 'LCM'). Defaults to 'All'.
.PARAMETER Subsystem
  Direct pre-filter for specific subsystem (e.g. 'HaSSD06', 'LCM_AI', 'LCM_Inventory'). Defaults to 'All'.
.PARAMETER HaSSD06
  Quick switch to filter directly to Home Assistant HaSSD06 Subsystem tools (Aliases: -Ha, -HomeAssistant).
.PARAMETER Role
  Pre-filter by functional role (e.g. 'QualityGate', 'ReviewGate', 'Elevation', 'DesktopGUI'). Defaults to 'All'.
.PARAMETER Tool
  Pre-select a specific tool name to highlight on startup. Defaults to 'All'.
.PARAMETER Env
  Pre-filter by tool environment ('PS1', 'CMD', 'PY', 'REG', 'LNK', 'All'). Defaults to 'All'.
.PARAMETER Filter
  Initial search keyword to apply on dashboard startup. Defaults to ''.
.PARAMETER Lifecycle
  Pre-filters the catalog for proposal lifecycle, review, and push tooling.
.PARAMETER NoBrowser
  Suppresses launching the web browser and outputs the tool catalog directly as formatted text in the terminal (Aliases: -Cli, -Text, -Console).
.PARAMETER NoLaunch
  Generates the HTML dashboard and caches but does NOT automatically trigger browser launch.
.PARAMETER LogFile
  Custom log file destination. Defaults to LCM_Inventory/data/logs/lcm/Show-ToolsExplorer-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh Show-ToolsExplorer.ps1 -h
.EXAMPLE
  ToolExplorer
.EXAMPLE
  ToolExplorer -HaSSD06
.EXAMPLE
  ToolExplorer -Subsystem HaSSD06
.EXAMPLE
  ToolExplorer -Audience Dev
.EXAMPLE
  ToolExplorer -NoBrowser
#>

[CmdletBinding()]
[Alias('ShowTools', 'ToolsExplorer', 'ToolExplorer')]
param(
  [ValidateSet('User', 'Dev', 'All')]
  [string]$Audience = 'User',

  [string]$Group = 'All',

  [string]$Subsystem = 'All',

  [Alias('Ha', 'HomeAssistant')]
  [switch]$HaSSD06,

  [string]$Role = 'All',

  [string]$Tool = 'All',

  [ValidateSet('PS1', 'CMD', 'PY', 'REG', 'LNK', 'All')]
  [string]$Env = 'All',

  [string]$Filter = '',

  [switch]$Lifecycle,

  [Alias('Cli', 'Text', 'Console')]
  [switch]$NoBrowser,

  [switch]$NoLaunch,

  [string]$LogFile = "",

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($HaSSD06) { $Group = 'HaSSD06' }
elseif ($Subsystem -ne 'All') { $Group = $Subsystem }
if ($Lifecycle) {
  if ([string]::IsNullOrWhiteSpace($Filter)) { $Filter = 'proposal' }
  if ($Audience -eq 'User') { $Audience = 'All' }
}

$scriptVersion = "10.0.0"
$scriptName = "Show-ToolsExplorer"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM TOOL EXPLORER DASHBOARD GENERATOR (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Generates and launches the authoritative LCM Tool Explorer interactive HTML"
  Write-Host "  viewer on your desktop. Use -NoBrowser for terminal text output."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  ToolExplorer [-Lifecycle] [-Subsystem <Subsystem>] [-Audience <User|Dev|All>] [-Group <Group>] [-Role <Role>] [-Tool <Name>] [-Env <PS1|CMD|PY>] [-Filter <Text>] [-NoBrowser] [-NoLaunch] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Subsystem <str> : Pre-filter specific subsystem (e.g. 'HaSSD06', 'SystemConfiguration', 'LCM_Inventory')."
  Write-Host "  -HaSSD06         : Quick switch to filter directly to Home Assistant HaSSD06 Subsystem (Aliases: -Ha)."
  Write-Host "  -Audience <str>  : Pre-filter audience ('User', 'Dev', 'All' - Default: 'User')."
  Write-Host "  -Group <str>     : Pre-filter subsystem group (Default: 'All')."
  Write-Host "  -Role <str>      : Pre-filter functional role (e.g. 'SystemInvariants', 'SystemCustomization')."
  Write-Host "  -Tool <str>      : Pre-filter specific tool by name (Default: 'All')."
  Write-Host "  -Env <str>       : Pre-filter execution environment (PS1, CMD, PY)."
  Write-Host "  -Filter <str>    : Initial search filter text."
  Write-Host "  -Lifecycle       : Pre-filter proposal lifecycle, exact-CRP review, and push tooling."
  Write-Host "  -NoBrowser       : Suppresses web browser and outputs catalog as terminal text (Aliases: -Cli, -Text)."
  Write-Host "  -NoLaunch        : Generates HTML viewer without opening browser."
  Write-Host "  -LogFile <str>   : Custom log file destination."
  Write-Host "  -h, -Help, -?    : Displays this comprehensive parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  ToolExplorer"
  Write-Host "  ToolExplorer -Subsystem HaSSD06"
  Write-Host "  ToolExplorer -HaSSD06"
  Write-Host "  ToolExplorer -Audience Dev"
  Write-Host "  ToolExplorer -NoBrowser"
  Write-Host "  ToolExplorer -Cli -Audience User"
  Write-Host "  ToolExplorer -Role SystemInvariants"
  Write-Host "  ToolExplorer -Lifecycle"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Initialize Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
$inventoryRoot = Split-Path $PSScriptRoot -Parent
$modulesDir = Join-Path $inventoryRoot 'modules'
$toolsDir = $PSScriptRoot

$contextModule = Join-Path $modulesDir 'LcmWorkspaceContext.psm1'
if (Test-Path -LiteralPath $contextModule) {
  try {
    Import-Module -Name $contextModule -Force
    $workspaceRoot = Get-LcmMachineGitRoot
  } catch {
    $workspaceRoot = Split-Path $inventoryRoot -Parent
  }
} else {
  $workspaceRoot = Split-Path $inventoryRoot -Parent
}

$logDir = Join-Path $inventoryRoot 'data\logs\lcm'
if (-not (Test-Path -Path $logDir)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $LogFile = Join-Path $logDir "$($scriptName)-$timestampStr.log"
}

function Write-ToolLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [ValidateSet('INFO', 'ACTION', 'DEBUG', 'WARN', 'ERROR')]
    [string]$Level = 'INFO'
  )
  $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  $line = "[$stamp] [$Level] $Message"
  Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

Write-ToolLog -Message "Initializing $scriptName v$scriptVersion..." -Level INFO

# ------------------------------------------------------------------------------
# 2. Register lcm:// Custom Protocol Handler (HKCU)
# ------------------------------------------------------------------------------
try {
  $regPath = "HKCU:\Software\Classes\lcm"
  if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "(Default)" -Value "URL:LCM Protocol"
    Set-ItemProperty -Path $regPath -Name "URL Protocol" -Value ""
  }
  $cmdPath = "$regPath\shell\open\command"
  if (-not (Test-Path $cmdPath)) {
    New-Item -Path $cmdPath -Force | Out-Null
  }
  $protocolScript = Join-Path $toolsDir 'Invoke-LcmProtocol.ps1'
  $handlerCmd = "pwsh.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$protocolScript`" `"%1`""
  Set-ItemProperty -Path $cmdPath -Name "(Default)" -Value $handlerCmd -ErrorAction SilentlyContinue
  Write-ToolLog -Message "Verified lcm:// URI protocol registration in HKCU." -Level DEBUG
} catch {
  Write-ToolLog -Message "Notice: Protocol handler check: $_" -Level DEBUG
}

# ------------------------------------------------------------------------------
# 3. Load Tool Catalog Module & Data
# ------------------------------------------------------------------------------
$modulePath = Join-Path $modulesDir 'LcmToolCatalog.psm1'
Import-Module -Name $modulePath -Force

$catalogData = Get-LcmToolCatalogData -ToolsDir $toolsDir
$catalog = $catalogData.Catalog

# Dynamic Global Baseline Version Extraction
$globalBaseline = '10.0.0'
$reqDoc = Join-Path $workspaceRoot 'LCM_AI\docs\Requirements.md'
if (Test-Path $reqDoc) {
  $match = Select-String -Path $reqDoc -Pattern '^Version:\s*(\S+)' | Select-Object -First 1
  if ($match -and $match.Matches.Groups.Count -gt 1) {
    $globalBaseline = $match.Matches.Groups[1].Value
  }
}

# Compile-Time Sequence Ordering & Static Index Assignment per CRP-182:
# Exclude the Tool Explorer dashboard runner itself from the catalog display
$catalog = @($catalog | Where-Object {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    $stem -notin @('Show-ToolsExplorer', 'ToolsExplorer', 'ToolExplorer') -and
    $_.ShortName -notin @('ToolsExplorer', 'ToolExplorer')
})

# 1. Sort catalog by ShortName (falling back to Name)
$sortedCatalog = @($catalog | Sort-Object {
    if (-not [string]::IsNullOrWhiteSpace($_.ShortName)) { $_.ShortName } else { $_.Name }
})
# 2. Assign static, monotonic 1..N index to each tool
for ($i = 0; $i -lt $sortedCatalog.Count; $i++) {
    $seq = $i + 1
    $sortedCatalog[$i] | Add-Member -MemberType NoteProperty -Name 'Index' -Value $seq -Force
}
$catalog = $sortedCatalog
$rawJson = $sortedCatalog | ConvertTo-Json -Depth 10

# ------------------------------------------------------------------------------
# 4. Handle Terminal Text Output Mode (-NoBrowser / -Cli / -Text)
# ------------------------------------------------------------------------------
if ($NoBrowser) {
  if ($Lifecycle) {
    Write-Host "LIFECYCLE QUICK REFERENCE: Suggested -> In Progress -> Verified -> In Review -> Completed -> Pushed" -ForegroundColor Cyan
    Write-Host "Use BCR <CRP-ID> and COMPLETE <CRP-ID>; repository-only review and completion are blocked." -ForegroundColor Yellow
    Write-Host "-Immediately is a temporary documented BUG-cohort quality-check deferral; it is not -Force." -ForegroundColor Yellow
    Write-Host "Inspect proposal state with: ShowCM -Lifecycle -Id <CRP-ID>" -ForegroundColor Green
    Write-Host ""
  }
  Format-LcmToolCatalogCli -Catalog $catalog -Audience $Audience -Group $Group -Role $Role -Tool $Tool -Env $Env -Filter $Filter
  return
}

# ------------------------------------------------------------------------------
# 5. Generate Interactive HTML Dashboard
# ------------------------------------------------------------------------------
$targetSubsystem = if ($Group -ne 'All') { $Group } else { 'LCM' }
$generatedHtmlPath = Build-LcmToolIndexHtml `
  -RawJson $rawJson `
  -Catalog $catalog `
  -WorkspaceRoot $workspaceRoot `
  -ToolsDir $toolsDir `
  -Audience $Audience `
  -Group $Group `
  -Role $Role `
  -Tool $Tool `
  -Env $Env `
  -Filter $Filter `
  -Subsystem $targetSubsystem `
  -Version $(if ($globalBaseline.StartsWith('v', [System.StringComparison]::OrdinalIgnoreCase)) { $globalBaseline } else { "v$globalBaseline" })

Write-ToolLog -Message "Interactive HTML dashboard generated: $generatedHtmlPath" -Level ACTION

# ------------------------------------------------------------------------------
# 6. Launch Browser on Interactive Desktop unless -NoLaunch
# ------------------------------------------------------------------------------
if (-not $NoLaunch) {
  $fileUri = [System.Uri]::new($generatedHtmlPath).AbsoluteUri
  
  # Dynamic User Default Browser Discovery (Windows Registry UserChoice)
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

  if (-not $browserPath -or -not (Test-Path -LiteralPath $browserPath)) {
    $zenPath = "D:\Tools\Zen Browser\zen.exe"
    if (Test-Path -LiteralPath $zenPath) {
      $browserPath = $zenPath
      $browserName = "zen"
    }
  }

  $dispatcher = Join-Path $toolsDir 'Invoke-InteractiveDesktop.ps1'

  if ($browserPath -and (Test-Path -LiteralPath $browserPath)) {
    $windowArg = "--new-window `"$fileUri`""
    Write-ToolLog -Message "Launching Tool Explorer in $browserName window: $fileUri" -Level ACTION
    if (Test-Path -LiteralPath $dispatcher) {
      & $dispatcher -FilePath $browserPath -ArgumentList $windowArg
    } else {
      Start-Process -FilePath $browserPath -ArgumentList $windowArg
    }
  } else {
    if (Test-Path -LiteralPath $dispatcher) {
      & pwsh -NoProfile -ExecutionPolicy Bypass -File $dispatcher -FilePath "explorer.exe" -ArgumentList "`"$fileUri`"" | Out-Null
      Write-ToolLog -Message "Launched default browser on Interactive Desktop: $fileUri" -Level ACTION
    } else {
      Start-Process "explorer.exe" -ArgumentList "`"$fileUri`""
    }
  }
}

Write-ToolLog -Message "$scriptName completed successfully." -Level INFO
