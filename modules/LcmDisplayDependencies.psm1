<#
.SYNOPSIS
  Declares and fingerprints standard display inputs.
.NOTES
  Module: LcmDisplayDependencies
  Purpose: Declare and fingerprint the inputs of each live Standard Display.
  Path: modules/LcmDisplayDependencies.psm1
  Authors: Rolf, Copilot
  Version: 10.2.1
  Date: 2026-10-21
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'LcmToolScanLocations.psm1')

function Get-LcmDisplayDefinitions {
  [CmdletBinding()]
  param([string]$WorkspaceRoot = 'D:\Git_Repositories')
  $root = Join-Path $WorkspaceRoot 'LCM_Inventory'
  $assets = Join-Path $root 'assets'
  $common = @(
    (Join-Path $assets 'StandardTableDisplay.css'),
    (Join-Path $assets 'lcm-table-engine.js'),
    (Join-Path $assets 'lcm-table-print-atom.js'),
    (Join-Path $assets 'lcm-display-freshness.js')
    (Join-Path $root 'modules\LcmDisplayVersion.psm1')
  )
  $definitions = @{
    tools = @{
      Renderer = 'Show-ToolsExplorer.ps1'; Artifact = Join-Path $root 'data\artifacts\SHOW_TOOLS.html'
      Data = @('modules\*.psm1', 'Cmd\*.cmd', 'config\tool_catalog.json', 'config\tool_catalog_overrides.json', 'config\tool_explorer_options.json')
      Presentation = @('tools\Show-ToolsExplorer.ps1', 'modules\LcmToolCatalog.psm1', 'assets\lcm-tool-explorer.js', 'assets\LCMToolCatalog.css')
    }
    rules = @{
      Renderer = 'Show-Rules.ps1'; Artifact = Join-Path $root 'data\artifacts\SHOW_RULES.html'
      Data = @('.agents\rules\*.md')
      Presentation = @('tools\Show-Rules.ps1')
    }
    inventory = @{
      Renderer = 'Show-LCM_InventoryApp.ps1'; Artifact = Join-Path $root 'data\artifacts\LCM_INVENTORY_VIEWER.html'
      Data = @('data\inventory.json')
      Presentation = @('tools\Show-LCM_InventoryApp.ps1', 'assets\LCM_INVENTORY_VIEWER.html')
    }
    hub = @{
      Renderer = 'Show-LcmControl.ps1'; Artifact = Join-Path $root 'data\artifacts\CM_CONTROL_HUB.html'
      Data = @('data\proposals\proposals.json', 'data\catalog\apps.json', 'docs\Proposals\*\*.md', 'data\reviews\*.json', 'config\tool_catalog.json', 'logs\cm_activity.log', 'logs\history\cm_activity_v5_v6_history.log')
      Presentation = @('tools\Show-LcmControl.ps1', 'assets\CM_CONTROL_HUB.html')
    }
    dates = @{
      Renderer = 'Show-LcmControl.ps1'; Artifact = Join-Path $root 'data\artifacts\CM_CRP_DATES.html'
      Data = @('data\proposals\proposals.json')
      Presentation = @('tools\Show-LcmControl.ps1', 'assets\CM_CRP_DATES_READONLY.html', 'assets\CM_CONTROL_HUB.html')
    }
  }
  foreach ($id in $definitions.Keys) {
    $definition = $definitions[$id]
    $definition.Data = @($definition.Data | ForEach-Object { Join-Path $root $_ })
    if ($id -eq 'rules') {
      $definition.Data += @(
        (Join-Path $WorkspaceRoot '.agents\rules\*.md'),
        (Join-Path $WorkspaceRoot 'AGENTS.md'),
        (Join-Path $WorkspaceRoot 'GEMINI.md'),
        (Join-Path $WorkspaceRoot 'LCM_AI\docs\LCM-Rules-Cross-Reference.md')
      )
    }
    if ($id -in @('hub','dates')) {
      $definition.Data += Join-Path $root 'data\proposals\plans\*.md'
      $definition.Data += Join-Path $root 'data\reviews\*.json'
      $definition.Data += Join-Path $WorkspaceRoot '.agents\ACTIVE_SESSION.md'
      foreach ($repository in @(Get-ChildItem -LiteralPath $WorkspaceRoot -Directory | Where-Object { $_.Name -notmatch '^\.' -and $_.Name -notin @('tools','scratch','data','logs') })) {
        foreach ($doc in @('Architecture.md','Requirements.md','Implementation.md','install\Installation.md','README.md','docs\Architecture.md','docs\Requirements.md','docs\Implementation.md','docs\CM_POLICIES.md','docs\Proposals\*.md')) {
          $definition.Data += Join-Path $repository.FullName $doc
        }
      }
    }
    if ($id -eq 'tools') {
      foreach ($location in @(Get-LcmToolScanLocations)) {
        $definition.Data += Join-Path (Join-Path $WorkspaceRoot $location.Path) $location.Filter
      }
      $definition.Data += Join-Path $WorkspaceRoot 'LCM_AI\docs\Requirements.md'
    }
    $definition.Presentation = $common + @($definition.Presentation | ForEach-Object { Join-Path $root $_ })
    $definition.Renderer = Join-Path $root "tools\$($definition.Renderer)"
    if ($id -eq 'inventory') {
      # These are the same documents cached by the existing inventory renderer.
      foreach ($repo in @('LCM_Inventory','Installation_LCD','LCM_AI','SystemConfiguration','BackgroundModifier','VolumeInventory','HaSSD06','HaSSD06_Inventory','AuthorizeMasterUser','LCM_Shared','Git_Repositories')) {
        $repoRoot = if ($repo -eq 'Git_Repositories') { $WorkspaceRoot } else { Join-Path $WorkspaceRoot $repo }
        foreach ($doc in @('Architecture.md','Requirements.md','Implementation.md','install\Installation.md','Installation.md','README.md','docs\Architecture.md','docs\Requirements.md','docs\Implementation.md','docs\CM_POLICIES.md')) {
          $definition.Data += Join-Path $repoRoot $doc
        }
      }
    }
    $definition.Source = if ($id -eq 'tools') { @($definition.Data | Where-Object { $_ -notlike '*\config\tool_catalog.json' }) } else { $definition.Data }
  }
  return $definitions
}

function Get-LcmDisplayFingerprint {
  [CmdletBinding()]
  param([string[]]$Paths)
  $records = foreach ($path in $Paths) {
    $recursive = $path -match '\\(?:docs\\Proposals|data\\proposals\\plans)\\\*\.md$'
    $directory = [IO.Path]::GetDirectoryName($path)
    $leaf = [IO.Path]::GetFileName($path)
    $files = @(
      if ($leaf.Contains('*') -or $leaf.Contains('?')) {
        if ([IO.Directory]::Exists($directory)) {
          $search = if ($recursive) { [IO.SearchOption]::AllDirectories } else { [IO.SearchOption]::TopDirectoryOnly }
          [IO.Directory]::EnumerateFiles($directory, $leaf, $search)
        }
      } elseif ([IO.File]::Exists($path)) {
        $path
      }
    )
    if (-not $files.Count) { "MISSING:$path"; continue }
    foreach ($file in $files | Sort-Object) {
      $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($file)))
      "${file}:$hash"
    }
  }
  $bytes = [Text.Encoding]::UTF8.GetBytes(($records -join "`n"))
  [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

Export-ModuleMember -Function Get-LcmDisplayDefinitions, Get-LcmDisplayFingerprint
