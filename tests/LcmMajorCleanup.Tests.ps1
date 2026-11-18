<#
.SYNOPSIS
    Pester tests for the major-version cleanup (CRP-355).
.DESCRIPTION
    Module: tests/LcmMajorCleanup.Tests.ps1
    Purpose: Runs Invoke-LcmMajorCleanup.ps1 against an isolated workspace and store (LCM_PROPOSAL_STORE_PATH):
             selection by major and date, protection of unfinished and cited items, manifest hash check,
             deletion of exactly the manifest, ledger compaction, completed-proposal ledger and in-place log.
    Path: LCM_Inventory/tests/LcmMajorCleanup.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.7.5
    Date: 2026-11-18
#>

Describe 'Major-version cleanup (CRP-355)' {
  BeforeAll {
    $script:tool = Join-Path $PSScriptRoot '..\tools\Invoke-LcmMajorCleanup.ps1'
    $script:ws = Join-Path $TestDrive 'ws'
    $inv = Join-Path $script:ws 'LCM_Inventory'
    foreach ($d in 'LCM_AI\.agents', 'LCM_AI\docs\Logs\03_Propagation-and-Continuous-History', 'LCM_Inventory\docs\Proposals', 'LCM_Inventory\data\reviews', 'LCM_Inventory\logs', 'LCM_Inventory\data\proposals') {
      $null = New-Item -ItemType Directory -Path (Join-Path $script:ws $d) -Force
    }
    Set-Content -LiteralPath (Join-Path $script:ws 'LCM_AI\.agents\version.json') -Value '{ "version": "10.7.4" }'
    Set-Content -LiteralPath (Join-Path $script:ws 'LCM_AI\.agents\ACTIVE_CONTEXT.md') -Value 'Remark about BUG-004 still open.'
    Set-Content -LiteralPath (Join-Path $script:ws 'LCM_AI\.agents\LEARNED_ADVICE.md') -Value '# advice'
    $script:rollup = Join-Path $script:ws 'LCM_AI\docs\Logs\03_Propagation-and-Continuous-History\Major_Version_Milestone_Rollup.md'
    Set-Content -LiteralPath $script:rollup -Value @'
# Rollup

## 2. Release Register (CRP-355)

| Major | First release | Date | Evidence |
|:---|:---|:---|:---|
| 8 | 8.0.0 | 2026-09-26 | x |
| 10 | 10.0.0 | 2026-10-13 | y |

## 3. Cleanup Runs (in-place log, CRP-355)
'@
    function New-Bundle([string]$Name) { $d = Join-Path $inv "docs\Proposals\$Name"; $null = New-Item -ItemType Directory -Path $d -Force; Set-Content -LiteralPath (Join-Path $d 'Specification.md') -Value 'x'; "docs/Proposals/$Name" }
    $proposals = @(
      [ordered]@{ id = 1; crp_id = 'CRP-001'; title = 'Old pushed'; state = 'pushed'; lcm_version = 'Legacy (<10.0)'; bundle_dir = (New-Bundle 'CRP-001-Old'); details = 'long text'; state_history = @([ordered]@{ state = 'pushed'; timestamp = '2026-09-01 10:00:00' }) }
      [ordered]@{ id = 2; crp_id = 'CRP-002'; title = 'Old held'; state = 'held'; lcm_version = 'Legacy (<10.0)'; bundle_dir = (New-Bundle 'CRP-002-Held') }
      [ordered]@{ id = 203; crp_id = 'CRP-203'; title = 'New pushed'; state = 'pushed'; lcm_version = '10.2.0'; bundle_dir = (New-Bundle 'CRP-203-New') }
      [ordered]@{ id = 4; crp_id = 'BUG-004'; title = 'Old cited'; state = 'pushed'; lcm_version = 'Legacy (<10.0)'; bundle_dir = (New-Bundle 'BUG-004-Cited') }
    )
    Set-Content -LiteralPath (Join-Path $inv 'docs\Proposals\CRP-001-Legacy-Flat.md') -Value 'flat'
    Set-Content -LiteralPath (Join-Path $inv 'data\reviews\review_LCM_AI_20260901_100000.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $inv 'data\reviews\review_LCM_AI_20261101_100000.json') -Value '{}'
    $oldLog = Join-Path $inv 'logs\Tool-20260901_100000.log'; Set-Content -LiteralPath $oldLog -Value 'old'; (Get-Item $oldLog).LastWriteTime = [datetime]'2026-09-01'
    Set-Content -LiteralPath (Join-Path $inv 'logs\Tool-20261117_100000.log') -Value 'new'
    $script:storePath = Join-Path $TestDrive 'proposals.json'
    ([ordered]@{ last_proposal_id = 203; updated_at = ''; proposals = $proposals } | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $script:storePath -Encoding UTF8
    $script:previousStore = $env:LCM_PROPOSAL_STORE_PATH
    $env:LCM_PROPOSAL_STORE_PATH = $script:storePath
    $script:report = & $script:tool -Report -WorkspaceRoot $script:ws 6>$null | Select-Object -Last 1
    $script:manifest = Get-Content -LiteralPath $script:report.Manifest -Raw | ConvertFrom-Json
  }

  AfterAll { $env:LCM_PROPOSAL_STORE_PATH = $script:previousStore }

  It 'selects only final-state items of major M-2 and older and their dated evidence' {
    @($script:manifest.ledger.crp_id) | Should -BeExactly @('CRP-001')
    $paths = @($script:manifest.entries | Where-Object selected | ForEach-Object path)
    $paths | Should -Contain 'LCM_Inventory\docs\Proposals\CRP-001-Old'
    $paths | Should -Contain 'LCM_Inventory\docs\Proposals\CRP-001-Legacy-Flat.md'
    $paths | Should -Contain 'LCM_Inventory\data\reviews\review_LCM_AI_20260901_100000.json'
    $paths | Should -Contain 'LCM_Inventory\logs\Tool-20260901_100000.log'
    $paths | Should -Not -Contain 'LCM_Inventory\data\reviews\review_LCM_AI_20261101_100000.json'
    $paths | Should -Not -Contain 'LCM_Inventory\logs\Tool-20261117_100000.log'
  }

  It 'keeps held, newer and cited items' {
    @($script:manifest.protected_kept) | Should -Contain 'CRP-002 (held)'
    @($script:manifest.protected_kept) | Should -Contain 'BUG-004 (cited in continuity files)'
    @($script:manifest.entries.path) | Should -Not -Contain 'LCM_Inventory\docs\Proposals\CRP-203-New'
  }

  It 'refuses a manifest whose confirmed hash differs and deletes nothing' {
    { & $script:tool -Apply -Manifest $script:report.Manifest -ManifestHash 'deadbeef' -WorkspaceRoot $script:ws 6>$null } | Should -Throw '*hash mismatch*'
    Test-Path -LiteralPath (Join-Path $script:ws 'LCM_Inventory\docs\Proposals\CRP-001-Old') | Should -BeTrue
  }

  It 'deletes exactly the manifest, compacts the ledger row and writes ledger and in-place log' {
    $result = & $script:tool -Apply -Manifest $script:report.Manifest -ManifestHash $script:report.ManifestHash -WorkspaceRoot $script:ws 6>$null | Select-Object -Last 1
    $result.Deleted | Should -Be 4
    $result.Compacted | Should -Be 1
    Test-Path -LiteralPath (Join-Path $script:ws 'LCM_Inventory\docs\Proposals\CRP-001-Old') | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:ws 'LCM_Inventory\docs\Proposals\CRP-002-Held') | Should -BeTrue
    $store = Get-Content -LiteralPath $script:storePath -Raw | ConvertFrom-Json
    @($store.proposals).Count | Should -Be 4
    $row = @($store.proposals | Where-Object id -eq 1)[0]
    $row.archived_at | Should -Not -BeNullOrEmpty
    $row.pushed_at | Should -Be '2026-09-01 10:00:00'
    $row.details | Should -Be 'long text'  # CRP-355 revision B: archiving never removes a field
    $row.state_history | Should -Not -BeNullOrEmpty
    [IO.File]::ReadAllText((Join-Path $script:ws 'LCM_Inventory\docs\Proposals\LEDGER_COMPLETED.md')) | Should -Match '\| CRP-001 \| Old pushed \| pushed \| 8 \|'
    [IO.File]::ReadAllText($script:rollup) | Should -Match '### Cleanup run CLEANUP-'
  }

  It 'reports cleanly when nothing is left to select (after the apply)' {
    $again = & $script:tool -Report -WorkspaceRoot $script:ws 6>$null | Select-Object -Last 1
    $again.Selected | Should -Be 0
    $again.LedgerRows | Should -Be 0
  }
}
