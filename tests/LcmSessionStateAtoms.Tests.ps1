<#
.SYNOPSIS
  Pester v5 tests for LcmSessionStateAtoms.psm1 (CRP-350).
.DESCRIPTION
  Module: tests/LcmSessionStateAtoms.Tests.ps1
  Purpose: Verifies section-anchored reads/writes and host-block findings on in-memory samples only;
           never touches the live .agents files (BUG-336 lesson).
  Path: LCM_Inventory/tests/LcmSessionStateAtoms.Tests.ps1
  Authors: Rolf, Claude
  Version: 10.7.4
  Date: 2026-11-17
#>

BeforeAll {
  Import-Module -Name (Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LcmSessionStateAtoms.psm1') -Force
  $script:Sample = @(
    '# Active Session'
    ''
    '## 1. Workspace State'
    ''
    '- **Last Updated**: 2026-11-17 10:00:00'
    '- **Status**: Quiescent (GoodNight completed at 2026-11-16 22:00:00)'
    '- **GoodNight Timestamp**: 2026-11-16 22:00:00'
    ''
    '## 2. Multi-Host Session Registry'
    ''
    '### Host: Antigravity (Gemini)'
    '- **Status**: Active'
    '- **Conversation ID**: `abc`'
    '- **Last Activity**: 2026-11-14 22:37:21'
    '- **Current Task**: none'
    '- **Next Step**: none'
    ''
    '### Host: Claude Code'
    '- **Status**: Closed (2026-11-16 22:05:00)'
    '- **Session ID**: `def`'
    '- **Last Activity**: 2026-11-16 22:05:00'
    '- **Current Task**: x'
    '- **Next Step**: y'
    '- **Open Operator Decisions**: none'
    '- **Attention Items**:'
    '  - first item'
    '  - second item'
    ''
    '## 3. Proposals'
    ''
    '- **Status**: must never be touched'
  ) -join "`r`n"
}

Describe 'Workspace fields (section 1 only)' {
  It 'reads the GoodNight timestamp from section 1' {
    Get-LcmSessionWorkspaceField -Content $script:Sample -Name 'GoodNight Timestamp' | Should -Be '2026-11-16 22:00:00'
  }
  It 'replaces Status in section 1 and leaves host blocks and section 3 unchanged' {
    $r = Set-LcmSessionWorkspaceField -Content $script:Sample -Name 'Status' -Value 'Active (resumed at 2026-11-17 08:00:00)'
    Get-LcmSessionWorkspaceField -Content $r -Name 'Status' | Should -Be 'Active (resumed at 2026-11-17 08:00:00)'
    $r | Should -Match '(?m)^- \*\*Status\*\*: Active\r?$'
    $r | Should -Match 'must never be touched'
    $r | Should -Match 'Closed \(2026-11-16 22:05:00\)'
  }
  It 'inserts a missing field after the anchor, keeping CRLF' {
    $r = Set-LcmSessionWorkspaceField -Content $script:Sample -Name 'Resumption Timestamp' -Value '2026-11-17 08:00:00' -After 'GoodNight Timestamp'
    $r | Should -Match "GoodNight Timestamp\*\*: 2026-11-16 22:00:00`r`n- \*\*Resumption Timestamp\*\*: 2026-11-17 08:00:00`r`n"
    ([regex]::Matches($r, '(?<!\r)\n')).Count | Should -Be 0
  }
  It 'inserts a missing field directly under the heading when no anchor exists' {
    $r = Set-LcmSessionWorkspaceField -Content $script:Sample -Name 'Resumption Timestamp' -Value 'x' -After 'Nope'
    $r | Should -Match "## 1\. Workspace State`r`n`r`n- \*\*Resumption Timestamp\*\*: x`r`n- \*\*Last Updated\*\*"
  }
  It 'throws when section 1 is missing' {
    { Set-LcmSessionWorkspaceField -Content '# empty' -Name 'Status' -Value 'x' } | Should -Throw
  }
}

Describe 'Host blocks' {
  BeforeAll {
    $script:Blocks = Get-LcmSessionHostBlocks -Content $script:Sample
    $script:GoodNight = ConvertTo-LcmSessionTimestamp -Text '2026-11-16 22:00:00'
  }
  It 'parses both host blocks with ids and attention items' {
    $script:Blocks.Count | Should -Be 2
    $script:Blocks[0].Id | Should -Be '`abc`'
    $script:Blocks[1].Items['Attention Items'].Count | Should -Be 2
  }
  It 'flags an Active block older than the GoodNight and its missing fields' {
    $f = Get-LcmSessionHostFinding -HostBlock $script:Blocks[0] -GoodNight $script:GoodNight
    ($f -join ' | ') | Should -Match 'stale'
    ($f -join ' | ') | Should -Match 'missing fields: Open Operator Decisions, Attention Items'
  }
  It 'reports nothing for a conforming closed block' {
    @(Get-LcmSessionHostFinding -HostBlock $script:Blocks[1] -GoodNight $script:GoodNight).Count | Should -Be 0
  }
  It 'flags the legacy Quiescent host vocabulary' {
    $legacy = $script:Sample.Replace('Closed (2026-11-16 22:05:00)', 'Quiescent (good-night 2026-11-16 22:05:00)')
    $b = (Get-LcmSessionHostBlocks -Content $legacy)[1]
    ((Get-LcmSessionHostFinding -HostBlock $b -GoodNight $script:GoodNight) -join ' ') | Should -Match 'outside the schema vocabulary'
  }
}
