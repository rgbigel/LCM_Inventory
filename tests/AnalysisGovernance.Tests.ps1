# Tests for AnalysisGovernance.psm1 and Analysis Governance Protocol (CRP-243)
BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\modules\AnalysisGovernance.psm1'
    Import-Module $modulePath -Force
}

Describe 'AnalysisGovernance Module Tests' {
    BeforeEach {
        # Restore clean state before each test
        Set-LcmOperatingMode -Mode 'GOVERNED_IMPLEMENTATION' | Out-Null
    }

    It 'Get-LcmAnalysisState returns default governance registers' {
        $state = Get-LcmAnalysisState
        $state | Should -Not -BeNullOrEmpty
        $state.operating_mode | Should -Be 'GOVERNED_IMPLEMENTATION'
        $state.search_radius | Should -Be 2
        $state.active_gate | Should -Be 'STEP_001'
        $state.circuit_breaker | Should -Be $false
    }

    It 'Set-LcmOperatingMode transitions to READ_ONLY_ANALYSIS' {
        $mode = Set-LcmOperatingMode -Mode 'READ_ONLY_ANALYSIS'
        $mode | Should -Be 'READ_ONLY_ANALYSIS'
        (Get-LcmOperatingMode) | Should -Be 'READ_ONLY_ANALYSIS'
    }

    It 'Assert-LcmImplementationAllowed passes under GOVERNED_IMPLEMENTATION' {
        Set-LcmOperatingMode -Mode 'GOVERNED_IMPLEMENTATION' | Out-Null
        { Assert-LcmImplementationAllowed } | Should -Not -Throw
    }

    It 'Assert-LcmImplementationAllowed throws under READ_ONLY_ANALYSIS' {
        Set-LcmOperatingMode -Mode 'READ_ONLY_ANALYSIS' | Out-Null
        { Assert-LcmImplementationAllowed } | Should -Throw '*READ_ONLY_ANALYSIS mode per RULE-ANA-001*'
    }

    It 'Invoke-LcmCircuitBreaker trips circuit breaker and sets CIRCUIT_BREAKER_HALT' {
        $cbState = Invoke-LcmCircuitBreaker -Reason 'Test constraint mismatch'
        $cbState.circuit_breaker | Should -Be $true
        $cbState.operating_mode | Should -Be 'CIRCUIT_BREAKER_HALT'
        { Assert-LcmImplementationAllowed } | Should -Throw '*CIRCUIT_BREAKER_HALT*'
    }

    It 'Reset-LcmCircuitBreaker clears breaker and defaults to READ_ONLY_ANALYSIS' {
        Invoke-LcmCircuitBreaker -Reason 'Tripping for reset test' | Out-Null
        $resetState = Reset-LcmCircuitBreaker
        $resetState.circuit_breaker | Should -Be $false
        $resetState.operating_mode | Should -Be 'READ_ONLY_ANALYSIS'
    }

    AfterAll {
        # Clean up by returning to GOVERNED_IMPLEMENTATION
        Set-LcmOperatingMode -Mode 'GOVERNED_IMPLEMENTATION' | Out-Null
    }
}
