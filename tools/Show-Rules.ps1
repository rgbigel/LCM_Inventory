<#
.SYNOPSIS
  Renders and displays the interactive LCM Authoritative Rules Explorer dashboard.
.DESCRIPTION
  Module: Show-Rules
  Purpose: Aggregates, indexes, and visualizes the authoritative Lifecycle Model (LCM)
           governance rules, policies, and invariants from .agents/rules/, AGENTS.md,
           and GEMINI.md. Provides an interactive dark/light web dashboard with instant
           filtering via column-header dropdowns, multi-page print and PDF preview,
           action results display, and Notepad++ dispatch via REST daemon (port 9876).
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: LCM_Inventory/tools/Show-Rules.ps1
  Authors: Rolf, LCM_AI Governance
  Version: 10.2.1
  Date: 2026-11-08 17:34:00
.PARAMETER Domain
  Pre-filter by governance domain (e.g. 'Proposal & Review Flow', 'PowerShell Standards', 'Security', 'All'). Defaults to 'All'.
.PARAMETER Filter
  Initial search keyword to apply on dashboard startup. Defaults to ''.
.PARAMETER NoBrowser
  Suppresses launching the web browser and outputs the rules catalog directly as formatted text in the terminal (Aliases: -Cli, -Text, -Console).
.PARAMETER NoLaunch
  Renders the HTML dashboard and logs without launching the browser window.
.PARAMETER Pane
  Opens the display inside an Antigravity IDE editor/side pane instead of an external browser window (Alias: -Panel).
.PARAMETER LogFile
  Custom log file destination. Defaults to LCM_Inventory/data/logs/lcm/Show-Rules-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  ShowRules
.EXAMPLE
  ShowRules -Domain "PowerShell"
.EXAMPLE
  ShowRules -Filter "RULE-PS"
.EXAMPLE
  ShowRules -NoBrowser
#>

