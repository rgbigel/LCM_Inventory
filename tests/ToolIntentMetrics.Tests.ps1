# =====================================================================
# ToolIntentMetrics.Tests.ps1 - Tests for CRP-315 Tool Intent Metrics
# =====================================================================

BeforeAll {
    $workspaceRoot = 'D:\Git_Repositories'
    $catModule = Join-Path $workspaceRoot 'LCM_Inventory\modules\LcmToolCatalog.psm1'
    Import-Module -Name $catModule -Force
    $intentsPath = Join-Path $workspaceRoot 'LCM_Inventory\config\tool_intents.json'
}

Describe 'Tool Intent Metrics & Millisecond Tracking (CRP-315)' {
    It 'Updates call_count and records timestamp with millisecond precision' {
        $beforeTime = [DateTime]::Now
        Update-LcmToolIntentCall -CommandOrPath "Show-ToolIntents.ps1" -DurationMs 88.5

        $intents = Get-Content -LiteralPath $intentsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $intent = $intents.intents.toolintents
        $intent | Should -Not -BeNullOrEmpty
        $intent.call_count | Should -BeGreaterOrEqual 1
        $intent.last_called_at | Should -Not -BeNullOrEmpty

        # Verify millisecond precision pattern yyyy-MM-dd HH:mm:ss.fff
        $intent.last_called_at | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$'
        $intent.last_duration_ms | Should -Be 88.5
        $intent.total_duration_ms | Should -BeGreaterOrEqual 88.5
    }

    It 'Preserves metrics across Update-ToolCatalog synchronization' {
        $updateScript = Join-Path $workspaceRoot 'LCM_Inventory\tools\Update-ToolCatalog.ps1'
        & pwsh -NoProfile -File $updateScript | Out-Null

        $intents = Get-Content -LiteralPath $intentsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $intent = $intents.intents.toolintents
        $intent.call_count | Should -BeGreaterOrEqual 1
        $intent.last_called_at | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$'
    }

    It 'Renders metrics in Show-ToolIntents CLI mode' {
        $showScript = Join-Path $workspaceRoot 'LCM_Inventory\tools\Show-ToolIntents.ps1'
        $cliOut = & pwsh -NoProfile -File $showScript -Filter "toolintents" -Cli 2>&1 | Out-String
        $cliOut | Should -Match 'Calls'
        $cliOut | Should -Match 'LastCalled'
    }
}

