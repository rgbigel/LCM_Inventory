<#
.SYNOPSIS
  Tests completed-only and lockstep push eligibility.
.DESCRIPTION
  Module: tests/LCM_PushEligibility.Tests.ps1
  Purpose: Verifies that PUSH requires completed proposals and preflights every
           member of the required lockstep cohort.
  Path: LCM_Inventory/tests/LCM_PushEligibility.Tests.ps1
  Authors: GitHub Copilot
  Version: 10.2.0
  Date: 2026-10-13
#>

Describe 'Workspace push eligibility' {
  BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\modules\LCM_PushEligibility.psm1'
    Import-Module -Name $modulePath -Force
  }

  It 'requires a completed proposal before creating a push cohort' {
    $proposals = @(
      [pscustomobject]@{ id = 101; origin_repo = 'ExampleRepo'; state = 'in_progress'; progress_state = 'in_progress' }
    )

    { Resolve-WorkspacePushPlan -Proposals $proposals } | Should -Throw '*requires at least one proposal*'
  }

  It 'includes LCM_Inventory in every completed proposal push cohort' {
    $proposals = @(
      [pscustomobject]@{ id = 102; origin_repo = 'ExampleRepo'; affected_repos = @('LCM_AI', 'Git_Repositories'); state = 'completed'; progress_state = 'completed' }
    )

    $plan = Resolve-WorkspacePushPlan -Proposals $proposals -RequestedRepositories 'ExampleRepo'

    $plan.TargetRepositories | Should -Contain 'ExampleRepo'
    $plan.TargetRepositories | Should -Contain 'LCM_AI'
    $plan.TargetRepositories | Should -Contain 'Git_Repositories'
    $plan.RequiredRepositories | Should -Contain 'LCM_Inventory'
    $plan.CompletedProposalIds | Should -Contain 102
    $plan.CompletedProposals[0].Repository | Should -Be 'ExampleRepo'
    $plan.CompletedProposals[0].BundlePath | Should -Be ''
  }

  It 'includes every completed proposal when no repository filter is supplied' {
    $proposals = @(
      [pscustomobject]@{ id = 105; origin_repo = 'ExampleRepo'; state = 'completed'; progress_state = 'completed' },
      [pscustomobject]@{ id = 106; origin_repo = 'LCM_Inventory'; state = 'completed'; progress_state = 'completed' }
    )

    $plan = Resolve-WorkspacePushPlan -Proposals $proposals -RequestedRepositories @('')

    $plan.CompletedProposalIds | Should -Contain 105
    $plan.CompletedProposalIds | Should -Contain 106
  }

  It 'allows a fully eligible completed proposal lockstep cohort' {
    $proposals = @(
      [pscustomobject]@{ id = 103; origin_repo = 'ExampleRepo'; state = 'completed'; progress_state = 'completed' }
    )
    $plan = Resolve-WorkspacePushPlan -Proposals $proposals
    $repositoryStates = @(
      [pscustomobject]@{ Name = 'ExampleRepo'; HasGit = $true; HasRemote = $true; AheadCount = 1 },
      [pscustomobject]@{ Name = 'LCM_Inventory'; HasGit = $true; HasRemote = $true; AheadCount = 1 }
    )

    Test-WorkspacePushCohort -PushPlan $plan -RepositoryStates $repositoryStates | Should -BeTrue
  }

  It 'rejects a lockstep cohort when LCM_Inventory is not ahead' {
    $proposals = @(
      [pscustomobject]@{ id = 103; origin_repo = 'ExampleRepo'; state = 'completed'; progress_state = 'completed' }
    )
    $plan = Resolve-WorkspacePushPlan -Proposals $proposals
    $repositoryStates = @(
      [pscustomobject]@{ Name = 'ExampleRepo'; HasGit = $true; HasRemote = $true; AheadCount = 1 },
      [pscustomobject]@{ Name = 'LCM_Inventory'; HasGit = $true; HasRemote = $true; AheadCount = 0 }
    )

    { Test-WorkspacePushCohort -PushPlan $plan -RepositoryStates $repositoryStates } | Should -Throw '*LCM_Inventory*ahead*'
  }

  It 'requires a completed proposal bundle to exist in repository HEAD' {
    $repoPath = Join-Path $TestDrive 'ExampleRepo'
    New-Item -ItemType Directory -Path (Join-Path $repoPath 'docs\Proposals\CRP-104-Example') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $repoPath 'docs\Proposals\CRP-104-Example\Specification.md') -Value '# Example' -Encoding UTF8
    git -C $repoPath init -q
    git -C $repoPath config user.name 'LCM Test'
    git -C $repoPath config user.email 'lcm@test.local'
    git -C $repoPath add -- docs/Proposals
    git -C $repoPath commit -q -m 'docs: add proposal bundle'

    $pushPlan = [pscustomobject]@{
      CompletedProposals = @([pscustomobject]@{ Id = 104; Repository = 'ExampleRepo'; BundlePath = 'docs/Proposals/CRP-104-Example' })
    }
    $repositoryStates = @([pscustomobject]@{ Name = 'ExampleRepo'; Path = $repoPath })

    Test-WorkspaceProposalBundlesInHead -PushPlan $pushPlan -RepositoryStates $repositoryStates | Should -BeTrue
    $pushPlan.CompletedProposals[0].BundlePath = 'docs/Proposals/Missing'
    { Test-WorkspaceProposalBundlesInHead -PushPlan $pushPlan -RepositoryStates $repositoryStates } | Should -Throw '*not present*HEAD*'
  }
}