[CmdletBinding()]
param(
  [string]$Domain = 'All',
  [string]$Filter = '',
  [Alias('Cli', 'Text', 'Console')]
  [switch]$NoBrowser,
  [switch]$NoLaunch,
  [Parameter(Mandatory = $false, HelpMessage = 'Opens the display inside an Antigravity IDE editor/side pane')]
  [Alias('Panel')]
  [switch]$Pane,
  [string]$LogFile = '',
  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmDisplayVersion.psm1') -Force
$scriptVersion = Get-LcmDisplaySourceVersion -Path $PSCommandPath
$provenance = Get-LcmDisplayProvenance -ScriptPath $PSCommandPath -TemplatePath $PSCommandPath
$scriptName = 'Show-Rules'

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM AUTHORITATIVE RULES EXPLORER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Renders and displays the interactive LCM Authoritative Rules Explorer"
  Write-Host "  dashboard with full policy inspection, column-header dropdown filtering,"
  Write-Host "  Notepad++ editor dispatch, and multi-page print preview."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Show-Rules.ps1 [-Domain <str>] [-Filter <str>] [-NoBrowser] [-NoLaunch] [-h]"
  Write-Host "  ShowRules"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Domain <str>  : Pre-filter by domain ('Proposal & Review Flow', 'PowerShell Standards', etc.)."
  Write-Host "  -Filter <str>  : Initial search term to filter rules."
  Write-Host "  -NoBrowser     : Outputs clean formatted table directly to console."
  Write-Host "  -NoLaunch      : Generates HTML dashboard without launching browser."
  Write-Host "  -LogFile <str> : Custom log file destination."
  Write-Host "  -h, -Help, -?  : Displays this comprehensive parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  ShowRules"
  Write-Host "  ShowRules -Domain 'PowerShell'"
  Write-Host "  ShowRules -Filter 'RULE-LCM'"
  Write-Host "  ShowRules -NoBrowser"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Initialize Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = if (-not [string]::IsNullOrWhiteSpace($env:Git_Root)) { $env:Git_Root.TrimEnd('\', '/') } else { 'D:\Git_Repositories' }
$lcmRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$logDir = Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm'
if (-not (Test-Path -LiteralPath $logDir)) {
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
# 2. Parse Canonical Rules from AGENTS.md & Disk
# ------------------------------------------------------------------------------
$rulesHubDir = Join-Path $workspaceRoot '.agents\rules'
$agentsMdPath = Join-Path $workspaceRoot 'AGENTS.md'
$geminiMdPath = Join-Path $workspaceRoot 'GEMINI.md'
$crossRefPath = Join-Path $workspaceRoot 'LCM_AI\docs\LCM-Rules-Cross-Reference.md'

$ruleEntries = [System.Collections.Generic.List[PSCustomObject]]::new()
$agentsTableMap = @{}

if (Test-Path -LiteralPath $agentsMdPath) {
  $agentsLines = Get-Content -LiteralPath $agentsMdPath -Encoding UTF8
  foreach ($line in $agentsLines) {
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith('| **[')) {
      $parts = @($trimmed.Split('|') | Where-Object { $null -ne $_ })
      if ($parts.Count -ge 6) {
        $filePart = $parts[1].Trim()
        $idPart = $parts[2].Trim()
        $domainPart = $parts[3].Trim().Replace('**', '')
        $scopePart = $parts[4].Trim()
        $invPart = $parts[5].Trim()

        $fileName = if ($filePart -match '\[(?<fn>[^\]]+)\]') { $Matches['fn'] } else { $filePart }
        $cleanIds = $idPart.Replace('`', '').Trim()

        $agentsTableMap[$fileName] = @{
          Identifiers = $cleanIds
          Domain      = $domainPart
          Scope       = $scopePart
          Invariant   = $invPart
        }
      }
    }
  }
}

# Scan all Markdown rules in .agents/rules/
if (Test-Path -LiteralPath $rulesHubDir) {
  $ruleFiles = @(Get-ChildItem -LiteralPath $rulesHubDir -Filter '*.md' -File | Sort-Object Name)
  foreach ($rf in $ruleFiles) {
    $fn = $rf.Name
    $meta = if ($agentsTableMap.ContainsKey($fn)) { $agentsTableMap[$fn] } else { $null }
    
    $rawContent = Get-Content -LiteralPath $rf.FullName -Raw -Encoding UTF8
    $lineCount = ($rawContent -split "`n").Count
    $sizeKb = [Math]::Round($rf.Length / 1024, 1)

    # Fallback extraction from frontmatter / content
    $extractedDomain = if ($meta) { $meta.Domain } else { 'General Policy' }
    $extractedScope = if ($meta) { $meta.Scope } else { 'Workspace-wide' }
    $extractedIds = if ($meta) { $meta.Identifiers } else { 'RULE-UNSET' }
    $extractedInv = if ($meta) { $meta.Invariant } else {
      if ($rawContent -match 'description:\s*(?<desc>[^\r\n]+)') { $Matches['desc'].Trim() } else { 'Authoritative LCM Rule Policy' }
    }

    $ruleEntries.Add([PSCustomObject]@{
      Name         = $fn
      Title        = [System.IO.Path]::GetFileNameWithoutExtension($fn)
      Identifiers  = $extractedIds
      Domain       = $extractedDomain
      Scope        = $extractedScope
      Invariant    = $extractedInv
      Path         = $rf.FullName
      RelativePath = ".agents/rules/$fn"
      Lines        = $lineCount
      SizeKb       = $sizeKb
      Content      = $rawContent
      Category     = 'Canonical Rule Policy'
    })
  }
}

# Add Core Governance files (AGENTS.md, GEMINI.md, LCM-Rules-Cross-Reference.md)
$governanceFiles = @(
  @{ Path = $agentsMdPath; Name = 'AGENTS.md'; Domain = 'Core Governance'; Scope = 'Workspace Container'; Ids = 'ROOT-GOVERNANCE'; Inv = 'Authoritative LCM multi-repository governance root directive, quick reference index, and system troubleshooting invariants.' },
  @{ Path = $geminiMdPath; Name = 'GEMINI.md'; Domain = 'Directive'; Scope = 'Workspace Container'; Ids = 'DIRECTIVE'; Inv = 'Authoritative LCM governance directive linking to AGENTS.md, .agents/rules/, and cross-reference matrix.' },
  @{ Path = $crossRefPath; Name = 'LCM-Rules-Cross-Reference.md'; Domain = 'Rules Matrix'; Scope = 'All Repositories'; Ids = 'RULE-MATRIX'; Inv = 'Comprehensive matrix cross-referencing all 16 canonical rule policies, child repository junctions, and enforcement scripts.' }
)

foreach ($gf in $governanceFiles) {
  if (Test-Path -LiteralPath $gf.Path) {
    $item = Get-Item -LiteralPath $gf.Path
    $rawContent = Get-Content -LiteralPath $item.FullName -Raw -Encoding UTF8
    $ruleEntries.Add([PSCustomObject]@{
      Name         = $gf.Name
      Title        = $gf.Name
      Identifiers  = $gf.Ids
      Domain       = $gf.Domain
      Scope        = $gf.Scope
      Invariant    = $gf.Inv
      Path         = $item.FullName
      RelativePath = $gf.Name
      Lines        = ($rawContent -split "`n").Count
      SizeKb       = [Math]::Round($item.Length / 1024, 1)
      Content      = $rawContent
      Category     = 'Governance Architecture'
    })
  }
}

Write-ToolLog -Message "Loaded $($ruleEntries.Count) authoritative rules and governance specifications." -Level INFO

# ------------------------------------------------------------------------------
# 3. Handle Terminal CLI Output Mode (-NoBrowser / -Cli / -Text)
# ------------------------------------------------------------------------------
if ($NoBrowser) {
  Write-Host ""
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM AUTHORITATIVE RULES EXPLORER (Total: $($ruleEntries.Count))" -ForegroundColor Cyan
  Write-Host " Hub: D:\Git_Repositories\.agents\rules\" -ForegroundColor DarkGray
  Write-Host "==========================================================================" -ForegroundColor Cyan

  $filtered = @($ruleEntries | Where-Object {
    ($Domain -eq 'All' -or $_.Domain -like "*$Domain*") -and
    ([string]::IsNullOrWhiteSpace($Filter) -or $_.Name -like "*$Filter*" -or $_.Identifiers -like "*$Filter*" -or $_.Domain -like "*$Filter*" -or $_.Invariant -like "*$Filter*")
  })

  foreach ($r in $filtered) {
    Write-Host " [$($r.Identifiers)] " -ForegroundColor Yellow -NoNewline
    Write-Host "$($r.Name) " -ForegroundColor White -NoNewline
    Write-Host "($($r.Domain))" -ForegroundColor Cyan
    Write-Host "    Scope    : " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($r.Scope)" -ForegroundColor Gray
    Write-Host "    Invariant: " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($r.Invariant)" -ForegroundColor DarkCyan
    Write-Host "    Location : " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($r.RelativePath) ($($r.Lines) lines, $($r.SizeKb) KB)" -ForegroundColor DarkGray
    Write-Host ""
  }
  Write-Host "Total displayed: $($filtered.Count) of $($ruleEntries.Count) rules." -ForegroundColor Green
  return
}

# ------------------------------------------------------------------------------
# 4. Generate Interactive HTML Dashboard
# ------------------------------------------------------------------------------
$artifactsDir = Join-Path $lcmRoot 'data\artifacts'
if (-not (Test-Path -LiteralPath $artifactsDir)) {
  New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
}

$rulesJson = ([ordered]@{ rules = @($ruleEntries.ToArray()) } | ConvertTo-Json -Depth 6 -Compress).Replace('<', '\u003c')

$htmlTemplate = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="lcm-display-id" content="rules">
  <title>LCM Rules Explorer - Authoritative Governance Policies {{DISPLAY_VERSION}}</title>
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📜</text></svg>">
  <link rel="stylesheet" href="/assets/StandardTableDisplay.css">
  <script src="/assets/lcm-display-freshness.js" defer></script>
  <style>
    :root {
      --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji";
      --font-mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
      height: 100vh;
      overflow: hidden;
      background-color: var(--bg-primary, #0d1117);
      color: var(--text-primary, #e6edf3);
      font-family: var(--font-family);
      font-size: 13px;
      display: flex;
      flex-direction: column;
    }

    /* Top Pinned Header */
    header {
      background: var(--bg-secondary, #161b22);
      border-bottom: 1px solid var(--border, #30363d);
      padding: 12px 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-shrink: 0;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .brand-icon {
      font-size: 26px;
      line-height: 1;
    }

    .brand-titles h1 {
      font-size: 18px;
      font-weight: 700;
      color: var(--text-primary, #e6edf3);
      letter-spacing: -0.2px;
    }

    .brand-titles .subtitle {
      font-size: 11px;
      color: var(--text-secondary, #8b949e);
      font-family: var(--font-mono);
      margin-top: 2px;
    }

    .header-badges {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .badge {
      display: inline-flex;
      align-items: center;
      padding: 3px 8px;
      border-radius: 12px;
      font-size: 11px;
      font-weight: 600;
      font-family: var(--font-mono);
      background: var(--bg-tertiary, #21262d);
      border: 1px solid var(--border, #30363d);
      color: var(--text-secondary, #8b949e);
    }

    .badge-primary {
      background: rgba(88, 166, 255, 0.15);
      border-color: rgba(88, 166, 255, 0.3);
      color: var(--accent, #58a6ff);
    }

    .badge-success {
      background: rgba(63, 185, 80, 0.15);
      border-color: rgba(63, 185, 80, 0.3);
      color: var(--success, #3fb950);
    }

    /* Pinned Toolbar */
    .toolbar {
      background: var(--bg-secondary, #161b22);
      border-bottom: 1px solid var(--border, #30363d);
      padding: 10px 20px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      flex-shrink: 0;
    }

    .search-row {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
    }

    .search-wrapper {
      position: relative;
      flex: 1;
      min-width: 240px;
    }

    .search-wrapper input {
      width: 100%;
      background: var(--bg-primary, #0d1117);
      border: 1px solid var(--border, #30363d);
      border-radius: 6px;
      padding: 8px 12px 8px 34px;
      color: var(--text-primary, #e6edf3);
      font-size: 13px;
      outline: none;
      transition: border-color 0.15s, box-shadow 0.15s;
    }

    .search-wrapper input:focus {
      border-color: var(--accent, #58a6ff);
      box-shadow: 0 0 0 3px rgba(88, 166, 255, 0.15);
    }

    .search-icon {
      position: absolute;
      left: 10px;
      top: 50%;
      transform: translateY(-50%);
      color: var(--text-muted, #6e7681);
      font-size: 14px;
      pointer-events: none;
    }

    .toolbar-actions {
      display: flex;
      gap: 8px;
      align-items: center;
      flex-wrap: wrap;
    }

    .btn {
      background: var(--bg-tertiary, #21262d);
      border: 1px solid var(--border, #30363d);
      color: var(--text-primary, #e6edf3);
      padding: 6px 12px;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 500;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s;
      user-select: none;
    }

    .btn:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: var(--text-muted, #6e7681);
    }

    .btn-primary {
      background: #238636;
      border-color: rgba(240, 246, 252, 0.1);
      color: #ffffff;
      font-weight: 600;
    }

    .btn-primary:hover {
      background: #2ea043;
    }

    .btn-reset {
      color: var(--warning, #d29922);
      border-color: rgba(210, 153, 34, 0.4);
    }

    .btn-reset:hover {
      background: rgba(210, 153, 34, 0.15);
      border-color: var(--warning, #d29922);
    }

    /* Action Results Banner (Multi-line persistent output replacing pills) */
    .action-results-area {
      background: rgba(56, 139, 253, 0.08);
      border: 1px solid rgba(56, 139, 253, 0.25);
      border-radius: 6px;
      padding: 8px 14px;
      margin: 0 20px 8px 20px;
      flex-shrink: 0;
      display: flex;
      flex-direction: column;
      gap: 5px;
    }

    body.light-theme .action-results-area {
      background: #f0f7ff;
      border-color: #0969da;
    }

    .action-results-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid rgba(88, 166, 255, 0.2);
      padding-bottom: 4px;
    }

    .action-results-title {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--accent, #58a6ff);
    }

    .action-results-close {
      background: transparent;
      border: none;
      color: var(--text-secondary, #8b949e);
      font-size: 14px;
      cursor: pointer;
      padding: 0 4px;
      border-radius: 3px;
    }

    .action-results-close:hover {
      background: var(--bg-tertiary, #21262d);
      color: var(--text-primary, #e6edf3);
    }

    .action-results-content {
      display: flex;
      flex-direction: column;
      gap: 3px;
      font-family: var(--font-mono);
      font-size: 11.5px;
    }

    .action-result-line {
      display: flex;
      align-items: center;
      gap: 8px;
      color: var(--text-primary, #e6edf3);
      word-break: break-all;
    }

    .action-result-btn {
      background: var(--bg-tertiary, #21262d);
      border: 1px solid var(--border, #30363d);
      color: var(--text-secondary, #8b949e);
      padding: 1px 6px;
      border-radius: 4px;
      font-size: 10.5px;
      cursor: pointer;
      font-family: var(--font-family);
    }

    .action-result-btn:hover {
      color: var(--text-primary, #e6edf3);
      border-color: var(--accent, #58a6ff);
    }

    /* Scrollable Table Viewport */
    .table-viewport {
      flex: 1;
      overflow-y: auto;
      overflow-x: auto;
      position: relative;
    }

    table {
      width: 100%;
      border-collapse: separate;
      border-spacing: 0;
      text-align: left;
    }

    thead th {
      background: var(--bg-secondary, #161b22);
      color: var(--text-secondary, #8b949e);
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      padding: 10px 14px;
      border-bottom: 1px solid var(--border, #30363d);
      position: sticky;
      top: 0;
      z-index: 10;
      user-select: none;
      cursor: pointer;
      white-space: nowrap;
    }

    thead th:hover {
      color: var(--text-primary, #e6edf3);
    }

    /* Column Filter Select Row */
    .col-filter-row th {
      top: 37px;
      z-index: 9;
      background: var(--bg-tertiary, #21262d);
      padding: 4px 10px;
      border-bottom: 2px solid var(--border, #30363d);
      cursor: default;
    }

    .col-filter-select {
      width: 100%;
      background: var(--bg-primary, #0d1117);
      border: 1px solid var(--border, #30363d);
      color: var(--text-primary, #e6edf3);
      border-radius: 4px;
      padding: 4px 6px;
      font-size: 11px;
      outline: none;
      transition: border-color 0.15s;
    }

    .col-filter-select:focus {
      border-color: var(--accent, #58a6ff);
    }

    body.light-theme .col-filter-row th {
      background: #eaeef2 !important;
      border-bottom: 2px solid #d0d7de !important;
    }

    body.light-theme .col-filter-select {
      background: #ffffff !important;
      border-color: #d0d7de !important;
      color: #1f2328 !important;
    }

    tbody tr {
      background: var(--bg-primary, #0d1117);
      transition: background-color 0.1s;
    }

    tbody tr:nth-child(even) {
      background: rgba(255, 255, 255, 0.015);
    }

    body.light-theme tbody tr:nth-child(even) {
      background: rgba(0, 0, 0, 0.02);
    }

    tbody tr:hover {
      background: var(--bg-tertiary, #21262d);
    }

    body.light-theme tbody tr:hover {
      background: #f3f6f9 !important;
    }

    tbody td {
      padding: 9px 14px;
      border-bottom: 1px solid var(--border, #30363d);
      vertical-align: middle;
      font-size: 12.5px;
      white-space: normal;
      word-break: break-word;
      overflow-wrap: anywhere;
    }

    .rule-name {
      font-weight: 600;
      color: var(--accent, #58a6ff);
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      word-break: break-word;
      overflow-wrap: anywhere;
    }

    .rule-name:hover {
      text-decoration: underline;
    }

    .rule-id-badge {
      font-family: var(--font-mono);
      font-size: 11px;
      font-weight: 600;
      padding: 2px 6px;
      border-radius: 4px;
      background: rgba(88, 166, 255, 0.15);
      color: var(--accent, #58a6ff);
      border: 1px solid rgba(88, 166, 255, 0.3);
      display: inline-block;
      white-space: normal;
      word-break: break-word;
    }

    .domain-tag {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 10px;
      font-size: 11px;
      background: var(--bg-tertiary, #21262d);
      color: var(--text-secondary, #8b949e);
      border: 1px solid var(--border, #30363d);
      white-space: normal;
      word-break: break-word;
    }

    body.light-theme .domain-tag {
      background: #eaeef2;
      border-color: #d0d7de;
      color: #424a53;
    }

    .scope-text {
      color: var(--text-secondary, #8b949e);
      font-size: 12px;
      white-space: normal;
      word-break: break-word;
    }

    .invariant-text {
      color: var(--text-primary, #e6edf3);
      font-size: 12px;
      line-height: 1.4;
      max-width: 480px;
      word-break: break-word;
      overflow-wrap: anywhere;
    }

    .actions-cell {
      white-space: nowrap;
      text-align: right;
    }

    .btn-action {
      background: transparent;
      border: 1px solid var(--border, #30363d);
      color: var(--text-secondary, #8b949e);
      padding: 3px 8px;
      border-radius: 4px;
      font-size: 11px;
      cursor: pointer;
      margin-left: 4px;
      transition: all 0.12s;
    }

    .btn-action:hover {
      background: var(--bg-tertiary, #21262d);
      color: var(--text-primary, #e6edf3);
      border-color: var(--text-muted, #6e7681);
    }

    .btn-action.primary {
      color: var(--accent, #58a6ff);
      border-color: rgba(88, 166, 255, 0.3);
    }

    .btn-action.primary:hover {
      background: rgba(88, 166, 255, 0.15);
    }

    /* Pinned Footer Status Dock */
    footer {
      background: var(--bg-secondary, #161b22);
      border-top: 1px solid var(--border, #30363d);
      padding: 8px 20px;
      font-size: 11px;
      color: var(--text-secondary, #8b949e);
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-shrink: 0;
      font-family: var(--font-mono);
    }

    .daemon-indicator {
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }

    .dot-green {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--success, #3fb950);
      box-shadow: 0 0 6px var(--success, #3fb950);
    }

    .dot-muted {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--text-muted, #6e7681);
    }

    /* Fullscreen/Modal Markdown Reader */
    .modal-overlay {
      display: none;
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.75);
      backdrop-filter: blur(4px);
      z-index: 1000;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }

    .modal-overlay.open {
      display: flex;
    }

    .modal-content {
      background: var(--bg-secondary, #161b22);
      border: 1px solid var(--border, #30363d);
      border-radius: 8px;
      width: 100%;
      max-width: 960px;
      height: 85vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 16px 36px rgba(0, 0, 0, 0.6);
      overflow: hidden;
    }

    .modal-header {
      padding: 12px 20px;
      border-bottom: 1px solid var(--border, #30363d);
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: var(--bg-secondary, #161b22);
      flex-shrink: 0;
    }

    .modal-header-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .modal-title {
      font-size: 15px;
      font-weight: 700;
      color: var(--text-primary, #e6edf3);
    }

    .modal-body {
      padding: 24px;
      overflow-y: auto;
      flex: 1;
      font-family: var(--font-family);
      line-height: 1.6;
      color: var(--text-primary, #e6edf3);
    }

    .modal-body pre {
      background: var(--bg-primary, #0d1117);
      border: 1px solid var(--border, #30363d);
      padding: 14px;
      border-radius: 6px;
      overflow-x: auto;
      font-family: var(--font-mono);
      font-size: 12px;
      margin: 12px 0;
      white-space: pre-wrap;
      word-break: break-word;
    }

    .modal-body code {
      font-family: var(--font-mono);
      font-size: 11.5px;
      padding: 2px 5px;
      border-radius: 4px;
      background: rgba(110, 118, 129, 0.2);
      color: var(--text-primary, #e6edf3);
    }

    .modal-body blockquote {
      border-left: 3px solid var(--accent, #58a6ff);
      margin: 12px 0;
      padding: 6px 12px;
      background: rgba(88, 166, 255, 0.08);
      color: var(--text-primary, #e6edf3);
      border-radius: 0 4px 4px 0;
    }

    .modal-body h1, .modal-body h2, .modal-body h3 {
      color: var(--text-primary, #e6edf3);
      margin: 16px 0 8px 0;
      border-bottom: 1px solid var(--border, #30363d);
      padding-bottom: 4px;
    }

    .modal-body p, .modal-body li {
      margin: 8px 0;
      color: var(--text-primary, #e6edf3);
    }

    /* Light Theme Modal Overrides */
    body.light-theme .modal-content {
      background: #ffffff !important;
      border-color: #d0d7de !important;
      box-shadow: 0 16px 36px rgba(0, 0, 0, 0.15) !important;
    }

    body.light-theme .modal-header {
      background: #ffffff !important;
      border-bottom-color: #d0d7de !important;
    }

    body.light-theme .modal-title {
      color: #1f2328 !important;
    }

    body.light-theme .modal-body {
      color: #1f2328 !important;
    }

    body.light-theme .modal-body p,
    body.light-theme .modal-body li {
      color: #1f2328 !important;
    }

    body.light-theme .modal-body h1,
    body.light-theme .modal-body h2,
    body.light-theme .modal-body h3 {
      border-bottom-color: #d0d7de !important;
      color: #1f2328 !important;
    }

    body.light-theme .modal-body pre {
      background: #f6f8fa !important;
      border-color: #d0d7de !important;
    }

    body.light-theme .modal-body pre code {
      background: transparent !important;
      color: #24292f !important;
    }

    body.light-theme .modal-body code {
      background: rgba(175, 184, 193, 0.2);
      color: #1f2328;
    }

    body.light-theme .modal-body blockquote {
      border-left-color: #0969da;
      background: #eef6ff;
      color: #1f2328;
    }

    .close-btn {
      background: transparent;
      border: none;
      color: var(--text-secondary, #8b949e);
      font-size: 20px;
      cursor: pointer;
      padding: 2px 8px;
      border-radius: 4px;
    }

    .close-btn:hover {
      background: var(--bg-tertiary, #21262d);
      color: var(--text-primary, #e6edf3);
    }

    body.light-theme .close-btn:hover {
      background: #eaeef2;
      color: #1f2328;
    }

    .print-header { display: none; }

    /* Multi-Page Print & PDF Engine Compliance */
    @media print {
      /* Universal print cleanup */
      * {
        backdrop-filter: none !important;
        -webkit-backdrop-filter: none !important;
      }

      html, body {
        height: auto !important;
        overflow: visible !important;
        background: #ffffff !important;
        color: #000000 !important;
        font-size: 10pt !important;
      }

      /* ------------------------------------------------------------- */
      /* Case A: When printing the DOCUMENT modal reader               */
      /* ------------------------------------------------------------- */
      body.printing-doc-modal header,
      body.printing-doc-modal .toolbar,
      body.printing-doc-modal footer,
      body.printing-doc-modal .table-viewport,
      body.printing-doc-modal .toast,
      body.printing-doc-modal .action-results-area,
      body.printing-doc-modal .print-header#print-header-block {
        display: none !important;
      }

      body.printing-doc-modal .modal-overlay {
        display: block !important;
        position: static !important;
        inset: auto !important;
        background: transparent !important;
        backdrop-filter: none !important;
        padding: 0 !important;
        width: 100% !important;
        height: auto !important;
        overflow: visible !important;
      }

      body.printing-doc-modal .modal-content {
        border: none !important;
        box-shadow: none !important;
        background: transparent !important;
        width: 100% !important;
        max-width: 100% !important;
        height: auto !important;
        overflow: visible !important;
      }

      body.printing-doc-modal .modal-header {
        background: transparent !important;
        border-bottom: 2px solid #000000 !important;
        padding: 0 0 10px 0 !important;
        margin-bottom: 14px !important;
        display: flex !important;
        justify-content: space-between !important;
        align-items: baseline !important;
      }

      body.printing-doc-modal .modal-header .modal-title {
        color: #000000 !important;
        font-size: 16pt !important;
        font-weight: 800 !important;
      }

      body.printing-doc-modal .modal-header .badge {
        color: #333333 !important;
        border: 1px solid #777777 !important;
        background: #f0f0f0 !important;
        font-size: 9pt !important;
      }

      body.printing-doc-modal .modal-header button,
      body.printing-doc-modal .modal-header .close-btn {
        display: none !important;
      }

      body.printing-doc-modal .modal-body {
        overflow: visible !important;
        height: auto !important;
        padding: 0 !important;
        color: #000000 !important;
      }

      body.printing-doc-modal .modal-body h1,
      body.printing-doc-modal .modal-body h2,
      body.printing-doc-modal .modal-body h3 {
        color: #000000 !important;
        border-bottom: 1px solid #cccccc !important;
        page-break-after: avoid !important;
      }

      body.printing-doc-modal .modal-body p,
      body.printing-doc-modal .modal-body li {
        color: #111111 !important;
      }

      body.printing-doc-modal .modal-body pre,
      body.printing-doc-modal .modal-body code {
        background: #f6f8fa !important;
        border: 1px solid #d0d7de !important;
        color: #24292f !important;
        page-break-inside: avoid !important;
      }

      body.printing-doc-modal .modal-body blockquote {
        border-left: 4px solid #d0d7de !important;
        color: #57606a !important;
      }

      /* ------------------------------------------------------------- */
      /* Case B: Default Table Print (when NOT printing modal)         */
      /* ------------------------------------------------------------- */
      body:not(.printing-doc-modal) header,
      body:not(.printing-doc-modal) .toolbar,
      body:not(.printing-doc-modal) footer,
      body:not(.printing-doc-modal) .modal-overlay,
      body:not(.printing-doc-modal) .toast,
      body:not(.printing-doc-modal) .action-results-area,
      body:not(.printing-doc-modal) .col-filter-row,
      body:not(.printing-doc-modal) .actions-cell,
      body:not(.printing-doc-modal) th.actions-cell,
      body:not(.printing-doc-modal) td.actions-cell {
        display: none !important;
      }

      body:not(.printing-doc-modal) .table-viewport {
        height: auto !important;
        overflow: visible !important;
        display: block !important;
        flex: none !important;
      }

      body:not(.printing-doc-modal) table {
        width: 100% !important;
        border-collapse: collapse !important;
        page-break-after: auto !important;
      }

      body:not(.printing-doc-modal) thead {
        display: table-header-group !important;
      }

      body:not(.printing-doc-modal) tr {
        page-break-inside: avoid !important;
        page-break-after: auto !important;
      }

      body:not(.printing-doc-modal) td,
      body:not(.printing-doc-modal) th {
        color: #000000 !important;
        background: #ffffff !important;
        border: 1px solid #cccccc !important;
        padding: 6px 8px !important;
        font-size: 8.5pt !important;
      }

      body:not(.printing-doc-modal) .print-header {
        display: block !important;
        margin-bottom: 12px;
        border-bottom: 2px solid #000000;
        padding-bottom: 6px;
      }
    }
  </style>
</head>
<body>

  <!-- Top Pinned Header -->
  <header>
    <div class="brand">
      <div class="brand-icon">📜</div>
      <div class="brand-titles">
        <h1>LCM Authoritative Rules Explorer <small>{{DISPLAY_VERSION}}</small></h1>
        <div class="subtitle">Canonical Hub: D:\Git_Repositories\.agents\rules\ | Single Source of Truth</div>
      </div>
    </div>
    <div class="header-badges">
      <span class="badge badge-primary" id="total-badge">19 Rules Loaded</span>
      <span class="badge badge-success">LCM 10.0.0</span>
    </div>
  </header>

  <!-- Pinned Toolbar & Filters -->
  <div class="toolbar">
    <div class="search-row">
      <div class="search-wrapper">
        <span class="search-icon">🔍</span>
        <input type="text" id="searchInput" placeholder="Global search across all fields (supports !term negation)..." oninput="applyFilters()" autofocus>
      </div>
      <div class="toolbar-actions">
        <button class="btn btn-export" id="btn-theme-toggle" onclick="toggleTheme()" title="Switch between Dark and Light display modes">
          <span id="theme-icon">☀️</span> <span id="theme-label">Light Mode</span>
        </button>
        <button class="btn btn-reset" onclick="resetFilters()" title="Reset all search queries and column selectors">
          <span>↺</span> <span>Reset Filters</span>
        </button>
        <button class="btn" onclick="openPrintModal()" title="Open multi-page print and PDF document generator">
          <span>🖨️</span> <span>Print / Preview</span>
        </button>
        <button class="btn btn-primary" onclick="copyAllRulesMarkdown()" title="Copy all rules as Markdown bundle and export synchronization files">
          <span>📋</span> <span>Copy All Rules (Markdown)</span>
        </button>
      </div>
    </div>
  </div>

  <!-- Action Results Banner (Multi-line persistent output area replacing pills) -->
  <div id="actionResultsArea" class="action-results-area" style="display: none;">
    <div class="action-results-header">
      <span class="action-results-title" id="actionResultsTitle">⚡ Action Result</span>
      <button class="action-results-close" onclick="closeActionResult()" title="Dismiss">✕</button>
    </div>
    <div class="action-results-content">
      <div class="action-result-line" id="actionResultLine1"></div>
      <div class="action-result-line" id="actionResultLine2"></div>
    </div>
  </div>

  <!-- Scrollable Table Viewport -->
  <div class="table-viewport">
    <div class="print-header" id="print-header-block">
      <div style="display: grid; grid-template-columns: 1fr auto 1fr; align-items: baseline;">
        <div style="font-size: 13pt; font-weight: 800; color: #000;">📜 LCM Authoritative Rules Explorer</div>
        <div style="font-size: 10pt; font-weight: 700; color: #333; text-align: center;">Governance Policies & Invariants</div>
        <div style="font-size: 8.5pt; font-family: monospace; color: #444; text-align: right;">SHOW_RULES.html</div>
      </div>
    </div>

    <table id="rulesTable">
      <thead>
        <!-- Column Titles -->
        <tr>
          <th onclick="sortTable('Name')" style="min-width: 200px;">Rule File <span id="sort-Name">▲</span></th>
          <th onclick="sortTable('Identifiers')" style="min-width: 140px;">Identifiers <span id="sort-Identifiers"></span></th>
          <th onclick="sortTable('Domain')" style="min-width: 150px;">Domain <span id="sort-Domain"></span></th>
          <th onclick="sortTable('Scope')" style="min-width: 130px;">Scope <span id="sort-Scope"></span></th>
          <th>Core Invariant / Normative Requirement</th>
          <th onclick="sortTable('SizeKb')" style="width: 80px; text-align: right;">Size <span id="sort-SizeKb"></span></th>
          <th class="actions-cell" style="width: 150px;">Actions</th>
        </tr>
        <!-- Column Header Dropdowns Row -->
        <tr class="col-filter-row">
          <th>
            <select class="col-filter-select" id="filter-rule" onchange="applyFilters()">
              <option value="All">All Rules</option>
            </select>
          </th>
          <th>
            <select class="col-filter-select" id="filter-id" onchange="applyFilters()">
              <option value="All">All Identifiers</option>
            </select>
          </th>
          <th>
            <select class="col-filter-select" id="filter-domain" onchange="applyFilters()">
              <option value="All">All Domains</option>
            </select>
          </th>
          <th>
            <select class="col-filter-select" id="filter-scope" onchange="applyFilters()">
              <option value="All">All Scopes</option>
            </select>
          </th>
          <th></th>
          <th></th>
          <th class="actions-cell"></th>
        </tr>
      </thead>
      <tbody id="rulesTbody">
        <!-- Rendered dynamically -->
      </tbody>
    </table>
  </div>

  <!-- Pinned Footer Dock -->
  <footer>
    <div id="statusCount">Showing 19 of 19 rules</div>
    <div class="daemon-indicator" id="daemonStatus">
      <div class="dot-green" id="daemonDot"></div>
      <span id="daemonText">REST Daemon Port 9876 Online</span>
    </div>
  </footer>

  <!-- Modal Reader -->
  <div class="modal-overlay" id="modalOverlay" onclick="closeModalOnBg(event)">
    <div class="modal-content">
      <div class="modal-header">
        <div class="modal-header-left">
          <span class="modal-title" id="modalTitle">Rule Policy</span>
          <span class="badge" id="modalPathBadge">.agents/rules/...</span>
        </div>
        <div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap;">
          <button class="btn btn-export" id="modalThemeBtn" onclick="toggleTheme()" title="Switch between Dark and Light display modes">
            <span id="modal-theme-icon">☀️</span> <span id="modal-theme-label">Light Mode</span>
          </button>
          <button class="btn" id="modalPrintBtn" onclick="printCurrentModalRule()" title="Print or save this rule document to PDF (Shortcut: Ctrl+P)">
            <span>🖨️</span> <span>Print Document</span>
          </button>
          <button class="btn btn-action primary" id="modalEditBtn" onclick="editCurrentModalRule()" title="Open file in Notepad++">
            <span>✏️</span> <span>Edit in Notepad++</span>
          </button>
          <button class="btn btn-action" id="modalCopyBtn" onclick="copyCurrentModalContent()" title="Copy entire document markdown">
            <span>📋</span> <span>Copy</span>
          </button>
          <button class="close-btn" onclick="closeModal()" title="Close Document Viewer (Shortcut: ESC)">✕</button>
        </div>
      </div>
      <div class="modal-body" id="modalBody">
        <!-- Markdown content rendered here -->
      </div>
    </div>
  </div>

  <script src="/assets/lcm-table-print-atom.js"></script>
  <script id="lcm-display-data" type="application/json">/*__RULES_JSON__*/</script>

  <script>
    let RULES_DATA = JSON.parse(document.getElementById('lcm-display-data').textContent).rules;
    const DAEMON_URL = 'http://127.0.0.1:9876';

    const displayQuery = new URLSearchParams(window.location.search);
    let initialDomain = displayQuery.has('Domain')
      ? displayQuery.get('Domain').slice(0, 200)
      : /*__INITIAL_DOMAIN__*/;
    let initialFilter = displayQuery.has('Filter')
      ? displayQuery.get('Filter').slice(0, 300)
      : /*__INITIAL_FILTER__*/;
    let currentSortField = 'Name';
    let currentSortAsc = true;
    let activeModalRule = null;
    let initialDropdownStateApplied = false;

    // Initialize Theme
    function initTheme() {
      const saved = localStorage.getItem('lcm_rules_theme') || 'dark';
      applyTheme(saved);
    }

    function toggleTheme() {
      const current = document.body.classList.contains('light-theme') ? 'light' : 'dark';
      const target = current === 'dark' ? 'light' : 'dark';
      applyTheme(target);
      localStorage.setItem('lcm_rules_theme', target);
    }

    function applyTheme(theme) {
      if (theme === 'light') {
        document.body.classList.add('light-theme');
        document.documentElement.setAttribute('data-theme', 'light');
        const label = document.getElementById('theme-label');
        const icon = document.getElementById('theme-icon');
        if (label) label.innerText = 'Dark Mode';
        if (icon) icon.innerText = '🌙';
        const mLabel = document.getElementById('modal-theme-label');
        const mIcon = document.getElementById('modal-theme-icon');
        if (mLabel) mLabel.innerText = 'Dark Mode';
        if (mIcon) mIcon.innerText = '🌙';
      } else {
        document.body.classList.remove('light-theme');
        document.documentElement.setAttribute('data-theme', 'dark');
        const label = document.getElementById('theme-label');
        const icon = document.getElementById('theme-icon');
        if (label) label.innerText = 'Light Mode';
        if (icon) icon.innerText = '☀️';
        const mLabel = document.getElementById('modal-theme-label');
        const mIcon = document.getElementById('modal-theme-icon');
        if (mLabel) mLabel.innerText = 'Light Mode';
        if (mIcon) mIcon.innerText = '☀️';
      }
    }

    // Check daemon connectivity
    async function checkDaemon() {
      try {
        const res = await fetch(DAEMON_URL + '/ping', { method: 'GET', signal: AbortSignal.timeout(1500) });
        if (res.ok) {
          document.getElementById('daemonDot').className = 'dot-green';
          document.getElementById('daemonText').innerText = 'REST Daemon Port 9876 Online';
          return true;
        }
      } catch (e) {}
      document.getElementById('daemonDot').className = 'dot-muted';
      document.getElementById('daemonText').innerText = 'REST Daemon Offline (Local Reader Active)';
      return false;
    }

    // Populate Column Header Dropdowns
    function populateDropdowns() {
      const rules = [...new Set(RULES_DATA.map(r => r.Name))].filter(Boolean).sort();
      const ids = [...new Set(RULES_DATA.map(r => r.Identifiers))].filter(Boolean).sort();
      const domains = [...new Set(RULES_DATA.map(r => r.Domain))].filter(Boolean).sort();
      const scopes = [...new Set(RULES_DATA.map(r => r.Scope))].filter(Boolean).sort();

      const ruleSel = document.getElementById('filter-rule');
      const idSel = document.getElementById('filter-id');
      const domainSel = document.getElementById('filter-domain');
      const scopeSel = document.getElementById('filter-scope');
      [[ruleSel, rules], [idSel, ids], [domainSel, domains], [scopeSel, scopes]].forEach(([select, values]) => {
        const selected = select.value;
        select.replaceChildren(new Option('All', 'All'));
        values.forEach(value => select.add(new Option(value, value)));
        select.value = values.includes(selected) ? selected : 'All';
      });

      if (!initialDropdownStateApplied && initialDomain && initialDomain !== 'All' && domains.includes(initialDomain)) {
        domainSel.value = initialDomain;
      }
      if (!initialDropdownStateApplied && initialFilter) {
        document.getElementById('searchInput').value = initialFilter;
      }
      initialDropdownStateApplied = true;
    }

    // Action Results Banner management
    function showActionResults(title, line1Html, line2Html) {
      const area = document.getElementById('actionResultsArea');
      const titleEl = document.getElementById('actionResultsTitle');
      const l1 = document.getElementById('actionResultLine1');
      const l2 = document.getElementById('actionResultLine2');

      titleEl.innerText = title || '⚡ Action Result';
      l1.innerHTML = line1Html || '';
      l2.innerHTML = line2Html || '';
      area.style.display = 'flex';
    }

    function closeActionResult() {
      document.getElementById('actionResultsArea').style.display = 'none';
    }

    function copyPathText(path) {
      navigator.clipboard.writeText(path);
      const l2 = document.getElementById('actionResultLine2');
      if (l2) {
        l2.innerHTML += ' <span style="color: var(--success); font-size: 11px;">(Copied to clipboard!)</span>';
      }
    }

    // Filter and Search logic
    function applyFilters() {
      const search = document.getElementById('searchInput').value.toLowerCase().trim();
      const selRule = document.getElementById('filter-rule')?.value || 'All';
      const selId = document.getElementById('filter-id')?.value || 'All';
      const selDomain = document.getElementById('filter-domain')?.value || 'All';
      const selScope = document.getElementById('filter-scope')?.value || 'All';

      const tokens = search ? search.split(/\s+/).filter(t => t.length > 0) : [];

      let filtered = RULES_DATA.filter(r => {
        if (selRule !== 'All' && r.Name !== selRule) return false;
        if (selId !== 'All' && r.Identifiers !== selId) return false;
        if (selDomain !== 'All' && r.Domain !== selDomain) return false;
        if (selScope !== 'All' && r.Scope !== selScope) return false;

        if (tokens.length === 0) return true;

        const hay = [r.Name, r.Identifiers, r.Domain, r.Scope, r.Invariant, r.Content].filter(Boolean).join(' ').toLowerCase();

        for (let t of tokens) {
          if (t.startsWith('!')) {
            const neg = t.slice(1);
            if (neg && hay.includes(neg)) return false;
          } else {
            if (!hay.includes(t)) return false;
          }
        }
        return true;
      });

      renderTableRows(filtered);
    }

    function resetFilters() {
      document.getElementById('searchInput').value = '';
      document.getElementById('filter-rule').value = 'All';
      document.getElementById('filter-id').value = 'All';
      document.getElementById('filter-domain').value = 'All';
      document.getElementById('filter-scope').value = 'All';
      applyFilters();
    }

    function sortTable(field) {
      if (currentSortField === field) {
        currentSortAsc = !currentSortAsc;
      } else {
        currentSortField = field;
        currentSortAsc = true;
      }
      ['Name', 'Identifiers', 'Domain', 'Scope', 'SizeKb'].forEach(f => {
        const el = document.getElementById('sort-' + f);
        if (el) el.innerText = (f === field) ? (currentSortAsc ? '▲' : '▼') : '';
      });
      applyFilters();
    }

    function renderTableRows(filtered) {
      const tbody = document.getElementById('rulesTbody');

      filtered.sort((a, b) => {
        let valA = a[currentSortField] || '';
        let valB = b[currentSortField] || '';
        if (typeof valA === 'string') valA = valA.toLowerCase();
        if (typeof valB === 'string') valB = valB.toLowerCase();
        if (valA < valB) return currentSortAsc ? -1 : 1;
        if (valA > valB) return currentSortAsc ? 1 : -1;
        return 0;
      });

      tbody.innerHTML = '';
      filtered.forEach(r => {
        const tr = document.createElement('tr');
        const safeName = escapeHtml(r.Name);
        const safeIds = escapeHtml(r.Identifiers);
        const safeDomain = escapeHtml(r.Domain);
        const safeScope = escapeHtml(r.Scope);
        const safeInv = escapeHtml(r.Invariant);
        const safePath = r.Path.replace(/\\/g, '\\\\');

        tr.innerHTML = `
          <td>
            <span class="rule-name" onclick="openRuleModalByName('${safeName}')" title="View rule specification">
              📄 ${safeName}
            </span>
          </td>
          <td><span class="rule-id-badge">${safeIds}</span></td>
          <td><span class="domain-tag">${safeDomain}</span></td>
          <td><span class="scope-text">${safeScope}</span></td>
          <td><div class="invariant-text">${safeInv}</div></td>
          <td style="font-family: var(--font-mono); font-size: 11px; text-align: right; color: var(--text-secondary);">${r.SizeKb} KB</td>
          <td class="actions-cell">
            <button class="btn-action primary" onclick="openRuleModalByName('${safeName}')" title="View Full Document">👁️ Read</button>
            <button class="btn-action" onclick="editInNotepadPP('${safePath}')" title="Open in Notepad++">✏️ Edit</button>
            <button class="btn-action" onclick="copyRulePath('${safePath}')" title="Copy Path">📋 Path</button>
          </td>
        `;
        tbody.appendChild(tr);
      });

      document.getElementById('statusCount').innerText = `Showing ${filtered.length} of ${RULES_DATA.length} rules`;
      document.getElementById('total-badge').innerText = `${filtered.length} Rules Shown`;
    }

    // Modal view
    function openRuleModalByName(name) {
      const rule = RULES_DATA.find(r => r.Name === name);
      if (!rule) return;
      activeModalRule = rule;

      document.getElementById('modalTitle').innerText = rule.Name;
      document.getElementById('modalPathBadge').innerText = rule.RelativePath;
      document.getElementById('modalBody').innerHTML = renderMarkdown(rule.Content);
      document.getElementById('modalOverlay').classList.add('open');
      document.body.classList.add('modal-open');
    }

    function closeModal() {
      document.getElementById('modalOverlay').classList.remove('open');
      document.body.classList.remove('modal-open');
      document.body.classList.remove('printing-doc-modal');
      activeModalRule = null;
    }

    function closeModalOnBg(e) {
      if (e.target.id === 'modalOverlay') {
        closeModal();
      }
    }

    function printCurrentModalRule() {
      if (!activeModalRule) return;

      // Blur any active element to prevent Chromium focus/caret lock
      if (document.activeElement && typeof document.activeElement.blur === 'function') {
        document.activeElement.blur();
      }

      document.body.classList.add('printing-doc-modal');

      // Brief tick to allow media styles to bind cleanly before print dialog
      setTimeout(() => {
        window.print();
      }, 80);
    }

    function editCurrentModalRule() {
      if (activeModalRule) {
        editInNotepadPP(activeModalRule.Path);
      }
    }

    function copyCurrentModalContent() {
      if (activeModalRule) {
        navigator.clipboard.writeText(activeModalRule.Content);
        showActionResults(
          '📋 Content Copied',
          `<span>Copied entire contents of <strong>${activeModalRule.Name}</strong> (${activeModalRule.Lines} lines) to clipboard.</span>`,
          `<span>Location: <code>${activeModalRule.Path}</code></span>`
        );
      }
    }

    // Edit function routing directly to Notepad++ via REST daemon
    async function editInNotepadPP(fullPath) {
      const cleanPath = fullPath.replace(/\\\\/g, '\\');
      const escapedForJs = fullPath.replace(/\\/g, '\\\\');

      // 1. Dispatch Notepad++ via REST Daemon /execute
      try {
        const cmd = `notepad++ "${cleanPath}"`;
        const res = await fetch(DAEMON_URL + '/execute', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ command: cmd, elevated: false, noExit: false })
        });
        if (res.ok) {
          showActionResults(
            '✏️ Editor Dispatched (Notepad++)',
            `<span>📄 Opened in Notepad++: <strong>${cleanPath}</strong></span> <button class="action-result-btn" onclick="copyPathText('${escapedForJs}')">📋 Copy Path</button>`,
            `<span>⚠️ <strong>Governance Notice</strong>: Modifying authoritative rules requires an explicit Change Request Proposal (CRP) per RULE-LCM-012.</span>`
          );
          return;
        }
      } catch (e) {}

      // 2. Fallback via /open_editor
      try {
        const res = await fetch(DAEMON_URL + '/open_editor', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ filePath: cleanPath, line: 1 })
        });
        if (res.ok) {
          showActionResults(
            '✏️ Editor Dispatched',
            `<span>📄 Opened: <strong>${cleanPath}</strong></span> <button class="action-result-btn" onclick="copyPathText('${escapedForJs}')">📋 Copy Path</button>`,
            `<span>⚠️ <strong>Governance Notice</strong>: Modifying authoritative rules requires a formal CRP per RULE-LCM-012.</span>`
          );
          return;
        }
      } catch (e) {}

      // 3. Fallback: Copy to clipboard
      navigator.clipboard.writeText(cleanPath);
      showActionResults(
        '📋 Copied Path (REST Daemon Offline)',
        `<span>📄 File: <strong>${cleanPath}</strong> (Copied to Clipboard)</span>`,
        `<span>Command: <code>notepad++ "${cleanPath}"</code> • Note: Rule changes require a formal CRP.</span>`
      );
    }

    function copyRulePath(path) {
      const clean = path.replace(/\\\\/g, '\\');
      navigator.clipboard.writeText(clean);
      showActionResults(
        '📋 Path Copied to Clipboard',
        `<span>Location: <strong>${clean}</strong></span>`,
        `<span>Ready for shell dispatch or documentation referencing.</span>`
      );
    }

    // Export / Copy All Rules (Markdown) with persistent 2-line results
    async function copyAllRulesMarkdown() {
      let md = '# Consolidated Lifecycle Model (LCM) Rules\n\n';
      RULES_DATA.forEach(r => {
        md += `## ${r.Name} (${r.Identifiers})\n`;
        md += `**Domain**: ${r.Domain} | **Scope**: ${r.Scope}\n\n`;
        md += `${r.Content}\n\n---\n\n`;
      });
      try {
        await navigator.clipboard.writeText(md);
      } catch (e) {}

      const exportMd = 'D:\\Git_Repositories\\LCM_AI\\docs\\LCM_Rules_Gemini_Export.md';
      const crossRefMd = 'D:\\Git_Repositories\\LCM_AI\\docs\\LCM-Rules-Cross-Reference.md';
      const exportMdEsc = exportMd.replace(/\\/g, '\\\\');
      const crossRefMdEsc = crossRefMd.replace(/\\/g, '\\\\');

      showActionResults(
        '📋 Export & Clipboard Synchronization Result',
        `<span>✅ Copied to Clipboard & Export Target: <strong>${exportMd}</strong></span> <button class="action-result-btn" onclick="editInNotepadPP('${exportMdEsc}')">✏️ Notepad++</button> <button class="action-result-btn" onclick="copyPathText('${exportMdEsc}')">📋 Path</button>`,
        `<span>✅ Authoritative Rules Matrix: <strong>${crossRefMd}</strong></span> <button class="action-result-btn" onclick="editInNotepadPP('${crossRefMdEsc}')">✏️ Notepad++</button> <button class="action-result-btn" onclick="copyPathText('${crossRefMdEsc}')">📋 Path</button>`
      );
    }

    // Multi-page Print / Preview Modal via LcmTablePrintAtom
    function openPrintModal() {
      if (window.LcmTablePrintAtom) {
        window.LcmTablePrintAtom.openModal();
      } else {
        window.print();
      }
    }

    function escapeHtml(str) {
      if (!str) return '';
      return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function renderMarkdown(md) {
      if (!md) return '';
      let html = md;
      html = html.replace(/```([a-z0-9_-]*)\n([\s\S]*?)```/g, (m, lang, code) => {
        return `<pre><code>${escapeHtml(code)}</code></pre>`;
      });
      html = html.replace(/`([^`]+)`/g, (m, code) => `<code>${escapeHtml(code)}</code>`);
      html = html.replace(/^### (.*$)/gim, '<h3>$1</h3>');
      html = html.replace(/^## (.*$)/gim, '<h2>$1</h2>');
      html = html.replace(/^# (.*$)/gim, '<h1>$1</h1>');
      html = html.replace(/^\> (.*$)/gim, '<blockquote>$1</blockquote>');
      html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
      html = html.replace(/\*([^*]+)\*/g, '<em>$1</em>');
      html = html.replace(/^\s*-\s+(.*$)/gim, '<li>$1</li>');
      html = html.replace(/\n\n/g, '<p></p>');
      return html;
    }

    // Refresh rules from disk via daemon re-query
    async function refreshRules() {
      if (!window.LcmDisplay || typeof window.LcmDisplay.refresh !== 'function') {
        showActionResults('Refresh unavailable', '<span>The current rules snapshot is retained.</span>', '');
        return;
      }
      return window.LcmDisplay.refresh();
    }

    // Keyboard navigation
    window.addEventListener('keydown', (e) => {
      if (e.key === 'F5' || e.code === 'F5') {
        e.preventDefault();
        refreshRules();
      } else if (e.key === 'Escape') {
        if (document.getElementById('modalOverlay').classList.contains('open')) {
          closeModal();
        } else if (document.getElementById('actionResultsArea').style.display !== 'none') {
          closeActionResult();
        }
      } else if ((e.ctrlKey || e.metaKey) && (e.key === 'p' || e.key === 'P')) {
        e.preventDefault();
        const overlay = document.getElementById('modalOverlay');
        if (overlay && overlay.classList.contains('open')) {
          printCurrentModalRule();
        } else {
          openPrintModal();
        }
      }
    });

    // Print Lifecycle Hardening: Prevent Compositor/Thread Deadlock
    window.addEventListener('beforeprint', () => {
      const overlay = document.getElementById('modalOverlay');
      if (overlay && overlay.classList.contains('open')) {
        document.body.classList.add('printing-doc-modal');
      }
    });

    window.addEventListener('afterprint', () => {
      document.body.classList.remove('printing-doc-modal');
      // Force compositor/layout refresh to prevent Chromium frozen state
      window.requestAnimationFrame(() => {
        const overlay = document.getElementById('modalOverlay');
        if (overlay && overlay.classList.contains('open')) {
          overlay.style.display = 'none';
          void overlay.offsetHeight; // force DOM reflow
          overlay.style.display = 'flex';
        }
      });
    });

    // Startup sequence
    initTheme();
    populateDropdowns();
    checkDaemon();

    if (window.LcmTablePrintAtom) {
      window.LcmTablePrintAtom.init({
        documentTitle: 'LCM Authoritative Rules Explorer',
        subsystem: 'LCM',
        tableSelector: '#rulesTable',
        tbodySelector: '#rulesTbody',
        getViewMode: () => 'Canonical Governance Rules',
        getFileName: () => 'SHOW_RULES.html',
        getDate: () => new Date().toISOString().replace('T', ' ').substring(0, 19),
        getFilterSummary: () => {
          const s = document.getElementById('searchInput')?.value.trim();
          const d = document.getElementById('filter-domain')?.value;
          const r = document.getElementById('filter-rule')?.value;
          let parts = [];
          if (s) parts.push('Search: "' + s + '"');
          if (d && d !== 'All') parts.push('Domain: ' + d);
          if (r && r !== 'All') parts.push('Rule: ' + r);
          return parts.length ? parts.join(' • ') : 'All 19 Canonical Rules';
        }
      });
    }

    applyFilters();

    window.LcmDisplayApply = async function(html) {
      const parsedDocument = new DOMParser().parseFromString(html, 'text/html');
      const payloadNode = parsedDocument.querySelector('script#lcm-display-data[type="application/json"]');
      if (!payloadNode) throw new Error('Published rules page has no JSON display payload.');
      const payload = JSON.parse(payloadNode.textContent);
      if (!payload || !Array.isArray(payload.rules)) throw new Error('Published rules payload is malformed.');
      const modalName = activeModalRule?.Name;
      RULES_DATA = payload.rules;
      populateDropdowns();
      applyFilters();
      if (modalName && RULES_DATA.some(rule => rule.Name === modalName)) openRuleModalByName(modalName);
    };

    window.LcmDisplayCaptureState = function() {
      return { sortField: currentSortField, sortAsc: currentSortAsc, modalRule: activeModalRule?.Name || null };
    };

    window.LcmDisplayRestoreState = function(state) {
      if (!state || typeof state !== 'object') return;
      if (typeof state.sortField === 'string') currentSortField = state.sortField;
      if (typeof state.sortAsc === 'boolean') currentSortAsc = state.sortAsc;
      applyFilters();
      if (state.modalRule && RULES_DATA.some(rule => rule.Name === state.modalRule)) openRuleModalByName(state.modalRule);
    };
  </script>
</body>
</html>
'@

$safeDomainJson = $Domain | ConvertTo-Json -Compress
$safeFilterJson = $Filter | ConvertTo-Json -Compress

$htmlContent = $htmlTemplate.Replace('{{DISPLAY_VERSION}}', $provenance.Label)
$htmlContent = $htmlContent.Replace('/*__RULES_JSON__*/', $rulesJson)
$htmlContent = $htmlContent.Replace('/*__INITIAL_DOMAIN__*/', $safeDomainJson)
$htmlContent = $htmlContent.Replace('/*__INITIAL_FILTER__*/', $safeFilterJson)

$renderedHtmlPath = Join-Path $artifactsDir 'SHOW_RULES.html'
[System.IO.File]::WriteAllText($renderedHtmlPath, $htmlContent, [System.Text.UTF8Encoding]::new($false))

Write-ToolLog -Message "Interactive HTML dashboard rendered: $renderedHtmlPath" -Level ACTION

# ------------------------------------------------------------------------------
# 5. Dispatch to Session 1 Interactive Desktop
# ------------------------------------------------------------------------------
if (-not $NoLaunch) {
  $standardDisplayModule = Join-Path $lcmRoot 'modules\LcmStandardDisplay.psm1'
  if (-not (Test-Path -LiteralPath $standardDisplayModule -PathType Leaf)) {
    throw "Standard Display launcher module is missing: $standardDisplayModule"
  }
  Import-Module -Name $standardDisplayModule -Force
  Open-LcmStandardDisplay -DisplayId rules -Pane:$Pane -Parameters @{
    Domain = $Domain
    Filter = $Filter
  }

  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM AUTHORITATIVE RULES EXPLORER (v$scriptVersion)" -ForegroundColor Green
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " Dashboard: $renderedHtmlPath"
  Write-Host " Rules Hub: $rulesHubDir (Total: $($ruleEntries.Count))"
  Write-Host " Status   : Launched through port 9876 HTTP Standard Display" -ForegroundColor Green
  Write-Host "==========================================================================" -ForegroundColor Cyan
} else {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM AUTHORITATIVE RULES EXPLORER (v$($scriptVersion))" -ForegroundColor Green
  Write-Host " Dashboard rendered cleanly: $renderedHtmlPath"
  Write-Host " Browser launch suppressed via -NoLaunch." -ForegroundColor DarkGray
  Write-Host "==========================================================================" -ForegroundColor Cyan
}
