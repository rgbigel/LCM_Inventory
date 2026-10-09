<#
.SYNOPSIS
  Consolidates and exports all active LCM rules and governance files into a unified markdown artifact.
.DESCRIPTION
  Module: Export-LCMRules
  Purpose: Aggregates, cleans, and structures all authoritative LCM governance policies from
           .agents/rules/, AGENTS.md, and GEMINI.md into a single consolidated markdown artifact
           optimized for Gemini Gems, Google Drive synchronization, and model context initialization.
           Supports 1-click clipboard export (-ToClipboard) and multi-destination saving.
           Conforms to RULE-PS-008 (Metadata Headers), RULE-PS-009 (Audit Logging), and RULE-PS-010 (CLI Help).
  Path: tools/Export-LCMRules.ps1
  Authors: Rolf, LCM_AI Governance
  Version: 1.2.0
  Date: 2026-08-26
.PARAMETER OutputPath
  Target file path for the consolidated markdown artifact. Defaults to LCM_AI/docs/LCM_Rules_Gemini_Export.md.
.PARAMETER ToClipboard
  Copies the consolidated governance rules directly to the Windows clipboard for instant pasting (Aliases: -c, -CopyToClipboard).
.PARAMETER GoogleDrivePath
  Optional mirror directory path (e.g. Google Drive sync folder).
.PARAMETER LogFile
  Custom log file destination. Defaults to tools/logs/Export-LCMRules-yyyyMMdd_HHmmss.log.
.PARAMETER Help
  Displays this comprehensive parameter reference and usage instructions (Aliases: -h, -?).
.EXAMPLE
  pwsh tools/Export-LCMRules.ps1 -h
.EXAMPLE
  pwsh tools/Export-LCMRules.ps1 -ToClipboard
.EXAMPLE
  pwsh tools/Export-LCMRules.ps1 -OutputPath "D:\GoogleDrive\LCM_Rules.md"
#>

[CmdletBinding()]
param(
  [string]$OutputPath = "",
  
  [Alias('c', 'CopyToClipboard')]
  [switch]$ToClipboard,

  [string]$GoogleDrivePath = "",

  [string]$LogFile = "",

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = "1.2.0"
$scriptName = "Export-LCMRules"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM RULES CONSOLIDATION & GEMINI EXPORTER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Consolidates all 16 canonical LCM governance rules, AGENTS.md, and GEMINI.md"
  Write-Host "  into a clean, unified markdown artifact for Gemini Gems and cloud sync."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Export-LCMRules.ps1 [-ToClipboard] [-OutputPath <Path>] [-GoogleDrivePath <Path>] [-h]"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -ToClipboard, -c  : Copies the consolidated ruleset directly into the Windows clipboard."
  Write-Host "  -OutputPath <str> : Destination file path (Default: LCM_AI/docs/LCM_Rules_Gemini_Export.md)."
  Write-Host "  -GoogleDrivePath  : Optional mirror file path in local Google Drive sync directory."
  Write-Host "  -LogFile <str>    : Custom log file destination."
  Write-Host "  -h, -Help, -?     : Displays this parameter reference."
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  pwsh tools/Export-LCMRules.ps1 -ToClipboard"
  Write-Host "  pwsh tools/Export-LCMRules.ps1 -OutputPath 'D:\Backup\LCM_Rules.md'"
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Initialize Logging Context per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = 'D:\Git_Repositories'
$lcdRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcdRoot 'tools'
$logDir = Join-Path $lcdRoot 'data\logs\lcm'
if (-not (Test-Path -Path $logDir)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $LogFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"
}
$script:ActiveLogFile = $LogFile

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

  if (-not $LogOnly) {
    switch ($Level) {
      "WARN"    { Write-Warning $Message }
      "ERROR"   { Write-Error $Message }
      "DEBUG"   { Write-Host "  [DEBUG] $Message" -ForegroundColor DarkGray }
      "ACTION"  { Write-Host "  -> $Message" -ForegroundColor Green }
      "SUMMARY" { Write-Host $Message -ForegroundColor Cyan }
      default   { Write-Host $Message }
    }
  }
}

Write-ToolLog -Message "==========================================================================" -Level INFO
Write-ToolLog -Message " LCM RULES CONSOLIDATION & GEMINI EXPORTER (v$($scriptVersion))" -Level INFO
Write-ToolLog -Message " Log File : $($LogFile)" -Level INFO
Write-ToolLog -Message " Date     : $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | Host: $($env:COMPUTERNAME)" -Level INFO
Write-ToolLog -Message "==========================================================================" -Level INFO

