Describe 'Show-LcmFailureDiagnostic' {
  BeforeAll {
    $script:repositoryRoot = Split-Path $PSScriptRoot -Parent
    $script:toolPath = Join-Path $script:repositoryRoot 'tools\Show-LcmFailureDiagnostic.ps1'
  }

  It 'refuses a valid action before lifecycle execution' {
    $tool = Get-Content -LiteralPath $script:toolPath -Raw -Encoding UTF8

    $tool | Should -Match '\[string\]\$Action = ''do'''
    $tool | Should -Match '\[string\]\$TargetExpression = ''CRP-279'''
    $tool | Should -Match 'ShowFailureDiagnostic refuses valid action'
    $tool | Should -Match 'it never applies lifecycle actions'
  }

  It 'renders the shared structured failure report for an invalid action' {
    $tool = Get-Content -LiteralPath $script:toolPath -Raw -Encoding UTF8

    $tool | Should -Match 'Invoke-ProposalBatchAction -Action \$Action -TargetExpression \$TargetExpression'
    $tool | Should -Match 'LcmLifecycleFailureReport'
    $tool | Should -Match 'Format-LcmLifecycleFailureReport -Report \$report'
  }
}
