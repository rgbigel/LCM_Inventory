<#
.SYNOPSIS
  Synchronizes catalogued Show* tools into managed macros and provides macro maintenance.
.DESCRIPTION
  Module: Sync-LcmCatalogMacros
  Purpose: Automatically synchronizes eligible Show* tool definitions from config/tool_catalog.json
           into a managed section within .agents/rules/macro-definitions.md while preserving all
           manual macros. Provides sub-actions (Sync, List, Add, Update, Retire, Validate) for
           macro lifecycle management conforming to CRP-280, RULE-PS-001 - 025, and RULE-LCM-021.
  Path: LCM_Inventory/tools/Sync-LcmCatalogMacros.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 10.0.0
  Date: 2026-11-10
.PARAMETER CatalogPath
  Path to tool_catalog.json. Defaults to 'LCM_Inventory/config/tool_catalog.json'.
.PARAMETER MacroFilePath
  Path to macro-definitions.md. Defaults to '.agents/rules/macro-definitions.md'.
.PARAMETER SubAction
  The operation to execute: Sync (default), List, Add, Update, Retire, Validate.
.PARAMETER DryRun
  When specified, simulates changes and outputs proposed modifications without writing to disk.
.PARAMETER Name
  Macro name for Add, Update, or Retire operations.
.PARAMETER Description
  Operator-facing description for Add or Update operations.
.PARAMETER Syntax
  Command syntax string for Add or Update operations.
.PARAMETER Target
  Script target path for Add or Update operations.
.PARAMETER Aliases
  Array of alias names for Add or Update operations.
.PARAMETER Rules
  Array of specific rule strings for Add or Update operations.
.PARAMETER Help
  Displays parameter reference and usage (-h / -Help / -?).
.EXAMPLE
  pwsh LCM_Inventory/tools/Sync-LcmCatalogMacros.ps1 -DryRun
  Preview Show* macro synchronization without modifying macro-definitions.md.
.EXAMPLE
  pwsh LCM_Inventory/tools/Sync-LcmCatalogMacros.ps1
  Synchronize eligible Show* macros to macro-definitions.md.
.EXAMPLE
  pwsh LCM_Inventory/tools/Sync-LcmCatalogMacros.ps1 -SubAction Validate
  Validate all manual and managed macros against their targets and check collisions.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$CatalogPath = '',

  [Parameter(Mandatory = $false)]
  [string]$MacroFilePath = '',

  [Parameter(Mandatory = $false)]
  [ValidateSet('Sync', 'List', 'Add', 'Update', 'Retire', 'Validate')]
  [string]$SubAction = 'Sync',

  [switch]$DryRun,

  [Parameter(Mandatory = $false)]
  [string]$Name = '',

  [Parameter(Mandatory = $false)]
  [string]$Description = '',

  [Parameter(Mandatory = $false)]
  [string]$Syntax = '',

  [Parameter(Mandatory = $false)]
  [string]$Target = '',

  [Parameter(Mandatory = $false)]
  [string[]]$Aliases = @(),

  [Parameter(Mandatory = $false)]
  [string[]]$Rules = @(),

  [Alias('h', '?')]
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptVersion = '10.0.0'
$scriptName = 'Sync-LcmCatalogMacros'