# Default output paths
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $docsDir = Join-Path $workspaceRoot "LCM_AI\docs"
  if (-not (Test-Path -Path $docsDir)) {
    New-Item -Path $docsDir -ItemType Directory -Force | Out-Null
  }
  $OutputPath = Join-Path $docsDir "LCM_Rules_Gemini_Export.md"
}

$rulesDir = Join-Path $workspaceRoot "LCM_AI\.agents\rules"
if (-not (Test-Path -Path $rulesDir)) {
  $rulesDir = Join-Path $workspaceRoot ".agents\rules"
}
if (-not (Test-Path -Path $rulesDir)) {
  $errMsg = "Canonical rules directory not found in LCM_AI\.agents\rules or .agents\rules"
  Write-ToolLog -Message $errMsg -Level ERROR
  throw $errMsg
}

# ------------------------------------------------------------------------------
# 2. Define Logical Rule Order & Tier Hierarchy
# ------------------------------------------------------------------------------
$orderedRuleFiles = @(
  # Tier 1: Core Authority, Invariants & Security
  @{ Section = "1. Core Governance, Invariants & Security"; File = "RuleAuthority.md" },
  @{ Section = "1. Core Governance, Invariants & Security"; File = "InvariantRules.md" },
  @{ Section = "1. Core Governance, Invariants & Security"; File = "ElevationPolicy.md" },
  @{ Section = "1. Core Governance, Invariants & Security"; File = "LanguagePolicy.md" },
  @{ Section = "1. Core Governance, Invariants & Security"; File = "RepositoryContextPolicy.md" },

  # Tier 2: Proposal & Review Flow
  @{ Section = "2. Proposal, Review & Commit Lifecycle"; File = "ProposalReviewFlowPolicy.md" },
  @{ Section = "2. Proposal, Review & Commit Lifecycle"; File = "ReviewCommitGovernancePolicy.md" },
  @{ Section = "2. Proposal, Review & Commit Lifecycle"; File = "MethodEfficiencyPolicy.md" },

  # Tier 3: Code & Scripting Standards
  @{ Section = "3. Language & Coding Standards"; File = "PowerShellStandardsPolicy.md" },
  @{ Section = "3. Language & Coding Standards"; File = "PowerShellRules.md" },
  @{ Section = "3. Language & Coding Standards"; File = "PythonRules.md" },
  @{ Section = "3. Language & Coding Standards"; File = "CMDRules.md" },
  @{ Section = "3. Language & Coding Standards"; File = "JsonRules.md" },

  # Tier 4: Documentation & Subsystem Architecture
  @{ Section = "4. Documentation & Subsystem Architecture"; File = "DocumentationStandardsPolicy.md" },
  @{ Section = "4. Documentation & Subsystem Architecture"; File = "SubsystemGovernancePolicy.md" },
  @{ Section = "4. Documentation & Subsystem Architecture"; File = "macro-definitions.md" }
)

function Clean-MarkdownContent {
  param([string]$RawText)
  
  # Strip YAML frontmatter (--- ... ---)
  $cleaned = $RawText
  if ($cleaned -match '(?s)^---\r?\n.*?\r?\n---\r?\n(.*)$') {
    $cleaned = $matches[1]
  }

  # Strip redundant HTML mirror comments
  $cleaned = $cleaned -replace '(?s)<!-- ===================================================================== -->.*?<!-- ===================================================================== -->\r?\n', ''
  
  return $cleaned.Trim()
}

# ------------------------------------------------------------------------------
# 3. Build Consolidated Markdown Document
# ------------------------------------------------------------------------------
Write-ToolLog -Message "Aggregating canonical rules from $rulesDir..." -Level INFO

$exportTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$sb = [System.Text.StringBuilder]::new()

$sb.AppendLine("# Lifecycle Model (LCM) Authoritative Governance Framework") | Out-Null
$sb.AppendLine("> **Consolidated Master Specification for Gemini AI, Google Drive & Subagents**") | Out-Null
$sb.AppendLine("> *Exported on: $exportTimestamp | Host: $env:COMPUTERNAME | Version: $scriptVersion*") | Out-Null
$sb.AppendLine("") | Out-Null
$sb.AppendLine("---") | Out-Null
$sb.AppendLine("") | Out-Null

# Table of Contents
$sb.AppendLine("## 📑 Governance Matrix Table of Contents") | Out-Null
$currentSec = ""
$ruleIdx = 1

