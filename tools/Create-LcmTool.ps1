<#
.SYNOPSIS
  Atomic scaffolding engine for new LCM workspace and subsystem tools.
.DESCRIPTION
  Module: Create-LcmTool
  Purpose: Generates a complete, standard-compliant LCM tool in one atomic command:
           1. Creates the target .ps1 script with DOX metadata header (RULE-PS-008),
              strictmode defaults (RULE-PS-005), param block with -h/Help (RULE-PS-010),
              structured logging context (RULE-PS-009), approved verbs (RULE-PS-002),
              and .DEPENDENCIES documentation.
           2. Generates the companion <ShortName>.cmd trampoline launcher in LCM_Inventory/Cmd/.
           3. Creates the NTFS symbolic link in tools/ if located in a child repository.
           4. Synchronizes tool_catalog.json, README.md, and SHOW_TOOLS.html automatically.
  Path: tools/Create-LcmTool.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-10-13
.PARAMETER Name
  The canonical tool file name or base name (e.g. 'Test-NetworkAdapter.ps1' or 'Test-NetworkAdapter').
.PARAMETER ShortName
  Optional custom short-name command alias. If omitted, derived from the taxonomy rules.
.PARAMETER Subsystem
  The target subsystem or group (e.g. 'SystemConfiguration', 'HaSSD06', 'LCM', 'BackgroundModifier', 'LCM_Inventory', 'LCM_AI'). Defaults to 'LCM'.
.PARAMETER Role
  The functional lifecycle archetype: 'Invariants', 'Customization', 'Repair', 'Diagnostics', 'Telemetry', 'Recovery', 'ToolManagement', 'QualityGate', 'ReviewCommit', 'GUI', 'Elevation', 'Utility'.
.PARAMETER Category
  The component or domain category (e.g. 'Hardware Stability', 'Network Diagnostics', 'Registry Tweaks', 'Windows Setup').
.PARAMETER Audience
  The target audience persona: 'User' (Operator) or 'Developer' (Plumbing). Defaults to 'User'.
.PARAMETER Admin
  Indicates that execution requires Administrator elevation.
.PARAMETER NoExit
  Forces the terminal console to remain open after completion (Defaults to true for interactive/diagnostic/admin tools).
.PARAMETER Description
  A concise 1-2 sentence description of the tool's purpose and functionality.
.PARAMETER Force
  Overwrites existing tool files if present.
.PARAMETER Help
  Displays this parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Create-LcmTool.ps1 -Name Test-LanSpeed.ps1 -Role Diagnostics -Category "Network Diagnostics" -Description "Tests local LAN throughput and latency against gateway."
.EXAMPLE
  pwsh tools/Create-LcmTool.ps1 -Name Set-CustomPowerPlan.ps1 -Subsystem SystemConfiguration -Role Customization -Category "Power Settings" -Admin -Description "Configures low-latency power plan."
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0)]
  [string]$Name = "",

  [string]$ShortName = "",

  [ValidateSet('LCM', 'SystemConfiguration', 'HaSSD06', 'BackgroundModifier', 'LCM_Inventory', 'LCM_AI', 'WindowsHost')]
  [string]$Subsystem = 'LCM',

  [ValidateSet('Invariants', 'Customization', 'Repair', 'Diagnostics', 'Telemetry', 'Recovery', 'ToolManagement', 'QualityGate', 'ReviewCommit', 'GUI', 'Elevation', 'Utility',
               'SystemInvariants', 'SystemCustomization', 'SystemRepair', 'SystemDiagnostics', 'SubsystemDiagnostics', 'SubsystemTelemetry', 'SubsystemRecovery', 'DesktopGUI')]
  [string]$Role = 'Diagnostics',

  [string]$Category = 'General',

  [ValidateSet('User', 'Developer', 'Dev')]
  [string]$Audience = 'User',

  [switch]$Admin,

  [switch]$NoExit,

  [string]$Description = "",

  [switch]$Force,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Create-LcmTool"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help -or [string]::IsNullOrWhiteSpace($Name)) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM TOOL ATOMIC CREATION & SCAFFOLDING ENGINE (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Scaffolds a standard-compliant LCM tool with metadata header, logging,"
  Write-Host "  help handler, ShortName .cmd launcher in LCM_Inventory/Cmd/, and auto-synced catalog."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Create-LcmTool.ps1 -Name <str> [-ShortName <str>] [-Subsystem <str>]"
  Write-Host "         [-Role <str>] [-Category <str>] [-Audience <User|Dev>] [-Admin] [-NoExit]"
  Write-Host "         [-Description <str>] [-Force] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Name <str>        : Canonical tool file name (e.g. 'Test-NetworkAdapter.ps1')."
  Write-Host "  -ShortName <str>   : Custom short command alias (e.g. 'TestNetworkAdapter')."
  Write-Host "  -Subsystem <str>   : Subsystem target ('LCM', 'SystemConfiguration', 'HaSSD06', etc. - Default: 'LCM')."
  Write-Host "  -Role <str>        : Lifecycle archetype ('Diagnostics', 'Invariants', 'Customization', 'Repair', etc.)."
  Write-Host "  -Category <str>    : Feature category (e.g. 'Hardware Stability', 'Network Diagnostics')."
  Write-Host "  -Audience <str>    : 'User' (Operator) or 'Developer' (Plumbing) - Default: 'User'."
  Write-Host "  -Admin             : Flag requiring Administrator elevation."
  Write-Host "  -NoExit            : Flag keeping console open after completion."
  Write-Host "  -Description <str> : 1-2 sentence description."
  Write-Host "  -Force             : Overwrite existing target files."
  Write-Host "  -h, -Help, -?      : Displays this parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Create-LcmTool.ps1 -Name Diagnose-MemoryLeaks.ps1 -Role Diagnostics -Category `"Memory Management`" -Description `"Scans for unmanaged memory leaks.`""
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# Normalize tool name
if (-not $Name.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase)) {
  $baseStem = $Name
  $fileName = "$Name.ps1"
} else {
  $fileName = $Name
  $baseStem = $Name.Substring(0, $Name.Length - 4)
}

