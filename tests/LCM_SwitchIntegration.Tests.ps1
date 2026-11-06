Describe 'LCM switch action integration' {
  BeforeAll {
    $script:actionPath = Join-Path $PSScriptRoot '..\tools\Invoke-ProposalAction.ps1'
    $script:proposalStorePath = Join-Path $TestDrive 'proposals.json'
    $script:analysisStatePath = Join-Path $TestDrive 'active_session.json'
    $script:originalProposalStorePath = $env:LCM_PROPOSAL_STORE_PATH
    $script:originalAnalysisStatePath = $env:LCM_ANALYSIS_STATE_PATH
    $env:LCM_PROPOSAL_STORE_PATH = $script:proposalStorePath
    $env:LCM_ANALYSIS_STATE_PATH = $script:analysisStatePath

    @{
      '$schema' = 'https://json-schema.org/draft/2020-12/schema'
      title = 'Disposable switch integration ledger'
      updated_at = (Get-Date).ToString('o')
      review_granularity = 'coarse'
      lcm_mode = 'active'
      testing_mode = 'active'
      flow_mode = 'standard'
      always_proceed = $false
      minimal_tests = $false
      test_scope = 'full'
      last_proposal_id = 0
      proposals = @()
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:proposalStorePath -Encoding UTF8
  }

  AfterAll {
    if ($null -eq $script:originalProposalStorePath) {
      Remove-Item Env:LCM_PROPOSAL_STORE_PATH -ErrorAction SilentlyContinue
    } else {
      $env:LCM_PROPOSAL_STORE_PATH = $script:originalProposalStorePath
    }
    if ($null -eq $script:originalAnalysisStatePath) {
      Remove-Item Env:LCM_ANALYSIS_STATE_PATH -ErrorAction SilentlyContinue
    } else {
      $env:LCM_ANALYSIS_STATE_PATH = $script:originalAnalysisStatePath
    }
  }

  It 'persists Review Tight through the real action script' {
    $output = & pwsh -NoProfile -File $script:actionPath -Action granularity -TargetExpression tight 2>&1
    $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    (Get-Content -LiteralPath $script:proposalStorePath -Raw -Encoding UTF8 | ConvertFrom-Json).review_granularity | Should -Be 'tight'
  }

  It 'persists Governance and Testing modes through the real action script' {
    $output = & pwsh -NoProfile -File $script:actionPath -Action mode -Mode paused 2>&1
    $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    $output = & pwsh -NoProfile -File $script:actionPath -Action testing-mode -TestingMode paused 2>&1
    $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    $store = Get-Content -LiteralPath $script:proposalStorePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $store.lcm_mode | Should -Be 'paused'
    $store.testing_mode | Should -Be 'paused'
  }

  It 'persists DOIT and Minimal Tests through the real action script' {
    $output = & pwsh -NoProfile -File $script:actionPath -Action doit-mode -SwitchState active 2>&1
    $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    $output = & pwsh -NoProfile -File $script:actionPath -Action minimal-tests -SwitchState active 2>&1
    $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    $store = Get-Content -LiteralPath $script:proposalStorePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $store.flow_mode | Should -Be 'doit'
    $store.always_proceed | Should -BeTrue
    $store.minimal_tests | Should -BeTrue
    $store.test_scope | Should -Be 'minimal'
  }

  It 'persists Analysis mode through the real action script' {
    $output = & pwsh -NoProfile -File $script:actionPath -Action analyze 2>&1
    $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    $analysisState = Get-Content -LiteralPath $script:analysisStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $analysisState.operating_mode | Should -Be 'READ_ONLY_ANALYSIS'

    $output = & pwsh -NoProfile -File $script:actionPath -Action implement 2>&1
    $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    $analysisState = Get-Content -LiteralPath $script:analysisStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $analysisState.operating_mode | Should -Be 'GOVERNED_IMPLEMENTATION'
  }
}
