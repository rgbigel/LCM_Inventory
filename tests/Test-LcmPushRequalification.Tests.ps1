<#
.SYNOPSIS
  Unit and integration tests for LcmPushRequalification module and pre-push triage.
.DESCRIPTION
  Path: LCM_Inventory/tests/Test-LcmPushRequalification.Tests.ps1
  Authors: Rolf, LCM_AI Engine
  Date: 2026-11-12 12:45:00
#>

BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..\modules\LcmPushRequalification.psm1'
  Import-Module -Name $modulePath -Force
}

Describe 'LcmPushRequalification Module Tests' {
  Context 'Module exports and AST validation' {
    It 'Exports the required preflight and requalification cmdlets' {
      Get-Command Test-LcmPublishPreflight | Should -Not -BeNullOrEmpty
      Get-Command Show-LcmPublishTriagePrompt | Should -Not -BeNullOrEmpty
      Get-Command Invoke-RemediationStep | Should -Not -BeNullOrEmpty
      Get-Command Invoke-LcmStepwiseRequalification | Should -Not -BeNullOrEmpty
    }

    It 'Passes AST syntax validation on the module file' {
      $tokens = $null
      $errors = $null
      [System.Management.Automation.Language.Parser]::ParseFile($modulePath, [ref]$tokens, [ref]$errors) | Out-Null
      $errors.Count | Should -Be 0
    }

    It 'Passes AST syntax validation on Invoke-LcmPushRequalification.ps1' {
      $toolPath = Join-Path $PSScriptRoot '..\tools\Invoke-LcmPushRequalification.ps1'
      $tokens = $null
      $errors = $null
      [System.Management.Automation.Language.Parser]::ParseFile($toolPath, [ref]$tokens, [ref]$errors) | Out-Null
      $errors.Count | Should -Be 0
    }

    It 'Passes AST syntax validation on Invoke-LCM_Push.ps1' {
      $pushPath = Join-Path $PSScriptRoot '..\tools\Invoke-LCM_Push.ps1'
      $tokens = $null
      $errors = $null
      [System.Management.Automation.Language.Parser]::ParseFile($pushPath, [ref]$tokens, [ref]$errors) | Out-Null
      $errors.Count | Should -Be 0
    }
  }

  Context 'Test-LcmPublishPreflight' {
    It 'Detects active relief switches in proposals.json' {
      $tempJson = New-TemporaryFile
      $mockData = @{
        minimal_tests = $true
        flow_mode = 'relief'
        granularity = 'loose'
        testing_mode = 'passive'
        proposals = @(
          @{ id = 100; title = 'Test Proposal'; plan_state = 'completed' }
        )
      }
      $mockData | ConvertTo-Json -Depth 5 | Set-Content -Path $tempJson.FullName -Encoding UTF8

      $pushPlan = [PSCustomObject]@{
        CompletedProposals = @([PSCustomObject]@{ Id = 100 })
        RequiredRepositories = @('LCM_Inventory')
      }

      $result = Test-LcmPublishPreflight -PushPlan $pushPlan -WorkspaceRoot $PSScriptRoot -ProposalsFile $tempJson.FullName
      $result.HasReliefOrDebt | Should -BeTrue
      $result.ReliefActive | Should -BeTrue
      $result.DebtProposals.Count | Should -Be 0

      Remove-Item -Path $tempJson.FullName -Force
    }

    It 'Detects debt proposals completed with minimal tests' {
      $tempJson = New-TemporaryFile
      $mockData = @{
        minimal_tests = $false
        flow_mode = 'standard'
        granularity = 'tight'
        testing_mode = 'active'
        proposals = @(
          @{ id = 101; title = 'Debt Proposal'; plan_state = 'completed [minimal-tests]'; quality_checks_deferred = $true }
        )
      }
      $mockData | ConvertTo-Json -Depth 5 | Set-Content -Path $tempJson.FullName -Encoding UTF8

      $pushPlan = [PSCustomObject]@{
        CompletedProposals = @([PSCustomObject]@{ Id = 101 })
        RequiredRepositories = @('LCM_Inventory')
      }

      $result = Test-LcmPublishPreflight -PushPlan $pushPlan -WorkspaceRoot $PSScriptRoot -ProposalsFile $tempJson.FullName
      $result.HasReliefOrDebt | Should -BeTrue
      $result.ReliefActive | Should -BeFalse
      $result.DebtProposals.Count | Should -Be 1
      $result.DebtProposals[0].id | Should -Be 101

      Remove-Item -Path $tempJson.FullName -Force
    }

    It 'Passes cleanly when workspace is strict and proposals have no debt' {
      $tempJson = New-TemporaryFile
      $mockData = @{
        minimal_tests = $false
        flow_mode = 'standard'
        granularity = 'tight'
        testing_mode = 'active'
        proposals = @(
          @{ id = 102; title = 'Clean Proposal'; plan_state = 'completed'; quality_checks_deferred = $false }
        )
      }
      $mockData | ConvertTo-Json -Depth 5 | Set-Content -Path $tempJson.FullName -Encoding UTF8

      $pushPlan = [PSCustomObject]@{
        CompletedProposals = @([PSCustomObject]@{ Id = 102 })
        RequiredRepositories = @('LCM_Inventory')
      }

      $result = Test-LcmPublishPreflight -PushPlan $pushPlan -WorkspaceRoot $PSScriptRoot -ProposalsFile $tempJson.FullName
      $result.HasReliefOrDebt | Should -BeFalse
      $result.ReliefActive | Should -BeFalse
      $result.DebtProposals.Count | Should -Be 0

      Remove-Item -Path $tempJson.FullName -Force
    }
  }

  Context 'Invoke-RemediationStep' {
    It 'Executes auto-remediation in non-interactive mode when provided' {
      $remediated = $false
      $action = { $script:remediated = $true }
      $outcome = Invoke-RemediationStep -StepName 'TestStep' -IssueDescription 'Minor issue' -AutoRemediateAction $action -NonInteractive
      $outcome | Should -Be 'retried_ok'
      $script:remediated | Should -BeTrue
    }

    It 'Aborts in non-interactive mode when no auto-remediation action is provided' {
      $outcome = Invoke-RemediationStep -StepName 'FatalStep' -IssueDescription 'Major blocker' -NonInteractive
      $outcome | Should -Be 'aborted'
    }
  }
}

