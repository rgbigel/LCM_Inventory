<#
.SYNOPSIS
    Pester tests for the backup type of Start-MacriumDailyBackup.ps1 (CRP-362).
.DESCRIPTION
    Module: tests/MacriumBackupType.Tests.ps1
    Purpose: Get-ReflectArgumentList (extracted by AST) builds -e -full|-diff|-inc <definition>; the parameter defaults to
             Diff and accepts only Full, Diff, Inc.
    Path: LCM_Inventory/tests/MacriumBackupType.Tests.ps1
    Authors: Rolf, Claude
    Version: 10.7.5
    Date: 2026-11-18
#>

Describe 'Macrium backup type (CRP-362)' {
  BeforeAll {
    $script:path = Join-Path $PSScriptRoot '..\tools\Start-MacriumDailyBackup.ps1'
    $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($script:path, [ref]$null, [ref]$null)
    $fn = $script:ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-ReflectArgumentList' }, $true)
    . ([scriptblock]::Create($fn.Extent.Text))
  }

  It 'builds the Reflect command line per type' {
    Get-ReflectArgumentList -Type Diff -DefinitionPath 'X.xml' | Should -Be @('-e', '-diff', 'X.xml')
    Get-ReflectArgumentList -Type Full -DefinitionPath 'X.xml' | Should -Be @('-e', '-full', 'X.xml')
    Get-ReflectArgumentList -Type Inc -DefinitionPath 'X.xml' | Should -Be @('-e', '-inc', 'X.xml')
  }

  It 'defaults to Inc and accepts only Full, Diff, Inc' {
    $param = $script:ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'BackupType' }
    $param.DefaultValue.Value | Should -Be 'Inc'
    $set = $param.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' }
    @($set.PositionalArguments.Value) | Should -Be @('Full', 'Diff', 'Inc')
  }

  It 'passes the type to Reflect' {
    [IO.File]::ReadAllText($script:path) | Should -Match ([regex]::Escape('-ArgumentList (Get-ReflectArgumentList -Type $BackupType -DefinitionPath $BackupDefinitionPath)'))
  }
}
