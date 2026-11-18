<#
.SYNOPSIS
    Pester tests for item completion across all reviewed repositories and BUG creation/merge (BUG-351).
.DESCRIPTION
    Module: tests/ProposalCompletion.Tests.ps1
    Purpose: Verifies Invoke-ProposalAction.ps1 helper functions: changed governed repositories, primary/secondary
             completion order with cross-repository obligations, and merged BUG findings.
    Path: LCM_Inventory/tests/ProposalCompletion.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.2.3
    Date: 2026-11-18
#>

Describe 'Item completion across reviewed repositories (BUG-351)' {
  BeforeAll {
    $actionScript = Join-Path $PSScriptRoot '..\tools\Invoke-ProposalAction.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($actionScript, [ref]$tokens, [ref]$errors)
    $names = @('Test-LcmCompletionExcludedPath', 'Get-LcmChangedGovernedRepositories', 'Invoke-LcmItemReviewCompletion', 'Add-LcmBugMergedFinding')
    $definitions = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in $names }, $false))
    $definitions.Count | Should -Be $names.Count
    foreach ($definition in $definitions) { . ([scriptblock]::Create($definition.Extent.Text)) }

    function New-TestRepository([string]$Path) {
      $null = New-Item -ItemType Directory -Path $Path -Force
      $null = git -C $Path init --quiet
    }

    $script:workspaceRoot = Join-Path $TestDrive 'ws'
    New-TestRepository $script:workspaceRoot
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot '.git\info\exclude') -Value 'LCM_*/'
    foreach ($name in 'LCM_AI', 'LCM_Inventory') { New-TestRepository (Join-Path $script:workspaceRoot $name) }
    $script:LcmGovernedCompletionRepositories = @('Git_Repositories', 'LCM_AI', 'LCM_Inventory', 'LCM_Shared', 'LCM_Supervision', 'LCM_Tools')

    $script:submitLog = Join-Path $TestDrive 'submit.log'
    $script:LcmSubmitReviewResultPath = Join-Path $TestDrive 'submit-stub.ps1'
    Set-Content -LiteralPath $script:LcmSubmitReviewResultPath -Value @'
param([string]$RepositoryPath, [string]$CRP, [string]$Result, [string]$Notes)
Add-Content -LiteralPath $env:BUG351_SUBMIT_LOG -Value $RepositoryPath
'@
    $env:BUG351_SUBMIT_LOG = $script:submitLog

    $script:testStore = [PSCustomObject]@{
      proposals = @([PSCustomObject]@{ id = 1; crp_id = 'BUG-001'; origin_repo = 'LCM_Inventory'; state = 'in_review'; details = 'original'; bundle_dir = 'docs/Proposals/BUG-001-Test' })
    }
    function Get-ProposalStore { $script:testStore }
    function Set-ProposalStore { param($Store) }
    function Get-LcmProposalReviewObligations { param($Proposal, [switch]$UnresolvedOnly) @() }
    function Register-LcmCrossRepositoryReviewObligation { param([int]$Id, [string]$Repository, [string]$Reason) $script:registered.Add($Repository) }
  }

  BeforeEach {
    $script:registered = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $script:submitLog) { Remove-Item -LiteralPath $script:submitLog -Force }
    foreach ($name in 'LCM_AI', 'LCM_Inventory') {
      Get-ChildItem -LiteralPath (Join-Path $script:workspaceRoot $name) -Force | Where-Object { $_.Name -ne '.git' } | Remove-Item -Recurse -Force
    }
    Get-ChildItem -LiteralPath $script:workspaceRoot -Force | Where-Object { $_.Name -notin @('.git', 'LCM_AI', 'LCM_Inventory') } | Remove-Item -Recurse -Force
  }

  It 'ignores excluded paths and reports only repositories with committable changes' {
    $null = New-Item -ItemType Directory -Path (Join-Path $script:workspaceRoot 'LCM_Inventory\data') -Force
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_Inventory\data\proposals.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_AI\rule.md') -Value 'x'
    @(Get-LcmChangedGovernedRepositories) | Should -BeExactly @('LCM_AI')
  }

  It 'commits the secondary repositories first and the origin repository last' {
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_AI\rule.md') -Value 'x'
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_Inventory\tool.ps1') -Value 'x'
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'root.md') -Value 'x'
    Invoke-LcmItemReviewCompletion -ProposalId 1 -ReviewResultArgs @{ RepositoryPath = 'LCM_Inventory'; CRP = 'BUG-001'; Result = 'Completed'; Notes = 'n' }
    @(Get-Content -LiteralPath $script:submitLog) | Should -BeExactly @('Git_Repositories', 'LCM_AI', 'LCM_Inventory')
    @($script:registered) | Should -BeExactly @('Git_Repositories', 'LCM_AI')
  }

  It 'uses the last changed repository as primary when the origin repository is unchanged' {
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_AI\rule.md') -Value 'x'
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'root.md') -Value 'x'
    Invoke-LcmItemReviewCompletion -ProposalId 1 -ReviewResultArgs @{ RepositoryPath = 'LCM_Inventory'; CRP = 'BUG-001'; Result = 'Completed'; Notes = 'n' }
    @(Get-Content -LiteralPath $script:submitLog) | Should -BeExactly @('Git_Repositories', 'LCM_AI')
    @($script:registered) | Should -BeExactly @('Git_Repositories')
  }

  It 'keeps the single-repository path when nothing is changed' {
    Invoke-LcmItemReviewCompletion -ProposalId 1 -ReviewResultArgs @{ RepositoryPath = 'LCM_Inventory'; CRP = 'BUG-001'; Result = 'Completed'; Notes = 'n' }
    @(Get-Content -LiteralPath $script:submitLog) | Should -BeExactly @('LCM_Inventory')
    $script:registered.Count | Should -Be 0
  }

  It 'merges a finding into an existing BUG ledger entry and its specification' {
    $bundle = Join-Path $script:workspaceRoot 'LCM_Inventory\docs\Proposals\BUG-001-Test'
    $null = New-Item -ItemType Directory -Path $bundle -Force
    [System.IO.File]::WriteAllText((Join-Path $bundle 'Specification.md'), "# Specification: BUG-001`r`n")
    $merged = Add-LcmBugMergedFinding -ProposalId 1 -Finding 'second finding'
    $merged.details | Should -Match 'original'
    $merged.details | Should -Match '\[merged .+\] second finding'
    $spec = [System.IO.File]::ReadAllText((Join-Path $bundle 'Specification.md'))
    $spec | Should -Match '## Merged Findings'
    $spec | Should -Match '- \[merged .+\] second finding'
  }

  It 'refuses to merge a finding into a non-BUG item' {
    $script:testStore.proposals[0].crp_id = 'CRP-001'
    try {
      { Add-LcmBugMergedFinding -ProposalId 1 -Finding 'x' } | Should -Throw '*requires a BUG target*'
    } finally {
      $script:testStore.proposals[0].crp_id = 'BUG-001'
    }
  }
}
