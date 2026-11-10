# ==============================================================================
# BaselineModifications.Tests.ps1 - Tests for RULE-REV-013 Baseline Modification Guardrail
# ==============================================================================
BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..\modules\LcmMacriumAtoms.psm1'
  Import-Module -Name $modulePath -Force
}

Describe 'RULE-REV-013: Baseline Modification Detection Atom' {
  It 'Exports Test-LcmBaselineModifications from LcmMacriumAtoms' {
    $cmd = Get-Command -Name 'Test-LcmBaselineModifications' -ErrorAction SilentlyContinue
    $cmd | Should -Not -BeNullOrEmpty
  }

  It 'Returns negative modifications when drive is unmounted or nonexistent' {
    $result = Test-LcmBaselineModifications -CandidateDrives @('Z')
    $result.HasModifications | Should -BeFalse
    $result.TotalModifiedFiles | Should -BeExactly 0
    $result.ModifiedRepositories.Count | Should -BeExactly 0
  }

  It 'Correctly audits clean repository with git status' {
    # Test-LcmBaselineModifications against the live drive should succeed safely
    $result = Test-LcmBaselineModifications -CandidateDrives @('F')
    $result.PSObject.Properties['HasModifications'] | Should -Not -BeNullOrEmpty
    $result.PSObject.Properties['TotalModifiedFiles'] | Should -Not -BeNullOrEmpty
    $result.PSObject.Properties['ModifiedRepositories'] | Should -Not -BeNullOrEmpty
  }
}
