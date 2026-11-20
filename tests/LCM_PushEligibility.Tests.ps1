<#
.SYNOPSIS
  Tests completed-only and lockstep push eligibility.
.DESCRIPTION
  Module: tests/LCM_PushEligibility.Tests.ps1
  Purpose: Verifies that PUSH targets every repository with commits ahead of its remote (BUG-380 B12),
           keeps LCM_Inventory in lockstep, and preflights every member of the required cohort.
  Path: LCM_Inventory/tests/LCM_PushEligibility.Tests.ps1
  Implementation Choices (BUG-380 B12): the former cases "requires a completed proposal" and "targets
  origin_repo / affected_repos" encoded the retired eligibility rule; they are replaced by cases derived from
  the operator rule of 2026-11-20 (everything changed and committed is pushed, governed or not).
  Authors: GitHub Copilot, Claude
  Version: 10.2.3
  Date: 2026-11-20
#>

Describe 'Workspace push eligibility' {
  BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\modules\LCM_PushEligibility.psm1'
    Import-Module -Name $modulePath -Force
  }

  It 'refuses a push when no repository is ahead of its remote' {
    $proposals = @(
      [pscustomobject]@{ id = 101; origin_repo = 'LCM_Inventory'; state = 'completed'; progress_state = 'completed' }
    )

    { Resolve-WorkspacePushPlan -Proposals $proposals -AheadRepositories @() } | Should -Throw '*nothing to push*'
  }

  It 'pushes ahead repositories even without a completed proposal (push is maintenance and backup)' {
    $proposals = @(
      [pscustomobject]@{ id = 101; origin_repo = 'ExampleRepo'; state = 'in_progress'; progress_state = 'in_progress' }
    )

    $plan = Resolve-WorkspacePushPlan -Proposals $proposals -AheadRepositories @('ExampleRepo')

    $plan.TargetRepositories | Should -Be @('ExampleRepo')
    @($plan.CompletedProposalIds).Count | Should -Be 0
  }

  It 'targets every ahead repository, governed or not, independent of origin_repo' {
    $proposals = @(
      [pscustomobject]@{ id = 102; origin_repo = 'LCM_Inventory'; state = 'completed'; progress_state = 'completed' }
    )

    $plan = Resolve-WorkspacePushPlan -Proposals $proposals -AheadRepositories @('ExampleRepo', 'LCM_AI', '.', 'LCM_Inventory')

    $plan.TargetRepositories | Should -Contain 'ExampleRepo'
    $plan.TargetRepositories | Should -Contain 'LCM_AI'
    $plan.TargetRepositories | Should -Contain 'Git_Repositories'
    $plan.TargetRepositories | Should -Contain 'LCM_Inventory'
    $plan.RequiredRepositories | Should -Contain 'LCM_Inventory'
    $plan.CompletedProposalIds | Should -Contain 102
    $plan.CompletedProposals[0].Repository | Should -Be 'LCM_Inventory'
    $plan.CompletedProposals[0].BundlePath | Should -Be ''
  }

  It 'does not push an unchanged repository' {
    $plan = Resolve-WorkspacePushPlan -Proposals @() -AheadRepositories @('ExampleRepo')

    $plan.RequiredRepositories | Should -Not -Contain 'LCM_Inventory'
    $plan.RequiredRepositories | Should -Not -Contain 'OtherRepo'
  }

  It 'refuses a requested repository that has nothing ahead' {
    { Resolve-WorkspacePushPlan -Proposals @() -AheadRepositories @('ExampleRepo') -RequestedRepositories @('OtherRepo') } | Should -Throw '*OtherRepo*'
  }

  It 'keeps LCM_Inventory in lockstep with a requested subset when it is ahead' {
    $plan = Resolve-WorkspacePushPlan -Proposals @() -AheadRepositories @('ExampleRepo', 'LCM_Inventory', 'LCM_AI') -RequestedRepositories @('ExampleRepo')

    $plan.TargetRepositories | Should -Be @('ExampleRepo')
    $plan.RequiredRepositories | Should -Contain 'LCM_Inventory'
    $plan.RequiredRepositories | Should -Not -Contain 'LCM_AI'
  }

  It 'includes every completed proposal and validates requested proposal IDs' {
    $proposals = @(
      [pscustomobject]@{ id = 105; origin_repo = 'ExampleRepo'; state = 'completed'; progress_state = 'completed' },
      [pscustomobject]@{ id = 106; origin_repo = 'LCM_Inventory'; state = 'completed'; progress_state = 'completed' },
      [pscustomobject]@{ id = 107; origin_repo = 'LCM_Inventory'; state = 'in_progress'; progress_state = 'in_progress' }
    )

    $plan = Resolve-WorkspacePushPlan -Proposals $proposals -AheadRepositories @('LCM_Inventory') -RequestedRepositories @('')

    $plan.CompletedProposalIds | Should -Contain 105
    $plan.CompletedProposalIds | Should -Contain 106
    $plan.CompletedProposalIds | Should -Not -Contain 107
    { Resolve-WorkspacePushPlan -Proposals $proposals -AheadRepositories @('LCM_Inventory') -ProposalIds @(107) } | Should -Throw '*107*'
  }

  It 'allows a fully eligible lockstep cohort' {
    $plan = Resolve-WorkspacePushPlan -Proposals @() -AheadRepositories @('ExampleRepo', 'LCM_Inventory')
    $repositoryStates = @(
      [pscustomobject]@{ Name = 'ExampleRepo'; HasGit = $true; HasRemote = $true; AheadCount = 1 },
      [pscustomobject]@{ Name = 'LCM_Inventory'; HasGit = $true; HasRemote = $true; AheadCount = 1 }
    )

    Test-WorkspacePushCohort -PushPlan $plan -RepositoryStates $repositoryStates | Should -BeTrue
  }

  It 'rejects a lockstep cohort member that is not ahead' {
    $plan = Resolve-WorkspacePushPlan -Proposals @() -AheadRepositories @('ExampleRepo', 'LCM_Inventory')
    $repositoryStates = @(
      [pscustomobject]@{ Name = 'ExampleRepo'; HasGit = $true; HasRemote = $true; AheadCount = 1 },
      [pscustomobject]@{ Name = 'LCM_Inventory'; HasGit = $true; HasRemote = $true; AheadCount = 0 }
    )

    { Test-WorkspacePushCohort -PushPlan $plan -RepositoryStates $repositoryStates } | Should -Throw '*LCM_Inventory*ahead*'
  }

  It 'resolves the bundle repository of governed LCM_* proposals to LCM_Inventory (BUG-349)' {
    $proposals = @(
      [pscustomobject]@{ id = 331; origin_repo = 'LCM_AI'; state = 'completed'; progress_state = 'completed'; bundle_dir = 'docs/Proposals/CRP-331-Example' },
      [pscustomobject]@{ id = 110; origin_repo = 'ExampleRepo'; state = 'completed'; progress_state = 'completed'; bundle_dir = 'docs/Proposals/CRP-110-Example' }
    )
    $plan = Resolve-LCM_PushPlan -Proposals $proposals -AheadRepositories @('LCM_Inventory')
    $governed = @($plan.CompletedProposals | Where-Object { $_.Id -eq 331 })[0]
    $foreign = @($plan.CompletedProposals | Where-Object { $_.Id -eq 110 })[0]
    $governed.Repository | Should -Be 'LCM_AI'
    $governed.BundleRepository | Should -Be 'LCM_Inventory'
    $foreign.BundleRepository | Should -Be 'ExampleRepo'
  }

  It 'discovers ahead, unchanged and untracked repositories of a workspace (BUG-380 B12)' {
    $root = Join-Path $TestDrive 'ws'
    $remote = Join-Path $TestDrive 'remote.git'
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    git init -q --bare $remote
    git -C $root init -q
    foreach ($name in 'AheadRepo', 'CleanRepo', 'LocalRepo') {
      $path = Join-Path $root $name
      git init -q $path
      git -C $path config user.name 'LCM Test'
      git -C $path config user.email 'lcm@test.local'
      Set-Content -LiteralPath (Join-Path $path 'a.txt') -Value 'a' -Encoding UTF8
      git -C $path add -- a.txt
      git -C $path commit -q -m 'a'
    }
    New-Item -ItemType Directory -Path (Join-Path $root 'NotGit') -Force | Out-Null
    foreach ($name in 'AheadRepo', 'CleanRepo') {
      $path = Join-Path $root $name
      $branch = (git -C $path rev-parse --abbrev-ref HEAD).Trim()
      git -C $path remote add origin $remote
      $pushOutput = git -C $path push -u origin ('{0}:{1}' -f $branch, $name) 2>&1
      $LASTEXITCODE | Should -Be 0 -Because ($pushOutput | Out-String)
    }
    $aheadPath = Join-Path $root 'AheadRepo'
    Set-Content -LiteralPath (Join-Path $aheadPath 'b.txt') -Value 'b' -Encoding UTF8
    git -C $aheadPath add -- b.txt
    git -C $aheadPath commit -q -m 'b'

    $states = @(Get-LCM_PushRepositoryStates -WorkspaceRoot $root)

    @($states.Name) | Should -Not -Contain 'NotGit'
    @($states | Where-Object Name -eq 'AheadRepo')[0].AheadCount | Should -Be 1
    @($states | Where-Object Name -eq 'CleanRepo')[0].AheadCount | Should -Be 0
    @($states | Where-Object Name -eq 'LocalRepo')[0].HasRemote | Should -BeFalse
    @($states | Where-Object Name -eq 'Git_Repositories')[0].HasRemote | Should -BeFalse
  }

  It 'classifies the LCM core and the inventory-governed repositories as governed (review item 10, corrected)' {
    $inventory = @(
      [pscustomobject]@{ RepositoryName = 'BootEntryManager'; LCMStatus = 'governed'; CurrentLCMVersion = '10.6.3' },
      [pscustomobject]@{ RepositoryName = 'HaSSD06'; LCMStatus = 'not-lcm'; CurrentLCMVersion = $null }
    )
    foreach ($name in 'LCM_AI', 'LCM_Inventory', 'LCM_Shared', 'LCM_Supervision', 'LCM_Tools', 'Git_Repositories', '.') {
      Test-LCM_GovernedPushRepository -RepositoryName $name -InventoryRepositories $inventory | Should -BeTrue
    }
    Test-LCM_GovernedPushRepository -RepositoryName 'BootEntryManager' -InventoryRepositories $inventory | Should -BeTrue
    Test-LCM_GovernedPushRepository -RepositoryName 'HaSSD06' -InventoryRepositories $inventory | Should -BeFalse
    Test-LCM_GovernedPushRepository -RepositoryName 'Unknown' -InventoryRepositories $inventory | Should -BeFalse
  }

  It 'holds back governed repositories that are not converged and never pushes them (operator 2026-11-20)' {
    $inventory = @(
      [pscustomobject]@{ RepositoryName = 'BootEntryManager'; LCMStatus = 'governed'; CurrentLCMVersion = '10.6.3' },
      [pscustomobject]@{ RepositoryName = 'VolumeInventory'; LCMStatus = 'governed'; CurrentLCMVersion = '10.8.4' },
      [pscustomobject]@{ RepositoryName = 'LCM_Shared'; LCMStatus = 'governed'; CurrentLCMVersion = '10.6.3' },
      [pscustomobject]@{ RepositoryName = 'HaSSD06'; LCMStatus = 'not-lcm'; CurrentLCMVersion = $null }
    )
    $held = @(Get-LCM_UnconvergedPushRepositories -InventoryRepositories $inventory -LcmVersion '10.8.4')
    @($held.Name) | Should -Be @('BootEntryManager')

    $plan = Resolve-WorkspacePushPlan -Proposals @() -AheadRepositories @('BootEntryManager', 'VolumeInventory', 'HaSSD06', 'LCM_Inventory') -HeldRepositories @($held.Name)
    $plan.TargetRepositories | Should -Not -Contain 'BootEntryManager'
    $plan.TargetRepositories | Should -Contain 'VolumeInventory'
    $plan.TargetRepositories | Should -Contain 'HaSSD06'
    { Resolve-WorkspacePushPlan -Proposals @() -AheadRepositories @('BootEntryManager') -RequestedRepositories @('BootEntryManager') -HeldRepositories @('BootEntryManager') } | Should -Throw '*not converged*'
  }

  It 'never refuses a push because of a non-governed repository (review item 10)' {
    $plan = Resolve-WorkspacePushPlan -Proposals @() -AheadRepositories @('ExampleRepo', 'LCM_Inventory')
    $repositoryStates = @(
      [pscustomobject]@{ Name = 'LCM_Inventory'; HasGit = $true; HasRemote = $true; AheadCount = 1 }
    )

    Test-WorkspacePushCohort -PushPlan $plan -RepositoryStates $repositoryStates | Should -BeTrue
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
    # BUG-349: a missing bundle is bookkeeping; it warns and returns false, never throws (RULE-EFF-002).
    $warnings = $null
    $result = Test-WorkspaceProposalBundlesInHead -PushPlan $pushPlan -RepositoryStates $repositoryStates -WarningVariable warnings -WarningAction SilentlyContinue
    $result | Should -BeFalse
    ($warnings -join ' ') | Should -Match 'not present.*HEAD'
  }
}
