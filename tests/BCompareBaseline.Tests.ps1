Describe 'BCompare baseline' {
  BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\BCompareBaseline.psm1'
    Import-Module -Name $modulePath -Force
  }

  It 'exports committed junction-backed rules from their local authority commit' {
    $authorityRepository = Join-Path $TestDrive 'RuleAuthority'
    $targetRepository = Join-Path $TestDrive 'TargetRepository'
    $destination = Join-Path $TestDrive 'baseline'
    $ruleFile = Join-Path $authorityRepository '.agents\rules\DisplayStandardsPolicy.md'

    $null = New-Item -ItemType Directory -Path (Split-Path $ruleFile -Parent) -Force
    Set-Content -LiteralPath $ruleFile -Value 'committed rule' -Encoding UTF8
    & git -C $authorityRepository init --quiet
    & git -C $authorityRepository add .agents/rules/DisplayStandardsPolicy.md
    & git -C $authorityRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Track canonical rule'

    $null = New-Item -ItemType Directory -Path $targetRepository -Force
    Set-Content -LiteralPath (Join-Path $targetRepository 'tracked.txt') -Value 'target commit' -Encoding UTF8
    & git -C $targetRepository init --quiet
    & git -C $targetRepository add tracked.txt
    & git -C $targetRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Target baseline'
    $null = New-Item -ItemType Directory -Path (Join-Path $targetRepository '.agents') -Force
    $null = New-Item -ItemType Junction -Path (Join-Path $targetRepository '.agents\rules') -Target (Join-Path $authorityRepository '.agents\rules')

    $descriptor = Get-BCompareBaselineDescriptor -RepositoryPath $targetRepository -BaseCommit 'HEAD'
    Export-BCompareBaseline -Descriptor $descriptor -DestinationPath $destination

    $descriptor.TargetCommit | Should -Be (& git -C $targetRepository rev-parse --short HEAD).Trim()
    $descriptor.RulesAuthorityCommit | Should -Be (& git -C $authorityRepository rev-parse --short HEAD).Trim()
    $descriptor.RulesBaselineSource | Should -BeIn @('authority-commit', 'authority-time-aligned')
    (Get-Content -LiteralPath (Join-Path $destination '.agents\rules\DisplayStandardsPolicy.md') -Raw).Trim() | Should -Be 'committed rule'
  }

  It 'uses the nearest target-history rules snapshot after a junction migration' {
    $authorityRepository = Join-Path $TestDrive 'MigratedRuleAuthority'
    $targetRepository = Join-Path $TestDrive 'MigratedRuleTarget'
    $destination = Join-Path $TestDrive 'migrated-baseline'
    $historicalRule = Join-Path $targetRepository '.agents\rules\DisplayStandardsPolicy.md'

    $null = New-Item -ItemType Directory -Path (Split-Path $historicalRule -Parent) -Force
    Set-Content -LiteralPath $historicalRule -Value 'historical rule' -Encoding UTF8
    & git -C $targetRepository init --quiet
    & git -C $targetRepository add .agents/rules/DisplayStandardsPolicy.md
    & git -C $targetRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Track rules before migration'

    $authorityRule = Join-Path $authorityRepository '.agents\rules\DisplayStandardsPolicy.md'
    $null = New-Item -ItemType Directory -Path (Split-Path $authorityRule -Parent) -Force
    Set-Content -LiteralPath $authorityRule -Value 'authority rule' -Encoding UTF8
    & git -C $authorityRepository init --quiet
    & git -C $authorityRepository add .agents/rules/DisplayStandardsPolicy.md
    $env:GIT_COMMITTER_DATE = '2030-01-01T00:00:00Z'
    try {
      & git -C $authorityRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Track authority rules' --date='2030-01-01T00:00:00Z'
    } finally {
      Remove-Item Env:\GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
    }

    & git -C $targetRepository rm -r --quiet .agents/rules
    & git -C $targetRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Migrate rules to junction'
    $null = New-Item -ItemType Junction -Path (Join-Path $targetRepository '.agents\rules') -Target (Join-Path $authorityRepository '.agents\rules')

    $descriptor = Get-BCompareBaselineDescriptor -RepositoryPath $targetRepository -BaseCommit 'HEAD'
    Export-BCompareBaseline -Descriptor $descriptor -DestinationPath $destination

    $descriptor.RulesBaselineSource | Should -Be 'target-history'
    (Get-Content -LiteralPath (Join-Path $destination '.agents\rules\DisplayStandardsPolicy.md') -Raw).Trim() | Should -Be 'historical rule'
  }

  It 'leaves an authority rule absent from the baseline when it is not in the local commit' {
    $authorityRepository = Join-Path $TestDrive 'UncommittedRuleAuthority'
    $targetRepository = Join-Path $TestDrive 'UncommittedRuleTarget'
    $destination = Join-Path $TestDrive 'invalid-baseline'
    $ruleFile = Join-Path $authorityRepository '.agents\rules\DisplayStandardsPolicy.md'

    $null = New-Item -ItemType Directory -Path (Split-Path $ruleFile -Parent) -Force
    Set-Content -LiteralPath (Join-Path $authorityRepository 'tracked.txt') -Value 'authority commit' -Encoding UTF8
    & git -C $authorityRepository init --quiet
    & git -C $authorityRepository add tracked.txt
    & git -C $authorityRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Authority baseline'
    Set-Content -LiteralPath $ruleFile -Value 'uncommitted rule' -Encoding UTF8

    $null = New-Item -ItemType Directory -Path $targetRepository -Force
    Set-Content -LiteralPath (Join-Path $targetRepository 'tracked.txt') -Value 'target commit' -Encoding UTF8
    & git -C $targetRepository init --quiet
    & git -C $targetRepository add tracked.txt
    & git -C $targetRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Target baseline'
    $null = New-Item -ItemType Directory -Path (Join-Path $targetRepository '.agents') -Force
    $null = New-Item -ItemType Junction -Path (Join-Path $targetRepository '.agents\rules') -Target (Join-Path $authorityRepository '.agents\rules')

    $descriptor = Get-BCompareBaselineDescriptor -RepositoryPath $targetRepository -BaseCommit 'HEAD'
    $descriptor.RulesAuthorityContentPresent | Should -BeFalse

    { Export-BCompareBaseline -Descriptor $descriptor -DestinationPath $destination } | Should -Not -Throw
    (Test-Path -LiteralPath (Join-Path $destination '.agents\rules\DisplayStandardsPolicy.md')) | Should -BeFalse
  }

  It 'preserves historical file timestamps on exported baseline files' {
    $targetRepository = Join-Path $TestDrive 'TimestampRepo'
    $destination = Join-Path $TestDrive 'timestamp-baseline'
    $testFile = Join-Path $targetRepository 'historical.txt'

    $null = New-Item -ItemType Directory -Path $targetRepository -Force
    Set-Content -LiteralPath $testFile -Value 'historical content' -Encoding UTF8
    $pastDate = [System.DateTime]::new(2025, 6, 15, 10, 30, 0, [System.DateTimeKind]::Utc)
    [System.IO.File]::SetLastWriteTimeUtc($testFile, $pastDate)
    [System.IO.File]::SetCreationTimeUtc($testFile, $pastDate)

    & git -C $targetRepository init --quiet
    & git -C $targetRepository add historical.txt
    & git -C $targetRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Historical commit' --date='2025-06-15T10:30:00Z'

    $descriptor = Get-BCompareBaselineDescriptor -RepositoryPath $targetRepository -BaseCommit 'HEAD'
    Export-BCompareBaseline -Descriptor $descriptor -DestinationPath $destination

    $exportedFile = Join-Path $destination 'historical.txt'
    (Test-Path -LiteralPath $exportedFile) | Should -BeTrue
    $exportedItem = Get-Item -LiteralPath $exportedFile
    $exportedItem.LastWriteTimeUtc | Should -Be $pastDate
    (Get-Item -LiteralPath $destination).LastWriteTimeUtc | Should -Be $pastDate
  }

  It 'preserves historical per-file commit timestamps and directory max times when files are modified in working tree' {
    $targetRepository = Join-Path $TestDrive 'ModifiedTimestampRepo'
    $destination = Join-Path $TestDrive 'modified-baseline'
    $subDir = Join-Path $targetRepository 'nested\sub'
    $null = New-Item -ItemType Directory -Path $subDir -Force
    $file1 = Join-Path $subDir 'file1.txt'
    $file2 = Join-Path $subDir 'file2.txt'

    Set-Content -LiteralPath $file1 -Value 'file 1 original' -Encoding UTF8
    Set-Content -LiteralPath $file2 -Value 'file 2 original' -Encoding UTF8

    & git -C $targetRepository init --quiet
    & git -C $targetRepository add nested/sub/file1.txt
    $env:GIT_COMMITTER_DATE = '2024-01-01T12:00:00Z'
    & git -C $targetRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Commit 1' --date='2024-01-01T12:00:00Z'

    & git -C $targetRepository add nested/sub/file2.txt
    $env:GIT_COMMITTER_DATE = '2024-06-01T12:00:00Z'
    & git -C $targetRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Commit 2' --date='2024-06-01T12:00:00Z'
    Remove-Item Env:\GIT_COMMITTER_DATE -ErrorAction SilentlyContinue

    $date2 = [System.DateTime]::Parse('2024-06-01T12:00:00Z').ToUniversalTime()
    [System.IO.File]::SetLastWriteTimeUtc($file2, $date2)
    [System.IO.File]::SetCreationTimeUtc($file2, $date2)

    # Modify file1 in working tree (so its hash differs from baseline)
    Set-Content -LiteralPath $file1 -Value 'file 1 modified in working tree' -Encoding UTF8

    $descriptor = Get-BCompareBaselineDescriptor -RepositoryPath $targetRepository -BaseCommit 'HEAD'
    Export-BCompareBaseline -Descriptor $descriptor -DestinationPath $destination

    $exportedFile1 = Join-Path $destination 'nested\sub\file1.txt'
    $exportedFile2 = Join-Path $destination 'nested\sub\file2.txt'
    $exportedSubDir = Join-Path $destination 'nested\sub'
    $exportedNestedDir = Join-Path $destination 'nested'

    # File 1 was modified in working tree, but in baseline it must retain its commit 1 date (2024-01-01)
    (Get-Item -LiteralPath $exportedFile1).LastWriteTimeUtc | Should -Be ([System.DateTime]::Parse('2024-01-01T12:00:00Z').ToUniversalTime())
    # Subdirectories and root take max child timestamp (2024-06-01), not "now"
    (Get-Item -LiteralPath $exportedSubDir).LastWriteTimeUtc | Should -Be ([System.DateTime]::Parse('2024-06-01T12:00:00Z').ToUniversalTime())
    (Get-Item -LiteralPath $exportedNestedDir).LastWriteTimeUtc | Should -Be ([System.DateTime]::Parse('2024-06-01T12:00:00Z').ToUniversalTime())
    (Get-Item -LiteralPath $destination).LastWriteTimeUtc | Should -Be ([System.DateTime]::Parse('2024-06-01T12:00:00Z').ToUniversalTime())
  }

  It 'exports .copilot from authority baseline when target repository uses an external junction' {
    $authorityRepository = Join-Path $TestDrive 'AuthorityRepoCopilot'
    $targetRepository = Join-Path $TestDrive 'TargetRepoCopilot'
    $destination = Join-Path $TestDrive 'copilot-baseline'

    $authorityCopilot = Join-Path $authorityRepository '.copilot'
    $null = New-Item -ItemType Directory -Path $authorityCopilot -Force
    Set-Content -LiteralPath (Join-Path $authorityCopilot 'Config.json') -Value '{"test": true}' -Encoding UTF8
    & git -C $authorityRepository init --quiet
    & git -C $authorityRepository add .copilot/Config.json
    & git -C $authorityRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Copilot baseline'

    $null = New-Item -ItemType Directory -Path $targetRepository -Force
    Set-Content -LiteralPath (Join-Path $targetRepository 'tracked.txt') -Value 'target commit' -Encoding UTF8
    & git -C $targetRepository init --quiet
    & git -C $targetRepository add tracked.txt
    & git -C $targetRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Target baseline'

    $null = New-Item -ItemType Junction -Path (Join-Path $targetRepository '.copilot') -Target $authorityCopilot

    $descriptor = Get-BCompareBaselineDescriptor -RepositoryPath $targetRepository -BaseCommit 'HEAD'
    $descriptor.CopilotBaselineRepositoryPath | Should -Not -BeNullOrEmpty

    Export-BCompareBaseline -Descriptor $descriptor -DestinationPath $destination
    (Test-Path -LiteralPath (Join-Path $destination '.copilot\Config.json')) | Should -BeTrue
  }

  It 'exports rules when target repository uses a higher-up .agents junction' {
    $authorityRepository = Join-Path $TestDrive 'HigherUpAuthority'
    $targetRepository = Join-Path $TestDrive 'HigherUpTarget'
    $destination = Join-Path $TestDrive 'higher-up-baseline'
    $ruleFile = Join-Path $authorityRepository '.agents\rules\DisplayStandardsPolicy.md'

    $null = New-Item -ItemType Directory -Path (Split-Path $ruleFile -Parent) -Force
    Set-Content -LiteralPath $ruleFile -Value 'higher-up rule' -Encoding UTF8
    & git -C $authorityRepository init --quiet
    & git -C $authorityRepository add .agents/rules/DisplayStandardsPolicy.md
    & git -C $authorityRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Authority rules'

    $null = New-Item -ItemType Directory -Path $targetRepository -Force
    Set-Content -LiteralPath (Join-Path $targetRepository 'tracked.txt') -Value 'target commit' -Encoding UTF8
    & git -C $targetRepository init --quiet
    & git -C $targetRepository add tracked.txt
    & git -C $targetRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Target commit'

    # Higher-up junction at .agents
    $null = New-Item -ItemType Junction -Path (Join-Path $targetRepository '.agents') -Target (Join-Path $authorityRepository '.agents')

    $descriptor = Get-BCompareBaselineDescriptor -RepositoryPath $targetRepository -BaseCommit 'HEAD'
    Export-BCompareBaseline -Descriptor $descriptor -DestinationPath $destination

    $descriptor.RulesAuthorityCommit | Should -Be (& git -C $authorityRepository rev-parse --short HEAD).Trim()
    (Get-Content -LiteralPath (Join-Path $destination '.agents\rules\DisplayStandardsPolicy.md') -Raw).Trim() | Should -Be 'higher-up rule'
  }
}