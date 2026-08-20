# =====================================================================
# RuleHealth.Tests.ps1 - Pester Tests for LCM Rule Health & Diagnostics
# =====================================================================

Describe 'LCM Rule Health Diagnostics & Repair Engine' {
    BeforeAll {
        $script:diagTool = Join-Path $PSScriptRoot '..\tools\Test-LCMRuleHealth.ps1'
        $script:repairTool = Join-Path $PSScriptRoot '..\tools\Repair-LCMRules.ps1'
    }

    Context 'Diagnostic Engine' {
        It 'Executes Test-LCMRuleHealth and returns structured results' {
            $results = & $script:diagTool -WorkspaceRoot 'D:\Git_Repositories'
            @($results).Count | Should BeGreaterThan 0
        }

        It 'Validates that Workspace_Inventory has a valid junction' {
            $results = & $script:diagTool -TargetRepository 'Workspace_Inventory' -WorkspaceRoot 'D:\Git_Repositories'
            $wi = @($results | Where-Object { $_.Repository -eq 'Workspace_Inventory' })
            $wi.Count | Should Be 1
            $wi[0].JunctionState | Should Be 'Junction Valid'
        }
    }

    Context 'Repair Engine Simulation' {
        It 'Executes Repair-LCMRules in DryRun mode without errors' {
            { & $script:repairTool -TargetRepository 'BootEntryManager' -DryRun -WorkspaceRoot 'D:\Git_Repositories' } | Should Not Throw
        }
    }
}
