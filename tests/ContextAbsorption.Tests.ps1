# =====================================================================
# ContextAbsorption.Tests.ps1 - Tests for RULE-LCM-031 Implementation
# =====================================================================

BeforeAll {
    $workspaceRoot = 'D:\Git_Repositories'
    $scriptRoot = Join-Path $workspaceRoot 'LCM_Inventory\tools'
    $absorbScript = Join-Path $scriptRoot 'Absorb-LcmContextRemark.ps1'
    $linkScript = Join-Path $scriptRoot 'Link-LcmLearnedAdvice.ps1'
}

Describe 'Absorb-LcmContextRemark (RULE-LCM-031)' {
    It 'Validates AST syntax of Absorb-LcmContextRemark.ps1' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($absorbScript, [ref]$null, [ref]$null)
        $ast | Should -Not -BeNullOrEmpty
    }

    It 'Executes DryRun against active context remark without modifying files' {
        $result = & pwsh -NoProfile -File $absorbScript -Id 312 -TextMatch "identical viewer" -DryRun 2>&1 | Out-String
        $result | Should -Match '\[DRY-RUN\]'
        $result | Should -Match 'No files were modified'
    }

    It 'Executes CheckOnly mode for contradiction analysis' {
        $result = & pwsh -NoProfile -File $absorbScript -Id 312 -TextMatch "identical viewer" -CheckOnly 2>&1 | Out-String
        $result | Should -Match 'Contradiction pre-check passed'
    }
}

Describe 'Link-LcmLearnedAdvice (RULE-LCM-031)' {
    It 'Validates AST syntax of Link-LcmLearnedAdvice.ps1' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($linkScript, [ref]$null, [ref]$null)
        $ast | Should -Not -BeNullOrEmpty
    }

    It 'Performs Stage 1 DryRun annotation without deleting advice' {
        $result = & pwsh -NoProfile -File $linkScript -Id 311 -TextMatch "Decoupled baseline backup generation" -DryRun 2>&1 | Out-String
        $result | Should -Match '\[DRY-RUN\]'
        $result | Should -Match 'RECOGNIZED: BUG-311'
        $result | Should -Match 'No files were modified'
    }

    It 'Rejects -PurgeGuaranteed if guarantee evidence is omitted' {
        { & pwsh -NoProfile -File $linkScript -Id 311 -TextMatch "Decoupled baseline backup generation" -PurgeGuaranteed 2>&1 } | Should -Not -BeNullOrEmpty
    }
}