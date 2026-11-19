<#
Module: ToolIntentMetrics.Tests
Purpose: Tests for the CRP-315 tool intent metrics (call count, millisecond timestamps, carry-over by the catalog generator).
Path: LCM_Inventory/tests/ToolIntentMetrics.Tests.ps1
Authors: Rolf, Claude
Version: 10.7.4
Date: 2026-11-19 17:53:45
Implementation Choices (BUG-375): the metrics are written into an isolated copy (LCM_TOOL_INTENTS_PATH in TestDrive), never
into the live config/tool_intents.json; the carry-over through Update-ToolCatalog.ps1 is checked in its source instead of
running the generator against the live catalog.
#>

BeforeAll {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $catModule = Join-Path $repoRoot 'modules\LcmToolCatalog.psm1'
    Import-Module -Name $catModule -Force
    $intentsPath = Join-Path $TestDrive 'tool_intents.json'
    Copy-Item -LiteralPath (Join-Path $repoRoot 'config\tool_intents.json') -Destination $intentsPath
    $env:LCM_TOOL_INTENTS_PATH = $intentsPath
}

AfterAll {
    Remove-Item -Path 'Env:LCM_TOOL_INTENTS_PATH' -ErrorAction SilentlyContinue
}

Describe 'Tool Intent Metrics & Millisecond Tracking (CRP-315)' {
    It 'Updates call_count and records timestamp with millisecond precision' {
        $before = (Get-Content -LiteralPath $intentsPath -Raw -Encoding UTF8 | ConvertFrom-Json).intents.toolintents
        $beforeCount = if ($null -ne $before.call_count) { [int]$before.call_count } else { 0 }
        Update-LcmToolIntentCall -CommandOrPath "Show-ToolIntents.ps1" -DurationMs 88.5

        $intent = (Get-Content -LiteralPath $intentsPath -Raw -Encoding UTF8 | ConvertFrom-Json).intents.toolintents
        $intent | Should -Not -BeNullOrEmpty
        $intent.call_count | Should -Be ($beforeCount + 1)
        $intent.last_called_at | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$'
        $intent.last_duration_ms | Should -Be 88.5
        $intent.total_duration_ms | Should -BeGreaterOrEqual 88.5
    }

    It 'Leaves the live intent store untouched' {
        $live = Join-Path $repoRoot 'config\tool_intents.json'
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
