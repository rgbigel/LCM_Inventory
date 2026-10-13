<#
.SYNOPSIS
  Automated privilege-aware tool execution and CLI/agent elevation interceptor engine (RULE-ELEV-006 / CRP-118).
.DESCRIPTION
  Module: Invoke-PrivilegedTool
  Purpose: Intercepts CLI, terminal, and AI agent execution of workspace tools.
           Inspects tool metadata in tool_catalog.json for administrative privilege requirements.
           If the caller is un-elevated and the tool requires elevation, routes execution to the
           interactive user desktop (Session 1) via the Desktop Daemon (Port 9876) or Invoke-InteractiveDesktop.ps1,
           preventing Session 0 hangs and silent invariant failures.
  Path: LCM_Inventory/tools/Invoke-PrivilegedTool.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-10-13
.PARAMETER Tool
  The tool Name, ShortName, or relative path to execute (e.g., 'RestoreSettings', 'Restore-SystemSettings.ps1', 'SetGitRoot').
.PARAMETER Arguments
  Command-line arguments to forward to the target tool.
.PARAMETER NoExit
  Forces the spawned elevated window to remain open after execution per RULE-ELEV-005.
.PARAMETER DryRun
  Evaluates and returns the routing disposition without executing the tool.
.PARAMETER Force
  Bypasses daemon status probing and routes directly to Invoke-InteractiveDesktop.ps1.
.PARAMETER Help
  Displays this parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh LCM_Inventory/tools/Invoke-PrivilegedTool.ps1 -Tool RestoreSettings
.EXAMPLE
  pwsh LCM_Inventory/tools/Invoke-PrivilegedTool.ps1 -Tool ShowRules -Arguments "-Group LCM"
.EXAMPLE
  pwsh LCM_Inventory/tools/Invoke-PrivilegedTool.ps1 -Tool SetGitRoot -DryRun
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Name, ShortName, or file path of the tool to execute')]
  [string]$Tool = '',

  [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Arguments to pass to the tool')]
  [Alias('Args', 'ToolArgs', 'Parameters', 'Params', 'ArgumentList')]
  [string]$Arguments = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Force elevated console window to stay open after execution')]
  [switch]$NoExit,

  [Parameter(Mandatory = $false, HelpMessage = 'Simulate and output routing plan without launching process')]
  [switch]$DryRun,

  [Parameter(Mandatory = $false, HelpMessage = 'Force interactive desktop dispatch without daemon probe')]
  [switch]$Force,

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Invoke-PrivilegedTool"

# Aggregate explicit and remaining arguments seamlessly
$forwardedArgs = if (-not [string]::IsNullOrWhiteSpace($Arguments)) { $Arguments.Trim() } else { '' }

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help -or [string]::IsNullOrWhiteSpace($Tool)) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " AUTOMATED PRIVILEGE-AWARE TOOL DISPATCHER (v$scriptVersion)" -ForegroundColor Cyan
  Write-Host " Conforms to RULE-ELEV-006 & CRP-118" -ForegroundColor DarkCyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Automated privilege-aware CLI & AI agent dispatcher for all workspace tools."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Invoke-PrivilegedTool.ps1 -Tool <ToolName> [-Arguments <str>] [-NoExit] [-DryRun] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Tool <str>      : Tool Name, ShortName, or path (e.g. RestoreSettings, SetGitRoot, ShowRules)"
  Write-Host "  -Arguments <str> : Additional command arguments forwarded to the tool"
  Write-Host "  -NoExit          : Keeps elevated console open upon completion (RULE-ELEV-005)"
  Write-Host "  -DryRun          : Outputs resolved elevation and dispatch plan without execution"
  Write-Host "  -Force           : Bypasses daemon probe and routes directly via interactive desktop"
  Write-Host "  -Help (-h, -?)   : Displays this comprehensive help documentation"
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Invoke-PrivilegedTool.ps1 -Tool RestoreSettings"
  Write-Host "  pwsh LCM_Inventory/tools/Invoke-PrivilegedTool.ps1 -Tool SetGitRoot -Arguments '-TargetPath D:\Git_Repositories'"
  Write-Host "  pwsh LCM_Inventory/tools/Invoke-PrivilegedTool.ps1 -Tool ShowRules -DryRun"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Resolve Workspace Root & Catalog
