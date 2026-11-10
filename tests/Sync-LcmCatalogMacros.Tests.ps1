# =====================================================================
# Sync-LcmCatalogMacros.Tests.ps1 - Test suite for CRP-280
# =====================================================================
# Module: Sync-LcmCatalogMacros.Tests
# Purpose: Pester tests for Catalog-Synced Show Command Macros and Managed Alias Maintenance
# Authors: Rolf, LCM_AI Engine
# Version: 10.2.0
# Date: 2026-11-10
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Sync-LcmCatalogMacros (CRP-280)' {
  BeforeAll {
    $repoRoot = 'D:\Git_Repositories'
    $toolScript = Join-Path $repoRoot 'LCM_Inventory\tools\Sync-LcmCatalogMacros.ps1'
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $sampleMacroContent = @"
# macro-definitions.md
# version: 10.2.0
# date: 2026-11-10

MACRO: technical
- description: enforce strict technical, ascii-only, deterministic output
- syntax: technical | @technical

MACRO: ShowCustomManual
- description: a manually managed show macro
- syntax: ShowCustomManual [switches]
- primary target: LCM_Inventory/tools/Show-LastLog.ps1
"@
    $tempMacroFile = Join-Path $tempDir 'macro-definitions.md'
    [System.IO.File]::WriteAllText($tempMacroFile, $sampleMacroContent, [System.Text.UTF8Encoding]::new($false))

    $sampleCatalog = @(
      @{
        Name = 'Show-LastLog.ps1'
        ShortName = 'ShowLastLog'
        Description = 'Displays the most recently updated audit log.'
        RelativePath = 'LCM_Inventory\tools\Show-LastLog.ps1'
        Aliases = @('lastlog')
      },
      @{
        Name = 'Show-CustomManual.ps1'
        ShortName = 'ShowCustomManual'
        Description = 'This collides with manual'
        RelativePath = 'LCM_Inventory\tools\Show-LastLog.ps1'
        Aliases = @()
      },
      @{
        Name = 'OtherTool.ps1'
        ShortName = 'OtherTool'
        Description = 'Non-show tool'
        RelativePath = 'LCM_Inventory\tools\Show-LastLog.ps1'
        Aliases = @()
      }
    )
    $tempCatalogFile = Join-Path $tempDir 'tool_catalog.json'
    ($sampleCatalog | ConvertTo-Json -Depth 3) | Set-Content -LiteralPath $tempCatalogFile -Encoding UTF8
  }

  AfterAll {
    if ($null -ne $tempDir -and (Test-Path -LiteralPath $tempDir)) {
      Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'Performs DryRun without modifying target file' {
    $beforeHash = (Get-FileHash -LiteralPath $tempMacroFile).Hash
    & $toolScript -CatalogPath $tempCatalogFile -MacroFilePath $tempMacroFile -DryRun
    $afterHash = (Get-FileHash -LiteralPath $tempMacroFile).Hash
    $afterHash | Should -Be $beforeHash
  }

  It 'Synchronizes eligible Show* tools into managed section and preserves manual macros' {
    & $toolScript -CatalogPath $tempCatalogFile -MacroFilePath $tempMacroFile
    $content = Get-Content -LiteralPath $tempMacroFile -Raw
    $content | Should -Match '<!-- MANAGED-SHOW-MACROS-START -->'
    $content | Should -Match '<!-- MANAGED-SHOW-MACROS-END -->'
    $content | Should -Match 'MACRO: ShowLastLog'
    $content | Should -Match 'MACRO: ShowCustomManual'
    $content | Should -Match 'MACRO: technical'
    # OtherTool should not be generated
    $content | Should -Not -Match 'MACRO: OtherTool'
  }

  It 'Validates all macros successfully' {
    { & $toolScript -CatalogPath $tempCatalogFile -MacroFilePath $tempMacroFile -SubAction Validate } | Should -Not -Throw
  }

  It 'Adds a manual macro via subaction' {
    & $toolScript -MacroFilePath $tempMacroFile -SubAction Add -Name 'MyNewMacro' -Syntax 'MyNewMacro' -Description 'Test manual macro' -Target 'LCM_Inventory/tools/Show-LastLog.ps1'
    $content = Get-Content -LiteralPath $tempMacroFile -Raw
    $content | Should -Match 'MACRO: MyNewMacro'
  }

  It 'Updates a manual macro via subaction' {
    & $toolScript -MacroFilePath $tempMacroFile -SubAction Update -Name 'MyNewMacro' -Description 'Updated description'
    $content = Get-Content -LiteralPath $tempMacroFile -Raw
    $content | Should -Match 'Updated description'
  }

  It 'Retires a manual macro via subaction' {
    & $toolScript -MacroFilePath $tempMacroFile -SubAction Retire -Name 'MyNewMacro'
    $content = Get-Content -LiteralPath $tempMacroFile -Raw
    $content | Should -Not -Match 'MACRO: MyNewMacro'
  }

  It 'Fails closed when target script is missing' {
    $brokenCatalog = @(
      @{
        Name = 'Show-NonExistent.ps1'
        ShortName = 'ShowNonExistent'
        Description = 'Does not exist'
        RelativePath = 'NonExistentPath\Show-NonExistent.ps1'
      }
    )
    $brokenCatalogFile = Join-Path $tempDir 'broken_catalog.json'
    ($brokenCatalog | ConvertTo-Json -Depth 3) | Set-Content -LiteralPath $brokenCatalogFile -Encoding UTF8

    { & $toolScript -CatalogPath $brokenCatalogFile -MacroFilePath $tempMacroFile } | Should -Throw
  }
}
