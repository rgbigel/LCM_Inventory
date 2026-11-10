<#
.SYNOPSIS
  Formats, audits, and converts diagrammatic structures in Markdown and CM documents into Mermaid diagrams.

.DESCRIPTION
  Module: Format-LcmMarkdownDiagrams
  Purpose: Enforces the authoritative Mermaid diagramming standard across LCM documentation.
           Validates that all Mermaid diagram boxes declare the minimum 8pt typography constraint
           (classDef default font-size:8pt;) and detects legacy ASCII box art (+---+) for conversion.
           Supports execution across Git_root, Repo, Folder, and Document scopes.
  Path: LCM_Inventory/tools/Format-LcmMarkdownDiagrams.ps1
  Authors: Rolf, LCM_AI Governance
  Version: 10.2.0
  Date: 2026-10-13

.PARAMETER Scope
  Execution scope: 'Git_root', 'Repo', 'Folder', 'Document', or 'Auto' (default).

.PARAMETER Target
  Target path for the selected scope. If omitted, automatically resolves from current directory or Git_Root.

.PARAMETER FontSize
  Target minimum font size for Mermaid diagram boxes. Defaults to '8pt'.

.PARAMETER Inspect
  Scans and audits files, reporting candidate diagrams and legacy ASCII boxes without making modifications.

.PARAMETER Fix
  Applies diagram formatting and font-size rule enforcement in-place.

.PARAMETER LogFile
  Custom log file destination. Defaults to LCM_Inventory/data/logs/lcm/Format-LcmMarkdownDiagrams-yyyyMMdd_HHmmss.log.

.PARAMETER Help
  Displays parameter reference and usage instructions (Aliases: -h, -?).

.EXAMPLE
  FormatDiagrams -Scope Document -Target "docs/Architecture.md" -Inspect

.EXAMPLE
  FormatDiagrams -Scope Repo -Fix

