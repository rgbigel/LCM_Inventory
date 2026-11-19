<#
.SYNOPSIS
  Tests the LcmRuntimeAtoms PowerShell module.
.DESCRIPTION
  Module: LcmRuntimeAtoms.Tests
  Purpose: Verifies registry resolution of the python runtime and the fail-closed behaviour for unknown keys.
  Path: LCM_Inventory/tests/LcmRuntimeAtoms.Tests.ps1
  Authors: Rolf, Claude (Anthropic)
  Version: 10.7.5
  Date: 2026-11-19
.NOTES
  Part of the CRP-366 verification suite; reads tools.db read-only through tools/Get-LcmRuntime.py.
#>

Describe 'LcmRuntimeAtoms module' {
  BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmRuntimeAtoms.psm1') -Force
  }

  It 'resolves the python runtime to an existing executable' {
    $path = Get-LcmRuntimePath -Key 'python'
    $path | Should -Match 'python\.exe$'
    Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
  }

  It 'returns the cached value on the second call' {
    (Get-LcmRuntimePath) | Should -Be (Get-LcmRuntimePath -Key 'python')
  }

  It 'throws for an unknown runtime key' {
    { Get-LcmRuntimePath -Key 'no-such-runtime' } | Should -Throw '*not usable*'
  }
}
