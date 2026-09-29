<#
.SYNOPSIS
  Tests shared temporary-tool validation helpers.
#>

Describe 'Tool validation' {
  BeforeAll {
    $modulePath = 'D:\Git_Repositories\.lcm\modules\ToolValidation.psm1'
    Import-Module -Name $modulePath -Force
    $validScript = Join-Path $TestDrive 'valid.ps1'
    $invalidScript = Join-Path $TestDrive 'invalid.ps1'
    Set-Content -LiteralPath $validScript -Value 'Write-Output "valid"' -Encoding UTF8
    Set-Content -LiteralPath $invalidScript -Value 'function {' -Encoding UTF8
  }

  It 'accepts syntactically valid scripts' {
    (Test-ToolScriptSyntax -ScriptPath $validScript).IsValid | Should -BeTrue
  }

  It 'reports syntax errors without throwing' {
    $result = Test-ToolScriptSyntax -ScriptPath $invalidScript
    $result.IsValid | Should -BeFalse
    $result.Errors.Count | Should -BeGreaterThan 0
  }

  It 'recognizes idempotent transforms' {
    $result = Test-ToolIdempotence -InputObject 'Prefix-name' -Transform {
      param($value)
      $value -replace '^(Prefix-)+', 'Prefix-'
    }

    $result.IsIdempotent | Should -BeTrue
  }

  It 'recognizes non-idempotent transforms' {
    $result = Test-ToolIdempotence -InputObject 'value' -Transform {
      param($value)
      "$value!"
    }

    $result.IsIdempotent | Should -BeFalse
  }
}