# ------------------------------------------------------------------------------
$workspaceRoot = "D:\Git_Repositories"
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
  $workspaceRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
}

$catalogPathCandidates = @(
  (Join-Path $workspaceRoot "LCM_Inventory\config\tool_catalog.json"),
  (Join-Path $workspaceRoot "LCM_Inventory\tools\tool_catalog.json")
)

$catalogPath = $null
foreach ($cand in $catalogPathCandidates) {
  if (Test-Path -LiteralPath $cand) {
    $catalogPath = $cand
    break
  }
}

if (-not $catalogPath) {
  throw "Tool catalog not found in workspace candidate paths."
}

$catalogRaw = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json

# ------------------------------------------------------------------------------
# 2. Tool Lookup & Metadata Resolution
# ------------------------------------------------------------------------------
$toolClean = $Tool.Trim()
$targetEntry = $null

function Get-ObjProperty {
  param($Obj, [string]$PropName, $DefaultValue = $null)
  if ($null -ne $Obj -and $Obj.PSObject.Properties.Match($PropName).Count -gt 0) {
    return $Obj.$PropName
  }
  return $DefaultValue
}

# Priority A: Match in catalog (handles both JSON array and object)
$catalogList = if ($catalogRaw -is [System.Collections.IEnumerable] -and -not ($catalogRaw -is [string])) {
  $catalogRaw
} elseif ($catalogRaw.PSObject -and $catalogRaw.PSObject.Properties) {
  $catalogRaw.PSObject.Properties | ForEach-Object { $_.Value }
} else {
  @($catalogRaw)
}

$normTool = $toolClean.ToLowerInvariant() -replace '[\-_\\/\s]', ''
$toolTokens = @(([regex]::Matches($toolClean, '[A-Z][a-z0-9]+|[a-z0-9]+|[A-Z]+')).Value | Where-Object { $_.Length -ge 3 } | ForEach-Object { $_.ToLowerInvariant() })

