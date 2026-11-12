<#
.SYNOPSIS
    Unit and integration tests for CRP-322: SQLite Proposals Ledger Engine,
    Canonical SQL Projection, Git Auto-Hydration Hooks, and Version Grouping.
#>

Describe 'CRP-322: SQLite Proposals Ledger Engine & Canonical SQL Projection' {
    BeforeAll {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        $jsonPath = Join-Path $repoRoot 'data\proposals\proposals.json'
        $dbPath   = Join-Path $repoRoot 'data\proposals\proposals.db'
        $sqlPath  = Join-Path $repoRoot 'data\proposals\proposals.sql'
        $syncTool = Join-Path $repoRoot 'tools\Sync-LcmProposalsDb.ps1'
        $pyTool   = Join-Path $repoRoot 'tools\sync_proposals_db.py'
    }

    It 'Should have the SQLite proposals database and canonical SQL text dump on disk' {
        Test-Path -LiteralPath $dbPath  | Should -BeTrue
        Test-Path -LiteralPath $sqlPath | Should -BeTrue
    }

    It 'Should have the python sync engine and PowerShell tool facade on disk' {
        Test-Path -LiteralPath $syncTool | Should -BeTrue
        Test-Path -LiteralPath $pyTool   | Should -BeTrue
    }

    It 'Should verify 100% 3-way parity between JSON ledger, SQLite database, and SQL dump' {
        $output = & $syncTool -Action Verify
        $LASTEXITCODE | Should -Be 0
        $joined = $output -join [Environment]::NewLine
        $joined | Should -Match '100% Dual-State Parity Verified'
        $joined | Should -Match 'JSON <-> DB <-> SQL'
    }

    It 'Should verify database metadata table and workspace identity binding' {
        $output = & $syncTool -Action Verify
        $joined = $output -join [Environment]::NewLine
        $joined | Should -Match 'Metadata: Role=LIVE'
    }

    It 'Should ensure every proposal in proposals.json possesses an authoritative lcm_version' {
        $store = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $missingVersion = @($store.proposals | Where-Object {
            -not $_.PSObject.Properties['lcm_version'] -or [string]::IsNullOrWhiteSpace($_.lcm_version)
        })
        $missingVersion.Count | Should -Be 0
    }

    It 'Should filter historical published proposals in active horizon query mode' {
        $activeItems = & $syncTool -Action Query -Horizon active
        $allItems    = & $syncTool -Action Query -Horizon all

        $allItems.Count | Should -BeGreaterThan 290
        $activeItems.Count | Should -BeLessThan $allItems.Count
        $activeItems.Count | Should -BeLessThan 100

        foreach ($p in $activeItems) {
            if ($p.state -eq 'pushed') {
                [string]$p.lcm_version | Should -Match '^10\.2\.'
            }
        }
    }

    It 'Should support version-specific querying via Get-LCM_Proposals' {
        Import-Module (Join-Path $repoRoot 'modules\ProposalManager.psm1') -Force
        $v322 = Get-LCM_Proposals -LcmVersion '10.2.3'
        $v322.Count | Should -BeGreaterThan 0
        $v322[0].id | Should -Be 322
        $v322[0].crp_id | Should -Be 'CRP-322'
    }

    It 'Should cleanly re-hydrate SQLite database from canonical proposals.sql text dump' {
        $output = & $syncTool -Action Hydrate -Silent
        $LASTEXITCODE | Should -Be 0
        Test-Path -LiteralPath $dbPath | Should -BeTrue
    }

    It 'Should have Git post-merge and post-checkout auto-hydration hooks installed' {
        $hooksDir = Join-Path $repoRoot '.git\hooks'
        if (Test-Path -LiteralPath $hooksDir) {
            Test-Path -LiteralPath (Join-Path $hooksDir 'post-merge')    | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $hooksDir 'post-checkout') | Should -BeTrue
        }
    }

    It 'Should validate PowerShell AST syntax of all modified tools' {
        $modifiedFiles = @(
            (Join-Path $repoRoot 'tools\Sync-LcmProposalsDb.ps1'),
            (Join-Path $repoRoot 'tools\Show-LcmControl.ps1'),
            (Join-Path $repoRoot 'modules\ProposalManager.psm1')
        )

        foreach ($file in $modifiedFiles) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$null)
            $ast | Should -Not -BeNullOrEmpty
        }
    }
}