# Derive ShortName if not specified (Creators: Create<Noun>, Setters: Set<Noun>, Showers: Show<Noun>, Getters: Get<Noun>, Runners: <Noun>)
if ([string]::IsNullOrWhiteSpace($ShortName)) {
  $clean = $baseStem -replace '^@\d+[-_]?', ''
  $clean = $clean -replace '^\d+[-_]?', ''
  if ($clean -match '^(Create)[-_]?(.*)$') { $ShortName = "Create$($Matches[2] -replace '[-_]', '')" }
  elseif ($clean -match '^(Set)[-_]?(.*)$') { $ShortName = "Set$($Matches[2] -replace '[-_]', '')" }
  elseif ($clean -match '^(Show)[-_]?(.*)$') { $ShortName = "Show$($Matches[2] -replace '[-_]', '')" }
  elseif ($clean -match '^(Get)[-_]?(.*)$') { $ShortName = "Get$($Matches[2] -replace '[-_]', '')" }
  elseif ($clean -match '^(New|Invoke)[-_]?(.*)$') { $ShortName = ($Matches[2] -replace '[-_]', '') }
  elseif ($clean -match '^(Test|Diagnose|Repair|Restore|Kill|Convert|Build|Find|Fix|Initialize|Install|Register|Search|Stop|Submit|Toggle)[-_]?(.*)$') {
    $ShortName = "$($Matches[1])$($Matches[2] -replace '[-_]', '')"
  } else {
    $ShortName = ($clean -replace '[-_]', '')
  }
}

$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcdRoot 'tools'
$cmdDir = Join-Path $lcdRoot 'Cmd'
$logDir = Join-Path $lcdRoot 'data\logs\lcm'

if (-not (Test-Path -Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path -Path $cmdDir)) { New-Item -Path $cmdDir -ItemType Directory -Force | Out-Null }

$dateStamp = (Get-Date).ToString("yyyyMMdd")
$auditLog = Join-Path $logDir "$($scriptName)-$dateStamp.log"

function Write-ToolLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [ValidateSet('INFO', 'ACTION', 'WARN', 'ERROR', 'SUMMARY')]
    [string]$Level = 'INFO'
  )
  $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  $line = "[$stamp] [$Level] $Message"
  Add-Content -LiteralPath $auditLog -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
  if ($Level -eq 'ERROR') { Write-Host $line -ForegroundColor Red }
  elseif ($Level -eq 'WARN') { Write-Host $line -ForegroundColor Yellow }
  elseif ($Level -eq 'ACTION') { Write-Host $line -ForegroundColor Green }
  elseif ($Level -eq 'SUMMARY') { Write-Host $line -ForegroundColor Cyan }
  else { Write-Host $line -ForegroundColor Gray }
}

# Determine target directory
$targetDir = switch ($Subsystem) {
  'LCM'                  { $toolsDir }
  'SystemConfiguration'  { Join-Path $workspaceRoot 'SystemConfiguration\Source' }
  'HaSSD06'              { Join-Path $workspaceRoot 'HaSSD06\tools' }
  'BackgroundModifier'   { Join-Path $workspaceRoot 'BackgroundModifier\tools' }
  'LCM_Inventory'  { Join-Path $workspaceRoot 'LCM_Inventory\tools' }
  'LCM_AI'         { Join-Path $workspaceRoot 'LCM_Inventory\tools' }
  default                { $toolsDir }
}

if (-not (Test-Path -LiteralPath $targetDir)) {
  New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
}