foreach ($rf in $orderedRuleFiles) {
  if ($rf.Section -ne $currentSec) {
    $currentSec = $rf.Section
    $sb.AppendLine("`n### $currentSec") | Out-Null
  }
  $cleanAnchor = $rf.File.ToLower().Replace('.', '').Replace(' ', '-')
  $sb.AppendLine("- [$ruleIdx. $($rf.File)](#$cleanAnchor)") | Out-Null
  $ruleIdx++
}

$sb.AppendLine("- [$ruleIdx. Workspace AGENTS.md Directive](#workspace-agentsmd-directive)") | Out-Null
$sb.AppendLine("- [$($ruleIdx + 1). Workspace GEMINI.md Directive](#workspace-geminimd-directive)") | Out-Null
$sb.AppendLine("") | Out-Null
$sb.AppendLine("---") | Out-Null
$sb.AppendLine("") | Out-Null

# Append each rule file
$ruleNum = 1
$processedCount = 0
foreach ($rf in $orderedRuleFiles) {
  $filePath = Join-Path $rulesDir $rf.File
  if (Test-Path -Path $filePath) {
    $raw = Get-Content -Path $filePath -Raw -Encoding UTF8
    $cleaned = Clean-MarkdownContent -RawText $raw
    $cleanAnchor = $rf.File.ToLower().Replace('.', '').Replace(' ', '-')
    
    $sb.AppendLine("<a id=`"$cleanAnchor`"></a>") | Out-Null
    $sb.AppendLine("## Rule #$ruleNum`: $($rf.File)") | Out-Null
    $sb.AppendLine("> **Category**: $($rf.Section) | **Canonical Source**: ``.agents/rules/$($rf.File)``") | Out-Null
    $sb.AppendLine("") | Out-Null
    $sb.AppendLine($cleaned) | Out-Null
    $sb.AppendLine("") | Out-Null
    $sb.AppendLine("---") | Out-Null
    $sb.AppendLine("") | Out-Null
    
    $ruleNum++
    $processedCount++
  } else {
    Write-ToolLog -Message "Warning: Rule file not found: $($rf.File)" -Level WARN
  }
}

# Append Root AGENTS.md
$agentsMd = Join-Path $workspaceRoot "AGENTS.md"
if (Test-Path -Path $agentsMd) {
  $raw = Get-Content -Path $agentsMd -Raw -Encoding UTF8
  $cleaned = Clean-MarkdownContent -RawText $raw
  $sb.AppendLine('<a id="workspace-agentsmd-directive"></a>') | Out-Null
  $sb.AppendLine("## Rule #$ruleNum`: Root AGENTS.md Directive") | Out-Null
  $sb.AppendLine('> **Canonical Source**: `AGENTS.md` (Root Workspace Controller)') | Out-Null
  $sb.AppendLine("") | Out-Null
  $sb.AppendLine($cleaned) | Out-Null
  $sb.AppendLine("") | Out-Null
  $sb.AppendLine("---") | Out-Null
  $sb.AppendLine("") | Out-Null
  $ruleNum++
  $processedCount++
}

# Append Root GEMINI.md
$geminiMd = Join-Path $workspaceRoot "GEMINI.md"
if (Test-Path -Path $geminiMd) {
  $raw = Get-Content -Path $geminiMd -Raw -Encoding UTF8
  $cleaned = Clean-MarkdownContent -RawText $raw
  $sb.AppendLine('<a id="workspace-geminimd-directive"></a>') | Out-Null
  $sb.AppendLine("## Rule #$ruleNum`: Root GEMINI.md Directive") | Out-Null
  $sb.AppendLine('> **Canonical Source**: `GEMINI.md` (Gemini Directive)') | Out-Null
  $sb.AppendLine("") | Out-Null
  $sb.AppendLine($cleaned) | Out-Null
  $sb.AppendLine("") | Out-Null
}

$finalMarkdown = $sb.ToString()

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# 4. Save to Output Files & Google Drive Mirrors (.md & .txt formats)
# ------------------------------------------------------------------------------
$outDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path -Path $outDir)) {
  New-Item -Path $outDir -ItemType Directory -Force | Out-Null
}

# 4.1 Save Markdown and Plain Text master copies
[System.IO.File]::WriteAllText($OutputPath, $finalMarkdown, [System.Text.Encoding]::UTF8)

