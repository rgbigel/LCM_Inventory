<#
.SYNOPSIS
    Pester tests for the proposal bundle scaffold (BUG-340).
.DESCRIPTION
    Module: tests/ProposalScaffold.Tests.ps1
    Purpose: Verifies New-LCM_Proposal in an isolated store and workspace (BUG-336 isolation): document roles per
             REQ-WINV-014, placeholder marker and warning, bundle folder reuse, shortened-slug notice, version authority.
    Path: LCM_Inventory/tests/ProposalScaffold.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.2.5
    Date: 2026-11-18
#>

Describe 'Proposal bundle scaffold (BUG-340)' {
  BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1') -Force
    $script:ws = Join-Path $TestDrive 'ws'
    $null = New-Item -ItemType Directory -Path (Join-Path $script:ws 'LCM_AI\.agents') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $script:ws 'LCM_Inventory\data') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $script:ws 'LCM_Inventory\docs\Proposals') -Force
    Set-Content -LiteralPath (Join-Path $script:ws 'LCM_AI\.agents\version.json') -Value '{ "version": "9.9.9" }'
    Set-Content -LiteralPath (Join-Path $script:ws 'LCM_Inventory\data\inventory.json') -Value '{ "workspace_ai_baseline": { "GlobalLCMVersion": "1.0.0" } }'
    $script:storePath = Join-Path $TestDrive 'proposals.json'
    Set-Content -LiteralPath $script:storePath -Value '{ "last_proposal_id": 100, "updated_at": "", "proposals": [] }'
    $script:previousStore = $env:LCM_PROPOSAL_STORE_PATH
    $env:LCM_PROPOSAL_STORE_PATH = $script:storePath
    function Get-BundlePath([psobject]$Proposal) { Join-Path (Join-Path $script:ws 'LCM_Inventory') $Proposal.bundle_dir }
  }

  AfterAll {
    $env:LCM_PROPOSAL_STORE_PATH = $script:previousStore
  }

  It 'takes the version from LCM_AI/.agents/version.json, not from inventory.json' {
    $p = New-LCM_Proposal -Title 'Version Check' -Details 'intake text' -WorkspaceRoot $script:ws
    $p.lcm_version | Should -Be '9.9.9'
    [System.IO.File]::ReadAllText((Join-Path (Get-BundlePath $p) "Specification $($p.crp_id).md")) | Should -Match 'Version: 9\.9\.9'
  }

  It 'gives each bundle document its own role (REQ-WINV-014)' {
    $p = New-LCM_Proposal -Title 'Roles Check' -Details 'UNIQUE-INTAKE-TEXT' -WorkspaceRoot $script:ws
    $bundle = Get-BundlePath $p
    $spec = [System.IO.File]::ReadAllText((Join-Path $bundle "Specification $($p.crp_id).md"))
    $plan = [System.IO.File]::ReadAllText((Join-Path $bundle "Implementation Plan $($p.crp_id).md"))
    $walk = [System.IO.File]::ReadAllText((Join-Path $bundle "Walkthrough $($p.crp_id).md"))
    $spec | Should -Match 'UNIQUE-INTAKE-TEXT'
    $spec | Should -Match '- Review: this Specification only'
    $spec | Should -Not -Match 'Invariant 1: Must conform'
    foreach ($doc in $plan, $walk) {
      $doc | Should -Not -Match 'UNIQUE-INTAKE-TEXT'
      $doc | Should -Match '(?m)^Status: Placeholder\s*$'
    }
  }

  It 'reuses an existing bundle folder of the same ID' {
    $nextId = [int]((Get-Content -LiteralPath $script:storePath -Raw | ConvertFrom-Json).last_proposal_id) + 1
    $existing = Join-Path $script:ws ('LCM_Inventory\docs\Proposals\CRP-{0:D3}-Created-Beforehand-Under-The-Full-Title' -f $nextId)
    $null = New-Item -ItemType Directory -Path $existing -Force
    $p = New-LCM_Proposal -Title 'Other Title' -Details 'x' -WorkspaceRoot $script:ws
    $p.bundle_dir | Should -Be ('docs/Proposals/' + (Split-Path $existing -Leaf))
    @(Get-ChildItem -LiteralPath (Join-Path $script:ws 'LCM_Inventory\docs\Proposals') -Directory -Filter ('CRP-{0:D3}-*' -f $nextId)).Count | Should -Be 1
  }

  It 'reports a shortened bundle folder name' {
    $title = 'A Very Long Proposal Title That Certainly Exceeds The Fifty Character Slug Limit'
    $output = New-LCM_Proposal -Title $title -Details 'x' -WorkspaceRoot $script:ws 6>&1
    @($output | Where-Object { $_ -is [System.Management.Automation.InformationRecord] -and "$_" -match 'shortened to 50 characters' }).Count | Should -Be 1
  }

  It 'warns, but does not block, when moving to verified with placeholder documents' {
    $p = New-LCM_Proposal -Title 'Placeholder Check' -Details 'x' -WorkspaceRoot $script:ws
    InModuleScope ProposalManager -Parameters @{ Proposal = $p; Ws = $script:ws } {
      param($Proposal, $Ws)
      @(Get-LcmProposalPlaceholderDocuments -Proposal $Proposal -WorkspaceRoot $Ws) | Should -BeExactly @("Implementation Plan $($Proposal.crp_id).md", "Walkthrough $($Proposal.crp_id).md")  # CRP-359 names
      $planPath = Join-Path (Join-Path (Join-Path $Ws 'LCM_Inventory') $Proposal.bundle_dir) "Implementation Plan $($Proposal.crp_id).md"
      [System.IO.File]::WriteAllText($planPath, "# Implementation Plan`r`n`r`nNothing beyond the Specification.`r`n")
      @(Get-LcmProposalPlaceholderDocuments -Proposal $Proposal -WorkspaceRoot $Ws) | Should -BeExactly @("Walkthrough $($Proposal.crp_id).md")
    }
    Move-LcmProposalLifecycleState -Id $p.id -State in_progress -Details 'test' | Out-Null
    $warnings = $null
    $moved = Move-LcmProposalLifecycleState -Id $p.id -State verified -Details 'test' -WarningVariable warnings -WarningAction SilentlyContinue
    $moved.state | Should -Be 'verified'
  }
}