.EXAMPLE
  FormatDiagrams -Scope Git_root -Inspect
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, HelpMessage = "Execution scope: 'Git_root', 'Repo', 'Folder', 'Document', or 'Auto'")]
  [ValidateSet('Git_root', 'Repo', 'Folder', 'Document', 'Auto')]
  [string]$Scope = 'Auto',

  [Parameter(Mandatory = $false, HelpMessage = 'Target path for the selected scope')]
  [string]$Target = '',

  [Parameter(Mandatory = $false, HelpMessage = 'Target minimum font size for Mermaid diagram boxes (default: 8pt)')]
  [string]$FontSize = '8pt',

  [Parameter(Mandatory = $false, HelpMessage = 'Maximum line length before wrapping text in diagram nodes (default: 35)')]
  [int]$WrapLength = 35,

  [Parameter(Mandatory = $false, HelpMessage = 'Enable wrapping for Markdown table cells')]
  [switch]$WrapTables,

  [Parameter(Mandatory = $false, HelpMessage = 'Maximum line length before wrapping text in table cells (default: 65)')]
  [int]$TableWrapLength = 65,

  [Parameter(Mandatory = $false, HelpMessage = 'Scans and audits files without modifying them (read-only inspect)')]
  [switch]$Inspect,

  [Parameter(Mandatory = $false, HelpMessage = 'Applies diagram formatting and font-size rule enforcement in-place')]
  [switch]$Fix,

  [Parameter(Mandatory = $false, HelpMessage = 'Custom log file destination path')]
  [string]$LogFile = '',

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = '10.0.0'
$scriptName = 'Format-LcmMarkdownDiagrams'

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM MARKDOWN & CM MERMAID DIAGRAM FORMATTER (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Audits and standardizes Mermaid diagrams, detects legacy ASCII diagram"
  Write-Host "  boxes, and folds long lines in Mermaid boxes and Markdown table columns"
  Write-Host "  across all LCM-governed documentation."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Format-LcmMarkdownDiagrams.ps1 [-Scope <Scope>] [-Target <Path>] [-WrapLength <int>] [-WrapTables] [-Inspect] [-Fix] [-h]"
  Write-Host "  FormatDiagrams [-Scope <Scope>] [-Target <Path>] [-WrapLength <int>] [-WrapTables] [-Inspect] [-Fix]"
  Write-Host ""
  Write-Host "SCOPES:" -ForegroundColor Yellow
  Write-Host "  Git_root : All governed repositories under D:\Git_Repositories\"
  Write-Host "  Repo     : Target repository"
  Write-Host "  Folder   : Specific directory folder"
  Write-Host "  Document : Single specific .md or .cm file"
  Write-Host "  Auto     : Auto-detect based on current working path (default)"
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -Scope <str>          : Operational scope level."
  Write-Host "  -Target <str>         : Target path corresponding to scope."
  Write-Host "  -FontSize <str>       : Minimum typography constraint (default: '8pt')."
  Write-Host "  -WrapLength <int>     : Max length for lines in Mermaid boxes before folding (default: 35)."
  Write-Host "  -WrapTables           : Enable folding of long lines in Markdown table column cells."
  Write-Host "  -TableWrapLength <int>: Max length for lines in Markdown table cells before folding (default: 65)."
  Write-Host "  -Inspect              : Audit and preview findings without modifying files."
  Write-Host "  -Fix                  : Apply in-place formatting, 8pt styling, and line folding."
  Write-Host "  -LogFile <str>        : Custom log file destination."
  Write-Host "  -h, -Help, -?         : Displays this comprehensive parameter reference."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# ------------------------------------------------------------------------------
# 1. Initialize Context & Logging per RULE-PS-009
# ------------------------------------------------------------------------------
$workspaceRoot = if (-not [string]::IsNullOrWhiteSpace($env:Git_Root)) { $env:Git_Root.TrimEnd('\', '/') } else { 'D:\Git_Repositories' }
$lcmRoot = Join-Path $workspaceRoot 'LCM_Inventory'
$logDir = Join-Path $workspaceRoot 'LCM_Inventory\data\logs\lcm'
if (-not (Test-Path -LiteralPath $logDir)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $LogFile = Join-Path $logDir "$($scriptName)-$($timestampStr).log"
}

function Write-LcmLog {
  param([string]$Message, [string]$Level = 'INFO')
  $timeStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $entry = "[$timeStr] [$Level] $Message"
  Add-Content -LiteralPath $LogFile -Value $entry -Encoding utf8
  switch ($Level) {
    'WARN'  { Write-Host $Message -ForegroundColor Yellow }
    'ERROR' { Write-Host $Message -ForegroundColor Red }
    'PASS'  { Write-Host $Message -ForegroundColor Green }
    default { Write-Host $Message -ForegroundColor Gray }
  }
}

function Format-LcmTextLine {
  [CmdletBinding()]
  param(
    [string]$Text,
    [int]$MaxLength = 35
  )
  if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }
  $visible = [regex]::Replace($Text, '<[^>]+>', '')
  if ($visible.Length -le $MaxLength) { return $Text }

  $parts = [regex]::Split($Text, '(?i)<br\s*/?>')
  $resultParts = @()
  foreach ($part in $parts) {
    $visPart = [regex]::Replace($part, '<[^>]+>', '')
    if ($visPart.Length -le $MaxLength) {
      $resultParts += $part
      continue
    }

    # Tokenize preserving HTML tags, entities, attached punctuation, and boundaries (whitespace, slashes)
    $tokens = [regex]::Matches($part, '(</?[a-zA-Z0-9_-]+[^>]*>|&[a-zA-Z0-9#]+;|[^<>\s\\/]+|[\s\\/]+)')
    $currentLine = ''
    $currentVisLen = 0
    $subLines = @()
    foreach ($m in $tokens) {
      $tok = $m.Value
      $isTag = $tok -match '^</?[a-zA-Z0-9_-]+[^>]*>$'
      $visLen = if ($isTag) { 0 } else { $tok.Length }

      if ($currentVisLen + $visLen -gt $MaxLength -and $currentVisLen -gt 0 -and -not $isTag -and $tok -notmatch '^</') {
        # Check if current line ends with an opening tag: if so, relocate it to the next line
        $tagMatch = [regex]::Match($currentLine, '(<[a-zA-Z0-9_-]+[^>]*>)$')
        if ($tagMatch.Success) {
          $openingTag = $tagMatch.Groups[1].Value
          $currentLine = $currentLine.Substring(0, $currentLine.Length - $openingTag.Length).TrimEnd()
          $subLines += $currentLine
          $currentLine = $openingTag + $tok.TrimStart(' ')
        } else {
          $subLines += $currentLine.TrimEnd()
          $currentLine = $tok.TrimStart(' ')
        }
        $currentVisLen = [regex]::Replace($currentLine, '<[^>]+>', '').Length
      } else {
        $currentLine += $tok
        $currentVisLen += $visLen
      }
    }
    if ($currentLine.Length -gt 0) {
      $subLines += $currentLine.TrimEnd()
    }
    $resultParts += ($subLines -join '<br/>')
  }
  return ($resultParts -join '<br/>')
}

Write-LcmLog "=== $scriptName v$($scriptVersion) Started ==="

# Default to Inspect mode if neither -Inspect nor -Fix was explicitly requested
if (-not $Inspect -and -not $Fix) {
  $Inspect = $true
  Write-LcmLog "Defaulting to -Inspect mode (use -Fix to apply changes in-place)."
}

# ------------------------------------------------------------------------------
# 2. Scope Resolution
# ------------------------------------------------------------------------------
$currentLocation = (Get-Location).Path
$resolvedFiles = @()

if ($Scope -eq 'Auto') {
  if (-not [string]::IsNullOrWhiteSpace($Target)) {
    if (Test-Path -LiteralPath $Target -PathType Leaf) {
      $Scope = 'Document'
    } elseif (Test-Path -LiteralPath $Target -PathType Container) {
      $Scope = 'Folder'
    } else {
      $Scope = 'Repo'
    }
  } else {
    if ($currentLocation.TrimEnd('\', '/') -eq $workspaceRoot) {
      $Scope = 'Git_root'
    } else {
      $Scope = 'Repo'
    }
  }
}

Write-LcmLog "Resolved Execution Scope: $Scope"

switch ($Scope) {
  'Document' {
    $docPath = if (-not [string]::IsNullOrWhiteSpace($Target)) { $Target } else { $currentLocation }
    if (-not (Test-Path -LiteralPath $docPath -PathType Leaf)) {
      Write-LcmLog "Target document not found: $docPath" -Level ERROR
      return
    }
    $resolvedFiles = @((Get-Item -LiteralPath $docPath))
  }
  'Folder' {
    $folderPath = if (-not [string]::IsNullOrWhiteSpace($Target)) { $Target } else { $currentLocation }
    if (-not (Test-Path -LiteralPath $folderPath -PathType Container)) {
      Write-LcmLog "Target folder not found: $folderPath" -Level ERROR
      return
    }
    $resolvedFiles = @(Get-ChildItem -LiteralPath $folderPath -Filter "*.md" -File | Where-Object {
      $_.FullName -notmatch '\\(\.git|\.venv|node_modules|\.agents\\skills|\.gemini|scratch|archives)\\'
    })
  }
  'Repo' {
    $repoPath = if (-not [string]::IsNullOrWhiteSpace($Target)) {
      if ([System.IO.Path]::IsPathRooted($Target)) { $Target } else { Join-Path $workspaceRoot $Target }
    } else {
      $currentLocation
    }
    if (-not (Test-Path -LiteralPath $repoPath -PathType Container)) {
      Write-LcmLog "Target repository folder not found: $repoPath" -Level ERROR
      return
    }
    $resolvedFiles = @(Get-ChildItem -LiteralPath $repoPath -Filter "*.md" -Recurse -File | Where-Object {
      $_.FullName -notmatch '\\(\.git|\.venv|node_modules|\.agents\\skills|\.gemini|scratch|archives)\\'
    })
  }
  'Git_root' {
    Write-LcmLog "Scanning full Git_Root: $workspaceRoot"
    $resolvedFiles = @(Get-ChildItem -LiteralPath $workspaceRoot -Filter "*.md" -Recurse -File | Where-Object {
      $_.FullName -notmatch '\\(\.git|\.venv|node_modules|\.agents\\skills|\.gemini|scratch|archives)\\'
    })
  }
}

Write-LcmLog "Discovered $(@($resolvedFiles).Count) Markdown document(s) for evaluation."

# ------------------------------------------------------------------------------
# 3. Document Analysis & Transformation
# ------------------------------------------------------------------------------
$filesScanned = 0
$mermaidBlocksFound = 0
$mermaidBlocksUpdated = 0
$mermaidBoxesFolded = 0
$tableCellsFolded = 0
$legacyAsciiBoxesFound = 0

foreach ($fileItem in $resolvedFiles) {
  $filesScanned++
  $filePath = $fileItem.FullName
  $content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
  $isModified = $false

  # Check for legacy ASCII box art: +---+
  $asciiMatches = [regex]::Matches($content, '(?m)^\s*\+[-=]{4,}\+')
  if ($asciiMatches.Count -gt 0) {
    $legacyAsciiBoxesFound += $asciiMatches.Count
    Write-LcmLog "[$($fileItem.Name)] Legacy ASCII box art detected ($($asciiMatches.Count) instance(s)) at: $filePath" -Level WARN
  }

  # Check for Mermaid code blocks
  $mermaidPattern = '(?ms)(```mermaid\r?\n)(.*?)(```)'
  $newContent = [regex]::Replace($content, $mermaidPattern, {
    param($match)
    $script:mermaidBlocksFound++
    $header = $match.Groups[1].Value
    $body = $match.Groups[2].Value
    $footer = $match.Groups[3].Value
    $blockModified = $false

    # Check for long lines in Mermaid boxes and fold them with <br/>
    $nodePattern = '((?:\b[A-Za-z0-9_]+|subgraph\s+[A-Za-z0-9_]+)\s*(?:\["|\(\["|\[\("|\{\{"|\{"|\[/"))([^"\]\r\n]+)("\]|"\)|"\}\}|"\}|"/\])'
    $foldedBody = [regex]::Replace($body, $nodePattern, {
      param($nm)
      $pre = $nm.Groups[1].Value
      $label = $nm.Groups[2].Value
      $post = $nm.Groups[3].Value
      $foldedLabel = Format-LcmTextLine -Text $label -MaxLength $WrapLength
      if ($foldedLabel -ne $label) {
        $script:mermaidBoxesFolded++
        if ($Fix) {
          return "$pre$foldedLabel$post"
        } else {
          Write-LcmLog "[$($fileItem.Name)] Mermaid box has long line (> $WrapLength chars): '$label'" -Level WARN
        }
      }
      return $nm.Value
    })
    if ($Fix -and $foldedBody -ne $body) {
      $body = $foldedBody
      $script:isModified = $true
    }

    # Check if 8pt styling is already present
    if ($body -notmatch 'font-size\s*:\s*8pt') {
      if ($Fix) {
        $script:mermaidBlocksUpdated++
        $script:isModified = $true
        # Insert default classDef at the top of the diagram
        $lines = @($body -split "\r?\n")
        $firstDirectiveIndex = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
          $trimmed = $lines[$i].Trim()
          if ($trimmed -match '^(flowchart|graph|sequenceDiagram|stateDiagram|classDiagram)') {
            $firstDirectiveIndex = $i
            break
          }
        }

        if ($firstDirectiveIndex -ge 0) {
          $indent = "    "
          $fontDef = "$indent`classDef default font-size:$($FontSize);"
          $newLines = @()
          for ($j = 0; $j -lt $lines.Count; $j++) {
            $newLines += $lines[$j]
            if ($j -eq $firstDirectiveIndex) {
              $newLines += $fontDef
            }
          }
          $body = ($newLines -join "`r`n") + "`r`n"
        }
      } else {
        Write-LcmLog "[$($fileItem.Name)] Mermaid diagram lacking $($FontSize) constraint at: $filePath" -Level WARN
      }
    }

    if ($Fix -and ($body -ne $match.Groups[2].Value)) {
      return $header + $body + $footer
    }

    return $match.Value
  })

  # Check for Markdown tables and fold long lines in table columns if requested
  if ($WrapTables) {
    $tableRowPattern = '(?m)^(\|.+?\|)$'
    $newContent = [regex]::Replace($newContent, $tableRowPattern, {
      param($tmatch)
      $rowLine = $tmatch.Groups[1].Value
      if ($rowLine -match '^\|[\s:\-]+(?:\|[\s:\-]+)+\|$') {
        return $rowLine
      }
      $cells = $rowLine -split '(?<!\\)\|'
      $modifiedRow = $false
      $newCells = @()
      for ($c = 1; $c -lt ($cells.Count - 1); $c++) {
        $cellText = $cells[$c]
        $foldedCell = Format-LcmTextLine -Text $cellText -MaxLength $TableWrapLength
        if ($foldedCell -ne $cellText) {
          $script:tableCellsFolded++
          if ($Fix) {
            $script:isModified = $true
            $modifiedRow = $true
            $newCells += $foldedCell
          } else {
            $newCells += $cellText
            Write-LcmLog "[$($fileItem.Name)] Table cell has long line (> $TableWrapLength chars)" -Level WARN
          }
        } else {
          $newCells += $cellText
        }
      }
      if ($Fix -and $modifiedRow) {
        return '|' + ($newCells -join '|') + '|'
      }
      return $rowLine
    })
  }

  if ($Fix -and $isModified) {
    [System.IO.File]::WriteAllText($filePath, $newContent, [System.Text.UTF8Encoding]::new($false))
    Write-LcmLog "[$($fileItem.Name)] Standardized Mermaid formatting & line-folding applied: $filePath" -Level PASS
  }
}

# ------------------------------------------------------------------------------
# 4. Summary & Completion
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " DIAGRAM FORMATTING & AUDIT REPORT" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Execution Scope        : $Scope"
Write-Host " Files Evaluated        : $filesScanned"
Write-Host " Mermaid Blocks Checked : $mermaidBlocksFound"
Write-Host " Mermaid Blocks Updated : $mermaidBlocksUpdated"
Write-Host " Mermaid Boxes Folded   : $mermaidBoxesFolded"
Write-Host " Table Cells Folded     : $tableCellsFolded"
Write-Host " Legacy ASCII Boxes     : $legacyAsciiBoxesFound"
Write-Host " Audit Log File         : $LogFile"
Write-Host "==========================================================================" -ForegroundColor Cyan

Write-LcmLog "=== $scriptName v$($scriptVersion) Finished (Evaluated: $filesScanned, Mermaid Blocks: $mermaidBlocksFound, Boxes Folded: $mermaidBoxesFolded, ASCII: $legacyAsciiBoxesFound) ==="
