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

  It 'routes an invoked COH complete action to the BCR cohort completion path' {
    $actionScript = Join-Path $PSScriptRoot '..\tools\Invoke-ProposalAction.ps1'

    {
      & $actionScript -Action complete -TargetExpression 'COH-999999' -Details 'Invocation routing regression test.'
    } | Should -Throw '*No declared review cohort, proposal, or repository matches*'
  }

  It 'classifies a computed BCR cohort without advancing lifecycle state' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{ id = 9101; crp_id = 'CRP-9101'; origin_repo = 'LCM_Inventory'; state = 'in_progress' },
          [PSCustomObject]@{ id = 9102; crp_id = 'CRP-9102'; origin_repo = 'LCM_Inventory'; state = 'verified' },
          [PSCustomObject]@{ id = 9103; crp_id = 'CRP-9103'; origin_repo = 'LCM_Inventory'; state = 'in_review' }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }

      $resolution = Get-LcmReviewCohortResolution

      $resolution.ResolutionKind | Should -Be 'computed'
      $resolution.RequiresConfirmation | Should -BeTrue
      $resolution.NeedsSelection | Should -BeFalse
      @($resolution.Members | Where-Object Classification -eq 'review_ready').Id | Should -Be 9102
      @($resolution.Members | Where-Object Classification -eq 'pending_verification').Id | Should -Be 9101
      @($resolution.Members | Where-Object Classification -eq 'already_in_review').Id | Should -Be 9103
      $script:testProposalStore.proposals[1].state | Should -Be 'verified'
    }
  }

  It 'resolves one declared BCR cohort before using computed candidates' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @(
          [PSCustomObject]@{ id = 'COH-9104'; state = 'open'; proposal_ids = @(9104) }
        )
        proposals = @(
          [PSCustomObject]@{ id = 9104; crp_id = 'CRP-9104'; origin_repo = 'LCM_AI'; state = 'verified' },
          [PSCustomObject]@{ id = 9105; crp_id = 'CRP-9105'; origin_repo = 'LCM_AI'; state = 'verified' }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }

      $resolution = Get-LcmReviewCohortResolution

      $resolution.ResolutionKind | Should -Be 'declared'
      $resolution.DeclaredCohortId | Should -Be 'COH-9104'
      $resolution.RequiresConfirmation | Should -BeFalse
      @($resolution.Members).Count | Should -Be 1
      $resolution.Members[0].Id | Should -Be 9104
    }
  }

  It 'rejects cohort completion when the current BCR staging receipt is missing' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @(
          [PSCustomObject]@{ id = 'COH-9116'; state = 'open'; prime_proposal_id = 9116; proposal_ids = @(9116); repositories = @('LCM_Inventory') }
        )
        proposals = @(
          [PSCustomObject]@{ id = 9116; crp_id = 'CRP-9116'; origin_repo = 'LCM_Inventory'; state = 'in_review'; bcr_initiated_at = '2026-10-13 10:00:00'; bcr_scope = 'COH-9116' }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Test-Path { $false }

      { Get-LcmReviewCohortCompletionPlan -CohortId 'COH-9116' } |
        Should -Throw '*Cohort staging receipt is missing*'
    }
  }

  It 'atomically records accepted BCR evidence and completes every reviewed cohort member' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @(
          [PSCustomObject]@{ id = 'COH-9117'; state = 'open'; prime_proposal_id = 9117; proposal_ids = @(9117, 9118); repositories = @('LCM_Inventory') }
        )
        proposals = @(
          [PSCustomObject]@{ id = 9117; crp_id = 'CRP-9117'; origin_repo = 'LCM_Inventory'; state = 'in_review'; bcr_initiated_at = '2026-10-13 10:00:00'; bcr_scope = 'COH-9117' },
          [PSCustomObject]@{ id = 9118; crp_id = 'CRP-9118'; origin_repo = 'LCM_Inventory'; state = 'in_review'; bcr_initiated_at = '2026-10-13 10:00:00'; bcr_scope = 'COH-9117' }
        )
      }
      $plan = [PSCustomObject]@{
        CohortId = 'COH-9117'
        ReceiptPath = 'D:\evidence\cohort-resolution.json'
        Repositories = @(
          [PSCustomObject]@{
            Repository = 'LCM_Inventory'
            Members = @(
              [PSCustomObject]@{ Id = 9117; Identity = 'CRP-9117' },
              [PSCustomObject]@{ Id = 9118; Identity = 'CRP-9118' }
            )
          }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Get-LcmReviewCohortCompletionPlan { $plan }
      Mock Test-Path { $true }
      Mock Set-ProposalStore {}

      $updated = @(Complete-LcmReviewCohortAcceptance -CohortId 'COH-9117' -ResolutionReceiptPath $plan.ReceiptPath -ReviewReceiptPaths @{ LCM_Inventory = 'D:\evidence\review.json' } -Details 'Accepted cohort review.')

      $updated.Count | Should -Be 2
      @($script:testProposalStore.proposals | ForEach-Object state | Select-Object -Unique) | Should -Be @('completed')
      @($script:testProposalStore.proposals | ForEach-Object bcr_disposition | Select-Object -Unique) | Should -Be @('Completed')
      @($script:testProposalStore.proposals | ForEach-Object bcr_resolution_receipt | Select-Object -Unique) | Should -Be @($plan.ReceiptPath)
      $script:testProposalStore.review_cohorts[0].state | Should -Be 'closed'
    }
  }

  It 'rejects partial cohort review without recording dispositions or changing members' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @(
          [PSCustomObject]@{ id = 'COH-9119'; state = 'open'; prime_proposal_id = 9119; proposal_ids = @(9119, 9120); repositories = @('LCM_Inventory') }
        )
        proposals = @(
          [PSCustomObject]@{ id = 9119; crp_id = 'CRP-9119'; origin_repo = 'LCM_Inventory'; state = 'in_review'; bcr_initiated_at = '2026-10-13 10:00:00'; bcr_scope = 'COH-9119' },
          [PSCustomObject]@{ id = 9120; crp_id = 'CRP-9120'; origin_repo = 'LCM_Inventory'; state = 'verified'; bcr_initiated_at = '2026-10-13 10:00:00'; bcr_scope = 'COH-9119' }
        )
      }
      $plan = [PSCustomObject]@{
        CohortId = 'COH-9119'
        ReceiptPath = 'D:\evidence\cohort-resolution.json'
        Repositories = @(
          [PSCustomObject]@{
            Repository = 'LCM_Inventory'
            Members = @(
              [PSCustomObject]@{ Id = 9119; Identity = 'CRP-9119' },
              [PSCustomObject]@{ Id = 9120; Identity = 'CRP-9120' }
            )
          }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Get-LcmReviewCohortCompletionPlan { $plan }
      Mock Test-Path { $true }
      Mock Set-ProposalStore {}

      {
        Complete-LcmReviewCohortAcceptance -CohortId 'COH-9119' -ResolutionReceiptPath $plan.ReceiptPath -ReviewReceiptPaths @{ LCM_Inventory = 'D:\evidence\review.json' }
      } | Should -Throw '*no member changed*'

      @($script:testProposalStore.proposals | ForEach-Object state | Select-Object -Unique) | Should -Contain 'in_review'
      $script:testProposalStore.proposals[0].PSObject.Properties['bcr_disposition'] | Should -BeNullOrEmpty
    }
  }

  It 'manages one declared cohort without allowing its prime member to be excluded' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{ id = 9106; crp_id = 'CRP-9106'; origin_repo = 'LCM_Inventory'; state = 'verified' },
          [PSCustomObject]@{ id = 9107; crp_id = 'CRP-9107'; origin_repo = 'LCM_Inventory'; state = 'verified' },
          [PSCustomObject]@{ id = 9108; crp_id = 'CRP-9108'; origin_repo = 'LCM_Inventory'; state = 'verified' }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $cohort = Set-LcmReviewCohort -Action create -ProposalIds @(9106, 9107)
      $cohort.id | Should -Be 'COH-9106'
      $cohort.proposal_ids | Should -Contain 9107

      $cohort = Set-LcmReviewCohort -Action add -ProposalIds 9108
      $cohort.proposal_ids | Should -Contain 9108

      { Set-LcmReviewCohort -Action remove -ProposalIds 9106 } | Should -Throw '*cannot be removed*'
      $cohort = Set-LcmReviewCohort -Action remove -ProposalIds 9107
      $cohort.proposal_ids | Should -Not -Contain 9107

      $cohort = Set-LcmReviewCohort -Action hold
      $cohort.state | Should -Be 'held'
      $script:testProposalStore.proposals[0].state | Should -Be 'verified'

      $cohort = Set-LcmReviewCohort -Action reopen
      $cohort.state | Should -Be 'open'
    }
  }

  It 'creates a valid active single-head cohort when no cohort is open' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{ id = 9109; crp_id = 'CRP-9109'; origin_repo = 'LCM_Inventory'; state = 'verified' }
        )
        review_cohorts = @()
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $cohort = Set-LcmReviewCohort -Action create -ProposalIds 9109

      $cohort.id | Should -Be 'COH-9109'
      $cohort.state | Should -Be 'open'
      $cohort.prime_proposal_id | Should -Be 9109
      @($cohort.proposal_ids) | Should -Be @(9109)
    }
  }

  It 'creates an inactive cohort when an open cohort already exists' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{ id = 9110; crp_id = 'CRP-9110'; origin_repo = 'LCM_Inventory'; state = 'verified' }
        )
        review_cohorts = @(
          [PSCustomObject]@{ id = 'COH-9109'; state = 'open'; prime_proposal_id = 9109; proposal_ids = @(9109) }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $cohort = Set-LcmReviewCohort -Action create -ProposalIds 9110

      $cohort.id | Should -Be 'COH-9110'
      $cohort.state | Should -Be 'inactive'
    }
  }

  It 'blocks opening an inactive cohort when an open cohort already exists' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @()
        review_cohorts = @(
          [PSCustomObject]@{ id = 'COH-9114'; state = 'open'; prime_proposal_id = 9114; proposal_ids = @(9114) },
          [PSCustomObject]@{ id = 'COH-9115'; state = 'inactive'; prime_proposal_id = 9115; proposal_ids = @(9115) }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      { Set-LcmReviewCohort -Action reopen -CohortId 'COH-9115' } |
        Should -Throw "*Open review cohort 'COH-9114' already exists*"
    }
  }

  It 'adds a member to the sole open cohort without requiring its ID' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{ id = 9111; crp_id = 'CRP-9111'; origin_repo = 'LCM_Inventory'; state = 'verified' },
          [PSCustomObject]@{ id = 9112; crp_id = 'CRP-9112'; origin_repo = 'LCM_Inventory'; state = 'verified' }
        )
        review_cohorts = @(
          [PSCustomObject]@{ id = 'COH-9111'; state = 'open'; prime_proposal_id = 9111; proposal_ids = @(9111); repositories = @('LCM_Inventory') }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $cohort = Set-LcmReviewCohort -Action add -ProposalIds 9112

      $cohort.id | Should -Be 'COH-9111'
      $cohort.proposal_ids | Should -Contain 9112
    }
  }

  It 'rejects adding members when no open cohort exists' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{ id = 9113; crp_id = 'CRP-9113'; origin_repo = 'LCM_Inventory'; state = 'verified' }
        )
        review_cohorts = @(
          [PSCustomObject]@{ id = 'COH-9100'; state = 'closed'; prime_proposal_id = 9100; proposal_ids = @(9100) }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      { Set-LcmReviewCohort -Action add -ProposalIds 9113 } |
        Should -Throw '*No open review cohort exists. Create a review cohort before adding members.*'
    }
  }

  It 'gives every lifecycle state its documented action set' {
    $expectedActions = @{
      suggested = @('edit', 'do', 'hold', 'withdraw', 'supersede')
      in_progress = @('edit', 'verify', 'hold', 'reset', 'withdraw', 'supersede')
      verified = @('bcr', 'reopen', 'hold', 'supersede')
      in_review = @('complete', 'commit', 'reject', 'reopen', 'hold')
      completed = @('push', 'hold')
      pushed = @('view')
      held = @('reopen', 'edit', 'withdraw')
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

      $resumed = Invoke-ProposalBatchAction -Action reopen -TargetExpression '9001'
      $resumed = $resumed[0]
      $resumed.state | Should -Be 'in_progress'
      $resumed.progress_state | Should -Be 'in_progress'
      $resumed.disposition | Should -BeNullOrEmpty
      $resumed.hold_reason | Should -BeNullOrEmpty
      $resumed.dates.in_progress | Should -Not -BeNullOrEmpty
      $resumed.state_history.Count | Should -Be 2
      $resumed.state_history[1].from_state | Should -Be 'held'
    }
  }

  It 'derives a legacy held proposal resume state from its history' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{
            id = 9003
            state = 'held'
            progress_state = 'blocked'
            disposition = 'held'
            state_history = @(
              [PSCustomObject]@{ state = 'suggested'; timestamp = '2026-10-01 10:00:00' },
              [PSCustomObject]@{ state = 'held'; timestamp = '2026-10-01 10:01:00' }
            )
          }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $resumed = @(Invoke-ProposalBatchAction -Action reopen -TargetExpression '9003')[0]

      $resumed.state | Should -Be 'suggested'
      $resumed.state_history[-1].from_state | Should -Be 'held'
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

  It 'rejects a nonexistent numeric CRP before applying a batch lifecycle action' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{
            id = 9001
            state = 'suggested'
            progress_state = 'undecided'
            disposition = $null
          }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      {
        Invoke-ProposalBatchAction -Action do -TargetExpression '9701'
      } | Should -Throw "*Target expression '9701' contains unresolved CRP ID(s): 9701*"

      $script:testProposalStore.proposals[0].state | Should -Be 'suggested'
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

  It 'records both sides of a supersession relationship' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{ id = 9011; state = 'suggested'; progress_state = 'undecided'; disposition = $null },
          [PSCustomObject]@{ id = 9012; state = 'suggested'; progress_state = 'undecided'; disposition = $null }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $updated = Set-LcmProposalSupersession -Id 9011 -SuccessorId 9012 -Details 'Replacement scope is approved.'

      $updated.state | Should -Be 'superseded'
      $updated.superseded_by_id | Should -Be 9012
      $script:testProposalStore.proposals[1].supersedes_id | Should -Be 9011
    }
  }

  It 'rejects an ineligible cohort lifecycle action without changing any member' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @([PSCustomObject]@{ id = 'COH-9013'; state = 'open'; proposal_ids = @(9013, 9014) })
        proposals = @(
          [PSCustomObject]@{ id = 9013; state = 'suggested'; progress_state = 'undecided'; disposition = $null },
          [PSCustomObject]@{ id = 9014; state = 'completed'; progress_state = 'completed'; disposition = $null }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      { Invoke-LcmCohortLifecycleAction -CohortId 'COH-9013' -Action do } | Should -Throw '*no member changed*'
      $script:testProposalStore.proposals[0].state | Should -Be 'suggested'
      $script:testProposalStore.proposals[1].state | Should -Be 'completed'
    }
  }

  It 'proceeds every declared cohort member atomically' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @([PSCustomObject]@{ id = 'COH-9266'; state = 'open'; proposal_ids = @(9266, 9265) })
        proposals = @(
          [PSCustomObject]@{ id = 9266; state = 'suggested'; progress_state = 'undecided'; disposition = $null },
          [PSCustomObject]@{ id = 9265; state = 'in_progress'; progress_state = 'in_progress'; disposition = $null }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $updated = @(Invoke-LcmCohortLifecycleAction -CohortId 'COH-9266' -Action proceed)

      @($updated | Select-Object -ExpandProperty id) | Should -Be @(9266, 9265)
      $script:testProposalStore.proposals[0].state | Should -Be 'in_progress'
      $script:testProposalStore.proposals[1].state | Should -Be 'in_progress'
    }
  }

  It 'invokes lifecycle action atomically for the sole member of an active single-head cohort' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @(
          [PSCustomObject]@{
            id = 'COH-9268'
            state = 'open'
            prime_proposal_id = 9268
            proposal_ids = @(9268)
          }
        )
        proposals = @(
          [PSCustomObject]@{ id = 9268; state = 'suggested'; progress_state = 'undecided'; disposition = $null }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $updated = @(Invoke-LcmCohortLifecycleAction -CohortId 'COH-9268' -Action proceed)

      @($updated).Count | Should -Be 1
      $updated[0].id | Should -Be 9268
      $script:testProposalStore.proposals[0].state | Should -Be 'in_progress'
    }
  }

  It 'lists every ineligible cohort member and preserves every member atomically' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @([PSCustomObject]@{ id = 'COH-9267'; state = 'open'; proposal_ids = @(9267, 9268, 9269) })
        proposals = @(
          [PSCustomObject]@{ id = 9267; state = 'verified'; progress_state = 'verification'; disposition = $null },
          [PSCustomObject]@{ id = 9268; state = 'completed'; progress_state = 'completed'; disposition = $null },
          [PSCustomObject]@{ id = 9269; state = 'suggested'; progress_state = 'undecided'; disposition = $null }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      { Invoke-LcmCohortLifecycleAction -CohortId 'COH-9267' -Action proceed } |
        Should -Throw "*no member changed*Proposal #9267 cannot synchronize from 'verified'*Proposal #9268 cannot synchronize from 'completed'*"
      $script:testProposalStore.proposals[0].state | Should -Be 'verified'
      $script:testProposalStore.proposals[1].state | Should -Be 'completed'
      $script:testProposalStore.proposals[2].state | Should -Be 'suggested'
    }
  }

  It 'requires a recorded BCR disposition before passing a review gate' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{ id = 9015; state = 'in_review'; progress_state = 'verification'; disposition = $null }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      { Move-LcmProposalLifecycleState -Id 9015 -State completed } |
        Should -Throw '*recorded BCR disposition*'
      $script:testProposalStore.proposals[0].state | Should -Be 'in_review'

      $script:testProposalStore.proposals[0] | Add-Member -NotePropertyName 'bcr_disposition' -NotePropertyValue 'Completed'
      $completed = Move-LcmProposalLifecycleState -Id 9015 -State completed
      $completed.state | Should -Be 'completed'
    }
  }

  It 'allows an explicit authorized BCR bypass but not Force alone' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        proposals = @(
          [PSCustomObject]@{ id = 9016; state = 'in_review'; progress_state = 'verification'; disposition = $null; force_commit = $true },
          [PSCustomObject]@{ id = 9017; state = 'in_review'; progress_state = 'verification'; disposition = $null; bcr_bypass_authorized = $true }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      { Move-LcmProposalLifecycleState -Id 9016 -State completed } |
        Should -Throw '*recorded BCR disposition*'
      (Move-LcmProposalLifecycleState -Id 9017 -State completed).state | Should -Be 'completed'
    }
  }

  It 'automatically synchronizes every valid open cohort member before BCR' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @([PSCustomObject]@{ id = 'COH-9301'; state = 'open'; proposal_ids = @(9301, 9302) })
        proposals = @(
          [PSCustomObject]@{ id = 9301; state = 'in_progress'; verification_status = 'passed'; progress_state = 'in_progress'; disposition = $null },
          [PSCustomObject]@{ id = 9302; state = 'in_progress'; verification_evidence = 'Focused tests passed'; progress_state = 'in_progress'; disposition = $null }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $result = Sync-LcmCohortGateState -CohortId 'COH-9301' -Gate BCR -Details 'Validated cohort BCR preflight.'

      @($result.SynchronizedMemberIds) | Should -Be @(9301, 9302)
      @($result.NoOpMemberIds).Count | Should -Be 0
      $script:testProposalStore.proposals.state | Should -Be @('verified', 'verified')
      $script:testProposalStore.review_cohorts[0].gate_history[-1].required_state | Should -Be 'verified'
    }
  }

  It 'stops BCR synchronization without a partial lifecycle transition when one member lacks evidence' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @([PSCustomObject]@{ id = 'COH-9303'; state = 'open'; proposal_ids = @(9303, 9304) })
        proposals = @(
          [PSCustomObject]@{ id = 9303; state = 'in_progress'; verification_status = 'passed'; progress_state = 'in_progress'; disposition = $null },
          [PSCustomObject]@{ id = 9304; state = 'in_progress'; progress_state = 'in_progress'; disposition = $null }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      { Sync-LcmCohortGateState -CohortId 'COH-9303' -Gate BCR } |
        Should -Throw '*no member changed*Proposal #9304 cannot synchronize to verified*'
      $script:testProposalStore.proposals.state | Should -Be @('in_progress', 'in_progress')
      $script:testProposalStore.review_cohorts[0].gate_history[-1].stopped_members |
        Should -Contain 'Proposal #9304 cannot synchronize to verified: validated verification evidence is missing.'
    }
  }

  It 'does not begin BCR lifecycle advancement until every cohort member is aligned' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @([PSCustomObject]@{ id = 'COH-9305'; state = 'open'; proposal_ids = @(9305, 9306) })
        proposals = @(
          [PSCustomObject]@{ id = 9305; state = 'verified'; progress_state = 'verification'; disposition = $null },
          [PSCustomObject]@{ id = 9306; state = 'in_progress'; verification_status = 'passed'; progress_state = 'in_progress'; disposition = $null }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $members = @(Invoke-LcmCohortLifecycleAction -CohortId 'COH-9305' -Action bcr)

      $members.state | Should -Be @('verified', 'verified')
      $script:testProposalStore.proposals.state | Should -Be @('verified', 'verified')
    }
  }

  It 'records a pre-aligned cohort gate as a no-op' {
    InModuleScope ProposalManager {
      $script:testProposalStore = [PSCustomObject]@{
        review_cohorts = @([PSCustomObject]@{ id = 'COH-9307'; state = 'open'; proposal_ids = @(9307, 9308) })
        proposals = @(
          [PSCustomObject]@{ id = 9307; state = 'verified'; progress_state = 'verification'; disposition = $null },
          [PSCustomObject]@{ id = 9308; state = 'verified'; progress_state = 'verification'; disposition = $null }
        )
      }
      Mock Get-ProposalStore { $script:testProposalStore }
      Mock Set-ProposalStore {}

      $result = Sync-LcmCohortGateState -CohortId 'COH-9307' -Gate BCR

      @($result.SynchronizedMemberIds).Count | Should -Be 0
      @($result.NoOpMemberIds) | Should -Be @(9307, 9308)
      $script:testProposalStore.review_cohorts[0].gate_history[-1].no_op_member_ids | Should -Be @(9307, 9308)
    }
  }
}