$textOutputPath = [System.IO.Path]::ChangeExtension($OutputPath, ".txt")
[System.IO.File]::WriteAllText($textOutputPath, $finalMarkdown, [System.Text.Encoding]::UTF8)

$shortTextPath = Join-Path $outDir "LCM_Rules.txt"
[System.IO.File]::WriteAllText($shortTextPath, $finalMarkdown, [System.Text.Encoding]::UTF8)

Write-ToolLog -Message "Saved consolidated rules ($($finalMarkdown.Length) chars, $($processedCount) rules) to: $OutputPath" -Level ACTION
Write-ToolLog -Message "Saved plain-text Gemini mirror to: $textOutputPath" -Level ACTION

# 4.2 Auto-detect active Google Drive mirror destinations (Authoritative path: D:\GDrive)
$candidateGDrives = [System.Collections.Generic.List[string]]::new()
if (-not [string]::IsNullOrWhiteSpace($GoogleDrivePath)) {
  $candidateGDrives.Add($GoogleDrivePath)
}
if (Test-Path -LiteralPath "D:\GDrive") {
  $candidateGDrives.Add("D:\GDrive\LCM")
  $candidateGDrives.Add("D:\GDrive")
}

$mirroredPaths = [System.Collections.Generic.List[string]]::new()
foreach ($cand in $candidateGDrives) {
  try {
    if (-not (Test-Path -LiteralPath $cand)) { New-Item -Path $cand -ItemType Directory -Force | Out-Null }
      
      # Mirror .md and .txt rules
      $targetRulesMd = Join-Path $cand "LCM_Rules_Gemini_Export.md"
      $targetRulesTxt = Join-Path $cand "LCM_Rules_Gemini_Export.txt"
      $targetShortTxt = Join-Path $cand "LCM_Rules.txt"
      
      [System.IO.File]::WriteAllText($targetRulesMd, $finalMarkdown, [System.Text.Encoding]::UTF8)
      [System.IO.File]::WriteAllText($targetRulesTxt, $finalMarkdown, [System.Text.Encoding]::UTF8)
      [System.IO.File]::WriteAllText($targetShortTxt, $finalMarkdown, [System.Text.Encoding]::UTF8)
      
      $mirroredPaths.Add($targetRulesTxt) | Out-Null
      Write-ToolLog -Message "Mirrored .md and .txt rules to: $cand" -Level ACTION

      # Also mirror tool_catalog.json and tool_catalog.txt
      $catalogSource = Join-Path $toolsDir "tool_catalog.json"
      if (Test-Path -Path $catalogSource) {
        $targetCatalogJson = Join-Path $cand "tool_catalog.json"
        $targetCatalogTxt = Join-Path $cand "tool_catalog.txt"
        Copy-Item -Path $catalogSource -Destination $targetCatalogJson -Force
        Copy-Item -Path $catalogSource -Destination $targetCatalogTxt -Force
        Write-ToolLog -Message "Mirrored tool_catalog (.json & .txt) to: $cand" -Level ACTION
      }
    } catch {
      Write-ToolLog -Message "Notice: Mirror attempt to $cand skipped ($($_.Exception.Message))" -Level DEBUG
    }
}

# ------------------------------------------------------------------------------
# 5. Clipboard Integration (-ToClipboard)
# ------------------------------------------------------------------------------
if ($ToClipboard) {
  Set-Clipboard -Value $finalMarkdown
  Write-ToolLog -Message "Consolidated governance text copied to Windows clipboard (Ready for Gemini Gem paste)!" -Level ACTION
}

# ------------------------------------------------------------------------------
# 6. Authoritative Summary Footer (RULE-PS-009)
# ------------------------------------------------------------------------------
$now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
Write-ToolLog -Message "" -Level INFO
Write-ToolLog -Message "==========================================================================" -Level SUMMARY
Write-ToolLog -Message " [SUMMARY] $scriptName (v$($scriptVersion))" -Level SUMMARY
Write-ToolLog -Message " Status        : COMPLETED" -Level SUMMARY
Write-ToolLog -Message " Rules Bundled : $processedCount" -Level SUMMARY
Write-ToolLog -Message " Target Output : $OutputPath" -Level SUMMARY
Write-ToolLog -Message " Clipboard     : $(if ($ToClipboard) { 'COPIED' } else { 'NO' })" -Level SUMMARY
Write-ToolLog -Message " Timestamp     : $now" -Level SUMMARY
Write-ToolLog -Message " Log File      : $LogFile" -Level SUMMARY
Write-ToolLog -Message "==========================================================================" -Level SUMMARY

