Describe 'Fix-Documentation' {
    BeforeAll {
        $script:toolPath = Join-Path $PSScriptRoot '..\tools\Fix-Documentation.ps1'
        $script:workspaceRoot = Join-Path $TestDrive 'Workspace'
        $script:proposalRoot = Join-Path $script:workspaceRoot 'Workspace_Inventory\docs\Proposals\CRP-999-Test'
        $script:ledgerPath = Join-Path $script:workspaceRoot 'Workspace_Inventory\data\proposals\proposals.json'
        $script:docsPath = Join-Path $script:workspaceRoot 'Workspace_AI\docs'

        $null = New-Item -ItemType Directory -Path $script:proposalRoot -Force
        $null = New-Item -ItemType Directory -Path (Split-Path $script:ledgerPath -Parent) -Force
        $null = New-Item -ItemType Directory -Path $script:docsPath -Force
        @('Architecture', 'Requirements', 'Implementation') | ForEach-Object {
            Set-Content -LiteralPath (Join-Path $script:docsPath "$_` .md".Replace(' ', '')) -Value "# $_" -Encoding UTF8
        }
        @{
            proposals = @(@{
                id = 999
                crp_id = 'CRP-999'
                cr_id = 'CRP-999'
                bundle_dir = 'docs\Proposals\CRP-999-Test'
            })
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:ledgerPath -Encoding UTF8
        @'
# Test

## Documentation Updates

### Architecture
```markdown
## Reconciled Test Contract

Declared architecture content.
```
'@ | Set-Content -LiteralPath (Join-Path $script:proposalRoot 'Specification.md') -Encoding UTF8
    }

    It 'creates a dry-run manifest without changing documentation' {
        $manifestPath = Join-Path $TestDrive 'dry-run.json'
        & $script:toolPath -CrpScope 'CRP-999' -WorkspaceRoot $script:workspaceRoot -OutputPath $manifestPath -Trace
        (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).mode | Should -Be 'dry-run'
        (Get-Content -LiteralPath (Join-Path $script:docsPath 'Architecture.md') -Raw) | Should -Not -Match 'Reconciled Test Contract'
    }

    It 'applies only declared updates and writes a marker' {
        $manifestPath = Join-Path $TestDrive 'apply.json'
        & $script:toolPath -CrpScope '999' -WorkspaceRoot $script:workspaceRoot -OutputPath $manifestPath -Apply
        $content = Get-Content -LiteralPath (Join-Path $script:docsPath 'Architecture.md') -Raw
        $content | Should -Match '<!-- FixDocumentation: CRP-999 Architecture -->'
        $content | Should -Match 'Declared architecture content.'
        (Get-Content -LiteralPath (Join-Path $script:docsPath 'Requirements.md') -Raw) | Should -Not -Match 'Declared architecture content.'
    }

    It 'rejects unscoped identifiers' {
        { & $script:toolPath -CrpScope 'all' -WorkspaceRoot $script:workspaceRoot } | Should -Throw '*Invalid CRP scope token*'
    }

    It 'stops when one proposal declares conflicting updates for one document' {
        @'
# Conflicting update

## Documentation Updates

### Architecture
```markdown
## Conflicting Contract
```
'@ | Set-Content -LiteralPath (Join-Path $script:proposalRoot 'Walkthrough.md') -Encoding UTF8

        { & $script:toolPath -CrpScope 'CRP-999' -WorkspaceRoot $script:workspaceRoot } | Should -Throw '*conflicting payloads*'
    }
}