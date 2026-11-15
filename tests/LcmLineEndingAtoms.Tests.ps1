<#
.SYNOPSIS
  Tests the LcmLineEndingAtoms PowerShell module.
.DESCRIPTION
  Module: LcmLineEndingAtoms.Tests
  Purpose: Verifies byte-level CRLF conversion, idempotence, BOM preservation, type filtering and skip rules.
  Path: LCM_Inventory/tests/LcmLineEndingAtoms.Tests.ps1
  Authors: Rolf, Claude (Anthropic)
  Version: 10.6.4
  Date: 2026-11-15
.NOTES
  Part of CRP-332 verification suite.
#>

Describe 'LcmLineEndingAtoms module' {
  BeforeAll {
    $script:modulePath = Join-Path $PSScriptRoot '..\modules\LcmLineEndingAtoms.psm1'
    Import-Module -Name $script:modulePath -Force
    $script:work = Join-Path ([IO.Path]::GetTempPath()) ('lcm-crlf-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $script:work -Force
  }

  AfterAll {
    if (Test-Path -LiteralPath $script:work) { Remove-Item -LiteralPath $script:work -Recurse -Force }
  }

  It 'expands lone LF and keeps existing CRLF' {
    $in = [byte[]](0x61, 0x0A, 0x62, 0x0D, 0x0A, 0x63, 0x0A)
    $out = ConvertTo-LcmCrlfBytes -Bytes $in
    ($out -join ',') | Should -Be '97,13,10,98,13,10,99,13,10'
  }

  It 'is idempotent' {
    $once = ConvertTo-LcmCrlfBytes -Bytes ([byte[]](0x61, 0x0A, 0x62))
    $twice = ConvertTo-LcmCrlfBytes -Bytes $once
    ($twice -join ',') | Should -Be ($once -join ',')
  }

  It 'handles an empty array' {
    $out = ConvertTo-LcmCrlfBytes -Bytes ([byte[]]@())
    @($out).Count | Should -Be 0
  }

  It 'counts line breaks and detects binary content' {
    $stats = Get-LcmLineEndingStats -Bytes ([byte[]](0x61, 0x0A, 0x0D, 0x0A))
    $stats.LoneLf | Should -Be 1
    $stats.Crlf | Should -Be 1
    (Get-LcmLineEndingStats -Bytes ([byte[]](0x61, 0x00, 0x0A))).Binary | Should -BeTrue
  }

  It 'classifies governed and excluded paths' {
    Test-LcmCrlfCandidatePath -Path 'D:\x\a.ps1' | Should -BeTrue
    Test-LcmCrlfCandidatePath -Path 'D:\x\.gitattributes' | Should -BeTrue
    Test-LcmCrlfCandidatePath -Path 'D:\x\run.sh' | Should -BeFalse
    Test-LcmCrlfCandidatePath -Path 'D:\x\main.go' | Should -BeFalse
    Test-LcmCrlfCandidatePath -Path 'D:\x\.git\config.json' | Should -BeFalse
  }

  It 'converts a file in place and preserves the UTF-8 BOM' {
    $file = Join-Path $script:work 'bom.md'
    [IO.File]::WriteAllBytes($file, [byte[]](0xEF, 0xBB, 0xBF, 0x61, 0x0A, 0x62))
    (Repair-LcmLineEnding -Path $file).Status | Should -Be 'Converted'
    ([IO.File]::ReadAllBytes($file) -join ',') | Should -Be '239,187,191,97,13,10,98'
    (Repair-LcmLineEnding -Path $file).Status | Should -Be 'Clean'
  }

  It 'reports without writing in dry-run mode' {
    $file = Join-Path $script:work 'dry.json'
    [IO.File]::WriteAllBytes($file, [byte[]](0x7B, 0x0A, 0x7D))
    (Repair-LcmLineEnding -Path $file -DryRun).Status | Should -Be 'WouldConvert'
    ([IO.File]::ReadAllBytes($file) -join ',') | Should -Be '123,10,125'
  }

  It 'skips UTF-16 files and non-governed types' {
    $wide = Join-Path $script:work 'wide.txt'
    [IO.File]::WriteAllBytes($wide, [byte[]](0xFF, 0xFE, 0x61, 0x00, 0x0A, 0x00))
    (Repair-LcmLineEnding -Path $wide).Status | Should -Be 'Skipped'
    $sh = Join-Path $script:work 'run.sh'
    [IO.File]::WriteAllBytes($sh, [byte[]](0x61, 0x0A))
    (Repair-LcmLineEnding -Path $sh).Status | Should -Be 'Skipped'
  }

  It 'enumerates candidates without following junctions' {
    $sub = Join-Path $script:work 'sub'
    $null = New-Item -ItemType Directory -Path $sub -Force
    [IO.File]::WriteAllBytes((Join-Path $sub 'x.ps1'), [byte[]](0x61))
    $link = Join-Path $script:work 'link'
    $null = New-Item -ItemType Junction -Path $link -Target $sub
    $found = @(Get-LcmCrlfCandidateFiles -Root $script:work | Where-Object { $_ -like '*x.ps1' })
    $found.Count | Should -Be 1
    [IO.Directory]::Delete($link)
  }
}
