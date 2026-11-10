<#
.SYNOPSIS
  Retrieves the canonical LCM Table Print & PDF Export Atom (LcmTablePrintAtom) for HTML table displays.
.DESCRIPTION
  Provides the standardized, modular JavaScript and CSS asset code for the LcmTablePrintAtom.
  Enables any PowerShell-generated HTML dashboard or table viewer to embed instant, zero-dependency
  Print & PDF export capabilities with live WYSIWYG A4 preview, paper sizing, density scaling,
  and cross-dashboard preference persistence.
  Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: tools/Get-LcmTablePrintAtom.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.2.0
  Date: 2026-10-13
.PARAMETER Inline
  Returns the raw JavaScript content wrapped in <script> tags for direct single-file HTML inlining.
.PARAMETER RawScriptOnly
  Returns only the raw JavaScript code without surrounding HTML tags.
.PARAMETER ScriptTag
  Returns an HTML <script src="..."> tag referencing the asset path.
.PARAMETER LogFile
  Custom log file destination. Defaults to tools/logs/Get-LcmTablePrintAtom-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays this comprehensive parameter reference (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Get-LcmTablePrintAtom.ps1 -Inline
.EXAMPLE
  pwsh tools/Get-LcmTablePrintAtom.ps1 -ScriptTag
#>

[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
  [Parameter(ParameterSetName = 'Inline')]
  [switch]$Inline,

  [Parameter(ParameterSetName = 'RawScript')]
  [switch]$RawScriptOnly,

  [Parameter(ParameterSetName = 'ScriptTag')]
  [switch]$ScriptTag,

  [string]$LogFile = "",

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "10.0.0"
$scriptName = "Get-LcmTablePrintAtom"

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM TABLE PRINT ATOM GENERATOR (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "  Retrieves the modular Print & PDF Export Atom for embedding in any HTML dashboard."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Get-LcmTablePrintAtom.ps1 [-Inline] [-RawScriptOnly] [-ScriptTag] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Inline        : Returns <script> embedded JS code (Default)."
  Write-Host "  -RawScriptOnly : Returns raw JS code without HTML wrapper."
  Write-Host "  -ScriptTag     : Returns <script src=\"assets/lcm-table-print-atom.js\"></script>."
  Write-Host "  -LogFile <str> : Custom log file destination."
  Write-Host "  -h, -Help, -?  : Displays this reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$assetsDir = Join-Path $lcdRoot 'assets'
$atomJsPath = Join-Path $assetsDir 'lcm-table-print-atom.js'

if (-not (Test-Path -LiteralPath $atomJsPath)) {
  throw "LcmTablePrintAtom asset not found at: $atomJsPath"
}

$atomJsContent = Get-Content -LiteralPath $atomJsPath -Raw -Encoding UTF8

if ($RawScriptOnly) {
  return $atomJsContent
}

if ($ScriptTag) {
  return '<script src="assets/lcm-table-print-atom.js"></script>'
}

# Default: Inline script tag
return @"
<script>
$atomJsContent
</script>
"@

