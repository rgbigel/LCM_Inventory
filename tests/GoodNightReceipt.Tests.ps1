BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..\modules\GoodNightReceipt.psm1'
  Import-Module $modulePath -Force
  $script:workspaceRoot = 'D:\Git_Repositories'
  $script:contextSnapshot = [datetime]'2026-10-18T19:00:00+02:00'
}

Describe 'GoodNIGHT Save All receipt contract' {
  It 'creates a valid receipt only from an explicit confirmation call' {
    $receiptPath = Join-Path $TestDrive 'goodnight-saveall-receipt.json'

    $receipt = New-GoodNightSaveAllReceipt -ReceiptPath $receiptPath -ContextSnapshotSavedAt $script:contextSnapshot `
      -WorkspaceRoot $script:workspaceRoot -ConfirmedBy 'operator' -SessionIdentity 'host\operator'
    $state = Get-GoodNightSaveAllReceiptState -ReceiptPath $receiptPath -ContextSnapshotSavedAt $script:contextSnapshot -WorkspaceRoot $script:workspaceRoot

    $receipt.completion_state | Should -Be 'save_all_confirmed'
    $state.State | Should -Be 'valid'
  }

  It 'reports missing, malformed, and stale receipts as recovery blockers' {
    $missingPath = Join-Path $TestDrive 'missing.json'
    (Get-GoodNightSaveAllReceiptState -ReceiptPath $missingPath -ContextSnapshotSavedAt $script:contextSnapshot -WorkspaceRoot $script:workspaceRoot).State | Should -Be 'missing'

    $malformedPath = Join-Path $TestDrive 'malformed.json'
    Set-Content -LiteralPath $malformedPath -Value '{not-json' -Encoding utf8
    (Get-GoodNightSaveAllReceiptState -ReceiptPath $malformedPath -ContextSnapshotSavedAt $script:contextSnapshot -WorkspaceRoot $script:workspaceRoot).State | Should -Be 'malformed'

    $stalePath = Join-Path $TestDrive 'stale.json'
    $stale = [ordered]@{
      schema_version = 1; completion_state = 'save_all_confirmed'; completed_at = '2026-10-18T18:00:00+02:00'
      workspace_root = $script:workspaceRoot; confirmed_by = 'operator'; session_identity = 'host\operator'
      context_snapshot_saved_at = '2026-10-18T18:00:00+02:00'
    }
    $stale | ConvertTo-Json | Set-Content -LiteralPath $stalePath -Encoding utf8
    (Get-GoodNightSaveAllReceiptState -ReceiptPath $stalePath -ContextSnapshotSavedAt $script:contextSnapshot -WorkspaceRoot $script:workspaceRoot).State | Should -Be 'stale'
  }
}
