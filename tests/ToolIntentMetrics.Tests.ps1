<#
Module: ToolIntentMetrics.Tests
Purpose: Tests for the CRP-315 tool intent metrics (call count, millisecond timestamps, carry-over by the catalog generator).
Path: LCM_Inventory/tests/ToolIntentMetrics.Tests.ps1
Authors: Rolf, Claude
Version: 10.7.5
Date: 2026-11-20 17:29:46
Implementation Choices (BUG-375, CRP-358): the metrics are written into an isolated copy of tools.db (LCM_TOOLS_DB_PATH in
TestDrive), never into the live store; the carry-over through Update-ToolCatalog.ps1 is checked in its source instead of
running the generator against the live catalog.
#>

BeforeAll {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $catModule = Join-Path $repoRoot 'modules\LcmToolCatalog.psm1'
    Import-Module -Name $catModule -Force
    $dbCopy = Join-Path $TestDrive 'tools.db'
    Copy-Item -LiteralPath (Join-Path $repoRoot 'data\tools\tools.db') -Destination $dbCopy
    $env:LCM_TOOLS_DB_PATH = $dbCopy
}

AfterAll {
    Remove-Item -Path 'Env:LCM_TOOLS_DB_PATH' -ErrorAction SilentlyContinue
}

Describe 'Tool Intent Metrics & Millisecond Tracking (CRP-315)' {
    It 'Updates call_count and records timestamp with millisecond precision' {
        $before = (Get-LcmToolStoreDocument -Store intents).intents.toolintents
        $beforeCount = if ($null -ne $before.call_count) { [int]$before.call_count } else { 0 }
        Update-LcmToolIntentCall -CommandOrPath "Show-ToolIntents.ps1" -DurationMs 88.5

        $intent = (Get-LcmToolStoreDocument -Store intents).intents.toolintents
        $intent | Should -Not -BeNullOrEmpty
        $intent.call_count | Should -Be ($beforeCount + 1)
        $intent.last_called_at | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$'
        $intent.last_duration_ms | Should -Be 88.5
        $intent.total_duration_ms | Should -BeGreaterOrEqual 88.5
    }

    It 'Leaves the live intent store untouched' {
        $live = Join-Path $repoRoot 'data\tools\tools.db'
        $hashBefore = (Get-FileHash -LiteralPath $live -Algorithm SHA256).Hash
        Update-LcmToolIntentCall -CommandOrPath "Show-ToolIntents.ps1" -DurationMs 1.0
        (Get-FileHash -LiteralPath $live -Algorithm SHA256).Hash | Should -Be $hashBefore
    }

    It 'Carries the metrics over in the catalog generator (source check, no live run)' {
        $generator = Get-Content -LiteralPath (Join-Path $repoRoot 'tools\Update-ToolCatalog.ps1') -Raw -Encoding UTF8
        foreach ($field in 'call_count', 'last_called_at', 'last_duration_ms', 'total_duration_ms') {
            $generator | Should -Match ([regex]::Escape($field) + '\s*=\s*if \(\$m\) \{ \$m\.' + [regex]::Escape($field) + ' \}')
        }
    }

    It 'Renders metrics in Show-ToolIntents CLI mode' {
        $showScript = Join-Path $repoRoot 'tools\Show-ToolIntents.ps1'
        $cliOut = & pwsh -NoProfile -File $showScript -Filter "toolintents" -Cli 2>&1 | Out-String
        $cliOut | Should -Match 'Calls'
        $cliOut | Should -Match 'LastCalled'
    }
}
