<#
.SYNOPSIS
    Pester tests for the ledger write guard against dropped fields (CRP-355 revision C).
.DESCRIPTION
    Module: tests/ProposalStoreFieldGuard.Tests.ps1
    Purpose: Set-ProposalStore refuses a write in which an existing row loses a field (store unchanged on disk);
             adding fields, new rows and removing the transient status_note stay allowed.
    Path: LCM_Inventory/tests/ProposalStoreFieldGuard.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.7.5
    Date: 2026-11-18
#>

Describe 'Ledger write guard (CRP-355 revision C)' {
  BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1') -Force
    $script:storePath = Join-Path $TestDrive 'proposals.json'
    $script:previous = $env:LCM_PROPOSAL_STORE_PATH
    $env:LCM_PROPOSAL_STORE_PATH = $script:storePath
    function Reset-Store {
      ([ordered]@{ last_proposal_id = 2; updated_at = ''; proposals = @(
            [ordered]@{ id = 1; crp_id = 'CRP-001'; title = 'A'; state = 'pushed'; details = 'keep me'; status_note = 'temp' }
          ) } | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $script:storePath -Encoding UTF8
    }
  }
  AfterAll { $env:LCM_PROPOSAL_STORE_PATH = $script:previous }
  BeforeEach { Reset-Store }

  It 'refuses a write that removes a field and leaves the stored ledger unchanged' {
    $store = Get-ProposalStore
    $store.proposals[0].PSObject.Properties.Remove('details')
    { Set-ProposalStore -Store $store } | Should -Throw '*Refused ledger write*#1: details*'
    (Get-Content -LiteralPath $script:storePath -Raw | ConvertFrom-Json).proposals[0].details | Should -Be 'keep me'
  }

  It 'allows added fields, new rows and the removal of the transient status_note' {
    $store = Get-ProposalStore
    $store.proposals[0] | Add-Member -NotePropertyName 'archived_at' -NotePropertyValue 'now'
    $store.proposals[0].PSObject.Properties.Remove('status_note')
    $store.proposals = @($store.proposals) + @([pscustomobject]@{ id = 2; crp_id = 'CRP-002'; title = 'B'; state = 'suggested' })
    { Set-ProposalStore -Store $store } | Should -Not -Throw
    $saved = Get-Content -LiteralPath $script:storePath -Raw | ConvertFrom-Json
    @($saved.proposals).Count | Should -Be 2
    $saved.proposals[0].archived_at | Should -Be 'now'
  }
}
