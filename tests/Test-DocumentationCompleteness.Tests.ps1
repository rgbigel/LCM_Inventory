# =====================================================================
# Test-DocumentationCompleteness.Tests.ps1 - Test suite for CRP-267
# =====================================================================
# Module: Test-DocumentationCompleteness.Tests
# Purpose: Pester tests for Durable Documentation Completeness for LCM and Governed Repositories
# Authors: Rolf, LCM_AI Engine
# Version: 10.0.0
# Date: 2026-11-10
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Test-DocumentationCompleteness (CRP-267)' {
  BeforeAll {
    $scriptRoot = 'D:\Git_Repositories'
    $toolScript = Join-Path $scriptRoot 'LCM_Inventory\tools\Test-DocumentationCompleteness.ps1'
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    # Create dummy compliant repo
    $goodRepo = Join-Path $tempRoot 'CompliantRepo'
    New-Item -ItemType Directory -Path (Join-Path $goodRepo 'docs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $goodRepo 'install') -Force | Out-Null

    $header = @"
# Sample Document
Module: docs/Sample.md
Purpose: Testing compliance
Path: docs/Sample.md
Authors: Test Engine
Version: 1.0.0
Date: 2026-11-10
"@
    [System.IO.File]::WriteAllText((Join-Path $goodRepo 'docs\Architecture.md'), $header, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $goodRepo 'docs\Requirements.md'), $header, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $goodRepo 'docs\Implementation.md'), $header, [System.Text.UTF8Encoding]::new($false))

    $install7Phase = @"
# Installation Runbook
Module: install/Installation.md
Purpose: Installation runbook
Path: install/Installation.md
Authors: Test Engine
Version: 1.0.0
Date: 2026-11-10

## Phase 1: Prerequisites & Environmental Dependencies
## Phase 2: Target Destination Layout
## Phase 3: Preflight System Health Checks
## Phase 4: Step-by-Step Deployment
## Phase 5: Post-Deployment Verification & Smoke Tests
## Phase 6: Ongoing Servicing & Maintenance
## Phase 7: Rollback & De-provisioning
"@
    [System.IO.File]::WriteAllText((Join-Path $goodRepo 'install\Installation.md'), $install7Phase, [System.Text.UTF8Encoding]::new($false))

    # Create dummy deficient repo
    $badRepo = Join-Path $tempRoot 'DeficientRepo'
    New-Item -ItemType Directory -Path (Join-Path $badRepo 'docs') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $badRepo 'docs\Architecture.md'), "No DOX header", [System.Text.UTF8Encoding]::new($false))
  }

  AfterAll {
    if ($null -ne $tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'Passes compliant repository with 7-phase runbook' {
    $results = & $toolScript -WorkspaceRoot $tempRoot -Repositories 'CompliantRepo' -RequireInstall -PassThru
    $results.Count | Should -Be 1
    $results[0].Compliant | Should -BeTrue
    $results[0].TripartiteComplete | Should -BeTrue
    $results[0].HasInstallationMd | Should -BeTrue
    $results[0].InstallationPhases | Should -Be '7/7'
  }

  It 'Detects missing tripartite documents and missing installation runbook in deficient repo' {
    $results = & $toolScript -WorkspaceRoot $tempRoot -Repositories 'DeficientRepo' -RequireInstall -PassThru
    $results.Count | Should -Be 1
    $results[0].Compliant | Should -BeFalse
    $results[0].TripartiteComplete | Should -BeFalse
    $results[0].HasInstallationMd | Should -BeFalse
    $results[0].MissingItems | Should -Contain 'docs/Requirements.md'
    $results[0].MissingItems | Should -Contain 'docs/Implementation.md'
    $results[0].MissingItems | Should -Contain 'install/Installation.md'
  }

  It 'Emits valid JSON format when -AsJson is specified' {
    $json = & $toolScript -WorkspaceRoot $tempRoot -Repositories 'CompliantRepo' -AsJson
    $obj = $json | ConvertFrom-Json
    $obj.Repository | Should -Be 'CompliantRepo'
    $obj.Compliant | Should -BeTrue
  }

  It 'Audits LCM_Inventory successfully' {
    $results = & $toolScript -WorkspaceRoot $scriptRoot -Repositories 'LCM_Inventory' -RequireInstall -PassThru
    $results.Count | Should -Be 1
    $results[0].Compliant | Should -BeTrue
    $results[0].TripartiteComplete | Should -BeTrue
    $results[0].HasInstallationMd | Should -BeTrue
    $results[0].InstallationPhases | Should -Be '7/7'
  }
}
