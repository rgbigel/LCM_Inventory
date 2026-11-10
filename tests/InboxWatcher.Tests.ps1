# =====================================================================
# InboxWatcher.Tests.ps1 - Test suite for CRP-263
# =====================================================================
# Module: InboxWatcher.Tests
# Purpose: Pester tests for LCM Inbox Two-Phase Acknowledgement Protocol
# Authors: Rolf, LCM_AI Engine
# Version: 10.0.0
# Date: 2026-11-10
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'InboxWatcher Two-Phase Acknowledgement (CRP-263)' {
  BeforeAll {
    $repoRoot = 'D:\Git_Repositories'
    $modulePath = Join-Path $repoRoot 'LCM_Inventory\modules\InboxWatcher.psm1'
    Import-Module -Name $modulePath -Force

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    $inboxDir = Join-Path $tempRoot 'INBOX'
    $archiveDir = Join-Path $inboxDir 'archive'
    $ackDir = Join-Path $inboxDir 'acks'
    $ledgerDir = Join-Path $tempRoot 'data\inbox\acks'

    foreach ($d in @($inboxDir, $archiveDir, $ackDir, $ledgerDir)) {
      New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
  }

  AfterAll {
    if ($null -ne $tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'Saves and reads Phase 1 receipt acknowledgement' {
    $corrId = 'INBOX-TEST-001'
    $record = Save-InboxAcknowledgement -CorrelationId $corrId `
                                       -Phase 1 `
                                       -Status 'RECEIVED' `
                                       -SourceFile 'BUG-test.md' `
                                       -InboxPath $inboxDir `
                                       -AckLedgerPath $ledgerDir

    $record.correlation_id | Should -Be $corrId
    $record.phase | Should -Be 1
    $record.status | Should -Be 'RECEIVED'

    $readRecord = Get-InboxAcknowledgement -CorrelationId $corrId -InboxPath $inboxDir -AckLedgerPath $ledgerDir
    $readRecord | Should -Not -BeNullOrEmpty
    $readRecord.correlation_id | Should -Be $corrId
    $readRecord.phase | Should -Be 1
    $readRecord.status | Should -Be 'RECEIVED'
  }

  It 'Updates Phase 1 to Phase 2 terminal success acknowledgement' {
    $corrId = 'INBOX-TEST-001'
    $record = Save-InboxAcknowledgement -CorrelationId $corrId `
                                       -Phase 2 `
                                       -Status 'SUCCESS' `
                                       -SourceFile 'BUG-test.md' `
                                       -ProposalId 999 `
                                       -InboxPath $inboxDir `
                                       -AckLedgerPath $ledgerDir

    $record.phase | Should -Be 2
    $record.status | Should -Be 'SUCCESS'
    $record.proposal_id | Should -Be 999

    $readRecord = Get-InboxAcknowledgement -CorrelationId $corrId -InboxPath $inboxDir -AckLedgerPath $ledgerDir
    $readRecord.phase | Should -Be 2
    $readRecord.status | Should -Be 'SUCCESS'
    $readRecord.proposal_id | Should -Be 999

    Test-InboxItemProcessed -CorrelationId $corrId -InboxPath $inboxDir -AckLedgerPath $ledgerDir | Should -BeTrue
  }

  It 'Rejects AUDIT classification with terminal failure ACK per CRP-263' {
    $auditFile = Join-Path $inboxDir 'AUDIT-20261110-Check.md'
    $auditContent = @"
# [TYPE: AUDIT]: Security and Access Audit
**Timestamp**: 2026-11-10 12:00:00
**Classification**: AUDIT
**Correlation-ID**: INBOX-AUDIT-TEST-01
**Target Repository**: HaSSD06

Audit report details...
"@
    [System.IO.File]::WriteAllText($auditFile, $auditContent, [System.Text.UTF8Encoding]::new($false))

    $outcomes = Invoke-TwoPhaseInboxIntake -InboxPath $inboxDir `
                                          -ArchivePath $archiveDir `
                                          -AckPath $ackDir `
                                          -AckLedgerPath $ledgerDir `
                                          -WorkspaceRoot $repoRoot

    $outcomes.Count | Should -Be 1
    $outcomes[0].Phase | Should -Be 2
    $outcomes[0].Status | Should -Be 'FAILURE'
    $outcomes[0].Error | Should -Match 'Unsupported classification.*AUDIT'

    # Check terminal ACK file
    $ackRecord = Get-InboxAcknowledgement -CorrelationId 'INBOX-AUDIT-TEST-01' -InboxPath $inboxDir -AckLedgerPath $ledgerDir
    $ackRecord.status | Should -Be 'FAILURE'
    $ackRecord.phase | Should -Be 2
    $ackRecord.error | Should -Match 'AUDIT'
  }

  It 'Correctly executes DryRun without advancing proposal ledger' {
    $dryFile = Join-Path $inboxDir 'TASK-20261110-DryRun.md'
    $dryContent = @"
# [TYPE: TASK]: Test Dry Run Intake
**Timestamp**: 2026-11-10 12:05:00
**Correlation-ID**: INBOX-DRYRUN-TEST-01
**Target Repository**: LCM_Inventory

Task content...
"@
    [System.IO.File]::WriteAllText($dryFile, $dryContent, [System.Text.UTF8Encoding]::new($false))

    $outcomes = Invoke-TwoPhaseInboxIntake -InboxPath $inboxDir `
                                          -ArchivePath $archiveDir `
                                          -AckPath $ackDir `
                                          -AckLedgerPath $ledgerDir `
                                          -WorkspaceRoot $repoRoot `
                                          -DryRun

    $outcomes.Count | Should -Be 1
    $outcomes[0].Phase | Should -Be 1
    $outcomes[0].Status | Should -Be 'RECEIVED (DRY-RUN)'

    # File must still exist in inbox
    Test-Path -LiteralPath $dryFile | Should -BeTrue
  }

  It 'Get-GeminiInboxStatus retrieves status correctly' {
    $statusScript = Join-Path $repoRoot 'LCM_Inventory\tools\Get-GeminiInboxStatus.ps1'
    $res = & $statusScript -CorrelationId 'INBOX-AUDIT-TEST-01' -InboxPath $inboxDir -AckLedgerPath $ledgerDir -PassThru
    $res | Should -Not -BeNullOrEmpty
    $res.correlation_id | Should -Be 'INBOX-AUDIT-TEST-01'
    $res.status | Should -Be 'FAILURE'
  }
}
