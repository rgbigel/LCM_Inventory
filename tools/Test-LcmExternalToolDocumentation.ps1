[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = 'Workspace root (default: parent of LCM_Inventory)')]
  [string]$WorkspaceRoot = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Lists every executable with its documentation table')]
  [switch]$ShowAll,

  [Alias('h', '?')]
  [switch]$Help
)

<#
.SYNOPSIS
  Reports external executables named in LCM code that are not documented in install/Installation.md (CRP-345).
.DESCRIPTION
  Module: tools/Test-LcmExternalToolDocumentation.ps1
  Purpose: Collects executable names (*.exe) from LCM code in the governed LCM_* repositories (tools, modules,
           src, assets, Cmd, DoT; *.ps1, *.psm1, *.py, *.go, *.js, *.cmd, *.ahk) and from tools.db table tool_intents,
           and compares them with the tables of the "External Tools" section of LCM_Inventory/install/Installation.md
           (third-party, Windows components, referenced-not-invoked, registered for documentation).
           Exit code 0 when every name is covered, 1 when undocumented names remain.
  Path: LCM_Inventory/tools/Test-LcmExternalToolDocumentation.ps1
  Authors: Rolf, Claude
  Version: 10.7.6
  Date: 2026-11-20
  Implementation Choices (BUG-368): an intent executable is compared by its file name (the registered Python
           interpreter is recorded as a full path).
  Implementation Choices (CRP-345): a name counts as covered when it appears in any of the four tables;
           "registered for documentation" rows are counted separately so open documentation work stays visible.
           Names inside test, scratch, data, log and archive folders are ignored.
.NOTES
  Caveats: the code scan finds every *.exe name, including process names that code only matches; such names
           belong in the "referenced, not invoked" table.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Test-LcmExternalToolDocumentation.ps1 [-WorkspaceRoot <path>] [-ShowAll] [-h]' -ForegroundColor Yellow
  Write-Host '  Reports executables named in LCM code or the tool intents (tools.db) that install/Installation.md does not document.'
  Write-Host '  Exit code: 0 all covered, 1 undocumented names found.'
  return
}

$inventoryRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { $WorkspaceRoot = Split-Path $inventoryRoot -Parent }
$logDir = Join-Path $inventoryRoot 'logs'
$logFile = Join-Path $logDir ('Test-LcmExternalToolDocumentation-{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
function Write-AuditLog([string]$Level, [string]$Message) {
  $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
  if (Test-Path -LiteralPath $logDir) { Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 }
  Write-Host $line
}

# 1. documented names (four tables of the External Tools section)
$installPath = Join-Path $WorkspaceRoot 'LCM_Inventory\install\Installation.md'
$installText = [System.IO.File]::ReadAllText($installPath)
$sectionMatch = [regex]::Match($installText, '(?ms)^### External Tools.*?(?=^## |\z)')
if (-not $sectionMatch.Success) { throw "No 'External Tools' section in $installPath." }
$documented = @{}
$category = ''
foreach ($line in ($sectionMatch.Value -split "`r?`n")) {
  if ($line -match '^Third-party') { $category = 'third-party' }
  elseif ($line -match '^Windows components') { $category = 'windows' }
  elseif ($line -match '^Referenced, not invoked') { $category = 'referenced' }
  elseif ($line -match '^Registered for documentation') { $category = 'registered' }
  elseif ($line -match '^\|' -and $line -notmatch '^\|\s*(:?-|Executable)') {
    $firstCell = ($line -split '\|')[1]
    foreach ($m in [regex]::Matches($firstCell, '`([A-Za-z0-9+_.-]+\.(?:exe|cmd))`')) {
      $documented[$m.Groups[1].Value.ToLowerInvariant()] = $category
    }
  }
}

# 2. names used: LCM code and tool_intents.json
$used = @{}
$codeRoots = @('LCM_Inventory', 'LCM_AI', 'LCM_Shared', 'LCM_Supervision', 'LCM_Tools')
$excluded = '\\(scratch|\.venv|node_modules|Deletions|data|logs|tests|archive|Archive|\.git)\\'
foreach ($root in $codeRoots) {
  $rootPath = Join-Path $WorkspaceRoot $root
  if (-not (Test-Path -LiteralPath $rootPath)) { continue }
  $files = @(Get-ChildItem -LiteralPath $rootPath -Recurse -File -Include *.ps1, *.psm1, *.py, *.go, *.js, *.cmd, *.ahk -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $excluded })
  foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    foreach ($m in [regex]::Matches($text, '(?<![\w~`\\$])([A-Za-z][\w+-]*\.exe)\b')) {
      $name = $m.Groups[1].Value.ToLowerInvariant()
      if (-not $used.ContainsKey($name)) { $used[$name] = $file.FullName.Substring($WorkspaceRoot.Length).TrimStart('\') }
    }
  }
}
Import-Module -Name (Join-Path $inventoryRoot 'modules\LcmToolCatalog.psm1')  # CRP-358: tools.db
$registry = Get-LcmToolStoreDocument -Store intents
foreach ($property in $registry.intents.PSObject.Properties) {
  $exe = [System.IO.Path]::GetFileName(([string]$property.Value.executable -split '\s+')[0]).ToLowerInvariant()  # BUG-368: full paths
  if ($exe -match '\.exe$' -and -not $used.ContainsKey($exe)) { $used[$exe] = "tools.db tool_intents ($($property.Name))" }
}

# 3. compare
$undocumented = @($used.Keys | Where-Object { -not $documented.ContainsKey($_) } | Sort-Object)
$registered = @($used.Keys | Where-Object { $documented.ContainsKey($_) -and $documented[$_] -eq 'registered' } | Sort-Object)
if ($ShowAll) {
  foreach ($name in ($used.Keys | Sort-Object)) {
    $where = if ($documented.ContainsKey($name)) { $documented[$name] } else { 'UNDOCUMENTED' }
    Write-AuditLog 'INFO' ('{0,-28} {1,-14} first seen: {2}' -f $name, $where, $used[$name])
  }
}
foreach ($name in $undocumented) { Write-AuditLog 'WARN' ('Undocumented executable: {0} (first seen: {1})' -f $name, $used[$name]) }
Write-AuditLog 'SUMMARY' ('Test-LcmExternalToolDocumentation: {0} executables named, {1} undocumented, {2} registered for documentation; log {3}' -f $used.Count, $undocumented.Count, $registered.Count, $logFile)
exit $(if ($undocumented.Count -eq 0) { 0 } else { 1 })
