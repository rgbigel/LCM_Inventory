<#
Module: ProposalSpecificationState.Tests
Purpose: Verify automatic lifecycle metadata mirroring and failed-write safeguards.
Path: tests/ProposalSpecificationState.Tests.ps1
Authors: Rolf, Copilot
Version: 10.2.1
Date: 2026-10-21
#>
BeforeAll {
  Import-Module (Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1') -Force
  $savedOverride = $env:LCM_PROPOSAL_STORE_PATH
}
AfterAll { $env:LCM_PROPOSAL_STORE_PATH = $savedOverride }

Describe 'Persisted specification lifecycle mirrors' {
  BeforeEach {
    $workspace = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $env:LCM_PROPOSAL_STORE_PATH = Join-Path $workspace 'LCM_Inventory\data\proposals\proposals.json'
    $null = New-Item -ItemType Directory -Path (Split-Path $env:LCM_PROPOSAL_STORE_PATH -Parent) -Force
    $specs = @()
    foreach ($id in @(1,2)) {
      $path = Join-Path $workspace "LCM_Inventory\docs\Proposals\CRP-$id\Specification.md"
      $null = New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force
      $text = "# CRP-$id`r`n`r`n" + '```yaml' + "`r`nStatus: Suggested`r`nPlan-State: suggested`r`nProgress-State: undecided`r`n" + '```' + "`r`n`r`n## Contract`r`nStatus: Preserve this body example.`r`n"
      [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
      $specs += $path
    }
    $store = [pscustomobject]@{
      updated_at=''
      proposals=@(foreach ($id in @(1,2)) {
        [pscustomobject]@{id=$id;state='suggested';origin_repo='LCM_Inventory';bundle_dir="docs\Proposals\CRP-$id"}
      })
    }
    $store | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:LCM_PROPOSAL_STORE_PATH
  }

  It 'mirrors an ordinary lifecycle transition and preserves the contract body' {
    Move-LcmProposalLifecycleState -Id 1 -State in_progress | Out-Null
    $text = [IO.File]::ReadAllText($specs[0])
    $text | Should -Match 'Status: In Progress\r\nPlan-State: in_progress\r\nProgress-State: in_progress'
    $text | Should -Match '## Contract\r\nStatus: Preserve this body example.'
    (Get-ProposalStore).proposals[0].state | Should -Be 'in_progress'
  }

  It 'does not write documents until a deferred batch is persisted, then synchronizes every member' {
    foreach ($id in @(1,2)) {
      Move-LcmProposalLifecycleState -Id $id -State in_progress -Store $store -SkipPersist | Out-Null
    }
    [IO.File]::ReadAllText($specs[0]) | Should -Match 'Plan-State: suggested'
    Set-ProposalStore -Store $store
    foreach ($path in $specs) { [IO.File]::ReadAllText($path) | Should -Match 'Plan-State: in_progress' }
  }

  It 'prevalidates all metadata before changing any documents or the ledger' {
    [IO.File]::WriteAllText($specs[1], 'Missing metadata fence')
    $before = [IO.File]::ReadAllText($env:LCM_PROPOSAL_STORE_PATH)
    foreach ($p in $store.proposals) { $p.state='in_progress' }
    { Set-ProposalStore $store } | Should -Throw '*metadata fence missing*'
    [IO.File]::ReadAllText($specs[0]) | Should -Match 'Plan-State: suggested'
    [IO.File]::ReadAllText($env:LCM_PROPOSAL_STORE_PATH) | Should -BeExactly $before
  }

  It 'reports ledger staging failure before changing documents' {
    $before = [IO.File]::ReadAllBytes($specs[0])
    $store.proposals[0].state='in_progress'
    Mock Set-Content -ModuleName ProposalManager { throw 'Injected ledger write failure' }
    { Set-ProposalStore $store } | Should -Throw '*Injected ledger write failure*'
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($specs[0])) | Should -Be ([Convert]::ToBase64String($before))
  }

  It 'rolls back written documents when ledger replacement fails' {
    $before = [IO.File]::ReadAllText($env:LCM_PROPOSAL_STORE_PATH)
    $original = [IO.File]::ReadAllText($specs[0])
    $store.proposals[0].state='in_progress'
    $lock = [IO.File]::Open($env:LCM_PROPOSAL_STORE_PATH, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { { Set-ProposalStore $store } | Should -Throw } finally { $lock.Dispose() }
    [IO.File]::ReadAllText($specs[0]) | Should -BeExactly $original
    [IO.File]::ReadAllText($env:LCM_PROPOSAL_STORE_PATH) | Should -BeExactly $before
    @(Get-ChildItem -LiteralPath (Split-Path $env:LCM_PROPOSAL_STORE_PATH) -Filter '*.tmp').Count | Should -Be 0
  }

  It 'reports specification write failures without advancing the ledger' {
    $before = [IO.File]::ReadAllText($env:LCM_PROPOSAL_STORE_PATH)
    $store.proposals[0].state='in_progress'
    $lock = [IO.File]::Open($specs[0], [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { { Set-ProposalStore $store } | Should -Throw } finally { $lock.Dispose() }
    [IO.File]::ReadAllText($env:LCM_PROPOSAL_STORE_PATH) | Should -BeExactly $before
  }

  It 'maps every canonical lifecycle state into display and compatibility metadata' {
    foreach ($state in @('suggested','in_progress','verified','in_review','completed','pushed','held','withdrawn','rejected','superseded')) {
      $current = Get-ProposalStore
      $current.proposals[0].state = if ($state -eq 'suggested') { 'in_progress' } else { 'suggested' }
      $current | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $env:LCM_PROPOSAL_STORE_PATH
      $current.proposals[0].state = $state
      Set-ProposalStore $current
      [IO.File]::ReadAllText($specs[0]) | Should -Match "Plan-State: $state"
    }
  }

  It 'mirrors cross-repository bundles using their owner rather than Inventory' {
    $target = Join-Path $workspace 'LCM_AI\docs\Proposals\CRP-1\Specification.md'
    $null = New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
    Move-Item -LiteralPath $specs[0] -Destination $target
    $store.proposals[0].origin_repo='LCM_AI'
    $store.proposals[0].state='verified'
    Set-ProposalStore $store
    [IO.File]::ReadAllText($target) | Should -Match 'Status: Verified\r\nPlan-State: verified\r\nProgress-State: verification'
  }
}
