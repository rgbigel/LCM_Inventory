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
            $p.id | Should -BeGreaterThan 0
            $p.title | Should -Be 'Test Feature Proposal'
            $p.state | Should -Be 'suggested'
            $p.origin_repo | Should -Be 'TestRepo'
        }

        It 'Retrieves open proposals correctly' {
            $open = Get-WorkspaceProposals -OpenOnly
            @($open).Count | Should -BeGreaterThan 0
            @($open | Where-Object { $_.title -eq 'Test Feature Proposal' }).Count | Should -Be 1
        }
    }

    Context 'State Transitions & Batch Actions' {
        It 'Parses ID ranges and lists correctly' {
            $ids = @(Parse-ProposalIdExpression -Expression '1-3')
            $ids.Count | Should -Be 3

            $ids2 = @(Parse-ProposalIdExpression -Expression '#1, #4, #5')
            $ids2.Count | Should -Be 3
        }

        It 'Updates state to "processed" on "do" action' {
            $p = New-WorkspaceProposal -Title 'Batch Action Test' -OriginRepo 'TestRepo'
            $res = @(Invoke-ProposalBatchAction -Action 'do' -TargetExpression "$($p.id)")
            $res.Count | Should -Be 1
            $res[0].state | Should -Be 'processed'

            $updated = @(Get-WorkspaceProposals -Id $p.id)
            $updated[0].state | Should -Be 'processed'
        }

        It 'Updates state to "deferred" on "defer" action' {
            $p = New-WorkspaceProposal -Title 'Defer Test' -OriginRepo 'TestRepo'
            $res = @(Invoke-ProposalBatchAction -Action 'defer' -TargetExpression "$($p.id)")
            $res[0].state | Should -Be 'deferred'
        }

        It 'Updates state to "deleted" on "delete" action' {
            $p = New-WorkspaceProposal -Title 'Delete Test' -OriginRepo 'TestRepo'
            $res = @(Invoke-ProposalBatchAction -Action 'delete' -TargetExpression "$($p.id)")
            $res[0].state | Should -Be 'deleted'
        }
    }

    Context 'Review Granularity & LCM Mode Toggles' {
        It 'Sets and gets review granularity' {
            Set-ReviewGranularity -Granularity 'tight' | Should -Be 'tight'
            Get-ReviewGranularity | Should -Be 'tight'

            Set-ReviewGranularity -Granularity 'coarse' | Should -Be 'coarse'
            Get-ReviewGranularity | Should -Be 'coarse'
        }

        It 'Sets and gets LCM Mode' {
            Set-LCMMode -Mode 'paused' | Should -Be 'paused'
            Get-LCMMode | Should -Be 'paused'

            Set-LCMMode -Mode 'active' | Should -Be 'active'
            Get-LCMMode | Should -Be 'active'
        }
    }

    Context 'Repository Review Queue' {
        It 'Scans workspace for repositories under review' {
            $queue = @(Get-ReposUnderReview)
            $queue | Should -Not -BeNullOrEmpty
        }
    }

    Context 'CRP-048 Active App Context Engine & Inheritance' {
        It 'Sets and retrieves active App context using shorthand A1' {
            $ctx = Set-ActiveAppContext -Context 'A1' -Repo 'Workspace_AI'
            $ctx | Should -Not -BeNullOrEmpty
            $ctx.app_id | Should -Be 'App: 1'
            $ctx.app_number | Should -Be 1
            $ctx.repo | Should -Be 'Workspace_AI'

            $current = Get-ActiveAppContext
            $current.app_id | Should -Be 'App: 1'
        }

        It 'Automatically inherits active app_id on New-WorkspaceProposal' {
            Set-ActiveAppContext -Context 'A2' -Repo 'Workspace_AI' | Out-Null
            $p = New-WorkspaceProposal -Title 'App Sliced Feature' -OriginRepo 'Workspace_AI' -WorkspaceRoot $TestDrive
            $p.app_id | Should -Be 'App: 2'
        }

        It 'Supports multi-App problem declaration with primary_app and affected_apps' {
            Set-ActiveAppContext -Context 'clear' | Out-Null
            $bug = New-WorkspaceProposal -Title 'Cross-App Contract Failure' -OriginRepo 'bug' -PrimaryApp 'App: 2' -AffectedApps @('App: 1', 'App: 3') -WorkspaceRoot $TestDrive
            $bug.primary_app | Should -Be 'App: 2'
            $bug.affected_apps.Count | Should -Be 2
            $bug.affected_apps[0] | Should -Be 'App: 1'
        }

        It 'Sets context to foundational Architecture focus' {
            $ctx = Set-ActiveAppContext -Context 'Architecture'
            $ctx.app_id | Should -Be 'Architecture'
            $ctx.app_title | Should -Be 'Foundational Tripartite Architecture'

            $p = New-WorkspaceProposal -Title 'Foundational Core Refactor' -OriginRepo 'Workspace_AI' -WorkspaceRoot $TestDrive
            # Architecture context does not slice proposal with App: #
            $p.app_id | Should -BeNullOrEmpty
        }

        It 'Clears active context on clear/base' {
            Set-ActiveAppContext -Context 'clear' | Out-Null
            $ctx = Get-ActiveAppContext
            $ctx | Should -BeNullOrEmpty
        }

        It 'Synchronizes the machine-readable catalog with Sync-LcmAppCatalog' {
            $cat = Sync-LcmAppCatalog
            $cat | Should -Not -BeNullOrEmpty
            $cat.title | Should -Be 'LCM Workspace App-Centric Architecture Catalog'
            $cat.updated_at | Should -Not -BeNullOrEmpty
        }
    }

    Context 'App Documentation Slicing (-SplitDocs & Split-LcmAppDocs)' {
        It 'Discovers directory-separated App documents via Get-LcmApps' {
            $apps = @(Get-LcmApps -Repo 'BackgroundModifier')
            $apps.Count | Should -BeGreaterThan 0
            $app1 = $apps | Where-Object { $_.number -eq 1 }
            $app1 | Should -Not -BeNullOrEmpty
            $app1.doc_layout | Should -Be 'Directory'
            $app1.arch_defined | Should -Be $true
            $app1.req_defined | Should -Be $true
            $app1.impl_defined | Should -Be $true
        }

        It 'Scaffolds new directory-separated App docs when -SplitDocs is specified' {
            $testRepo = 'TestRepoSplit'
            $testRepoDir = Join-Path $TestDrive $testRepo
            $testDocsDir = Join-Path $testRepoDir 'docs'
            New-Item -ItemType Directory -Path $testDocsDir -Force | Out-Null
            Set-Content -Path (Join-Path $testDocsDir 'Architecture.md') -Value "# Test Architecture" -Encoding UTF8
            Set-Content -Path (Join-Path $testDocsDir 'Requirements.md') -Value "# Test Requirements" -Encoding UTF8
            Set-Content -Path (Join-Path $testDocsDir 'Implementation.md') -Value "# Test Implementation" -Encoding UTF8

            $app = New-LcmApp -Repo $testRepo -Title 'Telemetry Streamer' -WorkspaceRoot $TestDrive -SplitDocs

            $app | Should -Not -BeNullOrEmpty
            $app.DocLayout | Should -Be 'Directory'
            Test-Path (Join-Path $testDocsDir 'App#1-TelemetryStreamer\Architecture.md') | Should -Be $true
            Test-Path (Join-Path $testDocsDir 'App#1-TelemetryStreamer\Requirements.md') | Should -Be $true
            Test-Path (Join-Path $testDocsDir 'App#1-TelemetryStreamer\Implementation.md') | Should -Be $true
        }

        It 'Splits in-document App sections into dedicated directory documents with Split-LcmAppDocs' {
            $testRepo2 = 'TestRepoMigration'
            $testRepoDir2 = Join-Path $TestDrive $testRepo2
            $testDocsDir2 = Join-Path $testRepoDir2 'docs'
            New-Item -ItemType Directory -Path $testDocsDir2 -Force | Out-Null

            $archText = @"
# Main Architecture

Some root architecture text.

## App: 1 - Sensor Engine
Sensors capture data.

## App: 2 - Display Renderer
Renders visualization.
"@
            $reqText = @"
# Main Requirements

Root requirements.

## App: 1 - Sensor Engine
Sensor invariants.

## App: 2 - Display Renderer
Display invariants.
"@
            $implText = @"
# Main Implementation

Root implementation.

## App: 1 - Sensor Engine
### 1. Constituent Manifest Table
| Relative Path | Role / Layer | Primary Cmdlets / Entrypoints | Test Suite |
|:---|:---|:---|:---|
| modules/Sensor.psm1 | Core | Get-Sensor | tests/Sensor.Tests.ps1 |

## App: 2 - Display Renderer
### 1. Constituent Manifest Table
| Relative Path | Role / Layer | Primary Cmdlets / Entrypoints | Test Suite |
|:---|:---|:---|:---|
| modules/Render.psm1 | UI | Show-Render | tests/Render.Tests.ps1 |
"@

            Set-Content -Path (Join-Path $testDocsDir2 'Architecture.md') -Value $archText -Encoding UTF8
            Set-Content -Path (Join-Path $testDocsDir2 'Requirements.md') -Value $reqText -Encoding UTF8
            Set-Content -Path (Join-Path $testDocsDir2 'Implementation.md') -Value $implText -Encoding UTF8

            $migrated = @(Split-LcmAppDocs -Repo $testRepo2 -WorkspaceRoot $TestDrive)
            $migrated.Count | Should -Be 2

            Test-Path (Join-Path $testDocsDir2 'App#1-SensorEngine\Architecture.md') | Should -Be $true
            Test-Path (Join-Path $testDocsDir2 'App#2-DisplayRenderer\Requirements.md') | Should -Be $true
            Test-Path (Join-Path $testDocsDir2 'App#2-DisplayRenderer\Implementation.md') | Should -Be $true

            $rootArch = Get-Content -Path (Join-Path $testDocsDir2 'Architecture.md') -Raw -Encoding UTF8
            $rootArch | Should -Match 'App Subsystems & Sliced Specifications'
            $rootArch | Should -Not -Match '## App: 1'
        }
    }

    Context 'Proposal Bundle Architecture & Git Object Resolver (CRP-162)' {
        It 'Scaffolds new proposal inside a dedicated directory bundle with tripartite files' {
            $testRepo = 'TestBundleRepo'
            $testRepoDir = Join-Path $TestDrive $testRepo
            New-Item -ItemType Directory -Path (Join-Path $testRepoDir 'docs\Proposals') -Force | Out-Null

            $p = New-WorkspaceProposal -Title 'Live Metrics Streaming Engine' -OriginRepo $testRepo -Details 'Streaming metrics to dashboard' -WorkspaceRoot $TestDrive

            $p | Should -Not -BeNullOrEmpty
            $p.bundle_dir | Should -Match '^docs/Proposals/CRP-\d+-Live-Metrics-Streaming-Engine'
            $p.docs.specification | Should -Be 'Specification.md'
            $p.docs.plan | Should -Be 'Implementation_Plan.md'
            $p.docs.walkthrough | Should -Be 'Walkthrough.md'

            $bundlePath = Join-Path $testRepoDir $p.bundle_dir
            Test-Path (Join-Path $bundlePath 'Specification.md') | Should -Be $true
            Test-Path (Join-Path $bundlePath 'Implementation_Plan.md') | Should -Be $true
            Test-Path (Join-Path $bundlePath 'Walkthrough.md') | Should -Be $true
        }

        It 'Retrieves live proposal documents from disk via Get-LcmProposalDocument' {
            $testRepo = 'TestBundleRepo2'
            $testRepoDir = Join-Path $TestDrive $testRepo
            New-Item -ItemType Directory -Path (Join-Path $testRepoDir 'docs\Proposals') -Force | Out-Null
            $p = New-WorkspaceProposal -Title 'Dual Resolver Probe' -OriginRepo $testRepo -Details 'Probing dual resolver' -WorkspaceRoot $TestDrive

            $spec = Get-LcmProposalDocument -Id $p.id -DocumentType 'Specification' -WorkspaceRoot $TestDrive
            $spec | Should -Not -BeNullOrEmpty
            $spec.Found | Should -Be $true
            $spec.SourceMode | Should -Be 'LiveWorkingTree'
            $spec.Content | Should -Match 'Dual Resolver Probe'
        }

        It 'Extracts proposal documents from Git object database and purges working tree post-push' {
            $testRepo = 'TestGitRepo'
            $testRepoDir = Join-Path $TestDrive $testRepo
            New-Item -ItemType Directory -Path (Join-Path $testRepoDir 'docs\Proposals') -Force | Out-Null

            # Initialize mock git repository in test drive
            & git -C $testRepoDir init -q
            & git -C $testRepoDir config user.name "LCM Test"
            & git -C $testRepoDir config user.email "lcm@test.local"

            $p = New-WorkspaceProposal -Title 'Pushed Bundle Feature' -OriginRepo $testRepo -Details 'Post-push test' -WorkspaceRoot $TestDrive
            $bundlePath = Join-Path $testRepoDir $p.bundle_dir
            Test-Path $bundlePath | Should -Be $true

            # Stage and commit the proposal bundle to git object database
            & git -C $testRepoDir add .
            & git -C $testRepoDir commit -q -m "feat: add proposal bundle $($p.crp_id)"
            $commitSha = (& git -C $testRepoDir rev-parse HEAD).Trim()
            $commitSha | Should -Not -BeNullOrEmpty

            # Purge the local bundle from working tree
            $purgeResult = Remove-LcmProposalBundle -Id $p.id -CommitSha $commitSha -WorkspaceRoot $TestDrive
            $purgeResult.Purged | Should -Be $true
            Test-Path $bundlePath | Should -Be $false

            # Verify Get-LcmProposalDocument successfully extracts document from git object
            $docResult = Get-LcmProposalDocument -Id $p.id -DocumentType 'Specification' -WorkspaceRoot $TestDrive
            $docResult.Found | Should -Be $true
            $docResult.SourceMode | Should -Be 'GitObject'
            $docResult.Content | Should -Match 'Pushed Bundle Feature'
        }
    }
}

