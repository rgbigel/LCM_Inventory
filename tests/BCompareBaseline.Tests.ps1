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
    $descriptor.RulesBaselineSource | Should -Be 'authority-commit'
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
    & git -C $authorityRepository -c user.name='Pester' -c user.email='pester@example.invalid' commit --quiet -m 'Track authority rules'

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
}