if ($Help) {
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host " LCM CATALOG MACRO SYNCHRONIZER & MAINTENANCE (v$($scriptVersion))" -ForegroundColor Cyan
  Write-Host "==========================================================================" -ForegroundColor Cyan
  Write-Host "SYNOPSIS:" -ForegroundColor Yellow
  Write-Host "  Synchronizes Show* commands from tool_catalog.json to macro-definitions.md"
  Write-Host "  and maintains manual macro entries (CRP-280)."
  Write-Host ""
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh LCM_Inventory/tools/Sync-LcmCatalogMacros.ps1 [-SubAction <Action>] [-DryRun] [-h]"
  Write-Host ""
  Write-Host "SUB-ACTIONS:" -ForegroundColor Yellow
  Write-Host "  Sync      : Automatically synchronize active Show* catalog tools (Default)."
  Write-Host "  List      : List all registered macros (manual and managed)."
  Write-Host "  Add       : Add a new explicit manual macro definition."
  Write-Host "  Update    : Update an existing manual macro definition."
  Write-Host "  Retire    : Remove an existing manual macro definition."
  Write-Host "  Validate  : Verify all macro targets exist and detect collisions."
  Write-Host ""
  Write-Host "PARAMETERS:" -ForegroundColor Yellow
  Write-Host "  -CatalogPath <path>     : Path to tool_catalog.json."
  Write-Host "  -MacroFilePath <path>   : Path to macro-definitions.md."
  Write-Host "  -DryRun                 : Render proposed changes without writing to disk."
  Write-Host "  -Name <string>          : Macro name for Add, Update, or Retire."
  Write-Host "  -Description <string>   : Operator-facing description."
  Write-Host "  -Syntax <string>        : Invocation syntax."
  Write-Host "  -Target <string>        : Script target file."
  Write-Host "  -Aliases <string[]>     : Secondary invocation aliases."
  Write-Host "  -Rules <string[]>       : Custom operational rules."
  Write-Host "  -h, -Help, -?           : Displays this help."
  Write-Host "==========================================================================" -ForegroundColor Cyan
  return
}

# Resolve workspace root and file paths
$workspaceRoot = 'D:\Git_Repositories'
if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
  $CatalogPath = Join-Path $workspaceRoot 'LCM_Inventory\config\tool_catalog.json'
}
if ([string]::IsNullOrWhiteSpace($MacroFilePath)) {
  $MacroFilePath = Join-Path $workspaceRoot '.agents\rules\macro-definitions.md'
}

$sectionStartMarker = '<!-- MANAGED-SHOW-MACROS-START -->'
$sectionEndMarker   = '<!-- MANAGED-SHOW-MACROS-END -->'

function Parse-MacroDefinitionsFile {
  param([string]$FilePath)

  if (-not (Test-Path -LiteralPath $FilePath)) {
    throw "Macro definitions file not found: $FilePath"
  }

  $rawText = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
  $lines = @($rawText -split "\r?\n")

  $beforeManaged = @()
  $managedLines = @()
  $afterManaged = @()
  $inManaged = $false
  $managedFound = $false

  foreach ($line in $lines) {
    if ($line.Trim() -eq $sectionStartMarker) {
      $inManaged = $true
      $managedFound = $true
      continue
    }
    if ($line.Trim() -eq $sectionEndMarker) {
      $inManaged = $false
      continue
    }

    if ($inManaged) {
      $managedLines += $line
    } elseif (-not $managedFound) {
      $beforeManaged += $line
    } else {
      $afterManaged += $line
    }
  }

  # Parse manual entries from before and after lines
  $manualEntries = @(Parse-MacroEntries -Lines ($beforeManaged + $afterManaged))
  $managedEntries = if ($managedFound) { @(Parse-MacroEntries -Lines $managedLines) } else { @() }

  return @{
    RawText        = $rawText
    BeforeManaged  = $beforeManaged
    ManagedLines   = $managedLines
    AfterManaged   = $afterManaged
    ManagedFound   = $managedFound
    ManualEntries  = $manualEntries
    ManagedEntries = $managedEntries
  }
}

