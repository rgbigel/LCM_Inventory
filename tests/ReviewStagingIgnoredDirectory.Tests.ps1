<#
.SYNOPSIS
    Pester tests for staging a tracked path under an ignored directory (BUG-360).
.DESCRIPTION
    Module: tests/ReviewStagingIgnoredDirectory.Tests.ps1
    Purpose: Reproduces the git behaviour Submit-ReviewResult.ps1 tolerates since BUG-360: "git add -A -- <path>" for a
             tracked file under a directory matched by .gitignore exits 1 but stages the change; an untracked ignored
             file is not staged. Also checks that the tolerance is present in the tool.
    Path: LCM_Inventory/tests/ReviewStagingIgnoredDirectory.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.7.4
    Date: 2026-11-18
#>

Describe 'Staging a tracked path under an ignored directory (BUG-360)' {
  BeforeAll {
    $script:repo = Join-Path $TestDrive 'repo'
    $null = New-Item -ItemType Directory -Path (Join-Path $script:repo 'docs\Logs') -Force
    git -C $script:repo init -q 2>$null
    git -C $script:repo config user.email 'test@local'
    git -C $script:repo config user.name 'test'
    git -C $script:repo config core.ignorecase true
    Set-Content -LiteralPath (Join-Path $script:repo 'docs\Logs\Rollup.md') -Value 'v1'
    git -C $script:repo add -A 2>$null
    git -C $script:repo commit -q -m 'init' 2>$null
    Set-Content -LiteralPath (Join-Path $script:repo '.gitignore') -Value 'logs/'
    git -C $script:repo add .gitignore 2>$null
    git -C $script:repo commit -q -m 'ignore' 2>$null
    Set-Content -LiteralPath (Join-Path $script:repo 'docs\Logs\Rollup.md') -Value 'v2'
    Set-Content -LiteralPath (Join-Path $script:repo 'docs\Logs\New.md') -Value 'new'
  }

  It 'stages the tracked file although git add reports the ignored directory' {
    git -C $script:repo add -A -- 'docs/Logs/Rollup.md' 2>$null
    $exit = $LASTEXITCODE
    @(git -C $script:repo diff --name-only -- 'docs/Logs/Rollup.md').Count | Should -Be 0
    @(git -C $script:repo diff --cached --name-only) | Should -Contain 'docs/Logs/Rollup.md'
    @(git -C $script:repo ls-files -- 'docs/Logs/Rollup.md').Count | Should -Be 1
    $exit | Should -BeIn @(0, 1)
  }

  It 'does not stage an untracked file under the ignored directory' {
    git -C $script:repo add -A -- 'docs/Logs/New.md' 2>$null
    $LASTEXITCODE | Should -Not -Be 0
    @(git -C $script:repo ls-files -- 'docs/Logs/New.md').Count | Should -Be 0
  }

  It 'Submit-ReviewResult tolerates only the tracked case' {
    $src = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\tools\Submit-ReviewResult.ps1') -Raw
    $src | Should -Match 'BUG-360'
    $src | Should -Match '\$unstaged\.Count -gt 0 -or \$tracked\.Count -eq 0'
  }
}
