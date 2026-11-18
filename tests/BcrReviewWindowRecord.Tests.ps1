<#
.SYNOPSIS
    Pester tests for matching the recorded BCR review window by process start time (CRP-346).
.DESCRIPTION
    Module: tests/BcrReviewWindowRecord.Tests.ps1
    Purpose: Test-LcmSameProcessStart (extracted from tools/Invoke-MacriumDailyBcrBaseline.ps1 by AST) matches a start
             time read back through ConvertFrom-Json (DateTime) and as an ISO string, and rejects another instant.
    Path: LCM_Inventory/tests/BcrReviewWindowRecord.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.7.5
    Date: 2026-11-18
#>

Describe 'BCR review window record match (CRP-346)' {
  BeforeAll {
    $path = Join-Path $PSScriptRoot '..\tools\Invoke-MacriumDailyBcrBaseline.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
    $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-LcmSameProcessStart' }, $true)
    if ($null -eq $fn) { throw 'Test-LcmSameProcessStart not found' }
    . ([scriptblock]::Create($fn.Extent.Text))
    $script:start = [datetime]::new(2026, 11, 18, 13, 23, 55, [DateTimeKind]::Local).AddTicks(5519615)
    $script:json = ([ordered]@{ StartTime = $script:start.ToString('o') } | ConvertTo-Json) | ConvertFrom-Json
  }

  It 'matches the start time read back from the JSON record (DateTime)' {
    $script:json.StartTime | Should -BeOfType [datetime]
    Test-LcmSameProcessStart -Recorded $script:json.StartTime -Actual $script:start | Should -BeTrue
  }

  It 'matches the start time given as ISO string' {
    Test-LcmSameProcessStart -Recorded $script:start.ToString('o') -Actual $script:start | Should -BeTrue
  }

  It 'rejects a different start time and an unreadable value' {
    Test-LcmSameProcessStart -Recorded $script:json.StartTime -Actual $script:start.AddSeconds(1) | Should -BeFalse
    Test-LcmSameProcessStart -Recorded 'not a date' -Actual $script:start | Should -BeFalse
  }
}
