Describe 'Proposal lifecycle authority' {
  BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
    Import-Module $modulePath -Force
  }

  It 'lists only actions valid for a suggested proposal' {
    $actions = @(Get-LcmProposalLifecycleActions -State suggested)
    $actions | Should -Contain 'do'
    $actions | Should -Not -Contain 'push'
  }

  It 'allows normal forward lifecycle transitions' {
    Test-LcmProposalLifecycleTransition -FromState suggested -ToState in_progress | Should -BeTrue
    Test-LcmProposalLifecycleTransition -FromState in_progress -ToState verified | Should -BeTrue
    Test-LcmProposalLifecycleTransition -FromState verified -ToState in_review | Should -BeTrue
    Test-LcmProposalLifecycleTransition -FromState in_review -ToState completed | Should -BeTrue
    Test-LcmProposalLifecycleTransition -FromState completed -ToState pushed | Should -BeTrue
  }

  It 'rejects an invalid direct push transition' {
    Test-LcmProposalLifecycleTransition -FromState suggested -ToState pushed | Should -BeFalse
  }

  It 'gives every lifecycle state its documented action set' {
    $expectedActions = @{
      suggested = @('edit', 'do', 'hold', 'withdraw', 'supersede')
      in_progress = @('edit', 'verify', 'hold', 'reset', 'withdraw', 'supersede')
      verified = @('bcr', 'reopen', 'hold', 'supersede')
      in_review = @('complete', 'commit', 'reject', 'reopen', 'hold')
      completed = @('push', 'hold')
      pushed = @('view')
      held = @('continue', 'edit', 'withdraw')
      withdrawn = @('view', 'supersede')
      rejected = @('view', 'supersede', 'create-linked-bug')
      superseded = @('view')
    }

    foreach ($state in $expectedActions.Keys) {
      @(Get-LcmProposalLifecycleActions -State $state) | Should -Be $expectedActions[$state]
    }
  }

  It 'holds a proposal with compatible fields and restores its resume state' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{
            id = 9001
            state = 'in_progress'
            progress_state = 'in_progress'
            disposition = $null
          }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $held = Move-LcmProposalLifecycleState -Id 9001 -State held -Details 'Waiting for dependency.'
      $held.state | Should -Be 'held'
      $held.resume_state | Should -Be 'in_progress'
      $held.progress_state | Should -Be 'blocked'
      $held.disposition | Should -Be 'held'
      $held.hold_reason | Should -Be 'Waiting for dependency.'
      $held.dates.held | Should -Not -BeNullOrEmpty

      $resumed = Move-LcmProposalLifecycleState -Id 9001 -State $held.resume_state
      $resumed.state | Should -Be 'in_progress'
      $resumed.progress_state | Should -Be 'in_progress'
      $resumed.disposition | Should -BeNullOrEmpty
      $resumed.hold_reason | Should -BeNullOrEmpty
      $resumed.dates.in_progress | Should -Not -BeNullOrEmpty
      $resumed.state_history.Count | Should -Be 2
      $resumed.state_history[1].from_state | Should -Be 'held'
    }
  }

  It 'maps legacy state setters through lifecycle authority' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{
            id = 9002
            state = 'suggested'
            progress_state = 'undecided'
            disposition = $null
          }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $updated = Set-WorkspaceProposalState -Id 9002 -State approved -Details 'Legacy compatibility transition.'
      $updated.state | Should -Be 'in_progress'
      $updated.progress_state | Should -Be 'in_progress'
      $updated.state_history[0].from_state | Should -Be 'suggested'
    }
  }

  It 'limits ALL batch actions to proposals with valid lifecycle transitions' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{
            id = 9003
            state = 'suggested'
            progress_state = 'undecided'
            disposition = $null
          },
          [PSCustomObject]@{
            id = 9004
            state = 'in_progress'
            progress_state = 'in_progress'
            disposition = $null
          }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $updated = @(Invoke-ProposalBatchAction -Action do -TargetExpression all)
      $updated.Count | Should -Be 1
      $updated[0].id | Should -Be 9003
      $script:testProposalStore.proposals[0].state | Should -Be 'in_progress'
      $script:testProposalStore.proposals[1].state | Should -Be 'in_progress'
    }
  }

  It 'reclassifies a CRP as a BUG without changing its lifecycle state' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{
            id = 9005
            crp_id = 'CRP-9005'
            state = 'in_progress'
            progress_state = 'in_progress'
            disposition = $null
          }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $updated = Set-LcmProposalBugIdentity -Id 9005 -Details 'Emergency recovery requires BUG classification.'
      $updated.crp_id | Should -Be 'BUG-9005'
      $updated.original_crp_id | Should -Be 'CRP-9005'
      $updated.state | Should -Be 'in_progress'
      $updated.identity_history.Count | Should -Be 1
      $updated.identity_history[0].from_identity | Should -Be 'CRP-9005'
    }
  }

  It 'reclassifies a single immediate target and defers its quality checks' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{
            id = 9006
            crp_id = 'CRP-9006'
            state = 'in_progress'
            progress_state = 'in_progress'
            disposition = $null
          }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $updated = @(Enable-LcmImmediateBugRecovery -Ids 9006 -Reason 'Deadlock prevents normal recovery.')
      $updated[0].crp_id | Should -Be 'BUG-9006'
      $updated[0].quality_checks_deferred | Should -BeTrue
      $updated[0].immediate_recovery_trigger_bugs | Should -Be 'BUG-9006'
      $updated[0].state | Should -Be 'in_progress'
    }
  }

  It 'defers an explicit BUG cohort without reclassifying other proposals' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{
            id = 9007
            crp_id = 'BUG-9007'
            state = 'in_progress'
            progress_state = 'in_progress'
            disposition = $null
          },
          [PSCustomObject]@{
            id = 9008
            crp_id = 'CRP-9008'
            state = 'in_progress'
            progress_state = 'in_progress'
            disposition = $null
          }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $updated = @(Enable-LcmImmediateBugRecovery -Ids @(9007, 9008) -Reason 'Race condition requires emergency recovery.')
      $updated.Count | Should -Be 2
      $script:testProposalStore.proposals[0].quality_checks_deferred | Should -BeTrue
      $script:testProposalStore.proposals[1].quality_checks_deferred | Should -BeTrue
      $script:testProposalStore.proposals[1].crp_id | Should -Be 'CRP-9008'
      $script:testProposalStore.proposals[1].immediate_recovery_trigger_bugs | Should -Be 'BUG-9007'
    }
  }

  It 'rejects an immediate multi-proposal cohort without a BUG' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{ id = 9009; crp_id = 'CRP-9009'; state = 'in_progress' },
          [PSCustomObject]@{ id = 9010; crp_id = 'CRP-9010'; state = 'in_progress' }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      { Enable-LcmImmediateBugRecovery -Ids @(9009, 9010) -Reason 'Loop requires emergency recovery.' } |
        Should -Throw '*multi-proposal cohort containing at least one BUG*'
    }
  }
}
