<#
.SYNOPSIS
  Verifies retained failure-analysis snapshot presentation.
.NOTES
  Module: ShowFailureAnalysis.Tests
  Purpose: Covers viewer snapshot creation, route contracts and non-launching safety.
  Path: LCM_Inventory/tests/ShowFailureAnalysis.Tests.ps1
  Authors: Rolf, Copilot
  Version: 10.2.1
  Date: 2026-10-21
#>
Describe 'Retained failure-analysis viewer' {
  BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    $viewer = Join-Path $root 'tools\Show-FailureAnalysis.ps1'
    Import-Module -Name (Join-Path $root 'modules\FailureAnalysisHtml.psm1') -Force
  }

  It 'creates a retained snapshot from an exact JSON report without launching' {
    $report = Join-Path $TestDrive 'analysis.json'
    $markdown = Join-Path $TestDrive 'analysis.md'
    $source = [ordered]@{
      Schema = 'LCM.FailureAnalysis'
      SchemaVersion = 1
      GeneratedAt = '2026-10-21T20:00:00+02:00'
      Host = 'Offline'
      SessionId = 'fixture'
      Source = 'fixture.jsonl'
      Summary = [ordered]@{Confirmed=1;Unresolved=1;EventCount=2;Number=304;AnchorMatches=1}
      Selection = [ordered]@{Anchor='literal';Number=304;Matches=1}
      Events = @()
      Findings = @()
      ExecutionFlow = @()
      Lifecycle = @()
      Actions = @()
      Limitations = @('Fixture limitation')
    }
    $source | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $report -Encoding UTF8
    'retained markdown' | Set-Content -LiteralPath $markdown -Encoding UTF8
    $snapshotRoot = Join-Path $TestDrive 'snapshots'
    $auditPath = Join-Path $TestDrive 'viewer.jsonl'
    $result = & $viewer -ReportPath $report -SnapshotRoot $snapshotRoot -NoLaunch -LogFile $auditPath -Detailed
    $result.Launched | Should -BeFalse
    $result.ReportPath | Should -Be (Resolve-Path $report).Path
    $result.SnapshotId | Should -Match '^[a-f0-9]{32}$'
    $result.Url | Should -Be "http://127.0.0.1:9876/failure-analysis/$($result.SnapshotId)/index.html"
    (Get-Content -LiteralPath $result.JsonPath -Raw | ConvertFrom-Json).SchemaVersion | Should -Be 1
    (Get-Content -LiteralPath $result.MarkdownPath -Raw).Trim() | Should -Be 'retained markdown'
    $html = Get-Content -LiteralPath (Join-Path $result.SnapshotPath 'index.html') -Raw
    $html | Should -Match 'data-has-json="true"'
    $html | Should -Match '<title>Failure analysis snapshot LCM-Show: v10.0.1 Template: v10.0.1</title>'
    $html | Should -Match '<p class="snapshot">LCM-Show: v10.0.1 Template: v10.0.1</p>'
    $html | Should -Match 'http://127\.0\.0\.1:9876/failure-analysis/[a-f0-9]{32}/report\.json'
    $html | Should -Match 'http://127\.0\.0\.1:9876/assets/failure-analysis\.css'
    $html | Should -Match 'http://127\.0\.0\.1:9876/assets/failure-analysis\.js'
    $html | Should -Match 'id="producer-header" class="producer">Producer not recorded'
    $html | Should -Match '<h2 id="overview-title">Summary</h2>'
    $script = Get-Content -LiteralPath (Join-Path $root 'assets\failure-analysis.js') -Raw
    $script | Should -Match 'report\.Producer'
    $script | Should -Match 'report\.ProducerVersion'
    $script | Should -Match 'Producer not recorded'
    $html | Should -Not -Match 'file:'
    $records = @(Get-Content -LiteralPath $auditPath | ConvertFrom-Json)
    $records.Count | Should -Be 2
    $records[-1].Status | Should -Be 'Succeeded'
    $records[-1].Tool | Should -Be 'Show-FailureAnalysis.ps1'
    $records[-1].Version | Should -Be '10.0.1'
    $records[-1].SnapshotId | Should -Be $result.SnapshotId
  }

  It 'keeps Markdown-only legacy evidence accessible without reconstructing JSON' {
    $report = Join-Path $TestDrive 'legacy.md'
    'legacy report contents' | Set-Content -LiteralPath $report -Encoding UTF8
    $result = & $viewer -ReportPath $report -SnapshotRoot (Join-Path $TestDrive 'legacy-snapshots') -NoLaunch -LogFile (Join-Path $TestDrive 'legacy.jsonl')
    $result.JsonPath | Should -BeNullOrEmpty
    $result.MarkdownPath | Should -Not -BeNullOrEmpty
    $html = Get-Content -LiteralPath (Join-Path $result.SnapshotPath 'index.html') -Raw
    $html | Should -Match 'data-has-json="false"'
    $html | Should -Match 'Producer not recorded'
    $html | Should -Not -Match 'report\.json'
    $html | Should -Match 'report\.md'
  }

  It 'rejects missing, unsupported, and malformed reports before snapshot creation' {
    $snapshotRoot = Join-Path $TestDrive 'invalid-snapshots'
    $auditPath = Join-Path $TestDrive 'invalid.jsonl'
    { & $viewer -ReportPath (Join-Path $TestDrive 'missing.md') -SnapshotRoot $snapshotRoot -NoLaunch -LogFile $auditPath } | Should -Throw '*does not exist*'
    $wrongType = Join-Path $TestDrive 'wrong.txt'
    'not a report' | Set-Content -LiteralPath $wrongType
    { & $viewer -ReportPath $wrongType -SnapshotRoot $snapshotRoot -NoLaunch -LogFile $auditPath } | Should -Throw '*must identify*'
    $badJson = Join-Path $TestDrive 'bad.json'
    '{invalid' | Set-Content -LiteralPath $badJson
    { & $viewer -ReportPath $badJson -SnapshotRoot $snapshotRoot -NoLaunch -LogFile $auditPath } | Should -Throw
    @(Get-Content -LiteralPath $auditPath | ConvertFrom-Json)[-1].Status | Should -Be 'Failed'
    @(Get-ChildItem -LiteralPath $snapshotRoot -ErrorAction SilentlyContinue).Count | Should -Be 0
  }

  It 'rejects a custom snapshot root before writing when browser launch is requested' {
    $report = Join-Path $TestDrive 'custom-root.json'
    [ordered]@{
      Schema = 'LCM.FailureAnalysis'
      SchemaVersion = 1
      Producer = 'Invoke-FailureModeAnalysis.ps1'
      ProducerVersion = '10.0.1'
      GeneratedAt = '2026-10-21T20:00:00+02:00'
      Host = 'Offline'
      SessionId = 'fixture'
      Source = 'fixture.jsonl'
      Summary = [ordered]@{Confirmed=0;Unresolved=0;EventCount=0;Number=304;AnchorMatches=1}
      Selection = [ordered]@{Anchor='literal';Number=304;Matches=1}
      Events = @()
      Findings = @()
      ExecutionFlow = @()
      Lifecycle = @()
      Actions = @()
      Limitations = @()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $report -Encoding UTF8
    $customRoot = Join-Path $TestDrive 'custom-snapshot-root'
    { & $viewer -ReportPath $report -SnapshotRoot $customRoot -LogFile (Join-Path $TestDrive 'custom-root.jsonl') } | Should -Throw '*requires -NoLaunch*'
    Test-Path -LiteralPath $customRoot | Should -BeFalse
  }

  It 'returns help before creating snapshots or audit files and emits no result objects' {
    $auditPath = Join-Path $TestDrive 'help-audit.jsonl'
    $snapshotRoot = Join-Path $TestDrive 'help-snapshots'
    $result = @(& $viewer -h -SnapshotRoot $snapshotRoot -LogFile $auditPath -ShowAll)
    $result.Count | Should -Be 0
    Test-Path -LiteralPath $snapshotRoot | Should -BeFalse
    Test-Path -LiteralPath $auditPath | Should -BeFalse
  }

  It 'builds only fixed loopback route references from a validated snapshot identifier' {
    $html = New-FailureAnalysisIndexHtml -SnapshotId '0123456789abcdef0123456789abcdef' -HasJson -HasMarkdown
    $html | Should -Match 'http://127\.0\.0\.1:9876/failure-analysis/0123456789abcdef0123456789abcdef/report\.json'
    $html | Should -Match 'http://127\.0\.0\.1:9876/failure-analysis/0123456789abcdef0123456789abcdef/report\.md'
    $script = Get-Content -LiteralPath (Join-Path $root 'assets\failure-analysis.js') -Raw
    $style = Get-Content -LiteralPath (Join-Path $root 'assets\failure-analysis.css') -Raw
    $script | Should -Match 'textContent'
    $script | Should -Match 'node\("details"\)'
    $script | Should -Match 'sourceField'
    $script | Should -Not -Match '\.innerHTML\s*='
    $style | Should -Match 'white-space:\s*pre-wrap'
    $html | Should -Not -Match 'file:'
    { New-FailureAnalysisIndexHtml -SnapshotId '../other' } | Should -Throw
  }
}