function Parse-MacroEntries {
  param([string[]]$Lines)

  $entries = @()
  $current = $null

  foreach ($line in $Lines) {
    if ($line -match '^MACRO:\s*(.+)$') {
      if ($null -ne $current) {
        $entries += $current
      }
      $current = @{
        Name        = $matches[1].Trim()
        Description = ''
        Syntax      = ''
        Aliases     = @()
        Target      = ''
        Rules       = @()
        RawLines    = @($line)
      }
      continue
    }

    if ($null -ne $current) {
      $current.RawLines += $line
      if ($line -match '^\s*-\s*description:\s*(.+)$') {
        $current.Description = $matches[1].Trim()
      } elseif ($line -match '^\s*-\s*syntax:\s*(.+)$') {
        $current.Syntax = $matches[1].Trim()
      } elseif ($line -match '^\s*-\s*aliases?:\s*(.+)$') {
        $aliasList = @($matches[1].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $current.Aliases = $aliasList
      } elseif ($line -match '^\s*-\s*primary target:\s*([^\(]+)') {
        $current.Target = $matches[1].Trim()
      } elseif ($line -match '^\s*-\s*rules:\s*$') {
        # rule section header
      } elseif ($line -match '^\s{4}-\s*(.+)$') {
        $current.Rules += $matches[1].Trim()
      }
    }
  }

  if ($null -ne $current) {
    $entries += $current
  }

  return $entries
}

function Format-MacroEntry {
  param([hashtable]$Entry)

  $output = @()
  $output += "MACRO: $($Entry.Name)"
  if (-not [string]::IsNullOrWhiteSpace($Entry.Description)) {
    $output += "- description: $($Entry.Description)"
  }
  if (-not [string]::IsNullOrWhiteSpace($Entry.Syntax)) {
    $output += "- syntax: $($Entry.Syntax)"
  }
  if ($null -ne $Entry.Aliases -and $Entry.Aliases.Count -gt 0) {
    $output += "- aliases: $($Entry.Aliases -join ', ')"
  }
  if (-not [string]::IsNullOrWhiteSpace($Entry.Target)) {
    $output += "- primary target: $($Entry.Target)"
  }
  if ($null -ne $Entry.Rules -and $Entry.Rules.Count -gt 0) {
    $output += "- rules:"
    foreach ($r in $Entry.Rules) {
      $output += "  - $r"
    }
  }
  return ($output -join "`r`n")
}

function Build-ManagedShowSection {
  param(
    [array]$EligibleTools,
    [hashtable]$ManualEntriesByName
  )

  $sectionLines = @()
  $sectionLines += "## Managed Catalog Show* Command Macros (Auto-Synchronized by CRP-280)"
  $sectionLines += "<!-- The entries below are synchronized from config/tool_catalog.json. Do not edit directly. -->"
  $sectionLines += ""

  foreach ($tool in $EligibleTools) {
    $cmdName = if (-not [string]::IsNullOrWhiteSpace($tool.ShortName)) { $tool.ShortName } else { ($tool.Name -replace '\.ps1$', '') }
    $desc = if (-not [string]::IsNullOrWhiteSpace($tool.Description)) { $tool.Description } else { "Show tool command for $($cmdName)" }
    $targetPath = ($tool.RelativePath -replace '\\', '/')

    $aliases = @()
    if ($null -ne $tool.Aliases) {
      foreach ($a in $tool.Aliases) {
        if (-not [string]::IsNullOrWhiteSpace($a) -and $a -ne $cmdName) {
          $aliases += $a
        }
      }
    }

    $entry = @{
      Name        = $cmdName
      Description = $desc
      Syntax      = "$($cmdName) [switches] | @$($cmdName) [switches]"
      Aliases     = $aliases
      Target      = $targetPath
      Rules       = @(
        "IDE-hosted display by default when supported by the host environment",
        "does not automatically launch an external browser when IDE display is unavailable; reports local display URL",
        "external browser launch requires explicit operator action"
      )
    }

    $sectionLines += (Format-MacroEntry -Entry $entry)
    $sectionLines += ""
  }

  return ($sectionLines -join "`r`n")
}

# ------------------------------------------------------------------------------
# Action: Validate
# ------------------------------------------------------------------------------
function Invoke-MacroValidation {
  param(
    [hashtable]$ParsedDoc,
    [string]$Root
  )

  Write-Host "[VALIDATION] Checking macro definitions..." -ForegroundColor Cyan
  $errors = @()
  $allNames = @{}

  $allEntries = @($ParsedDoc.ManualEntries) + @($ParsedDoc.ManagedEntries)

  foreach ($entry in $allEntries) {
    $nameLower = $entry.Name.ToLowerInvariant()
    if ($allNames.ContainsKey($nameLower)) {
      $errors += "Duplicate macro name detected: '$($entry.Name)' (collides with existing entry)"
    } else {
      $allNames[$nameLower] = $entry.Name
    }

    $seenAliasesForEntry = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($alias in $entry.Aliases) {
      $cleanAlias = ($alias -replace '^@', '').Trim()
      if ([string]::IsNullOrWhiteSpace($cleanAlias)) { continue }
      $aliasLower = $cleanAlias.ToLowerInvariant()
      if ($aliasLower -eq $nameLower) { continue }
      if ($seenAliasesForEntry.Contains($aliasLower)) { continue }
      $seenAliasesForEntry.Add($aliasLower) | Out-Null

      if ($allNames.ContainsKey($aliasLower)) {
        $owner = $allNames[$aliasLower]
        if ($owner -ne $entry.Name) {
          $errors += "Alias collision detected: alias '$alias' on macro '$($entry.Name)' collides with existing entry '$owner'"
        }
      } else {
        $allNames[$aliasLower] = "$($entry.Name) (alias)"
      }
    }

    if (-not [string]::IsNullOrWhiteSpace($entry.Target)) {
      $cleanTarget = ($entry.Target -split ' ')[0].Trim()
      $resolvedTarget = Join-Path $Root $cleanTarget
      if (-not (Test-Path -LiteralPath $resolvedTarget)) {
        # Check if target contains wildcards or parameters
        if (-not ($cleanTarget -like '*<*' -or $cleanTarget -like '*[*')) {
          $errors += "Missing target script: macro '$($entry.Name)' points to non-existent target '$cleanTarget'"
        }
      }
    }
  }

  if ($errors.Count -gt 0) {
    Write-Host "[VALIDATION FAILED] Found $($errors.Count) error(s):" -ForegroundColor Red
    foreach ($err in $errors) {
      Write-Host "  - $err" -ForegroundColor Red
    }
    return $false
  }

  Write-Host "[VALIDATION SUCCESS] All $($allEntries.Count) macro definitions validated successfully. No collisions found." -ForegroundColor Green
  return $true
}

# ------------------------------------------------------------------------------
# Dispatch SubActions
# ------------------------------------------------------------------------------
$parsedDoc = Parse-MacroDefinitionsFile -FilePath $MacroFilePath

switch ($SubAction) {
  'List' {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " REGISTERED MACROS IN $($MacroFilePath)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "MANUAL MACROS ($($parsedDoc.ManualEntries.Count)):" -ForegroundColor Yellow
    foreach ($m in $parsedDoc.ManualEntries) {
      Write-Host "  - $($m.Name) : $($m.Description)" -ForegroundColor White
      if ($m.Aliases.Count -gt 0) {
        Write-Host "    Aliases: $($m.Aliases -join ', ')" -ForegroundColor Gray
      }
      if (-not [string]::IsNullOrWhiteSpace($m.Target)) {
        Write-Host "    Target : $($m.Target)" -ForegroundColor DarkGray
      }
    }

    Write-Host ""
    Write-Host "MANAGED SHOW* MACROS ($($parsedDoc.ManagedEntries.Count)):" -ForegroundColor Yellow
    foreach ($m in $parsedDoc.ManagedEntries) {
      Write-Host "  - $($m.Name) : $($m.Description)" -ForegroundColor Green
      if (-not [string]::IsNullOrWhiteSpace($m.Target)) {
        Write-Host "    Target : $($m.Target)" -ForegroundColor DarkGray
      }
    }
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
  }

  'Validate' {
    $ok = Invoke-MacroValidation -ParsedDoc $parsedDoc -Root $workspaceRoot
    if (-not $ok) {
      exit 1
    }
    return
  }

  'Add' {
    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Syntax) -or [string]::IsNullOrWhiteSpace($Description)) {
      throw "Add requires -Name, -Syntax, and -Description parameters."
    }

    $existing = @($parsedDoc.ManualEntries | Where-Object { $_.Name.ToLowerInvariant() -eq $Name.ToLowerInvariant() })
    if ($existing.Count -gt 0) {
      throw "Macro '$Name' already exists in manual macros. Use -SubAction Update to modify it."
    }

    $newEntry = @{
      Name        = $Name
      Description = $Description
      Syntax      = $Syntax
      Aliases     = $Aliases
      Target      = $Target
      Rules       = $Rules
    }

    $formattedEntry = Format-MacroEntry -Entry $newEntry

    if ($DryRun) {
      Write-Host "[DRY-RUN] Would append manual macro '$Name':" -ForegroundColor Yellow
      Write-Host $formattedEntry -ForegroundColor White
      return
    }

    # Append before managed section or at end
    $updatedText = $parsedDoc.RawText.TrimEnd() + "`r`n`r`n" + $formattedEntry + "`r`n"
    [System.IO.File]::WriteAllText($MacroFilePath, $updatedText, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[SUCCESS] Added manual macro '$Name' to $($MacroFilePath)." -ForegroundColor Green
    return
  }

  'Update' {
    if ([string]::IsNullOrWhiteSpace($Name)) {
      throw "Update requires -Name parameter."
    }

    $existing = @($parsedDoc.ManualEntries | Where-Object { $_.Name.ToLowerInvariant() -eq $Name.ToLowerInvariant() })
    if ($existing.Count -eq 0) {
      throw "Macro '$Name' not found in manual macros."
    }

    Write-Host "[UPDATE] Updating manual macro '$Name'..." -ForegroundColor Cyan
    # Build updated entry
    $curr = $existing[0]
    $updDesc = if (-not [string]::IsNullOrWhiteSpace($Description)) { $Description } else { $curr.Description }
    $updSyntax = if (-not [string]::IsNullOrWhiteSpace($Syntax)) { $Syntax } else { $curr.Syntax }
    $updTarget = if (-not [string]::IsNullOrWhiteSpace($Target)) { $Target } else { $curr.Target }
    $updAliases = if ($Aliases.Count -gt 0) { $Aliases } else { $curr.Aliases }
    $updRules = if ($Rules.Count -gt 0) { $Rules } else { $curr.Rules }

    $newBlock = Format-MacroEntry -Entry @{
      Name        = $curr.Name
      Description = $updDesc
      Syntax      = $updSyntax
      Aliases     = $updAliases
      Target      = $updTarget
      Rules       = $updRules
    }

    $oldBlock = ($curr.RawLines -join "`r`n")
    if ($DryRun) {
      Write-Host "[DRY-RUN] Would update macro '$($curr.Name)':" -ForegroundColor Yellow
      Write-Host $newBlock -ForegroundColor White
      return
    }

    $newContent = $parsedDoc.RawText.Replace($oldBlock, $newBlock)
    [System.IO.File]::WriteAllText($MacroFilePath, $newContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[SUCCESS] Updated manual macro '$Name' in $($MacroFilePath)." -ForegroundColor Green
    return
  }

  'Retire' {
    if ([string]::IsNullOrWhiteSpace($Name)) {
      throw "Retire requires -Name parameter."
    }

    $existing = @($parsedDoc.ManualEntries | Where-Object { $_.Name.ToLowerInvariant() -eq $Name.ToLowerInvariant() })
    if ($existing.Count -eq 0) {
      throw "Macro '$Name' not found in manual macros."
    }

    $curr = $existing[0]
    $oldBlock = ($curr.RawLines -join "`r`n")
    if ($DryRun) {
      Write-Host "[DRY-RUN] Would retire (remove) macro '$($curr.Name)':" -ForegroundColor Yellow
      Write-Host $oldBlock -ForegroundColor DarkGray
      return
    }

    $newContent = $parsedDoc.RawText.Replace($oldBlock, "").Trim() + "`r`n"
    [System.IO.File]::WriteAllText($MacroFilePath, $newContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[SUCCESS] Retired manual macro '$Name' from $($MacroFilePath)." -ForegroundColor Green
    return
  }

  'Sync' {
    Write-Host "[SYNC] Synchronizing Show* tool catalog entries to macro-definitions.md..." -ForegroundColor Cyan

    if (-not (Test-Path -LiteralPath $CatalogPath)) {
      throw "Tool catalog not found at: $CatalogPath"
    }

    $catalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Build manual entries map
    $manualByName = @{}
    foreach ($m in $parsedDoc.ManualEntries) {
      $manualByName[$m.Name.ToLowerInvariant()] = $m
      foreach ($a in $m.Aliases) {
        $manualByName[$a.ToLowerInvariant()] = $m
      }
    }

    # Discover eligible Show* tools
    $eligibleTools = @()
    $diagnostics = @()

    foreach ($tool in $catalog) {
      $cmdName = if (-not [string]::IsNullOrWhiteSpace($tool.ShortName)) { $tool.ShortName } else { ($tool.Name -replace '\.ps1$', '') }

      # Must have Show* primary command name
      if (-not ($cmdName -like 'Show*')) {
        continue
      }

      # Validate target script existence
      $toolRelPath = $tool.RelativePath
      if ([string]::IsNullOrWhiteSpace($toolRelPath)) {
        $diagnostics += "Tool '$cmdName' is missing RelativePath in catalog."
        continue
      }

      $resolvedTarget = Join-Path $workspaceRoot $toolRelPath
      if (-not (Test-Path -LiteralPath $resolvedTarget)) {
        $diagnostics += "Tool '$cmdName' target script not found: $resolvedTarget"
        continue
      }

      # Check collision with manual entries
      $cmdNameLower = $cmdName.ToLowerInvariant()
      if ($manualByName.ContainsKey($cmdNameLower)) {
        $existingManual = $manualByName[$cmdNameLower]
        # If manual macro already defines this exact tool with identical/compatible target, skip generating duplicate
        $existingTargetClean = ($existingManual.Target -replace '\\', '/').Trim()
        $toolTargetClean = ($toolRelPath -replace '\\', '/').Trim()

        if ($existingTargetClean -eq $toolTargetClean -or $existingManual.Name.ToLowerInvariant() -eq $cmdNameLower) {
          Write-Host "  [SKIP] '$cmdName' is already manually managed in macro-definitions.md (preserved untouched)." -ForegroundColor DarkGray
          continue
        } else {
          $diagnostics += "Conflict: Tool '$cmdName' collides with existing manual macro '$($existingManual.Name)' pointing to different target '$($existingManual.Target)'."
          continue
        }
      }

      $eligibleTools += $tool
    }

    if ($diagnostics.Count -gt 0) {
      Write-Host "[SYNC HALTED] Catalog validation diagnostics failed:" -ForegroundColor Red
      foreach ($diag in $diagnostics) {
        Write-Host "  - $diag" -ForegroundColor Red
      }
      throw "Sync-LcmCatalogMacros failed closed due to catalog diagnostics / collisions."
    }

    Write-Host "Discovered $($eligibleTools.Count) eligible Show* tool(s) to synchronize." -ForegroundColor Green

    $managedSectionContent = Build-ManagedShowSection -EligibleTools $eligibleTools -ManualEntriesByName $manualByName

    # Construct complete document
    $newDocument = $null
    if ($parsedDoc.ManagedFound) {
      $beforeText = ($parsedDoc.BeforeManaged -join "`r`n").TrimEnd()
      $afterText = ($parsedDoc.AfterManaged -join "`r`n").TrimStart()
      $newDocument = "$beforeText`r`n`r`n$sectionStartMarker`r`n$managedSectionContent`r`n$sectionEndMarker"
      if (-not [string]::IsNullOrWhiteSpace($afterText)) {
        $newDocument += "`r`n`r`n$afterText"
      }
      $newDocument += "`r`n"
    } else {
      # Append managed section before legacy markers or at end
      $currentText = $parsedDoc.RawText.TrimEnd()
      $legacyMarker = 'MACRO: tsr (Legacy / Automated)'
      if ($currentText.Contains($legacyMarker)) {
        $idx = $currentText.IndexOf($legacyMarker)
        $firstPart = $currentText.Substring(0, $idx).TrimEnd()
        $secondPart = $currentText.Substring($idx)
        $newDocument = "$firstPart`r`n`r`n$sectionStartMarker`r`n$managedSectionContent`r`n$sectionEndMarker`r`n`r`n$secondPart`r`n"
      } else {
        $newDocument = "$currentText`r`n`r`n$sectionStartMarker`r`n$managedSectionContent`r`n$sectionEndMarker`r`n"
      }
    }

    if ($DryRun) {
      Write-Host "==========================================================================" -ForegroundColor Yellow
      Write-Host " [DRY-RUN] PROPOSED MANAGED SHOW* SECTION ($($eligibleTools.Count) entries):" -ForegroundColor Yellow
      Write-Host "==========================================================================" -ForegroundColor Yellow
      Write-Host $managedSectionContent -ForegroundColor White
      Write-Host "==========================================================================" -ForegroundColor Yellow
      Write-Host "[DRY-RUN] No files were modified." -ForegroundColor Green
      return
    }

    # Write canonical file with UTF-8 without BOM and CRLF
    [System.IO.File]::WriteAllText($MacroFilePath, $newDocument, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[SUCCESS] Synchronized $($eligibleTools.Count) Show* macros into $($MacroFilePath)." -ForegroundColor Green
  }
}
