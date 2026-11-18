<#
.SYNOPSIS
    Pester tests for registered AHK atoms (CRP-345).
.DESCRIPTION
    Module: tests/LcmAhkAtoms.Tests.ps1
    Purpose: Verifies Invoke-LcmAhkAtom against an isolated intents file: registered atoms run, unregistered
             requests are refused, an elevation mismatch is refused, and inline AHK code is no longer accepted.
    Path: LCM_Inventory/tests/LcmAhkAtoms.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.2.1
    Date: 2026-11-18
#>

BeforeDiscovery {
  Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmAhkAtoms.psm1') -Force
  $script:ahkAvailable = Test-LcmAhkAvailable
}

Describe 'Registered AHK atoms (CRP-345)' {
  BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmAhkAtoms.psm1') -Force
    $ws = Join-Path $TestDrive 'ws'
    $null = New-Item -ItemType Directory -Path (Join-Path $ws 'LCM_Inventory\config') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $ws 'LCM_Inventory\tools\automation') -Force
    Set-Content -LiteralPath (Join-Path $ws 'LCM_Inventory\tools\automation\Echo-Atom.ahk') -Value @'
#Requires AutoHotkey v2.0
FileAppend("ECHO: " (A_Args.Length ? A_Args[1] : "") "`n", "*")
ExitApp(0)
'@
    Set-Content -LiteralPath (Join-Path $ws 'LCM_Inventory\tools\automation\Echo-Env.ahk') -Value @'
#Requires AutoHotkey v2.0
FileAppend("ENV: ok`n", EnvGet("LCM_AHK_OUT"), "UTF-8")
ExitApp(0)
'@
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    $script:callerElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $registry = [ordered]@{
      intents = [ordered]@{
        'echo-atom'      = [ordered]@{ executable = 'AutoHotkey64.exe'; script = 'LCM_Inventory/tools/automation/Echo-Atom.ahk'; elevated = $script:callerElevated; goal = 'test atom' }
        'echo-mismatch'  = [ordered]@{ executable = 'AutoHotkey64.exe'; script = 'LCM_Inventory/tools/automation/Echo-Atom.ahk'; elevated = (-not $script:callerElevated); goal = 'test atom, other elevation' }
        'echo-env'       = [ordered]@{ executable = 'AutoHotkey64.exe'; script = 'LCM_Inventory/tools/automation/Echo-Env.ahk'; elevated = $script:callerElevated; goal = 'test atom writing to LCM_AHK_OUT' }
        'some-ps-tool'   = [ordered]@{ executable = 'pwsh.exe'; script = 'LCM_Inventory/tools/Some-Tool.ps1'; elevated = $false; goal = 'not an AHK atom' }
      }
    }
    $script:intentsPath = Join-Path $ws 'LCM_Inventory\config\tool_intents.json'
    $registry | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:intentsPath -Encoding UTF8
  }

  It 'lists only AHK atoms from the intents file' {
    $atoms = @(Get-LcmAhkAtomIntents -IntentsPath $script:intentsPath)
    @($atoms.Intent) | Should -BeExactly @('echo-atom', 'echo-mismatch', 'echo-env')
  }

  It 'runs a registered atom with its arguments' -Skip:(-not $script:ahkAvailable) {
    $result = Invoke-LcmAhkAtom -Intent 'echo-atom' -ArgumentList @('hello') -TimeoutSeconds 20 -IntentsPath $script:intentsPath
    $result.Succeeded | Should -BeTrue
    $result.Output | Should -Be 'ECHO: hello'
  }

  It 'collects output an atom writes to LCM_AHK_OUT (no shared-file lock)' -Skip:(-not $script:ahkAvailable) {
    $result = Invoke-LcmAhkAtom -Intent 'echo-env' -TimeoutSeconds 20 -IntentsPath $script:intentsPath
    $result.Succeeded | Should -BeTrue
    $result.Output | Should -Be 'ENV: ok'
  }

  It 'refuses an unregistered AHK request' {
    { Invoke-LcmAhkAtom -Intent 'not-registered' -IntentsPath $script:intentsPath } | Should -Throw '*not a registered AHK atom*'
  }

  It 'refuses a registered non-AHK intent' {
    { Invoke-LcmAhkAtom -Intent 'some-ps-tool' -IntentsPath $script:intentsPath } | Should -Throw '*not a registered AHK atom*'
  }

  It 'refuses an atom whose elevation differs from the caller' {
    { Invoke-LcmAhkAtom -Intent 'echo-mismatch' -IntentsPath $script:intentsPath } | Should -Throw '*change elevation only through the DO*'
  }

  It 'no longer exports the file runner or accepts inline AHK code' {
    Get-Command -Name 'Invoke-LcmAhkScript' -Module LcmAhkAtoms -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\modules\LcmAhkAtoms.psm1') -Raw
    $source | Should -Not -Match '\$InlineScript'
  }
}
