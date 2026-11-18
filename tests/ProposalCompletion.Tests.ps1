<#
.SYNOPSIS
    Pester tests for review completion (CRP-357 Complete-Review.ps1) and BUG creation/merge (BUG-351).
.DESCRIPTION
    Module: tests/ProposalCompletion.Tests.ps1
    Purpose: Changed governed repositories (atoms module); Complete-Review.ps1 end to end against an isolated workspace
             and ledger with a stub commit step: one commit per changed repository naming all members, lifecycle once,
             plan mode, refusal before any change, remaining repositories of completed items; merged BUG findings.
    Path: LCM_Inventory/tests/ProposalCompletion.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.7.5
    Date: 2026-11-18
    Implementation Choices (CRP-357): the former Invoke-LcmItemReviewCompletion tests became Complete-Review tests.
#>

BeforeAll {
  function New-TestRepository([string]$Path) {
    $null = New-Item -ItemType Directory -Path $Path -Force
    $null = git -C $Path init --quiet
  }
  $script:workspaceRoot = Join-Path $TestDrive 'ws'
  New-TestRepository $script:workspaceRoot
  Set-Content -LiteralPath (Join-Path $script:workspaceRoot '.git\info\exclude') -Value 'LCM_*/'
  foreach ($name in 'LCM_AI', 'LCM_Inventory') { New-TestRepository (Join-Path $script:workspaceRoot $name) }
  function Reset-TestWorkspace {
    foreach ($name in 'LCM_AI', 'LCM_Inventory') {
      Get-ChildItem -LiteralPath (Join-Path $script:workspaceRoot $name) -Force | Where-Object { $_.Name -ne '.git' } | Remove-Item -Recurse -Force
    }
    Get-ChildItem -LiteralPath $script:workspaceRoot -Force | Where-Object { $_.Name -notin @('.git', 'LCM_AI', 'LCM_Inventory') } | Remove-Item -Recurse -Force
  }
}

