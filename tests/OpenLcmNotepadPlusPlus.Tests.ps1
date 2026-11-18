<#
.SYNOPSIS
    Pester tests for the Notepad++ launcher and the activate-window AHK atom (CRP-354).
.DESCRIPTION
    Module: tests/OpenLcmNotepadPlusPlus.Tests.ps1
    Purpose: Path resolution of Open-LcmNotepadPlusPlus.ps1 (dry run: relative against the workspace root, absolute,
             missing files named) and the error exits of Activate-Window.ahk (bad arguments, no window); registration of
             both as non-elevated intents.
    Path: LCM_Inventory/tests/OpenLcmNotepadPlusPlus.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.7.5
    Date: 2026-11-18
#>

BeforeDiscovery {
  Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmAhkAtoms.psm1') -Force
  $script:hasAhk = $null -ne (Get-LcmAhkPath -ErrorAction SilentlyContinue)
}

Describe 'Open-LcmNotepadPlusPlus (CRP-354)' {
  BeforeAll {
    $script:tool = Join-Path $PSScriptRoot '..\tools\Open-LcmNotepadPlusPlus.ps1'
    $script:ws = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  }

  It 'resolves relative paths against the workspace root and names missing files' {
    $plan = & $script:tool 'LCM_Inventory/README.md' 'LCM_Inventory\no-such-file.md' -DryRun
    @($plan.Files) | Should -Contain (Join-Path $script:ws 'LCM_Inventory\README.md')
    @($plan.Missing) | Should -Contain 'LCM_Inventory\no-such-file.md'
  }

  It 'accepts absolute paths' {
    $file = Join-Path $TestDrive 'a.md'
    Set-Content -LiteralPath $file -Value 'x'
    $plan = & $script:tool $file -DryRun
    @($plan.Files) | Should -BeExactly @((Resolve-Path -LiteralPath $file).Path)
  }

  It 'is registered as non-elevated intents together with its atom' {
    $intents = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\config\tool_intents.json') -Raw | ConvertFrom-Json).intents
    $intents.'open-lcmnotepadplusplus'.elevated | Should -BeFalse
    $intents.'activate-window'.elevated | Should -BeFalse
    $intents.'activate-window'.executable | Should -Be 'AutoHotkey64.exe'
  }
}

Describe 'Activate-Window.ahk atom (CRP-354)' -Skip:(-not $script:hasAhk) {
  BeforeAll { Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmAhkAtoms.psm1') -Force }

  It 'refuses bad arguments with exit 2' {
    $r = Invoke-LcmAhkAtom -Intent 'activate-window' -ArgumentList @('not-an-exe') -TimeoutSeconds 20
    $r.ExitCode | Should -Be 2
    $r.Output | Should -Match 'BAD_ARGS'
  }

  It 'reports a missing window with exit 3' {
    $r = Invoke-LcmAhkAtom -Intent 'activate-window' -ArgumentList @('lcm-no-such-process.exe', 'none', '1') -TimeoutSeconds 20
    $r.ExitCode | Should -Be 3
    $r.Output | Should -Match 'NO_WINDOW'
  }
}
