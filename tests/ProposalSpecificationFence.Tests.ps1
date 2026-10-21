Describe 'New-WorkspaceProposal Specification template fences (BUG-302)' {
  BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\modules\ProposalManager.psm1'
    $script:source = Get-Content -LiteralPath $modulePath -Raw -Encoding UTF8
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($script:source, [ref]$tokens, [ref]$errors)
    $function = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'New-WorkspaceProposal'
      }, $true)
    $script:functionText = $function.Extent.Text
    # The expandable here-strings of the function, as the parser sees their literal source text.
    $script:hereStrings = @($tokens | Where-Object {
        $_.Kind -eq 'HereStringExpandable' -and $_.Extent.StartOffset -ge $function.Extent.StartOffset -and $_.Extent.EndOffset -le $function.Extent.EndOffset
      })
  }

  It 'finds the Specification template inside New-WorkspaceProposal' {
    $script:functionText | Should -Not -BeNullOrEmpty
    @($script:hereStrings | Where-Object { $_.Text -match 'Change Request Proposal' }).Count | Should -BeGreaterThan 0
  }

  It 'does not write a backtick directly before text in an expandable here-string (escape character)' {
    foreach ($token in $script:hereStrings) {
      # A backtick followed by a letter is an escape sequence and is removed or altered on expansion.
      $token.Text | Should -Not -Match '(?m)^`[A-Za-z]'
      $token.Text | Should -Not -Match '(?m)^```[A-Za-z]'
    }
  }

  It 'expands the yaml fence from a variable that holds three backticks' {
    $script:functionText | Should -Match ([regex]::Escape('$fence = ''```'''))
    $spec = @($script:hereStrings | Where-Object { $_.Text -match 'Change Request Proposal' })[0]
    $spec.Text | Should -Match ([regex]::Escape('${fence}yaml'))
  }

  It 'expands the template into an intact yaml block' {
    $fence = '```'
    $canonicalId = 'CRP-999'
    $expanded = $ExecutionContext.InvokeCommand.ExpandString((@($script:hereStrings | Where-Object { $_.Text -match 'Change Request Proposal' })[0].Value))
    $lines = $expanded -split "`r?`n"
    ($lines -contains '```yaml') | Should -BeTrue
    ($lines | Where-Object { $_ -eq '```' }).Count | Should -BeGreaterOrEqual 1
    ($lines | Where-Object { $_ -match '^`[a-z]' }).Count | Should -Be 0
  }
}