$targetFile = Join-Path $targetDir $fileName
$relPathForward = if ($targetFile.StartsWith($workspaceRoot)) { $targetFile.Substring($workspaceRoot.Length).TrimStart('\', '/').Replace('\', '/') } else { $targetFile.Replace('\', '/') }
$relPath = if ($targetFile.StartsWith($workspaceRoot)) { $targetFile.Substring($workspaceRoot.Length).TrimStart('\', '/') } else { $targetFile }
$isChildRepo = ($Subsystem -ne 'LCM')

# Check collision
if ((Test-Path -LiteralPath $targetFile) -and -not $Force) {
  Write-ToolLog -Message "File already exists: $targetFile (use -Force to overwrite)" -Level ERROR
  return
}

# Normalize Audience
$audienceNormalized = if ($Audience -in 'Developer', 'Dev') { 'Developer' } else { 'User' }
if ([string]::IsNullOrWhiteSpace($Description)) {
  $Description = "$baseStem utility and maintenance tool."
}

# Generate PowerShell script content
$todayStr = (Get-Date).ToString("yyyy-MM-dd")
$adminReqStr = if ($Admin) { "`$true" } else { "`$false" }
$noExitFlag = if ($NoExit) { "`$true" } else { "`$false" }

$scriptContent = @"
<#
.SYNOPSIS
  $Description
.DESCRIPTION
  Module: $baseStem
  Purpose: $Description
  Path: $relPath
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: $todayStr
.PARAMETER Help
  Displays this parameter reference (Aliases: -h, -?).
.EXAMPLE
  pwsh $relPath -h
.EXAMPLE
  pwsh $relPath
.DEPENDENCIES
  None
#>

[CmdletBinding()]
param(
  [Alias('h', '?')]
  [switch]`$Help
)

Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'

`$scriptVersion = "10.0.0"
`$scriptName = "$baseStem"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if (`$Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " `$(`$scriptName.ToUpper()) (v`$(`$scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  $Description"
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh $relPath [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -h, -Help, -?  : Displays this parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
`$workspaceRoot = 'D:\Git_Repositories'
`$logDir = Join-Path `$workspaceRoot 'tools\logs'
if (-not (Test-Path -Path `$logDir)) { New-Item -Path `$logDir -ItemType Directory -Force | Out-Null }
`$dateStamp = (Get-Date).ToString("yyyyMMdd")
`$auditLog = Join-Path `$logDir "`$(`$scriptName)-`$dateStamp.log"

function Write-ToolLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = `$true)]
    [string]`$Message,
    [ValidateSet('INFO', 'ACTION', 'WARN', 'ERROR', 'SUMMARY')]
    [string]`$Level = 'INFO'
  )
  `$stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
  `$line = "[`$stamp] [`$Level] `$Message"
  Add-Content -LiteralPath `$auditLog -Value `$line -Encoding UTF8 -ErrorAction SilentlyContinue
  if (`$Level -eq 'ERROR') { Write-Host `$line -ForegroundColor Red }
  elseif (`$Level -eq 'WARN') { Write-Host `$line -ForegroundColor Yellow }
  elseif (`$Level -eq 'ACTION') { Write-Host `$line -ForegroundColor Green }
  elseif (`$Level -eq 'SUMMARY') { Write-Host `$line -ForegroundColor Cyan }
  else { Write-Host `$line -ForegroundColor Gray }
}

Write-ToolLog -Message "Executing `$scriptName v`$scriptVersion..." -Level INFO

# ------------------------------------------------------------------------------
# 2. Main Execution Block
# ------------------------------------------------------------------------------
try {
  # TODO: Implement tool business logic here

  Write-ToolLog -Message "`$scriptName completed successfully." -Level ACTION
} catch {
  Write-ToolLog -Message "Execution error: `$(`$_.Exception.Message)" -Level ERROR
  throw `$_
}
"@

# Write source file
[System.IO.File]::WriteAllText($targetFile, $scriptContent, [System.Text.Encoding]::UTF8)
Write-ToolLog -Message "Created tool source: $targetFile" -Level ACTION

# Create symbolic link in tools/ if child repo
if ($isChildRepo) {
  $symlinkPath = Join-Path $toolsDir $fileName
  if (-not (Test-Path -LiteralPath $symlinkPath)) {
    try {
      New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $targetFile -Force | Out-Null
      Write-ToolLog -Message "Created tools/ symlink: $symlinkPath -> $targetFile" -Level ACTION
    } catch {
      Write-ToolLog -Message "Failed to create symlink: $_" -Level WARN
    }
  }
}

# Create companion <ShortName>.cmd in LCM_Inventory/Cmd/
$cmdLauncherPath = Join-Path $cmdDir "$ShortName.cmd"
$cmdContent = "@echo off`r`npwsh.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0..\..\$relPath`" %*`r`n"
[System.IO.File]::WriteAllText($cmdLauncherPath, $cmdContent, [System.Text.Encoding]::ASCII)
Write-ToolLog -Message "Generated short-name launcher: $cmdLauncherPath" -Level ACTION

# Synchronize catalog
$updateScript = Join-Path $toolsDir 'Update-ToolCatalog.ps1'
if (Test-Path -LiteralPath $updateScript) {
  & pwsh -File $updateScript -Silent
}

Write-Host "==========================================================================" -ForegroundColor Green
Write-Host " TOOL CREATION COMPLETE" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "  Source File : $targetFile"
Write-Host "  Short-Name  : $ShortName"
Write-Host "  Command Hub : LCM_Inventory/Cmd/$ShortName.cmd"
Write-Host "  Run Command : $ShortName"
Write-Host "==========================================================================" -ForegroundColor Green