# Pass 1: Exact / normalized name / shortname / alias / relative path match
foreach ($item in $catalogList) {
  if ($null -eq $item) { continue }
  $sn = Get-ObjProperty -Obj $item -PropName 'ShortName' -DefaultValue ''
  $nm = Get-ObjProperty -Obj $item -PropName 'Name' -DefaultValue ''
  $rp = Get-ObjProperty -Obj $item -PropName 'RelativePath' -DefaultValue ''
  $al = Get-ObjProperty -Obj $item -PropName 'Aliases' -DefaultValue @()

  $normSn = $sn.ToLowerInvariant() -replace '[\-_\\/\s]', ''
  $normNm = $nm.ToLowerInvariant() -replace '[\-_\\/\s]', ''

  if ($normSn -eq $normTool -or $normNm -eq $normTool -or $sn -eq $toolClean -or $nm -eq $toolClean -or ($rp -and $rp.Replace('/', '\') -like "*$toolClean*")) {
    $targetEntry = $item
    break
  }

  if ($al) {
    foreach ($alias in $al) {
      $normAlias = ($alias.ToString()).ToLowerInvariant() -replace '[\-_\\/\s]', ''
      if ($normAlias -eq $normTool) {
        $targetEntry = $item
        break
      }
    }
    if ($targetEntry) { break }
  }
}

# Pass 2: Substring containment and word token matching
if (-not $targetEntry) {
  foreach ($item in $catalogList) {
    if ($null -eq $item) { continue }
    $sn = Get-ObjProperty -Obj $item -PropName 'ShortName' -DefaultValue ''
    $nm = Get-ObjProperty -Obj $item -PropName 'Name' -DefaultValue ''
    $normSn = $sn.ToLowerInvariant() -replace '[\-_\\/\s]', ''
    $normNm = $nm.ToLowerInvariant() -replace '[\-_\\/\s]', ''

    if (-not [string]::IsNullOrWhiteSpace($normSn) -and ($normSn.Contains($normTool) -or ($normTool.Length -ge 4 -and $normTool.Contains($normSn)))) {
      $targetEntry = $item
      break
    }
    if (-not [string]::IsNullOrWhiteSpace($normNm) -and ($normNm.Contains($normTool) -or ($normTool.Length -ge 4 -and $normTool.Contains($normNm)))) {
      $targetEntry = $item
      break
    }

    # Check if all word tokens of input are present in target name or shortname
    if ($toolTokens.Count -gt 1) {
      $allMatchSn = $true
      $allMatchNm = $true
      foreach ($tok in $toolTokens) {
        if (-not $normSn.Contains($tok)) { $allMatchSn = $false }
        if (-not $normNm.Contains($tok)) { $allMatchNm = $false }
      }
      if (($allMatchSn -and -not [string]::IsNullOrWhiteSpace($normSn)) -or ($allMatchNm -and -not [string]::IsNullOrWhiteSpace($normNm))) {
        $targetEntry = $item
        break
      }
    }
  }
}

# Priority B: Direct file resolution if not explicitly in catalog
$scriptFullPath = $null
$toolName = $toolClean
$shortName = $toolClean
$requiresAdmin = $false
$toolType = "PowerShell"
$noExitFlag = $NoExit

if ($targetEntry) {
  $sn = Get-ObjProperty -Obj $targetEntry -PropName 'ShortName' -DefaultValue $toolClean
  $nm = Get-ObjProperty -Obj $targetEntry -PropName 'Name' -DefaultValue $toolClean
  $adm = Get-ObjProperty -Obj $targetEntry -PropName 'Admin' -DefaultValue $false
  $tp = Get-ObjProperty -Obj $targetEntry -PropName 'Type' -DefaultValue 'PowerShell'
  $ne = Get-ObjProperty -Obj $targetEntry -PropName 'NoExit' -DefaultValue $false
  $rp = Get-ObjProperty -Obj $targetEntry -PropName 'RelativePath' -DefaultValue ''

  $toolName = if ($nm) { $nm } else { $toolClean }
  $shortName = if ($sn) { $sn } else { $toolClean }
  $requiresAdmin = [bool]$adm
  $toolType = if ($tp) { $tp } else { "PowerShell" }
  if ($ne) { $noExitFlag = $true }
  $scriptFullPath = if ($rp) { Join-Path $workspaceRoot $rp.Replace('/', '\') } else { $null }
}

if (-not $scriptFullPath -or (-not (Test-Path -LiteralPath $scriptFullPath))) {
  # Fallback to direct path probe
  $directPath = if ([System.IO.Path]::IsPathRooted($toolClean)) { $toolClean } else { Join-Path $workspaceRoot $toolClean }
  if (Test-Path -LiteralPath $directPath) {
    $scriptFullPath = $directPath
    $leaf = Split-Path $directPath -Leaf
    $toolName = $leaf
    $ext = [System.IO.Path]::GetExtension($leaf).ToLowerInvariant()
    $toolType = if ($ext -eq '.py') { 'Python' } elseif ($ext -in @('.cmd', '.bat')) { 'Batch' } elseif ($ext -eq '.exe') { 'Executable' } else { 'PowerShell' }
    if ($leaf -match '(?i)(ADM|Admin|Privileged|Restore-System|Repair-Volume|KillLogitech|Set-GitRoot)') {
      $requiresAdmin = $true
    }
  } else {
    throw "Target tool '$toolClean' could not be resolved in tool_catalog.json or filesystem."
  }
}

# ------------------------------------------------------------------------------
# 3. Privilege & Elevation State Detection
# ------------------------------------------------------------------------------
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
$isElevated = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

# ------------------------------------------------------------------------------
# 4. Command Line Construction
# ------------------------------------------------------------------------------
$noExitSwitch = if ($noExitFlag) { "-NoExit " } else { "" }
$fullCmdLine = switch ($toolType) {
  'Python'     { "python `"$scriptFullPath`" $forwardedArgs".Trim() }
  'Batch'      { "cmd.exe /c `"$scriptFullPath`" $forwardedArgs".Trim() }
  'Executable' { "`"$scriptFullPath`" $forwardedArgs".Trim() }
  default      { "pwsh.exe $noExitSwitch-NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" $forwardedArgs".Trim() }
}

$nowStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# ------------------------------------------------------------------------------
# 5. Routing Engine (RULE-ELEV-006)
# ------------------------------------------------------------------------------
if ($DryRun) {
  $routeMode = if ($isElevated -or (-not $requiresAdmin)) { "Direct (In-Process)" } else { "Session 1 Desktop Daemon / Task Bridge" }
  [ordered]@{
    Tool           = $toolName
    ShortName      = $shortName
    TargetScript   = $scriptFullPath
    Type           = $toolType
    RequiresAdmin  = $requiresAdmin
    CallerElevated = $isElevated
    RoutingMode    = $routeMode
    CommandLine    = $fullCmdLine
  } | Format-List
  return
}

# Case A: Already Elevated OR Tool does NOT require admin
if ($isElevated -or (-not $requiresAdmin)) {
  Write-Host "[LCM-EXEC] Launching '$toolName' directly (Elevated: $isElevated | RequiresAdmin: $requiresAdmin)..." -ForegroundColor Cyan
  if ($toolType -eq 'PowerShell') {
    $pwshArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptFullPath)
    if (-not [string]::IsNullOrWhiteSpace($forwardedArgs)) {
      $pwshArgs += $forwardedArgs -split '\s+'
    }
    & pwsh.exe @pwshArgs
  } elseif ($toolType -eq 'Batch') {
    & cmd.exe /c "$scriptFullPath $forwardedArgs"
  } elseif ($toolType -eq 'Python') {
    & python "$scriptFullPath" ($forwardedArgs -split '\s+')
  } else {
    & "$scriptFullPath" ($forwardedArgs -split '\s+')
  }
  return
}

# Case B: Tool requires admin AND Caller is un-elevated (RULE-ELEV-006)
Write-Host "==========================================================================" -ForegroundColor Yellow
Write-Host " [LCM-ELEVATION-INTERCEPTION] Administrative Elevation Required (RULE-ELEV-006)" -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Yellow
Write-Host " Timestamp     : $nowStr"
Write-Host " Target Tool   : $toolName ($shortName)"
Write-Host " Required Priv : Administrator (Elevated: $requiresAdmin)"
Write-Host " Caller State  : Standard User Context (Elevated: $isElevated)"
Write-Host " Dispatch Path : Routing to Interactive Desktop Session 1 via Daemon / Scheduled Task"
Write-Host " Command Line  : $fullCmdLine"
Write-Host "==========================================================================" -ForegroundColor Yellow

$daemonPort = 9876
if ($env:LCM_DAEMON_PORT -and [int]::TryParse($env:LCM_DAEMON_PORT, [ref]$null)) {
  $daemonPort = [int]$env:LCM_DAEMON_PORT
}

$daemonOnline = $false
if (-not $Force) {
  try {
    $res = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/status" -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($res -and $res.status -eq "online") {
      $daemonOnline = $true
    }
  } catch {}
}

if ($daemonOnline) {
  Write-Host "[LCM-DISPATCH] Dispatched via Session 1 Desktop Daemon on Port $daemonPort..." -ForegroundColor Green
  $bodyJson = @{
    command  = $fullCmdLine
    elevated = $true
    noExit   = [bool]$noExitFlag
  } | ConvertTo-Json

  $response = Invoke-RestMethod -Uri "http://127.0.0.1:$daemonPort/execute" -Method Post -Body $bodyJson -ContentType "application/json" -TimeoutSec 5
  if ($response -and $response.status -eq "ok") {
    Write-Host "[LCM-SUCCESS] Elevated process successfully launched on interactive Session 1 desktop." -ForegroundColor Green
    return
  }
}

# Fallback: Invoke-InteractiveDesktop.ps1
Write-Host "[LCM-FALLBACK] Desktop daemon not responsive; dispatching via Invoke-InteractiveDesktop.ps1 -Elevated..." -ForegroundColor Cyan
$desktopDispatcher = Join-Path $workspaceRoot "LCM_Inventory\tools\Invoke-InteractiveDesktop.ps1"
if (Test-Path -LiteralPath $desktopDispatcher) {
  & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $desktopDispatcher -Command $fullCmdLine -Elevated
  Write-Host "[LCM-SUCCESS] Elevated scheduled task dispatched to Session 1." -ForegroundColor Green
} else {
  throw "Interactive desktop dispatcher not found at: $desktopDispatcher"
}
