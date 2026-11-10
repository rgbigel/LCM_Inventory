<#
Module: LcmPackageVersion.Tests
Purpose: Verify commit-index maximum component version enforcement.
Path: tests/LcmPackageVersion.Tests.ps1
Authors: Rolf, Copilot
Version: 10.2.1
Date: 2026-10-21
#>
BeforeAll {
  Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmPackageVersion.psm1') -Force
  function Set-TestPackageVersion {
    param($Root, $Version)
    foreach ($doc in @('Architecture','Requirements','Implementation')) {
      [IO.File]::WriteAllText((Join-Path $Root "docs\$doc.md"), "# $doc`r`nVersion: $Version`r`n")
    }
    [IO.File]::WriteAllText((Join-Path $Root 'README.md'), ('- **LCM Governance Baseline**: `' + $Version + '` (Active Baseline)'))
  }
}
Describe 'LCM_AI commit package version' {
  BeforeEach {
    $repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path (Join-Path $repo 'docs'), (Join-Path $repo '.agents\rules'), (Join-Path $repo 'docs\Optimizations')
    git -C $repo init --quiet
    Set-TestPackageVersion $repo '10.0.1'
    [IO.File]::WriteAllText((Join-Path $repo '.agents\rules\Test.md'), "# Rule`r`nVersion: 10.0.1`r`n")
    git -C $repo add -A
    if ($LASTEXITCODE -ne 0) { throw 'Unable to stage fixture' }
  }
  It 'uses numeric rather than lexical maximum ordering and blocks a stale package' {
    [IO.File]::WriteAllText((Join-Path $repo '.agents\rules\Test.md'), "Version: 10.0.10`r`n")
    git -C $repo add -A
    { Assert-LcmPackageVersion $repo } | Should -Throw '*must declare 10.0.10*'
    Set-TestPackageVersion $repo '10.0.10'
    git -C $repo add -A
    (Assert-LcmPackageVersion $repo).Version | Should -Be '10.0.10'
  }
  It 'validates staged bytes rather than an unstaged correction' {
    [IO.File]::WriteAllText((Join-Path $repo '.agents\rules\Test.md'), "Version: 10.1.0`r`n")
    git -C $repo add -A
    Set-TestPackageVersion $repo '10.1.0'
    { Assert-LcmPackageVersion $repo } | Should -Throw '*must declare 10.1.0*'
    (Assert-LcmPackageVersion $repo -WorkingTree).Version | Should -Be '10.1.0'
  }
  It 'ignores historical snapshots and prose version mentions' {
    [IO.File]::WriteAllText((Join-Path $repo 'docs\Optimizations\old.md'), "Version: 99.0.0`r`n")
    Add-Content -LiteralPath (Join-Path $repo '.agents\rules\Test.md') -Value 'Example version 99.9.9 is not metadata.'
    git -C $repo add -A
    (Assert-LcmPackageVersion $repo).Version | Should -Be '10.0.1'
  }
  It 'fails malformed owned metadata explicitly' {
    [IO.File]::WriteAllText((Join-Path $repo '.agents\rules\Test.md'), "Version: broken`r`n")
    git -C $repo add -A
    { Assert-LcmPackageVersion $repo } | Should -Throw '*Invalid component version*'
  }
}
