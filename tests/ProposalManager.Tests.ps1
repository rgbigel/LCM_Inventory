# =====================================================================
# ProposalManager.Tests.ps1 - Pester Tests for Proposal Governance
# =====================================================================

Describe 'ProposalManager Core Functions' {
    BeforeAll {
        $script:modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
        Import-Module $script:modulePath -Force

        $script:testBackupPath = Join-Path $PSScriptRoot '..\data\proposals\proposals.backup.json'
        $script:livePath = Join-Path $PSScriptRoot '..\data\proposals\proposals.json'

        if (Test-Path $script:livePath) {
            Copy-Item -LiteralPath $script:livePath -Destination $script:testBackupPath -Force
        }
    }

    AfterAll {
        if (Test-Path $script:testBackupPath) {
            Copy-Item -LiteralPath $script:testBackupPath -Destination $script:livePath -Force
            Remove-Item -LiteralPath $script:testBackupPath -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Proposal Creation & Retrieval' {
        It 'Creates a new proposal with state "suggested"' {
            $p = New-WorkspaceProposal -Title 'Test Feature Proposal' -OriginRepo 'TestRepo' -Details 'Test details'
            $p.id | Should BeGreaterThan 0
            $p.title | Should Be 'Test Feature Proposal'
            $p.state | Should Be 'suggested'
            $p.origin_repo | Should Be 'TestRepo'
        }

        It 'Retrieves open proposals correctly' {
            $open = Get-WorkspaceProposals -OpenOnly
            @($open).Count | Should BeGreaterThan 0
            @($open | Where-Object { $_.title -eq 'Test Feature Proposal' }).Count | Should Be 1
        }
    }

    Context 'State Transitions & Batch Actions' {
        It 'Parses ID ranges and lists correctly' {
            $ids = @(Parse-ProposalIdExpression -Expression '1-3')
            $ids.Count | Should Be 3

            $ids2 = @(Parse-ProposalIdExpression -Expression '#1, #4, #5')
            $ids2.Count | Should Be 3
        }

        It 'Updates state to "processed" on "do" action' {
            $p = New-WorkspaceProposal -Title 'Batch Action Test' -OriginRepo 'TestRepo'
            $res = @(Invoke-ProposalBatchAction -Action 'do' -TargetExpression "$($p.id)")
            $res.Count | Should Be 1
            $res[0].state | Should Be 'processed'

            $updated = @(Get-WorkspaceProposals -Id $p.id)
            $updated[0].state | Should Be 'processed'
        }

        It 'Updates state to "deferred" on "defer" action' {
            $p = New-WorkspaceProposal -Title 'Defer Test' -OriginRepo 'TestRepo'
            $res = @(Invoke-ProposalBatchAction -Action 'defer' -TargetExpression "$($p.id)")
            $res[0].state | Should Be 'deferred'
        }

        It 'Updates state to "deleted" on "delete" action' {
            $p = New-WorkspaceProposal -Title 'Delete Test' -OriginRepo 'TestRepo'
            $res = @(Invoke-ProposalBatchAction -Action 'delete' -TargetExpression "$($p.id)")
            $res[0].state | Should Be 'deleted'
        }
    }

    Context 'Review Granularity & LCM Mode Toggles' {
        It 'Sets and gets review granularity' {
            Set-ReviewGranularity -Granularity 'tight' | Should Be 'tight'
            Get-ReviewGranularity | Should Be 'tight'

            Set-ReviewGranularity -Granularity 'coarse' | Should Be 'coarse'
            Get-ReviewGranularity | Should Be 'coarse'
        }

        It 'Sets and gets LCM Mode' {
            Set-LCMMode -Mode 'paused' | Should Be 'paused'
            Get-LCMMode | Should Be 'paused'

            Set-LCMMode -Mode 'active' | Should Be 'active'
            Get-LCMMode | Should Be 'active'
        }
    }

    Context 'Repository Review Queue' {
        It 'Scans workspace for repositories under review' {
            $queue = @(Get-ReposUnderReview)
            $queue.Count | Should BeGreaterThan 0
            # Verify Workspace_Inventory itself is omitted
            @($queue | Where-Object { $_.Repository -eq 'Workspace_Inventory' }).Count | Should Be 0
        }
    }
}