Describe 'Changed governed repositories (CRP-357 atoms)' {
  BeforeAll { Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmReviewCompletionAtoms.psm1') -Force }
  BeforeEach { Reset-TestWorkspace }

  It 'ignores excluded paths and reports only repositories with committable changes' {
    $null = New-Item -ItemType Directory -Path (Join-Path $script:workspaceRoot 'LCM_Inventory\data') -Force
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_Inventory\data\proposals.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_AI\rule.md') -Value 'x'
    @(Get-LcmChangedGovernedRepositories -WorkspaceRoot $script:workspaceRoot) | Should -BeExactly @('LCM_AI')
  }
}

Describe 'Complete-Review.ps1 (CRP-357)' {
  BeforeAll {
    $script:tool = Join-Path $PSScriptRoot '..\tools\Complete-Review.ps1'
    $script:storePath = Join-Path $TestDrive 'proposals.json'
    $script:previousStore = $env:LCM_PROPOSAL_STORE_PATH
    $env:LCM_PROPOSAL_STORE_PATH = $script:storePath
    $script:submitLog = Join-Path $TestDrive 'submit.log'
    $env:CRP357_SUBMIT_LOG = $script:submitLog
    $script:stub = Join-Path $TestDrive 'submit-stub.ps1'
    Set-Content -LiteralPath $script:stub -Value @'
param([string]$RepositoryPath, [string]$CRP, [string]$Result, [string]$Notes, [switch]$MinimalTests, [switch]$Force, [switch]$SkipLifecycleSynchronization)
Add-Content -LiteralPath $env:CRP357_SUBMIT_LOG -Value ('{0}|{1}|{2}|{3}' -f $RepositoryPath, $CRP, $SkipLifecycleSynchronization.IsPresent, $Notes)
if ($SkipLifecycleSynchronization) { [pscustomobject]@{ RepositoryName = $RepositoryPath; ReviewReceiptPath = "receipt_$RepositoryPath.json"; CommitSha = 'abc1234' } }
'@
    function Set-TestStore([object[]]$Proposals) {
      ([ordered]@{ last_proposal_id = 9; updated_at = '2026-11-18 00:00:00'; proposals = $Proposals } | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $script:storePath -Encoding UTF8
    }
    function New-TestItem([int]$Id, [string]$Tag, [string]$State) {
      [ordered]@{ id = $Id; crp_id = $Tag; title = "Item $Tag"; state = $State; progress_state = 'verification'; origin_repo = 'LCM_Inventory'; lcm_version = '10.7.4'; state_history = @([ordered]@{ state = $State; timestamp = '2026-11-18 00:00:00' }) }
    }
    function Get-TestState([string]$Tag) { @((Get-Content -LiteralPath $script:storePath -Raw | ConvertFrom-Json).proposals | Where-Object crp_id -eq $Tag)[0].state }
    function Get-SubmitLines { if (Test-Path -LiteralPath $script:submitLog) { @(Get-Content -LiteralPath $script:submitLog) } else { @() } }
  }
  AfterAll { $env:LCM_PROPOSAL_STORE_PATH = $script:previousStore }
  BeforeEach {
    Reset-TestWorkspace
    if (Test-Path -LiteralPath $script:submitLog) { Remove-Item -LiteralPath $script:submitLog -Force }
  }

  It 'commits each changed repository once, names all members and completes them together' {
    Set-TestStore @((New-TestItem 1 'BUG-001' 'in_review'), (New-TestItem 2 'CRP-002' 'verified'))
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_AI\rule.md') -Value 'x'
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_Inventory\tool.ps1') -Value 'x'
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'root.md') -Value 'x'
    $null = & $script:tool -Target 'BUG-001', 'CRP-002' -Details 'shared change' -SubmitScriptPath $script:stub -WorkspaceRoot $script:workspaceRoot 6>$null
    $lines = @(Get-SubmitLines)
    @($lines | ForEach-Object { ($_ -split '\|')[0] }) | Should -BeExactly @('Git_Repositories', 'LCM_AI', 'LCM_Inventory')
    @($lines | ForEach-Object { ($_ -split '\|')[3] } | Select-Object -Unique) | Should -BeExactly @('[BUG-001, CRP-002] shared change')
    @($lines | ForEach-Object { ($_ -split '\|')[2] } | Select-Object -Unique) | Should -BeExactly @('True')
    Get-TestState 'BUG-001' | Should -Be 'completed'
    Get-TestState 'CRP-002' | Should -Be 'completed'
  }

  It 'changes nothing with -Plan' {
    Set-TestStore @((New-TestItem 1 'BUG-001' 'in_review'))
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_AI\rule.md') -Value 'x'
    $plan = & $script:tool -Target 'BUG-001' -Plan -SubmitScriptPath $script:stub -WorkspaceRoot $script:workspaceRoot 6>$null
    @($plan.Repositories) | Should -BeExactly @('LCM_AI')
    @(Get-SubmitLines).Count | Should -Be 0
    Get-TestState 'BUG-001' | Should -Be 'in_review'
  }

  It 'refuses before any change when a member is not ready' {
    Set-TestStore @((New-TestItem 1 'BUG-001' 'in_review'), (New-TestItem 2 'CRP-002' 'suggested'))
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_AI\rule.md') -Value 'x'
    { & $script:tool -Target 'BUG-001', 'CRP-002' -SubmitScriptPath $script:stub -WorkspaceRoot $script:workspaceRoot 6>$null } | Should -Throw '*Not ready*CRP-002 is suggested*'
    @(Get-SubmitLines).Count | Should -Be 0
    Get-TestState 'BUG-001' | Should -Be 'in_review'
  }

  It 'commits only the remaining repositories of a completed item without a lifecycle change (CRP-346 R1)' {
    Set-TestStore @((New-TestItem 1 'BUG-001' 'completed'))
    Set-Content -LiteralPath (Join-Path $script:workspaceRoot 'LCM_AI\rule.md') -Value 'x'
    $null = & $script:tool -Target 'BUG-001' -Details 'leftover' -SubmitScriptPath $script:stub -WorkspaceRoot $script:workspaceRoot 6>$null
    $lines = @(Get-SubmitLines)
    $lines.Count | Should -Be 1
    ($lines[0] -split '\|')[0..2] | Should -BeExactly @('LCM_AI', 'BUG-001', 'False')
    Get-TestState 'BUG-001' | Should -Be 'completed'
  }

  It 'completes the lifecycle only when no repository has changes' {
    Set-TestStore @((New-TestItem 1 'BUG-001' 'in_review'))
    $null = & $script:tool -Target 'BUG-001' -SubmitScriptPath $script:stub -WorkspaceRoot $script:workspaceRoot 6>$null
    @(Get-SubmitLines).Count | Should -Be 0
    Get-TestState 'BUG-001' | Should -Be 'completed'
  }
}

Describe 'BUG creation and merge (BUG-351)' {
  BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot '..\modules\ProposalSpecificationState.psm1') -Force  # CRP-359 resolver
    $actionScript = Join-Path $PSScriptRoot '..\tools\Invoke-ProposalAction.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($actionScript, [ref]$null, [ref]$null)
    $definition = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Add-LcmBugMergedFinding' }, $false)
    . ([scriptblock]::Create($definition.Extent.Text))
    $script:testStore = [PSCustomObject]@{
      proposals = @([PSCustomObject]@{ id = 1; crp_id = 'BUG-001'; origin_repo = 'LCM_Inventory'; state = 'in_review'; details = 'original'; bundle_dir = 'docs/Proposals/001_BUG-Test' })
    }
    function Get-ProposalStore { $script:testStore }
    function Set-ProposalStore { param($Store) }
  }

  It 'merges a finding into an existing BUG ledger entry and its specification' {
    $bundle = Join-Path $script:workspaceRoot 'LCM_Inventory\docs\Proposals\001_BUG-Test'
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
